import http from 'node:http';
import { pathToFileURL } from 'node:url';

import Anthropic from '@anthropic-ai/sdk';

import { askMechanic, DEFAULT_MODEL, MechanicError } from './mechanic.js';
import { TokenBucketLimiter } from './rate_limit.js';
import { LIMITS, parseMechanicRequest, ValidationError } from './validate.js';

const EFFORTS = new Set(['low', 'medium', 'high', 'xhigh', 'max']);

function send(res, status, body, headers = {}) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
    ...headers,
  });
  res.end(payload);
}

function readJson(req, maxBytes) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > maxBytes) {
        reject(new ValidationError('Request body too large'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(new ValidationError('Body is not valid JSON'));
      }
    });
    req.on('error', reject);
  });
}

function clientKey(req, trustProxy) {
  if (trustProxy) {
    const fwd = req.headers['x-forwarded-for'];
    if (typeof fwd === 'string' && fwd.length > 0) return fwd.split(',')[0].trim();
  }
  return req.socket.remoteAddress ?? 'unknown';
}

/**
 * Creates the proxy HTTP handler. Dependencies are injectable for tests.
 * Logs contain only metadata – never the question, context or answer.
 */
export function createHandler({
  client,
  model = DEFAULT_MODEL,
  effort = 'medium',
  limiter = new TokenBucketLimiter(),
  sharedKey = '',
  trustProxy = false,
  log = (entry) => console.log(JSON.stringify(entry)),
}) {
  return async function handler(req, res) {
    const started = Date.now();
    const url = new URL(req.url ?? '/', 'http://localhost');
    const done = (status, extra = {}) =>
      log({ t: new Date().toISOString(), method: req.method, path: url.pathname, status, ms: Date.now() - started, ...extra });

    if (req.method === 'GET' && url.pathname === '/healthz') {
      send(res, 200, { ok: true, model });
      return done(200);
    }
    if (url.pathname !== '/v1/mechanic') {
      send(res, 404, { error: 'not_found' });
      return done(404);
    }
    if (req.method !== 'POST') {
      send(res, 405, { error: 'method_not_allowed' }, { allow: 'POST' });
      return done(405);
    }
    // Optional shared key. NOTE: anything shipped inside an app binary can be
    // extracted, so this only deters casual abuse. Use App Attest / Play
    // Integrity for real client authentication in production.
    if (sharedKey && req.headers['x-app-key'] !== sharedKey) {
      send(res, 401, { error: 'unauthorized' });
      return done(401);
    }
    if (!String(req.headers['content-type'] ?? '').includes('application/json')) {
      send(res, 415, { error: 'unsupported_media_type' });
      return done(415);
    }

    const rl = limiter.take(clientKey(req, trustProxy));
    if (!rl.ok) {
      send(res, 429, { error: 'rate_limited', message: 'Too many questions. Please wait a moment.' },
        { 'retry-after': String(rl.retryAfterSeconds) });
      return done(429, { reason: rl.reason });
    }

    let request;
    try {
      request = parseMechanicRequest(await readJson(req, LIMITS.bodyBytes));
    } catch (err) {
      if (err instanceof ValidationError) {
        send(res, 400, { error: 'invalid_request', message: err.message });
        return done(400);
      }
      throw err;
    }

    try {
      const { answer, usage } = await askMechanic(client, request, { model, effort });
      send(res, 200, answer);
      return done(200, {
        codes: request.context.faultCodes.length,
        origin: request.context.dataOrigin,
        inTok: usage?.input_tokens,
        outTok: usage?.output_tokens,
        cacheRead: usage?.cache_read_input_tokens,
        safety: answer.safetyLevel,
      });
    } catch (err) {
      if (err instanceof MechanicError) {
        send(res, err.status, { error: 'mechanic_unavailable', message: err.publicMessage });
        return done(err.status, { detail: err.detail });
      }
      send(res, 500, { error: 'internal_error', message: 'Something went wrong.' });
      return done(500, { detail: String(err?.message ?? err) });
    }
  };
}

export function startServer(env = process.env) {
  const effort = EFFORTS.has(env.AI_EFFORT) ? env.AI_EFFORT : 'medium';
  // The SDK reads ANTHROPIC_API_KEY from the environment. It is never sent
  // to, or stored in, the mobile app.
  const client = new Anthropic({ maxRetries: 2, timeout: 90_000 });
  const handler = createHandler({
    client,
    model: env.AI_MODEL || DEFAULT_MODEL,
    effort,
    sharedKey: env.APP_SHARED_KEY ?? '',
    trustProxy: env.TRUST_PROXY === '1',
    limiter: new TokenBucketLimiter({
      capacity: Number(env.RATE_BURST ?? 5),
      refillPerMinute: Number(env.RATE_PER_MINUTE ?? 6),
      dailyCap: Number(env.DAILY_CAP ?? 2000),
    }),
  });
  const port = Number(env.PORT ?? 8787);
  const server = http.createServer((req, res) => {
    handler(req, res).catch((err) => {
      console.error(JSON.stringify({ level: 'error', msg: String(err?.message ?? err) }));
      if (!res.headersSent) send(res, 500, { error: 'internal_error' });
    });
  });
  server.requestTimeout = 120_000;
  server.listen(port, () => {
    console.log(JSON.stringify({ msg: 'mgh-ai-proxy listening', port, model: env.AI_MODEL || DEFAULT_MODEL, effort }));
  });
  return server;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  startServer();
}
