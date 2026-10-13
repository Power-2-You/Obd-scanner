// Pair device sheet – the "earphone moment". A bottom sheet (SheetFrame = RN
// Modal, transparent, animationType none, own backdrop fade + slide) running the
// pairing state machine:
//   searching -> found -> connecting -> connected | noVehicle | failed
// Every device, step and outcome is simulated: Expo Go cannot use Bluetooth.
// The sheet never changes the demo scenario by itself.

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Animated, Easing, LayoutAnimation, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { MaterialCommunityIcons as Icon } from '@expo/vector-icons';
import { Colors, alpha, Radii, Type } from '../theme';
import {
  SIMULATED,
  SIM_DEVICES,
  IQ_DEVICE,
  OTHER_DEVICES,
  CONNECTION_STEPS,
  RETRY_STEP_MS,
  SCENARIO_OPTIONS,
  failingStep,
} from '../sim';
import {
  MghCard,
  Pill,
  SimulatedBanner,
  InfoNote,
  SectionTitle,
  StatusDot,
  FilledButton,
  OutlinedButton,
  TextButton,
  SignalBars,
  Spinner,
  ChipRow,
  KeyValueRow,
  Divider,
  FadeIn,
  SheetFrame,
} from '../components';
import IqHeroGraphic from '../IqHeroGraphic';

if (!SIMULATED) throw new Error('This mockup only renders simulated devices');

const NATIVE_DRIVER = Platform.OS !== 'web';
const IS_NATIVE = Platform.OS !== 'web';

const BUMP_MS = 110;
const BORDER_IN_MS = 200;
const STEP_ICON_MS = 180;
const PROGRESS_FADE_MS = 200;
const CARD_REVEAL_MS = 200;
const TICK_FADE_MS = 150;
const TIP_FLASH_MS = 600;
const LAST_STEP = CONNECTION_STEPS.length - 1;

const PHASE_TITLES = {
  searching: 'Pair device',
  found: 'Pair device',
  connecting: 'Connecting…',
  connected: 'Demo scanner connected',
  noVehicle: 'Scanner ready · vehicle not responding',
  failed: 'Connection failed',
};

const CONNECTED_ROWS = [
  ['Scanner', 'Demo scanner (simulated)'],
  ['Link', 'Simulated scanner'],
  ['Vehicle', 'Demo vehicle (simulated)'],
  ['Device ID', 'Not available – simulated'],
  ['Pairing', 'No PIN – in-app only'],
  ['Access', 'Read-only'],
];

const ALL_NAMES = SIM_DEVICES.map((d) => d.name);
const PENDING_STEPS = CONNECTION_STEPS.map(() => 'pending');
const DONE_STEPS = CONNECTION_STEPS.map(() => 'done');

function layoutNext() {
  if (IS_NATIVE) LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
}

// Starting state for each phase (also used by the web-preview initialPhase).
function stateFor(phase) {
  switch (phase) {
    case 'found':
      return {
        seen: SIM_DEVICES.filter((d) => d.appearsAfterMs <= IQ_DEVICE.appearsAfterMs).map((d) => d.name),
        steps: PENDING_STEPS,
        showDemo: false,
      };
    case 'connecting':
      return { seen: ALL_NAMES, steps: PENDING_STEPS, showDemo: false };
    case 'connected':
      return { seen: ALL_NAMES, steps: DONE_STEPS, showDemo: false };
    case 'noVehicle':
      return { seen: ALL_NAMES, steps: CONNECTION_STEPS.map((_, i) => (i === LAST_STEP ? 'failed' : 'done')), showDemo: true };
    case 'failed':
      return { seen: ALL_NAMES, steps: CONNECTION_STEPS.map((_, i) => (i === 0 ? 'failed' : 'pending')), showDemo: true };
    case 'searching':
    default:
      return { seen: [], steps: PENDING_STEPS, showDemo: false };
  }
}

// A group of setTimeout handles that can be cleared together.
function useTimerGroup() {
  const ids = useRef([]);
  const api = useMemo(
    () => ({
      later(fn, ms) {
        const id = setTimeout(() => {
          ids.current = ids.current.filter((t) => t !== id);
          fn();
        }, ms);
        ids.current.push(id);
        return id;
      },
      clear() {
        ids.current.forEach(clearTimeout);
        ids.current = [];
      },
    }),
    [],
  );
  useEffect(() => () => api.clear(), [api]);
  return api;
}

