// All simulated data for the mockup. Expo Go cannot use Bluetooth, so every
// device, connection step, reading and fault code here is generated locally
// and labelled as simulated in the data itself. No React in this file.

import { Colors } from './theme';

// Import and assert this wherever devices are rendered so nobody can flip it
// quietly: if (!SIMULATED) throw new Error('This mockup only renders simulated devices')
export const SIMULATED = true;

// Real-app rule: 0–4 bars from RSSI. RSSI is never rendered as text.
export function signalBars(rssi) {
  if (rssi == null) return 0;
  if (rssi >= -60) return 4;
  if (rssi >= -70) return 3;
  if (rssi >= -80) return 2;
  if (rssi >= -90) return 1;
  return 0;
}

function device(name, kind, rssi, appearsAfterMs, compatible) {
  return Object.freeze({
    name,
    kind,
    rssi,
    appearsAfterMs,
    compatible,
    bars: signalBars(rssi),
  });
}

// Device objects deliberately have no `id` field – nothing here is a real
// address, service or identifier.
export const SIM_DEVICES = Object.freeze([
  device("Boost N' Inflate IQ (simulated)", 'obd-scanner', -58, 1800, true),
  device("Jess's Earbuds (simulated)", 'earbuds', -52, 500, false),
  device('Kitchen Speaker (simulated)', 'speaker', -71, 900, false),
  device('Lounge TV (simulated)', 'tv', -83, 1300, false),
  device('Fitness band (simulated)', 'wearable', -66, 2200, false),
]);

export const IQ_DEVICE = SIM_DEVICES.find((d) => d.compatible);
export const OTHER_DEVICES = Object.freeze(SIM_DEVICES.filter((d) => !d.compatible));

// Step titles are identical to the real app; details state what was simulated.
export const CONNECTION_STEPS = Object.freeze([
  Object.freeze({ label: 'Connect to scanner', durationMs: 900, detail: 'Simulated link – Expo Go has no Bluetooth' }),
  Object.freeze({ label: 'Identify scanner', durationMs: 700, detail: 'Simulated scanner – nothing was read from hardware' }),
  Object.freeze({ label: 'Initialise diagnostic session', durationMs: 600, detail: 'Simulated setup commands' }),
  Object.freeze({ label: 'Detect vehicle protocol', durationMs: 1100, detail: 'Simulated vehicle · 13 values supported' }),
]);

export const RETRY_STEP_MS = 1100;

export const SCENARIO_ORDER = Object.freeze(['healthyDriving', 'checkEngine', 'ignitionOff', 'scannerBusy']);

export const SCENARIOS = Object.freeze({
  healthyDriving: Object.freeze({
    key: 'healthyDriving',
    label: 'Healthy drive',
    description: 'Engine warming up, gentle driving, no fault codes.',
  }),
  checkEngine: Object.freeze({
    key: 'checkEngine',
    label: 'Check-engine light',
    description: 'Idling with a cylinder 1 misfire and catalyst code stored.',
  }),
  ignitionOff: Object.freeze({
    key: 'ignitionOff',
    label: 'Ignition off',
    description: 'Scanner powered but the car is off – the bus cannot be reached.',
  }),
  scannerBusy: Object.freeze({
    key: 'scannerBusy',
    label: 'Scanner busy',
    description: 'Another OBD app is holding the scanner, so the link fails.',
  }),
});

// Ready-made `options` for ChipRow: [{ key, label }].
export const SCENARIO_OPTIONS = Object.freeze(SCENARIO_ORDER.map((k) => SCENARIOS[k]));

// Which step (1-based) fails for a scenario, or null when all four succeed.
export function failingStep(scenario) {
  if (scenario === 'ignitionOff') return 4;
  if (scenario === 'scannerBusy') return 1;
  return null;
}

function round1(x) {
  return Math.round(x * 10) / 10;
}

function gearSpeed(speed) {
  if (speed < 18) return 18;
  if (speed < 35) return 35;
  if (speed < 55) return 55;
  return 80;
}

