// "How this mockup works" sheet: what is real, what is simulated, why, what is
// not claimed, and that the app is read-only by design. Also hosts the global
// DEMO SCENARIO chips and the "Forget saved scanner" demo action.

import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { MaterialCommunityIcons as Icon } from '@expo/vector-icons';
import { Colors, Type } from '../theme';
import { SIMULATED, SCENARIOS, SCENARIO_OPTIONS } from '../sim';
import {
  ChipRow,
  InfoNote,
  MghCard,
  OutlinedButton,
  SectionTitle,
  SheetFrame,
  SimulatedBanner,
} from '../components';

if (!SIMULATED) throw new Error('This mockup only renders simulated devices');

const ICON_BOX_SIZE = 40;
const ICON_BOX_RADIUS = 12;

const ROWS = [
  {
    icon: 'eye-outline',
    label: 'REAL',
    text: 'The screens, copy, colours and flow – the UI we are building towards.',
  },
  {
    icon: 'flask-outline',
    label: 'SIMULATED',
    text: 'Every Bluetooth device, connection, reading and fault code. They come from a built-in demo generator, not from hardware.',
  },
  {
    icon: 'help-circle-outline',
    label: 'WHY',
    text: 'Expo Go cannot use Bluetooth. Real pairing needs a development build with react-native-ble-plx, which this prototype does not include.',
  },
  {
    icon: 'cancel',
    label: 'NOT CLAIMED',
    text: 'Nothing here has been tested on a real IQ or a real car. No connection shown in this mockup is a working connection.',
  },
  {
    icon: 'lock-outline',
    label: 'READ-ONLY BY DESIGN',
    text: "The app only reads. It cannot clear codes, update firmware, or touch the IQ's jump-start, inflate or light functions.",
  },
];

function AboutRow({ icon, label, text }) {
  return (
    <MghCard padding={14} style={styles.row}>
      <View style={styles.rowInner}>
        <View style={styles.iconBox}>
          <Icon name={icon} size={22} color={Colors.yellow} />
        </View>
        <View style={styles.rowText}>
          <Text style={styles.rowLabel}>{label}</Text>
          <Text style={[Type.body, styles.rowBody]}>{text}</Text>
        </View>
      </View>
    </MghCard>
  );
}

export default function AboutSheet({ visible, onClose, scenario, onScenarioChange, savedDevice, onForget }) {
  const current = SCENARIOS[scenario];
  return (
    <SheetFrame visible={visible} title="How this mockup works" onRequestClose={onClose}>
      <SimulatedBanner compact />

      <View style={styles.rows}>
        {ROWS.map((row) => (
          <AboutRow key={row.label} icon={row.icon} label={row.label} text={row.text} />
        ))}
      </View>

      <SectionTitle title="DEMO SCENARIO" />
      <ChipRow options={SCENARIO_OPTIONS} value={scenario} onChange={onScenarioChange} />
      {current ? <Text style={[Type.small, styles.scenarioDescription]}>{current.description}</Text> : null}
      <Text style={[Type.caption, styles.scenarioCaption]}>
        Changes which simulated readings and codes the demo shows.
      </Text>

      <SectionTitle title="DEMO ACTIONS" />
      <OutlinedButton label="Forget saved scanner" onPress={onForget} disabled={!savedDevice} />

      <InfoNote
        style={styles.footer}
        text="Expo Go · react-native-ble-plx needs a development build. Run this prototype in Expo Go or as a web export only."
      />
    </SheetFrame>
  );
}

const styles = StyleSheet.create({
  rows: { marginTop: 16 },
  row: { marginBottom: 10 },
  rowInner: { flexDirection: 'row', alignItems: 'flex-start' },
  iconBox: {
    width: ICON_BOX_SIZE,
    height: ICON_BOX_SIZE,
    borderRadius: ICON_BOX_RADIUS,
    backgroundColor: Colors.yellowSoft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  rowText: { flex: 1, marginLeft: 12 },
  rowLabel: {
    fontSize: 13,
    fontWeight: '800',
    letterSpacing: 1.2,
    textTransform: 'uppercase',
    color: Colors.muted,
  },
  rowBody: { marginTop: 4 },

  scenarioDescription: { marginTop: 10, color: Colors.lightGrey },
  scenarioCaption: { marginTop: 6 },

  footer: { marginTop: 18 },
});