function Gap({ h = 0, w = 0 }) {
  return <View style={{ height: h, width: w }} />;
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

function OtherDeviceRow({ device }) {
  return (
    <FadeIn style={styles.otherRowWrap}>
      <MghCard padding={{ h: 16, v: 14 }} style={styles.otherRow}>
        <View style={styles.row}>
          <Icon name="bluetooth" size={22} color={Colors.faint} />
          <Gap w={12} />
          {/* Name above the pill (not beside it): at 360 px a one-line row
              truncates "Jess's Earbuds (simulated)" to "Jess's …". */}
          <View style={styles.flex1}>
            <Text style={styles.otherName} numberOfLines={1}>
              {device.name}
            </Text>
            <Pill label="Other Bluetooth device" color={Colors.faint} style={styles.otherPill} />
          </View>
          <Gap w={10} />
          <SignalBars bars={device.bars} lit={Colors.faint} animateIn />
        </View>
      </MghCard>
    </FadeIn>
  );
}

function StepRow({ label, detail, state }) {
  const titleOn = useRef(new Animated.Value(state === 'pending' ? 0 : 1)).current;
  const doneIn = useRef(new Animated.Value(state === 'done' ? 1 : 0)).current;
  useEffect(() => {
    const anims = [
      Animated.timing(titleOn, { toValue: state === 'pending' ? 0 : 1, duration: STEP_ICON_MS, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER }),
    ];
    if (state === 'done') {
      anims.push(Animated.timing(doneIn, { toValue: 1, duration: STEP_ICON_MS, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER }));
    } else {
      doneIn.setValue(0);
    }
    anims.forEach((a) => a.start());
    return () => anims.forEach((a) => a.stop());
  }, [state, titleOn, doneIn]);

  let icon = null;
  if (state === 'running') icon = <Spinner size={22} />;
  else if (state === 'done') {
    icon = (
      <Animated.View style={{ opacity: doneIn }}>
        <Icon name="check-circle" size={22} color={Colors.success} />
      </Animated.View>
    );
  } else if (state === 'failed') icon = <Icon name="close-circle" size={22} color={Colors.danger} />;
  else icon = <Icon name="radiobox-blank" size={22} color={Colors.faint} />;

  return (
    <View style={styles.stepRow} accessibilityLabel={`${label}: ${state}`}>
      <View style={styles.stepIconBox}>{icon}</View>
      <Gap w={12} />
      <View style={styles.stepBody}>
        {/* Colour tween via opacity swap: faint title underneath, white title fading in on top. */}
        <View>
          <Text style={[styles.stepTitle, styles.stepTitlePending]}>{label}</Text>
          <Animated.Text style={[styles.stepTitle, styles.stepTitleOverlay, { opacity: titleOn }]}>{label}</Animated.Text>
        </View>
        {state === 'done' ? <Text style={styles.stepDetail}>{detail}</Text> : null}
      </View>
    </View>
  );
}

// The IQ device card. Scales in once on mount; the highlight border is an
// absolute overlay so it can fade in. Whole card = Connect while `pressable`.
function IqCard({ name, phase, pressable, onConnect }) {
  const scale = useRef(new Animated.Value(0.96)).current;
  const border = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const anim = Animated.parallel([
      Animated.spring(scale, { toValue: 1, damping: 14, stiffness: 160, mass: 1, useNativeDriver: NATIVE_DRIVER }),
      Animated.timing(border, { toValue: 1, duration: BORDER_IN_MS, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER }),
    ]);
    anim.start();
    return () => anim.stop();
  }, [scale, border]);

  return (
    <Pressable
      disabled={!pressable}
      onPress={onConnect}
      accessibilityRole="button"
      accessibilityLabel={pressable ? `Connect to ${name}` : name}
      style={({ pressed }) => (pressed && pressable ? styles.pressedCard : null)}
    >
      <Animated.View style={{ transform: [{ scale }] }}>
        <MghCard padding={18} style={styles.iqCard}>
          <IqHeroGraphic size={150} animate active />
          <Gap h={10} />
          <Text style={styles.iqName}>{name}</Text>
          <Gap h={6} />
          <View style={styles.rowCentre}>
            <Pill label="Simulated IQ" color={Colors.yellow} />
            <Gap w={8} />
            <SignalBars bars={IQ_DEVICE.bars} animateIn />
            <Gap w={6} />
            <Text style={styles.signalCaption}>Strong signal (simulated)</Text>
          </View>
          {phase === 'found' ? (
            <View style={styles.fullWidth}>
              <Gap h={14} />
              <FilledButton label="Connect" onPress={onConnect} />
              <Gap h={8} />
              <Text style={styles.noPin}>No PIN needed – tap Connect and the app does the rest.</Text>
            </View>
          ) : null}
          {phase === 'connecting' ? (
            <View style={styles.fullWidth}>
              <Gap h={14} />
              <View style={styles.rowCentre}>
                <Spinner size={16} />
                <Gap w={8} />
                <Text style={styles.connectingText}>Connecting…</Text>
              </View>
            </View>
          ) : null}
        </MghCard>
        <Animated.View pointerEvents="none" style={[styles.iqBorder, { opacity: border }]} />
      </Animated.View>
    </Pressable>
  );
}

