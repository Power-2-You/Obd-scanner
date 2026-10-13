// WEB-PREVIEW ONLY. Lets the screenshot / flow-test tooling open the exported
// web build directly at a given screen or pairing phase via the query string,
// e.g. ?screen=pair&state=found or ?screen=faults&scenario=checkEngine.
// On native (Expo Go) readPreview() always returns {} and nothing changes.

import { Platform } from 'react-native';
import { IQ_DEVICE, SCENARIO_ORDER } from './sim';

const KEYS = ['screen', 'state', 'scenario', 'saved'];

// Mapping from ?state= to PairSheet's internal phase. A state that forces a
// scenario does so because that outcome is only honest under that scenario.
const PAIR_STATES = {
  scanning: { phase: 'searching' },
  found: { phase: 'found' },
  connecting: { phase: 'connecting' },
  connected: { phase: 'connected' },
  noVehicle: { phase: 'noVehicle', scenario: 'ignitionOff' },
  failed: { phase: 'failed', scenario: 'scannerBusy' },
};

// Returns { screen, state, scenario, saved } (all optional strings) on web, {} elsewhere.
export function readPreview() {
  if (Platform.OS !== 'web' || typeof window === 'undefined' || !window.location) return {};
  try {
    const params = new URLSearchParams(window.location.search);
    const out = {};
    KEYS.forEach((k) => {
      const v = params.get(k);
      if (v) out[k] = v;
    });
    return out;
  } catch (e) {
    return {};
  }
}

// Turns a preview into App.js INITIAL state. Keys not mentioned by the table
// in the task keep their defaults. `pairPhase` is passed to PairSheet as
// `initialPhase`; `faultsScanned` tells the Faults tab its codes are already read.
export function initialStateFromPreview(preview = readPreview()) {
  const saved = { name: IQ_DEVICE.name };
  const chosen = SCENARIO_ORDER.includes(preview.scenario) ? preview.scenario : 'healthyDriving';
  const base = {
    screen: 'welcome',
    tab: 0,
    connection: 'idle',
    scenario: chosen,
    savedDevice: null,
    sheet: null,
    pairPhase: null,
    faultsScanned: false,
  };
  switch (preview.screen) {
    case 'welcome':
      return preview.saved === '1' ? { ...base, savedDevice: saved } : base;
    case 'reopen':
      return { ...base, savedDevice: saved };
    case 'pair': {
      const state = PAIR_STATES[preview.state] || PAIR_STATES.scanning;
      const connected = state.phase === 'connected';
      return {
        ...base,
        scenario: state.scenario || chosen,
        sheet: { entry: 'search' },
        pairPhase: state.phase,
        connection: connected ? 'connected' : 'idle',
        savedDevice: connected ? saved : null,
      };
    }
    case 'dashboard':
      return { ...base, screen: 'home', tab: 0, connection: 'connected', savedDevice: saved };
    case 'faults':
      return { ...base, screen: 'home', tab: 1, connection: 'connected', savedDevice: saved, faultsScanned: true };
    default:
      return base;
  }
}