// Value generator using the real app's simulated-vehicle formulas.
// sample(tSeconds) returns one reading of every metric the dashboard shows.
export function makeVehicle(scenario) {
  const driving = scenario === 'healthyDriving';
  const checkEngine = scenario === 'checkEngine';

  function sample(t) {
    const phase = Math.sin((Math.PI * (t % 90)) / 90);
    const speed = driving ? Math.round(62 * phase * phase) : 0;
    const rpm = driving
      ? 820 + 1900 * (speed / gearSpeed(speed)) + 40 * Math.sin(2.1 * t)
      : 760 + 18 * Math.sin(1.7 * t) + (checkEngine ? 60 * Math.sin(7.3 * t) : 0);
    const coolant = 38 + 52 * (1 - Math.exp(-t / 140));
    const throttle = driving ? 15 + 0.35 * speed + 6 * Math.abs(Math.sin(0.9 * t)) : 14.5;
    const load = driving ? 22 + 0.45 * speed : 24 + 3 * Math.sin(0.7 * t);
    const voltage = round1(14.1 + 0.08 * Math.sin(0.5 * t));
    return {
      t,
      speed,
      rpm: Math.round(rpm),
      coolant: Math.round(coolant),
      throttle: Math.round(throttle),
      load: Math.round(load),
      voltage,
      battery: round1(voltage - 0.1),
      dtcCount: checkEngine ? 3 : 0,
      milOn: checkEngine,
    };
  }

  return { scenario, simulated: SIMULATED, sample };
}

export const DTC_META = 'Powertrain · Generic (SAE J2012) · ECU 7E8 (usually engine)';

export const DTC_LEVELS = Object.freeze({
  checkSoon: 'Check soon',
  inspectPromptly: 'Inspect promptly',
});

// Guidance colour for a severity label (rule-based general information – not
// a diagnosis).
export function guidanceColor(level) {
  return level === DTC_LEVELS.inspectPromptly ? Colors.caution : Colors.yellow;
}

function dtc(code, description, level) {
  return Object.freeze({ code, description, level, meta: DTC_META });
}

const NO_CODES = Object.freeze({ stored: Object.freeze([]), pending: Object.freeze([]) });

export const DTC_FIXTURES = Object.freeze({
  healthyDriving: NO_CODES,
  ignitionOff: NO_CODES,
  scannerBusy: NO_CODES,
  checkEngine: Object.freeze({
    stored: Object.freeze([
      dtc('P0301', 'Cylinder 1 Misfire Detected', DTC_LEVELS.inspectPromptly),
      dtc('P0420', 'Catalyst System Efficiency Below Threshold (Bank 1)', DTC_LEVELS.checkSoon),
      dtc('P0171', 'System Too Lean (Bank 1)', DTC_LEVELS.checkSoon),
    ]),
    pending: Object.freeze([
      dtc('P0302', 'Cylinder 2 Misfire Detected', DTC_LEVELS.inspectPromptly),
    ]),
  }),
});

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function pad2(n) {
  return n < 10 ? `0${n}` : String(n);
}

function clock(date, seconds) {
  const h24 = date.getHours();
  const h = h24 % 12 === 0 ? 12 : h24 % 12;
  const meridiem = h24 < 12 ? 'am' : 'pm';
  const mins = pad2(date.getMinutes());
  const secs = seconds ? `:${pad2(date.getSeconds())}` : '';
  return `${h}:${mins}${secs} ${meridiem}`;
}

// en-AU, 12-hour, no leading zero, lower-case meridiem: '12:16 pm' / '12:16:22 pm'.
export function fmtTime(date = new Date(), { seconds = false } = {}) {
  return clock(date, seconds);
}

// '12:16 pm, 13 Oct'
export function fmtScan(date = new Date()) {
  return `${clock(date, false)}, ${date.getDate()} ${MONTHS[date.getMonth()]}`;
}

export function greeting(date = new Date()) {
  const h = date.getHours();
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}
