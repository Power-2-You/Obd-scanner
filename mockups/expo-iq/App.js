// Root of the Expo Go pairing mockup. Owns the app state machine (spec §3),
// mounts the global SimStrip above every screen, switches between Welcome and
// the tabbed Home shell, and hosts the Pair and About sheets.
//
// Everything this app shows – devices, connections, readings and codes – is
// simulated. Expo Go cannot use Bluetooth, so there is nothing here that
// talks to a real IQ or a real car.

import React, { useCallback, useRef, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider, SafeAreaView, initialWindowMetrics } from 'react-native-safe-area-context';
import { Colors } from './src/theme';
import { SIMULATED, IQ_DEVICE, makeVehicle } from './src/sim';
import { SimStrip } from './src/components';
import { initialStateFromPreview } from './src/preview';
import Welcome from './src/screens/Welcome';
import PairSheet from './src/screens/PairSheet';
import AboutSheet from './src/screens/AboutSheet';
import Dashboard from './src/screens/Dashboard';
import Faults, { PlaceholderTab, NavigationBar } from './src/screens/Faults';

if (!SIMULATED) throw new Error('This mockup only renders simulated devices');

// Web-preview harness (no effect in Expo Go): ?screen=…&state=… picks the
// initial state so the screenshot tooling can open any phase directly.
const PREVIEW = initialStateFromPreview();

// Module-level so the saved scanner survives Disconnect -> Welcome for the
// rest of the session (spec §3 persistence).
let savedDeviceStore = PREVIEW.savedDevice;

const TAB_DASHBOARD = 0;
const TAB_FAULTS = 1;
const TAB_MECHANIC = 2;
const TAB_GARAGE = 3;

// Tab content + NavigationBar. All four tabs stay mounted (IndexedStack
// behaviour); the inactive ones are hidden with display:'none'.
function Home({ tab, onSelectTab, connection, scenario, vehicleRef, faultsInitialRead, onOpenStatus, onOpenPair }) {
  const goFaults = useCallback(() => onSelectTab(TAB_FAULTS), [onSelectTab]);
  const tabStyle = (index) => [styles.tab, tab === index ? null : styles.hiddenTab];
  return (
    <View style={styles.home}>
      <View style={styles.tabs}>
        <View style={tabStyle(TAB_DASHBOARD)}>
          <Dashboard
            connection={connection}
            scenario={scenario}
            vehicleRef={vehicleRef}
            active={tab === TAB_DASHBOARD}
            onOpenStatus={onOpenStatus}
            onOpenPair={onOpenPair}
            onGoFaults={goFaults}
          />
        </View>
        <View style={tabStyle(TAB_FAULTS)}>
          <Faults
            connection={connection}
            scenario={scenario}
            initialRead={faultsInitialRead}
            onOpenStatus={onOpenStatus}
            onOpenPair={onOpenPair}
          />
        </View>
        <View style={tabStyle(TAB_MECHANIC)}>
          <PlaceholderTab title="AI Mechanic" icon="creation" connection={connection} onOpenStatus={onOpenStatus} />
        </View>
        <View style={tabStyle(TAB_GARAGE)}>
          <PlaceholderTab title="Garage" icon="garage" connection={connection} onOpenStatus={onOpenStatus} />
        </View>
      </View>
      <NavigationBar tab={tab} onSelect={onSelectTab} />
    </View>
  );
}

export default function App() {
  const [screen, setScreen] = useState(PREVIEW.screen);
  const [tab, setTab] = useState(PREVIEW.tab);
  const [connection, setConnection] = useState(PREVIEW.connection);
  const [scenario, setScenarioState] = useState(PREVIEW.scenario);
  const [savedDevice, setSavedDevice] = useState(savedDeviceStore);
  const [sheet, setSheet] = useState(PREVIEW.sheet);
  const [aboutOpen, setAboutOpen] = useState(false);

  // The simulated vehicle is created when the sheet reaches `connected` and
  // shared by Dashboard and Faults so both see the same scenario.
  const vehicleRef = useRef(PREVIEW.connection === 'connected' ? makeVehicle(PREVIEW.scenario) : null);

  const openPair = useCallback((entry) => setSheet({ entry: entry || 'search' }), []);
  const closePair = useCallback(() => setSheet(null), []);
  const openAbout = useCallback(() => setAboutOpen(true), []);
  const closeAbout = useCallback(() => setAboutOpen(false), []);

  const onConnected = useCallback(() => {
    vehicleRef.current = makeVehicle(scenario);
    setConnection('connected');
    savedDeviceStore = { name: IQ_DEVICE.name };
    setSavedDevice(savedDeviceStore);
  }, [scenario]);

  const onDisconnect = useCallback(() => {
    vehicleRef.current = null;
    setConnection('idle');
    setSheet(null);
    setScreen('welcome');
  }, []);

  const goToDashboard = useCallback(() => {
    setSheet(null);
    setScreen('home');
    setTab(TAB_DASHBOARD);
  }, []);

  const setScenario = useCallback(
    (key) => {
      setScenarioState(key);
      // Keep the shared vehicle in step with the chosen scenario while connected.
      if (vehicleRef.current) vehicleRef.current = makeVehicle(key);
    },
    [],
  );

  const forgetDevice = useCallback(() => {
    savedDeviceStore = null;
    setSavedDevice(null);
  }, []);

  const openSearch = useCallback(() => openPair('search'), [openPair]);
  const openReconnect = useCallback(() => openPair('reconnect'), [openPair]);
  const openStatus = useCallback(() => openPair('status'), [openPair]);

  return (
    <SafeAreaProvider initialMetrics={initialWindowMetrics}>
      <View style={styles.root}>
        <StatusBar style="light" />
        <SafeAreaView edges={['top']} style={styles.topArea}>
          <SimStrip onWhatsReal={openAbout} />
        </SafeAreaView>

        {screen === 'welcome' ? (
          <Welcome
            savedDevice={savedDevice}
            connection={connection}
            onPair={openPair}
            onReconnect={openReconnect}
            onForget={forgetDevice}
            onGoToDashboard={goToDashboard}
            onOpenAbout={openAbout}
          />
        ) : (
          <Home
            tab={tab}
            onSelectTab={setTab}
            connection={connection}
            scenario={scenario}
            vehicleRef={vehicleRef}
            faultsInitialRead={PREVIEW.faultsScanned}
            onOpenStatus={openStatus}
            onOpenPair={openSearch}
          />
        )}

        <PairSheet
          visible={!!sheet}
          entry={sheet ? sheet.entry : 'search'}
          screen={screen}
          connection={connection}
          scenario={scenario}
          onScenarioChange={setScenario}
          savedDevice={savedDevice}
          onConnected={onConnected}
          onDisconnect={onDisconnect}
          onGoToDashboard={goToDashboard}
          onClose={closePair}
          initialPhase={PREVIEW.pairPhase}
        />
        <AboutSheet
          visible={aboutOpen}
          onClose={closeAbout}
          scenario={scenario}
          onScenarioChange={setScenario}
          savedDevice={savedDevice}
          onForget={forgetDevice}
        />
      </View>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.charcoal },
  topArea: { backgroundColor: Colors.charcoal },
  home: { flex: 1 },
  tabs: { flex: 1 },
  tab: { flex: 1 },
  hiddenTab: { display: 'none' },
});
