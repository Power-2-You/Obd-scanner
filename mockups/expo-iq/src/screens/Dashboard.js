// Dashboard tab (tab 0): header, greeting, simulated banner, gauge card,
// polling bar, metric grid and footer note, driven by a 1 s ticker over the
// simulated vehicle generator. Every reading shown here comes from
// sim.makeVehicle – nothing is read from hardware.

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ScrollView, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { MaterialCommunityIcons as Icon } from '@expo/vector-icons';
import { Colors, Gutter, Radii, Type } from '../theme';
import { SIMULATED, fmtTime, greeting, makeVehicle } from '../sim';
import {
  BrandWordmark,
  ConnectionPill,
  FilledButton,
  IconButton,
  InfoNote,
  MghCard,
  SectionTitle,
  SimulatedBanner,
} from '../components';
import { ArcGauge, MetricTile } from '../gauges';
import IqHeroGraphic from '../IqHeroGraphic';

if (!SIMULATED) throw new Error('This mockup only renders simulated devices');

const TICK_MS = 1000;
const HISTORY_MAX = 60;
const GAUGE_MIN = 120;
const GAUGE_MAX = 190;
const GAUGE_GAP = 8;
const GRID_GAP = 12;
const NOT_CONNECTED_HERO = 170;
const RPM_MAX = 8000;
const RPM_WARN = 6000;
const SPEED_MAX = 240;
const VEHICLE_NAME = 'Demo vehicle (simulated)';

const HISTORY_KEYS = ['speed', 'rpm', 'coolant', 'voltage', 'load', 'throttle', 'battery'];

function emptyHistories() {
  const out = {};
  HISTORY_KEYS.forEach((k) => {
    out[k] = [];
  });
  return out;
}

function pushHistories(prev, sample) {
  const next = {};
  HISTORY_KEYS.forEach((k) => {
    const arr = prev[k].concat(sample[k]);
    next[k] = arr.length > HISTORY_MAX ? arr.slice(arr.length - HISTORY_MAX) : arr;
  });
  return next;
}

function clamp(x, lo, hi) {
  return Math.min(hi, Math.max(lo, x));
}

// 1 s ticker over the simulated vehicle. `t` continues across pause/resume
// and resets when the vehicle instance changes.
function useTicker(vehicle, running) {
  const tRef = useRef(0);
  const [sample, setSample] = useState(null);
  const [histories, setHistories] = useState(emptyHistories);
  const [now, setNow] = useState(null);

  useEffect(() => {
    tRef.current = 0;
    setSample(null);
    setHistories(emptyHistories());
    setNow(null);
  }, [vehicle]);

  useEffect(() => {
    if (!running) return undefined;
    const tick = () => {
      const s = vehicle.sample(tRef.current);
      tRef.current += 1;
      setSample(s);
      setHistories((prev) => pushHistories(prev, s));
      setNow(new Date());
    };
    tick();
    const id = setInterval(tick, TICK_MS);
    return () => clearInterval(id);
  }, [running, vehicle]);

  return { sample, histories, now };
}

function NotConnectedCard({ onOpenPair }) {
  return (
    <MghCard padding={[20, 24, 20, 20]}>
      <View style={styles.notConnected}>
        <IqHeroGraphic size={NOT_CONNECTED_HERO} />
        <Text style={[Type.titleLarge, styles.notConnectedTitle]}>Connect your IQ to see live data</Text>
        <Text style={[Type.bodyMuted, styles.notConnectedBody]}>
          Engine speed, temperatures, voltage and more – straight from your car.
        </Text>
        <FilledButton icon="bluetooth-connect" label="Pair device" onPress={onOpenPair} style={styles.notConnectedButton} />
      </View>
    </MghCard>
  );
}

