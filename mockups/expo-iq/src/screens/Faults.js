// Faults tab (tab 1, read-only): scan card, stored/pending fault cards from
// the simulated fixtures, and the no-clearing footer. Also exports
// PlaceholderTab (tabs 2 and 3) and the bottom NavigationBar. There is no
// clear-codes control anywhere in this file by design.

import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Animated, Easing, Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { MaterialCommunityIcons as Icon } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors, alpha, Gutter, Radii, TabBarHeight, Type } from '../theme';
import { SIMULATED, DTC_FIXTURES, fmtScan, guidanceColor } from '../sim';
import {
  ConnectionPill,
  EmptyState,
  FadeIn,
  FilledButton,
  InfoNote,
  MghCard,
  OutlinedButton,
  Pill,
  SectionTitle,
  SimulatedBanner,
} from '../components';

if (!SIMULATED) throw new Error('This mockup only renders simulated devices');

const NATIVE_DRIVER = Platform.OS !== 'web';
const READ_MS = 1400;
const CARD_STAGGER_MS = 60;
const PILL_FADE_MS = 150;
const SCAN_ICON_BOX = 52;
const SCAN_ICON_SIZE = 28;
const FAULT_BAR_WIDTH = 5;
const NAV_PILL_WIDTH = 64;
const NAV_PILL_HEIGHT = 32;

const SCAN_SUBTITLE = 'Reads stored and pending codes from the simulated vehicle.';

export const TABS = [
  { key: 'dashboard', label: 'Dashboard', icon: 'speedometer' },
  { key: 'faults', label: 'Faults', icon: 'alert-outline' },
  { key: 'mechanic', label: 'AI Mechanic', icon: 'creation' },
  { key: 'garage', label: 'Garage', icon: 'garage' },
];

// Snapshot of one simulated scan. Codes come straight from DTC_FIXTURES.
function readCodes(scenario) {
  const fixture = DTC_FIXTURES[scenario] || DTC_FIXTURES.healthyDriving;
  return {
    stored: fixture.stored,
    pending: fixture.pending,
    milOn: scenario === 'checkEngine',
    when: new Date(),
    scenario,
  };
}

function ScreenHeader({ title, connected, onOpenStatus }) {
  return (
    <View style={styles.headerRow}>
      <Text style={[Type.headlineSmall, styles.headerTitle]} numberOfLines={1}>
        {title}
      </Text>
      {/* The Demo pill only renders while the demo scanner is connected. */}
      {connected ? <ConnectionPill onPress={onOpenStatus} /> : null}
    </View>
  );
}

function scanCardState(connected, result) {
  if (!connected || !result) {
    return { icon: 'magnify', colour: Colors.yellow, title: 'Check for trouble codes', subtitle: SCAN_SUBTITLE };
  }
  const subtitle = `Last scan ${fmtScan(result.when)} · light ${result.milOn ? 'ON' : 'OFF'}`;
  if (result.milOn) {
    return { icon: 'alert', colour: Colors.danger, title: 'Check-engine light is ON', subtitle };
  }
  return { icon: 'check-circle', colour: Colors.success, title: 'All clear', subtitle };
}

function ScanCard({ connected, result, reading, onScan, onOpenPair }) {
  const s = scanCardState(connected, result);
  let button;
  if (!connected) {
    button = <OutlinedButton icon="bluetooth" label="Connect your IQ to scan" onPress={onOpenPair} />;
  } else if (reading) {
    button = <FilledButton loading label="Reading codes…" />;
  } else {
    button = <FilledButton icon="magnify" label={result ? 'Scan again' : 'Scan for codes'} onPress={onScan} />;
  }
  return (
    <MghCard>
      <View style={styles.scanRow}>
        <View style={[styles.scanIconBox, { backgroundColor: alpha(s.colour, 0.14) }]}>
          <Icon name={s.icon} size={SCAN_ICON_SIZE} color={s.colour} />
        </View>
        <View style={styles.scanText}>
          <Text style={Type.titleMedium}>{s.title}</Text>
          <Text style={styles.scanSubtitle}>{s.subtitle}</Text>
        </View>
      </View>
      <View style={styles.scanButton}>{button}</View>
    </MghCard>
  );
}

