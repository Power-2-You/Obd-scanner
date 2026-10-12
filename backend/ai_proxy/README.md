# My Garage Hero IQ – AI mechanic proxy

A small Node.js service that sits between the mobile app and the Claude API.

* **The Anthropic API key lives only here** (environment variable). It is never
  compiled into, or sent to, the app.
* Every request is validated and rebuilt from a whitelist. VINs are stripped,
  strings are length-limited, and unknown fields are dropped.
* The answer is constrained to a JSON schema (structured outputs) so the app
  can show *possible causes*, *next checks*, *safety*, *cost outlook* and
  *unknowns* in separate, labelled sections. The "confirmed data" section is
  built by the app from the real scan, not by the AI.
* Logs contain metadata only (status, latency, token counts). Questions, scan
  data and answers are never logged.
* Per-client rate limiting plus a daily request cap to bound cost.
* Server-side refusal fallback (`fallbacks: "default"`) so a safety-classifier
  decline is retried on Anthropic's recommended model instead of failing.

## API

`POST /v1/mechanic` – `content-type: application/json`

```json
{
  "question": "Is it safe to keep driving?",
  "context": {
    "dataOrigin": "live",
    "vehicle": { "make": "Toyota", "model": "Corolla", "year": 2015, "engine": "1.8L" },
    "faultCodes": [{ "code": "P0301", "status": "stored", "description": "Cylinder 1 Misfire Detected", "source": "ECU 7E8 (usually engine)" }],
    "readings": [{ "name": "Engine speed", "value": 760, "unit": "rpm" }],
    "unsupported": ["Control module voltage"],
    "milOn": true
  },
  "history": []
}
```

Response `200`:

```json
{
  "summary": "…",
  "possibleCauses": [{ "cause": "…", "likelihood": "common", "reasoning": "…" }],
  "nextChecks": [{ "step": "…", "who": "workshop", "why": "…" }],
  "safetyLevel": "driveWithCaution",
  "safetyNotes": ["…"],
  "costOutlook": "…",
  "unknowns": ["…"],
  "disclaimer": "AI-generated guidance … not a confirmed mechanical diagnosis …",
  "generatedAt": "2026-10-12T00:00:00.000Z",
  "model": "claude-opus-5-5"
}
```

Errors: `400` invalid request, `401` wrong shared key, `415` wrong content
type, `422` the model declined to answer, `429` rate limited (with
`retry-after`), `502/503` upstream unavailable.

`GET /healthz` – liveness check.

## Run locally

```bash
cd backend/ai_proxy
npm install
npm test                                   # 16 offline tests, no API key needed
ANTHROPIC_API_KEY=sk-ant-... npm start     # listens on :8787
```

Point a development build of the app at it:

```bash
flutter run --dart-define=AI_PROXY_URL=http://<your-computer-LAN-IP>:8787
```

(iOS blocks plain `http://` to the internet; use an HTTPS deployment for
TestFlight/App Store builds.)

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | – (required) | Claude API key |
| `AI_MODEL` | `claude-opus-5-5` | Model id |
| `AI_EFFORT` | `medium` | `low` … `max`; lower is faster/cheaper |
| `PORT` | `8787` | Listen port |
| `APP_SHARED_KEY` | empty | If set, requests must send `x-app-key` with this value |
| `TRUST_PROXY` | `0` | `1` to rate-limit by `x-forwarded-for` behind a load balancer |
| `RATE_BURST` / `RATE_PER_MINUTE` | `5` / `6` | Per-client token bucket |
| `DAILY_CAP` | `2000` | Max requests per UTC day (cost guard) |

## Deploy

Any Node 20+ host works (Fly.io, Render, Google Cloud Run, AWS App Runner…).
A `Dockerfile` is included:

```bash
docker build -t mgh-ai-proxy .
docker run -p 8787:8787 -e ANTHROPIC_API_KEY=sk-ant-... mgh-ai-proxy
```

Always serve it over HTTPS.

## Before production

* `APP_SHARED_KEY` is **not** real authentication – anything shipped in an app
  binary can be extracted. Add Apple **App Attest** (and Google Play Integrity
  for Android) or user accounts before a public launch.
* The in-memory rate limiter is per instance; use Redis or your platform's
  rate limiting when running several instances.
* Review the system prompt in `src/mechanic.js` with your legal/compliance
  team (consumer-advice wording, Australian Consumer Law).