function GaugeCard({ sample, initialInnerWidth }) {
  const [innerWidth, setInnerWidth] = useState(initialInnerWidth);
  const size = clamp((innerWidth - GAUGE_GAP) / 2, GAUGE_MIN, GAUGE_MAX);
  const rpm = sample ? sample.rpm : 0;
  const speed = sample ? sample.speed : 0;
  return (
    <MghCard padding={[12, 18, 12, 12]}>
      <View style={styles.gaugeRow} onLayout={(e) => setInnerWidth(e.nativeEvent.layout.width)}>
        <ArcGauge label="Engine" unit="rpm" min={0} max={RPM_MAX} warnAbove={RPM_WARN} value={rpm} size={size} />
        <ArcGauge label="Speed" unit="km/h" min={0} max={SPEED_MAX} value={speed} size={size} />
      </View>
    </MghCard>
  );
}

function PollingBar({ paused, now, onToggle }) {
  const status = paused ? 'Paused' : `Live · updated ${now ? fmtTime(now, { seconds: true }) : '…'}`;
  return (
    <View style={styles.pollingBar}>
      <IconButton
        filled
        icon={paused ? 'play' : 'pause'}
        color={paused ? Colors.charcoal : Colors.white}
        filledBg={paused ? Colors.yellow : Colors.surfaceHigh}
        accessibilityLabel={paused ? 'Resume live data' : 'Pause live data'}
        onPress={onToggle}
      />
      <Text style={styles.pollingText} numberOfLines={1}>
        {status}
      </Text>
      {/* Static update-rate chip – the mockup has no rate menu. */}
      <View style={styles.rateChip} accessibilityLabel="Update rate 1 second">
        <Icon name="clock-outline" size={16} color={Colors.muted} />
        <Text style={styles.rateText}>1s</Text>
      </View>
    </View>
  );
}

function codesTile(sample, onGoFaults) {
  const milOn = !!(sample && sample.milOn);
  const count = sample ? sample.dtcCount : 0;
  return {
    key: 'codes',
    icon: milOn ? 'alert' : 'check-circle-outline',
    label: milOn ? 'Codes · light ON' : 'Trouble codes',
    unit: count === 1 ? 'code' : 'codes',
    value: count,
    accent: milOn ? Colors.danger : Colors.success,
    statusText: 'Tap to scan',
    history: [],
    onPress: onGoFaults,
  };
}

function MetricGrid({ sample, histories, onGoFaults }) {
  const v = (k) => (sample ? sample[k] : null);
  const tiles = [
    { key: 'coolant', icon: 'thermometer', label: 'Coolant', unit: '°C', value: v('coolant'), history: histories.coolant },
    { key: 'voltage', icon: 'flash', label: 'Voltage', unit: 'V', value: v('voltage'), decimals: 1, history: histories.voltage },
    { key: 'load', icon: 'gauge', label: 'Engine load', unit: '%', value: v('load'), history: histories.load },
    { key: 'throttle', icon: 'tune', label: 'Throttle', unit: '%', value: v('throttle'), history: histories.throttle },
    codesTile(sample, onGoFaults),
    { key: 'battery', icon: 'battery-charging', label: 'Battery at port', unit: 'V', value: v('battery'), decimals: 1, history: histories.battery },
  ];
  const rows = [];
  for (let i = 0; i < tiles.length; i += 2) rows.push(tiles.slice(i, i + 2));
  return (
    <View>
      {rows.map((row, r) => (
        <View key={row[0].key} style={[styles.gridRow, r < rows.length - 1 ? styles.gridRowGap : null]}>
          {row.map((tile, c) => {
            const { key, ...props } = tile;
            return <MetricTile key={key} {...props} style={c > 0 ? styles.gridColGap : null} />;
          })}
        </View>
      ))}
    </View>
  );
}