// Read-only: no chevron, no onPress, no long-press, no expansion.
function FaultCard({ dtc }) {
  const colour = guidanceColor(dtc.level);
  return (
    <MghCard padding={0} style={styles.faultCard}>
      <View style={styles.faultRow}>
        <View style={[styles.faultBar, { backgroundColor: colour }]} />
        <View style={styles.faultContent}>
          <View style={styles.faultHead}>
            <Text style={Type.faultCode}>{dtc.code}</Text>
            <Pill label={dtc.level} color={colour} style={styles.faultPill} />
          </View>
          <Text style={styles.faultDescription}>{dtc.description}</Text>
          <Text style={styles.faultMeta}>{dtc.meta}</Text>
        </View>
      </View>
    </MghCard>
  );
}

function ScanResults({ result }) {
  const { stored, pending } = result;
  if (stored.length === 0 && pending.length === 0) {
    return (
      <FadeIn>
        <EmptyState
          icon="shield-check-outline"
          title="No trouble codes reported"
          message="The simulated vehicle did not report any stored or pending emission-related codes."
        />
      </FadeIn>
    );
  }
  let index = 0;
  const nextDelay = () => {
    const d = index * CARD_STAGGER_MS;
    index += 1;
    return d;
  };
  return (
    <View>
      {stored.length > 0 ? (
        <>
          <SectionTitle title={`STORED CODES (${stored.length})`} />
          {stored.map((dtc) => (
            <FadeIn key={dtc.code} delay={nextDelay()}>
              <FaultCard dtc={dtc} />
            </FadeIn>
          ))}
        </>
      ) : null}
      {pending.length > 0 ? (
        <>
          <SectionTitle title={`PENDING CODES (${pending.length})`} />
          <Text style={styles.pendingNote}>Detected once but not yet confirmed by the vehicle.</Text>
          {pending.map((dtc) => (
            <FadeIn key={dtc.code} delay={nextDelay()}>
              <FaultCard dtc={dtc} />
            </FadeIn>
          ))}
        </>
      ) : null}
    </View>
  );
}

// Props: connection ('idle' | 'connected'), scenario, onOpenStatus (Demo pill),
// onOpenPair ("Connect your IQ to scan"), initialRead (web preview: start with
// the codes already read, skipping the 1400 ms reading state).
export default function Faults({ connection = 'idle', scenario = 'healthyDriving', onOpenStatus, onOpenPair, initialRead = false }) {
  const connected = connection === 'connected';
  const [reading, setReading] = useState(false);
  const [result, setResult] = useState(() => (initialRead && connected ? readCodes(scenario) : null));
  const timer = useRef(null);

  const clearTimer = useCallback(() => {
    if (timer.current) {
      clearTimeout(timer.current);
      timer.current = null;
    }
  }, []);

  useEffect(() => clearTimer, [clearTimer]);

  // Disconnecting discards the last scan so nothing is shown for a scanner
  // that is no longer (demo-)connected.
  useEffect(() => {
    if (!connected) {
      clearTimer();
      setReading(false);
      setResult(null);
    }
  }, [connected, clearTimer]);

  const scan = useCallback(() => {
    if (reading) return;
    clearTimer();
    setReading(true);
    timer.current = setTimeout(() => {
      timer.current = null;
      setResult(readCodes(scenario));
      setReading(false);
    }, READ_MS);
  }, [reading, scenario, clearTimer]);

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
      <ScreenHeader title="Fault codes" connected={connected} onOpenStatus={onOpenStatus} />
      <View style={styles.afterHeader}>
        {connected ? <SimulatedBanner style={styles.banner} /> : null}
        <ScanCard connected={connected} result={result} reading={reading} onScan={scan} onOpenPair={onOpenPair} />
        {connected && result ? (
          <View key={result.when.getTime()}>
            <ScanResults result={result} />
          </View>
        ) : null}
      </View>

      <View style={styles.footer}>
        <InfoNote
          icon="lock-outline"
          text="Clearing codes is not available in this version. Leaving them stored helps your mechanic diagnose the fault, and clearing also resets emissions readiness monitors."
        />
        <InfoNote
          icon="engine-outline"
          style={styles.footerNote}
          text="A trouble code shows which system or circuit failed a self-test. It does not identify the failed part, so further diagnosis is needed before replacing anything."
        />
        <InfoNote
          icon="information-outline"
          style={styles.footerNote}
          text="Severity labels are rule-based general information for a family of codes – not a diagnosis of your vehicle."
        />
      </View>
    </ScrollView>
  );
}