function ConnectedCard({ animateIn, primaryLabel, onPrimary, onDisconnect }) {
  const reveal = useRef(new Animated.Value(animateIn ? 0 : 1)).current;
  const tickScale = useRef(new Animated.Value(animateIn ? 0.6 : 1)).current;
  const tickOpacity = useRef(new Animated.Value(animateIn ? 0 : 1)).current;
  useEffect(() => {
    if (!animateIn) return undefined;
    const anim = Animated.parallel([
      Animated.timing(reveal, { toValue: 1, duration: CARD_REVEAL_MS, easing: Easing.out(Easing.cubic), useNativeDriver: NATIVE_DRIVER }),
      Animated.spring(tickScale, { toValue: 1, bounciness: 8, useNativeDriver: NATIVE_DRIVER }),
      Animated.timing(tickOpacity, { toValue: 1, duration: TICK_FADE_MS, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER }),
    ]);
    anim.start();
    return () => anim.stop();
  }, [animateIn, reveal, tickScale, tickOpacity]);
  const translateY = reveal.interpolate({ inputRange: [0, 1], outputRange: [16, 0] });

  return (
    <Animated.View style={{ opacity: reveal, transform: [{ translateY }] }}>
      <MghCard highlight>
        <Animated.View style={[styles.tickCircle, { opacity: tickOpacity, transform: [{ scale: tickScale }] }]}>
          <Icon name="check" size={32} color={Colors.yellow} />
        </Animated.View>
        <Gap h={14} />
        <View style={styles.row}>
          <StatusDot color={Colors.yellow} size={10} />
          <Gap w={10} />
          <Text style={[Type.titleLarge, styles.flex1]}>Demo scanner connected</Text>
          <Pill label="Simulated" color={Colors.yellow} />
        </View>
        <Gap h={6} />
        <Text style={Type.bodyMuted}>Your IQ is paired with this demo. Head to the dashboard to see live data.</Text>
        <Gap h={14} />
        {CONNECTED_ROWS.map(([k, v]) => (
          <KeyValueRow key={k} k={k} v={v} />
        ))}
        <Gap h={14} />
        {/* Stacked so the primary label never wraps at phone widths – one obvious action, like the earphones sheet. */}
        <FilledButton label={primaryLabel} onPress={onPrimary} />
        <Gap h={10} />
        <OutlinedButton label="Disconnect" onPress={onDisconnect} />
      </MghCard>
    </Animated.View>
  );
}

function ShowHideButton({ shown, onPress }) {
  return <TextButton label={shown ? 'Hide' : 'Show'} icon={shown ? 'chevron-up' : 'chevron-down'} onPress={onPress} />;
}

// ---------------------------------------------------------------------------
// Sheet
// ---------------------------------------------------------------------------