// Props: connection ('idle' | 'connected'), scenario, onOpenStatus (Demo pill ->
// PairSheet entry 'status'), onOpenPair (not-connected card -> PairSheet entry
// 'search'), onGoFaults (codes tile -> tab 1), vehicleRef ({ current: vehicle }
// owned by App.js so Faults sees the same scenario), active (false while
// another tab or the Welcome screen is showing – stops the ticker).
export default function Dashboard({
  connection = 'idle',
  scenario = 'healthyDriving',
  onOpenStatus,
  onOpenPair,
  onGoFaults,
  vehicleRef,
  active = true,
}) {
  const { width: windowWidth } = useWindowDimensions();
  const connected = connection === 'connected';
  const [paused, setPaused] = useState(false);

  // Use App.js's vehicle when it matches the current scenario; otherwise
  // (e.g. the web preview opens straight on the dashboard) build a local one.
  const external = vehicleRef ? vehicleRef.current : null;
  const vehicle = useMemo(
    () => (external && external.scenario === scenario ? external : makeVehicle(scenario)),
    [external, scenario],
  );

  const running = connected && !paused && active;
  const { sample, histories, now } = useTicker(vehicle, running);
  const togglePaused = useCallback(() => setPaused((p) => !p), []);

  // Card inner width before the first onLayout: window minus gutters, card
  // padding and borders.
  const initialInnerWidth = windowWidth - Gutter * 2 - 24 - 2;

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
      <View style={styles.header}>
        <View style={styles.headerBrand}>
          <BrandWordmark size={0.9} />
        </View>
        {/* The Demo pill only renders while the demo scanner is connected – it
            must never suggest a connection that does not exist. */}
        {connected ? <ConnectionPill onPress={onOpenStatus} /> : null}
      </View>

      <View style={styles.greetingBlock}>
        <Text style={styles.greeting}>{greeting()}</Text>
        <Text style={[Type.headlineSmall, styles.vehicleName]} numberOfLines={1}>
          {VEHICLE_NAME}
        </Text>
      </View>

      <View style={styles.body}>
        {!connected ? (
          <NotConnectedCard onOpenPair={onOpenPair} />
        ) : (
          <>
            <SimulatedBanner style={styles.banner} />
            <GaugeCard sample={sample} initialInnerWidth={initialInnerWidth} />
            <PollingBar paused={paused} now={now} onToggle={togglePaused} />
            <SectionTitle title="ENGINE & ELECTRICAL" />
            <MetricGrid sample={sample} histories={histories} onGoFaults={onGoFaults} />
            <InfoNote
              style={styles.footer}
              text='Only values the simulated vehicle reports are shown. Anything it does not support is marked as unavailable – the app never estimates readings. "Battery at port" is measured by the scanner itself.'
            />
          </>
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: Colors.charcoal },
  content: { paddingBottom: 28 },

  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingLeft: Gutter,
    paddingTop: 12,
    paddingRight: 12,
    paddingBottom: 0,
  },
  headerBrand: { flex: 1, marginRight: 8 },

  greetingBlock: { paddingLeft: Gutter, paddingTop: 18, paddingRight: Gutter, paddingBottom: 0 },
  greeting: { fontSize: 14, color: Colors.muted },
  vehicleName: { marginTop: 2 },

  body: { paddingLeft: Gutter, paddingTop: 16, paddingRight: Gutter, paddingBottom: 0 },
  banner: { marginBottom: 14 },

  gaugeRow: { flexDirection: 'row', justifyContent: 'space-evenly', alignItems: 'flex-start' },

  pollingBar: { flexDirection: 'row', alignItems: 'center', marginTop: 6 },
  pollingText: { flex: 1, marginLeft: 6, fontSize: 12.5, color: Colors.muted },
  rateChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surfaceRaised,
    borderRadius: Radii.chip,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  rateText: { marginLeft: 6, fontSize: 13, fontWeight: '600', color: Colors.lightGrey },

  gridRow: { flexDirection: 'row' },
  gridRowGap: { marginBottom: GRID_GAP },
  gridColGap: { marginLeft: GRID_GAP },

  footer: { marginTop: 16 },

  notConnected: { alignItems: 'center' },
  notConnectedTitle: { marginTop: 10, textAlign: 'center' },
  notConnectedBody: { marginTop: 8, textAlign: 'center' },
  notConnectedButton: { marginTop: 20, alignSelf: 'stretch' },
});
