// Request validation and sanitisation.
//
// The proxy never forwards the client's JSON as-is. It rebuilds a minimal,
// whitelisted context object so that unexpected fields, oversized strings or
// personal data (VINs) cannot reach the model or the logs.

export const LIMITS = Object.freeze({
  bodyBytes: 32 * 1024,
  question: 500,
  historyTurns: 6,
  historyText: 1200,
  faultCodes: 30,
  readings: 40,
  unsupported: 40,
  shortText: 200,
});

const DTC = /^[PCBU][0-3][0-9A-F]{3}$/;
// 17-char VIN alphabet token containing at least one non-hex letter.
const VIN = /(?<![A-Z0-9])(?=[A-HJ-NPR-Z0-9]{0,16}[G-HJ-NPR-Z])[A-HJ-NPR-Z0-9]{17}(?![A-Z0-9])/gi;

export class ValidationError extends Error {}

export function scrubVin(text) {
  return text.replace(VIN, '[VIN removed]');
}

function str(value, max, field, { required = false } = {}) {
  if (value === undefined || value === null || value === '') {
    if (required) throw new ValidationError(`${field} is required`);
    return null;
  }
  if (typeof value !== 'string') throw new ValidationError(`${field} must be a string`);
  // Strip control characters, collapse whitespace, truncate.
  const clean = value.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '').trim();
  return scrubVin(clean.slice(0, max));
}

function num(value, field) {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new ValidationError(`${field} must be a finite number`);
  }
  return Math.round(value * 100) / 100;
}

function list(value, max, field) {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw new ValidationError(`${field} must be an array`);
  return value.slice(0, max);
}

/**
 * Validates the POST /v1/mechanic body and returns a sanitised request:
 * { question, context, history }.
 */
export function parseMechanicRequest(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new ValidationError('Body must be a JSON object');
  }
  const question = str(body.question, LIMITS.question, 'question', { required: true });
  if (question.length < 2) throw new ValidationError('question is too short');

  const c = body.context ?? {};
  if (typeof c !== 'object' || Array.isArray(c)) throw new ValidationError('context must be an object');

  const dataOrigin = c.dataOrigin === 'live' ? 'live' : 'simulated';

  let vehicle = null;
  if (c.vehicle && typeof c.vehicle === 'object') {
    const year = Number.isInteger(c.vehicle.year) && c.vehicle.year > 1950 && c.vehicle.year < 2100
      ? c.vehicle.year
      : null;
    vehicle = {
      make: str(c.vehicle.make, 60, 'vehicle.make'),
      model: str(c.vehicle.model, 60, 'vehicle.model'),
      year,
      engine: str(c.vehicle.engine, 80, 'vehicle.engine'),
    };
  }

  const faultCodes = list(c.faultCodes, LIMITS.faultCodes, 'faultCodes').map((f, i) => {
    if (!f || typeof f !== 'object') throw new ValidationError(`faultCodes[${i}] must be an object`);
    const code = typeof f.code === 'string' ? f.code.toUpperCase() : '';
    if (!DTC.test(code)) throw new ValidationError(`faultCodes[${i}].code is not a valid DTC`);
    const status = ['stored', 'pending', 'permanent'].includes(f.status) ? f.status : 'stored';
    return {
      code,
      status,
      description: str(f.description, LIMITS.shortText, 'description'),
      definition: str(f.definition, 60, 'definition'),
      system: str(f.system, 40, 'system'),
      subsystem: str(f.subsystem, 120, 'subsystem'),
      source: str(f.source, 80, 'source'),
    };
  });

  const readings = list(c.readings, LIMITS.readings, 'readings').map((r, i) => {
    if (!r || typeof r !== 'object') throw new ValidationError(`readings[${i}] must be an object`);
    return {
      name: str(r.name, 100, `readings[${i}].name`, { required: true }),
      value: num(r.value, `readings[${i}].value`),
      unit: str(r.unit, 12, `readings[${i}].unit`) ?? '',
    };
  });

  const unsupported = list(c.unsupported, LIMITS.unsupported, 'unsupported')
    .map((u, i) => str(u, 100, `unsupported[${i}]`))
    .filter(Boolean);

  const history = list(body.history, LIMITS.historyTurns, 'history').map((h, i) => {
    if (!h || (h.role !== 'user' && h.role !== 'assistant')) {
      throw new ValidationError(`history[${i}].role must be user or assistant`);
    }
    return { role: h.role, text: str(h.text, LIMITS.historyText, `history[${i}].text`, { required: true }) };
  });
  // The Messages API needs alternating turns starting with the user.
  for (let i = 0; i < history.length; i++) {
    if (history[i].role !== (i % 2 === 0 ? 'user' : 'assistant')) {
      throw new ValidationError('history must alternate user/assistant, starting with user');
    }
  }
  if (history.length % 2 !== 0) throw new ValidationError('history must end with an assistant turn');

  return {
    question,
    history,
    context: {
      dataOrigin,
      vehicle,
      faultCodes,
      readings,
      unsupported,
      milOn: typeof c.milOn === 'boolean' ? c.milOn : null,
      reportedDtcCount: Number.isInteger(c.reportedDtcCount) ? c.reportedDtcCount : null,
      protocol: str(c.protocol, 80, 'protocol'),
    },
  };
}