// Tabs 2 and 3. Props: title ('AI Mechanic' | 'Garage'), icon ('creation' |
// 'garage'), connection, onOpenStatus.
export function PlaceholderTab({ title, icon, connection = 'idle', onOpenStatus }) {
  const connected = connection === 'connected';
  return (
    <View style={styles.screen}>
      <View style={styles.placeholderHeader}>
        <ScreenHeader title={title} connected={connected} onOpenStatus={onOpenStatus} />
      </View>
      <View style={styles.placeholderBody}>
        <EmptyState
          icon={icon}
          title="Not in this mockup"
          message="This prototype covers pairing, live data and fault codes only. Nothing here is a mechanical diagnosis."
        />
      </View>
    </View>
  );
}

function NavItem({ label, icon, selected, onPress }) {
  const pill = useRef(new Animated.Value(selected ? 1 : 0)).current;
  useEffect(() => {
    const anim = Animated.timing(pill, {
      toValue: selected ? 1 : 0,
      duration: PILL_FADE_MS,
      easing: Easing.linear,
      useNativeDriver: NATIVE_DRIVER,
    });
    anim.start();
    return () => anim.stop();
  }, [selected, pill]);
  const colour = selected ? Colors.yellow : Colors.muted;
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="tab"
      accessibilityLabel={label}
      accessibilityState={{ selected: !!selected }}
      aria-selected={!!selected}
      style={({ pressed }) => [styles.navItem, pressed ? styles.pressed : null]}
    >
      <View style={styles.navPill}>
        <Animated.View style={[styles.navPillBg, { opacity: pill }]} />
        <Icon name={icon} size={24} color={colour} />
      </View>
      <Text style={[selected ? Type.navLabelSelected : Type.navLabel, styles.navLabel]} numberOfLines={1}>
        {label}
      </Text>
    </Pressable>
  );
}

// Bottom tab bar. Props: tab (0-3), onSelect(index). Tabs stay mounted in
// App.js; switching has no transition beyond the pill fade.
export function NavigationBar({ tab = 0, onSelect }) {
  const insets = useSafeAreaInsets();
  return (
    <View style={[styles.navBar, { height: TabBarHeight + insets.bottom, paddingBottom: insets.bottom }]}>
      {TABS.map((t, i) => (
        <NavItem key={t.key} label={t.label} icon={t.icon} selected={i === tab} onPress={() => onSelect && onSelect(i)} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  pressed: { opacity: 0.85 },
  screen: { flex: 1, backgroundColor: Colors.charcoal },
  content: { paddingLeft: Gutter, paddingTop: 12, paddingRight: Gutter, paddingBottom: 28 },

  headerRow: { flexDirection: 'row', alignItems: 'center' },
  headerTitle: { flex: 1, marginRight: 8 },
  afterHeader: { marginTop: 16 },
  banner: { marginBottom: 14 },

  scanRow: { flexDirection: 'row', alignItems: 'center' },
  scanIconBox: {
    width: SCAN_ICON_BOX,
    height: SCAN_ICON_BOX,
    borderRadius: Radii.button,
    alignItems: 'center',
    justifyContent: 'center',
  },
  scanText: { flex: 1, marginLeft: 14 },
  scanSubtitle: { marginTop: 3, fontSize: 13, color: Colors.muted },
  scanButton: { marginTop: 16 },

  pendingNote: { paddingLeft: 4, paddingBottom: 10, fontSize: 13, color: Colors.muted },

  faultCard: { marginBottom: 10 },
  faultRow: { flexDirection: 'row', alignItems: 'stretch' },
  faultBar: { width: FAULT_BAR_WIDTH },
  faultContent: { flex: 1, paddingLeft: 14, paddingTop: 14, paddingRight: 10, paddingBottom: 14 },
  faultHead: { flexDirection: 'row', alignItems: 'center' },
  faultPill: { marginLeft: 10 },
  faultDescription: { marginTop: 6, fontSize: 14, lineHeight: 19, color: Colors.lightGrey },
  faultMeta: { marginTop: 8, fontSize: 12, color: Colors.faint },

  footer: { marginTop: 18 },
  footerNote: { marginTop: 10 },

  placeholderHeader: { paddingLeft: Gutter, paddingTop: 12, paddingRight: Gutter },
  placeholderBody: { flex: 1, justifyContent: 'center' },

  navBar: {
    flexDirection: 'row',
    backgroundColor: Colors.surface,
    borderTopWidth: 0.6,
    borderTopColor: Colors.outline,
  },
  navItem: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  navPill: {
    width: NAV_PILL_WIDTH,
    height: NAV_PILL_HEIGHT,
    borderRadius: NAV_PILL_HEIGHT / 2,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  navPillBg: { ...StyleSheet.absoluteFillObject, backgroundColor: Colors.yellowSoft },
  navLabel: { marginTop: 4 },
});