export default function PairSheet({
  visible,
  entry = 'search',
  scenario: scenarioProp,
  onScenarioChange,
  savedDevice,
  onConnected,
  onDisconnect,
  onGoToDashboard,
  onClose,
  connection,
  screen = 'welcome',
  initialPhase,
  initialScenario,
  initialStep = 1,
}) {
  // Scenario is normally global (controlled by App.js); the local fallback
  // keeps the sheet usable on its own and seeds the web preview.
  const [localScenario, setLocalScenario] = useState(initialScenario || 'healthyDriving');
  const scenario = scenarioProp != null ? scenarioProp : localScenario;
  const scenarioRef = useRef(scenario);
  scenarioRef.current = scenario;

  const startPhase = initialPhase && PHASE_TITLES[initialPhase] ? initialPhase : null;
  const first = useRef({ phase: startPhase || 'searching', ...stateFor(startPhase || 'searching') }).current;
  const [phase, setPhase] = useState(first.phase);
  const [seen, setSeen] = useState(first.seen);
  const [steps, setSteps] = useState(first.steps);
  const [showOthers, setShowOthers] = useState(false);
  const [showDemo, setShowDemo] = useState(first.showDemo);
  // Connecting -> connected reveal: 'fading' (progress card fading out) ->
  // 'animate' (connected card sliding in) ; 'static' = no reveal animation.
  const [reveal, setReveal] = useState('static');

  const scanTimers = useTimerGroup();
  const stepTimers = useTimerGroup();
  const progressOpacity = useRef(new Animated.Value(1)).current;
  const bump = useRef(new Animated.Value(1)).current;
  const tipFlash = useRef(new Animated.Value(0)).current;
  const anims = useRef([]);

  // Latest callbacks for use inside timers.
  const cb = useRef({});
  cb.current = { onConnected, onScenarioChange };

  const runAnim = useCallback((anim) => {
    anims.current.push(anim);
    anim.start(() => {
      anims.current = anims.current.filter((a) => a !== anim);
    });
  }, []);
  useEffect(
    () => () => {
      anims.current.forEach((a) => a.stop());
      anims.current = [];
    },
    [],
  );

  const enterConnected = useCallback(
    (animated) => {
      setSteps(DONE_STEPS);
      setPhase('connected');
      setReveal(animated ? 'fading' : 'static');
      if (cb.current.onConnected) cb.current.onConnected();
    },
    [],
  );

  // Runs CONNECTION_STEPS sequentially from `from`, evaluating the current
  // scenario honestly at each step.
  const runSteps = useCallback(
    (from) => {
      stepTimers.clear();
      setSteps(CONNECTION_STEPS.map((_, i) => (i < from ? 'done' : i === from ? 'running' : 'pending')));
      const tick = (i) => {
        stepTimers.later(() => {
          if (failingStep(scenarioRef.current) === i + 1) {
            setSteps((prev) => prev.map((s, j) => (j === i ? 'failed' : s)));
            setShowDemo(true);
            setPhase(i === 0 ? 'failed' : 'noVehicle');
            return;
          }
          if (i === LAST_STEP) {
            enterConnected(true);
            return;
          }
          setSteps((prev) => prev.map((s, j) => (j === i ? 'done' : j === i + 1 ? 'running' : s)));
          tick(i + 1);
        }, CONNECTION_STEPS[i].durationMs);
      };
      tick(from);
    },
    [stepTimers, enterConnected],
  );

  // Devices tick in at their appearsAfterMs (minus time already "elapsed").
  const scheduleDiscovery = useCallback(
    (elapsedMs) => {
      scanTimers.clear();
      SIM_DEVICES.forEach((d) => {
        if (d.appearsAfterMs <= elapsedMs) return;
        scanTimers.later(() => {
          setSeen((prev) => (prev.includes(d.name) ? prev : [...prev, d.name]));
          if (d.compatible) setPhase((p) => (p === 'searching' ? 'found' : p));
        }, d.appearsAfterMs - elapsedMs);
      });
    },
    [scanTimers],
  );

  const enterPhase = useCallback(
    (p, opts = {}) => {
      scanTimers.clear();
      stepTimers.clear();
      const s = stateFor(p);
      setPhase(p);
      setSeen(s.seen);
      setSteps(s.steps);
      setShowDemo(s.showDemo);
      setShowOthers(false);
      setReveal('static');
      progressOpacity.setValue(1);
      tipFlash.setValue(0);
      if (p === 'searching') scheduleDiscovery(0);
      else if (p === 'found') scheduleDiscovery(IQ_DEVICE.appearsAfterMs);
      else if (p === 'connecting') runSteps(opts.stepFrom || 0);
      else if (p === 'connected' && !opts.alreadyConnected) enterConnected(false);
    },
    [scanTimers, stepTimers, progressOpacity, tipFlash, scheduleDiscovery, runSteps, enterConnected],
  );

  // Entry mapping each time the sheet opens; the web-preview initialPhase
  // wins on the very first open only.
  const pendingInitial = useRef(startPhase);
  useEffect(() => {
    if (!visible) {
      scanTimers.clear();
      stepTimers.clear();
      return;
    }
    const initial = pendingInitial.current;
    pendingInitial.current = null;
    if (initial) {
      enterPhase(initial, { stepFrom: initial === 'connecting' ? initialStep : 0 });
    } else if (entry === 'reconnect') {
      enterPhase('connecting');
    } else if (entry === 'status' && connection === 'connected') {
      enterPhase('connected', { alreadyConnected: true });
    } else {
      enterPhase('searching');
    }
    // Only re-run when visibility flips; entry/connection are read at open time.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  // Count pill bump whenever the number found changes (not on first render).
  const seenCount = seen.length;
  const lastCount = useRef(seenCount);
  useEffect(() => {
    if (lastCount.current === seenCount) return;
    lastCount.current = seenCount;
    bump.setValue(1);
    runAnim(
      Animated.sequence([
        Animated.timing(bump, { toValue: 1.15, duration: BUMP_MS, easing: Easing.out(Easing.quad), useNativeDriver: NATIVE_DRIVER }),
        Animated.timing(bump, { toValue: 1, duration: BUMP_MS, easing: Easing.in(Easing.quad), useNativeDriver: NATIVE_DRIVER }),
      ]),
    );
  }, [seenCount, bump, runAnim]);

  // Connected reveal: fade the progress card, then slide the connected card in.
  useEffect(() => {
    if (phase !== 'connected' || reveal !== 'fading') return undefined;
    const anim = Animated.timing(progressOpacity, { toValue: 0, duration: PROGRESS_FADE_MS, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER });
    let cancelled = false;
    anim.start(({ finished }) => {
      if (finished && !cancelled) setReveal('animate');
    });
    return () => {
      cancelled = true;
      anim.stop();
    };
  }, [phase, reveal, progressOpacity]);

  // ---- interactions -------------------------------------------------------

  const startConnect = useCallback(() => {
    if (phase !== 'found') return;
    scanTimers.clear();
    setSeen(ALL_NAMES);
    setShowOthers(false);
    setPhase('connecting');
    progressOpacity.setValue(1);
    runSteps(0);
  }, [phase, scanTimers, progressOpacity, runSteps]);

  // Cancel (connecting) / Dismiss (failed): back to found, devices stay listed.
  const backToFound = useCallback(() => {
    stepTimers.clear();
    setSteps(PENDING_STEPS);
    setPhase('found');
  }, [stepTimers]);

  const retry = useCallback(() => {
    if (steps[LAST_STEP] === 'running') return;
    stepTimers.clear();
    setSteps((prev) => prev.map((s, i) => (i === LAST_STEP ? 'running' : s)));
    stepTimers.later(() => {
      if (failingStep(scenarioRef.current) === LAST_STEP + 1) {
        setSteps((prev) => prev.map((s, i) => (i === LAST_STEP ? 'failed' : s)));
        tipFlash.setValue(1);
        // Background colour is not a native-driver prop.
        runAnim(Animated.timing(tipFlash, { toValue: 0, duration: TIP_FLASH_MS, easing: Easing.out(Easing.quad), useNativeDriver: false }));
        return;
      }
      enterConnected(true);
    }, RETRY_STEP_MS);
  }, [steps, stepTimers, tipFlash, runAnim, enterConnected]);

  const handleClose = useCallback(() => {
    if (phase === 'connecting') {
      backToFound();
      return;
    }
    if (onClose) onClose();
  }, [phase, backToFound, onClose]);

  const changeScenario = useCallback(
    (key) => {
      setLocalScenario(key);
      if (cb.current.onScenarioChange) cb.current.onScenarioChange(key);
    },
    [],
  );

  const toggleOthers = useCallback(() => {
    layoutNext();
    setShowOthers((v) => !v);
  }, []);
  const toggleDemo = useCallback(() => {
    layoutNext();
    setShowDemo((v) => !v);
  }, []);

  // ---- render -------------------------------------------------------------

  const deviceName = (savedDevice && savedDevice.name) || IQ_DEVICE.name;
  const othersSeen = OTHER_DEVICES.filter((d) => seen.includes(d.name));
  const listing = phase === 'searching' || phase === 'found';
  const showIqCard = phase === 'found' || phase === 'connecting' || phase === 'noVehicle' || phase === 'failed' || (phase === 'connected' && reveal === 'fading');
  const showProgress = phase === 'connecting' || phase === 'noVehicle' || phase === 'failed' || (phase === 'connected' && reveal === 'fading');
  const showConnectedCard = phase === 'connected' && reveal !== 'fading';
  const primaryIsDone = entry === 'status' && screen !== 'welcome';

  const headerExtra = listing ? (
    <Animated.View style={[styles.countPill, { transform: [{ scale: bump }] }]}>
      <Pill label={`${seenCount} found`} color={Colors.yellow} />
    </Animated.View>
  ) : null;

  const tipBackground = tipFlash.interpolate({
    inputRange: [0, 1],
    outputRange: [alpha(Colors.yellow, 0), alpha(Colors.yellow, 0.12)],
  });

  const demoChips = (
    <ChipRow options={SCENARIO_OPTIONS} value={scenario} onChange={changeScenario} />
  );

  return (
    <SheetFrame
      visible={visible}
      title={PHASE_TITLES[phase]}
      titleStyle={phase === 'noVehicle' ? styles.cautionTitle : null}
      headerExtra={headerExtra}
      onRequestClose={handleClose}
      closeAccessibilityLabel={phase === 'connecting' ? 'Cancel connecting' : 'Close'}
    >
      <SimulatedBanner compact />
      <Gap h={16} />

      {phase === 'searching' ? (
        <View style={styles.centre}>
          <IqHeroGraphic size={120} animate radar active={false} />
          <Gap h={8} />
          <Text style={[Type.titleLarge, styles.centreText]}>Searching nearby…</Text>
          <Gap h={6} />
          <Text style={[Type.bodyMuted, styles.centreText]}>Keep your phone close to the IQ. This takes a few seconds.</Text>
        </View>
      ) : null}

      {showIqCard || showProgress ? (
        <Animated.View style={{ opacity: progressOpacity }}>
          {showIqCard ? <IqCard name={deviceName} phase={phase} pressable={phase === 'found'} onConnect={startConnect} /> : null}
          {showProgress ? (
            <View>
              <Gap h={12} />
              <MghCard highlight={phase === 'failed'}>
                {CONNECTION_STEPS.map((s, i) => (
                  <StepRow key={s.label} label={s.label} detail={s.detail} state={steps[i]} />
                ))}

                {phase === 'connecting' ? (
                  <View>
                    <Gap h={14} />
                    <OutlinedButton label="Cancel" onPress={backToFound} />
                  </View>
                ) : null}

                {phase === 'noVehicle' ? (
                  <View>
                    <Divider />
                    <InfoNote icon="key-outline" color={Colors.caution} text="The vehicle did not answer. Turn the ignition on and try again." />
                    <Gap h={10} />
                    <Animated.View style={[styles.tipRow, { backgroundColor: tipBackground }]}>
                      <InfoNote
                        icon="flask-outline"
                        color={Colors.yellow}
                        text="Demo tip: in the real car you'd turn the key. Here, switch the scenario to Healthy drive, then tap try again."
                      />
                    </Animated.View>
                    <Gap h={10} />
                    <SectionTitle title="DEMO SCENARIO" style={styles.innerSection} />
                    {demoChips}
                    <Gap h={14} />
                    <FilledButton label="Ignition is on – try again" onPress={retry} loading={steps[LAST_STEP] === 'running'} />
                    <Gap h={8} />
                    <OutlinedButton label="Disconnect" onPress={onDisconnect} />
                  </View>
                ) : null}

                {phase === 'failed' ? (
                  <View>
                    <Divider />
                    <InfoNote icon="alert-circle-outline" color={Colors.danger} text={`Could not connect to ${deviceName}.`} />
                    <Gap h={8} />
                    <InfoNote
                      icon="information-outline"
                      color={Colors.muted}
                      text="Close other apps. Bluetooth scanners accept one connection at a time. Fully close Mini OBDII or any other OBD app."
                    />
                    <Gap h={10} />
                    <InfoNote icon="flask-outline" color={Colors.yellow} text="Demo tip: switch the scenario to Healthy drive, then tap Connect again." />
                    <SectionTitle title="DEMO SCENARIO" style={styles.innerSection} />
                    {demoChips}
                    <Gap h={14} />
                    <OutlinedButton label="Dismiss" onPress={backToFound} />
                  </View>
                ) : null}
              </MghCard>
            </View>
          ) : null}
        </Animated.View>
      ) : null}

      {showConnectedCard ? (
        <ConnectedCard
          animateIn={reveal === 'animate'}
          primaryLabel={primaryIsDone ? 'Done' : 'Go to dashboard'}
          onPrimary={primaryIsDone ? onClose : onGoToDashboard}
          onDisconnect={onDisconnect}
        />
      ) : null}

      {listing ? (
        <View>
          <SectionTitle title="COMPATIBLE SCANNERS · SIMULATED" />
          <Text style={phase === 'found' ? styles.compatibleFound : styles.compatibleLooking}>
            {phase === 'found' ? 'Your IQ is above – ready to connect.' : 'Looking for your IQ…'}
          </Text>

          <SectionTitle
            title={`OTHER BLUETOOTH DEVICES (${othersSeen.length}) · SIMULATED`}
            trailing={<ShowHideButton shown={showOthers} onPress={toggleOthers} />}
          />
          {showOthers ? othersSeen.map((d) => <OtherDeviceRow key={d.name} device={d} />) : null}

          <SectionTitle title="DEMO SCENARIO" trailing={<ShowHideButton shown={showDemo} onPress={toggleDemo} />} />
          {showDemo ? (
            <View>
              {demoChips}
              <Gap h={10} />
              <Text style={[Type.caption, styles.demoCaption]}>Changes which simulated readings and codes the demo shows.</Text>
            </View>
          ) : null}
        </View>
      ) : null}
    </SheetFrame>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center' },
  rowCentre: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center' },
  centre: { alignItems: 'center' },
  centreText: { textAlign: 'center' },
  flex1: { flex: 1 },
  fullWidth: { width: '100%' },
  pressedCard: { opacity: 0.92 },

  countPill: { marginRight: 4 },
  cautionTitle: { fontSize: 18, color: Colors.caution },

  iqCard: { alignItems: 'center' },
  iqBorder: {
    ...StyleSheet.absoluteFillObject,
    borderRadius: Radii.card,
    borderWidth: 1.2,
    borderColor: alpha(Colors.yellow, 0.7),
  },
  iqName: { fontSize: 20, fontWeight: '700', color: Colors.white, textAlign: 'center' },
  signalCaption: { fontSize: 12, color: Colors.faint },
  noPin: { fontSize: 12.5, color: Colors.muted, textAlign: 'center' },
  connectingText: { fontSize: 14, color: Colors.muted },

  stepRow: { flexDirection: 'row', alignItems: 'flex-start', paddingVertical: 6 },
  stepIconBox: { width: 22, height: 22, alignItems: 'center', justifyContent: 'center' },
  stepBody: { flex: 1 },
  stepTitle: { fontSize: 15, fontWeight: '600', lineHeight: 22 },
  stepTitlePending: { color: Colors.faint },
  stepTitleOverlay: { ...StyleSheet.absoluteFillObject, color: Colors.white },
  stepDetail: { fontSize: 12.5, color: Colors.muted, marginTop: 2 },

  tipRow: { borderRadius: Radii.chip, paddingHorizontal: 8, paddingVertical: 6, marginHorizontal: -8 },
  innerSection: { paddingLeft: 0, paddingRight: 0 },

  tickCircle: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: alpha(Colors.yellow, 0.15),
    alignItems: 'center',
    justifyContent: 'center',
    alignSelf: 'center',
  },

  compatibleLooking: { fontSize: 14, color: Colors.muted, paddingLeft: 4 },
  compatibleFound: { fontSize: 13, color: Colors.muted, paddingLeft: 4 },
  otherRowWrap: { marginBottom: 8 },
  otherRow: { opacity: 0.55 },
  otherName: { fontSize: 15, fontWeight: '600', color: Colors.muted },
  otherPill: { marginTop: 6 },
  demoCaption: { paddingLeft: 4 },
});
