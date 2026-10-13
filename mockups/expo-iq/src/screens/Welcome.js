// Welcome screen – one job: tap "Pair device". Shows the saved-device
// reconnect card when a (simulated) scanner was connected earlier in this
// session. No devices or readings are rendered here; the global SimStrip sits
// above it in App.js.

import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  Animated,
  Easing,
  LayoutAnimation,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { MaterialCommunityIcons as Icon } from '@expo/vector-icons';
import { Colors, Radii, Type } from '../theme';
import { SIMULATED, IQ_DEVICE } from '../sim';
import {
  BrandWordmark,
  FilledButton,
  IconButton,
  InfoNote,
  MghCard,
  Pill,
  SectionTitle,
  TextButton,
} from '../components';
import IqHeroGraphic from '../IqHeroGraphic';

if (!SIMULATED) throw new Error('This mockup only renders simulated devices');

const NATIVE_DRIVER = Platform.OS !== 'web';
const IS_NATIVE = Platform.OS !== 'web';

const WELCOME_GUTTER = 24;
const HERO_SIZE = 220;
const HERO_FADE_MS = 300;
const TEXT_ENTER_MS = 420;
const HEADLINE_DELAY_MS = 150;
const BODY_DELAY_MS = 260;
const FORGET_FADE_MS = 200;

const CHECK_ROWS = [
  "Only reads diagnostic data – it never changes your car's settings",
  "Cannot clear codes, reprogram modules or affect your IQ's jump-start, inflate or light functions",
  "No PIN or passcode – pairing happens inside the app, not in your phone's Bluetooth settings",
];

function layoutAnimate() {
  if (IS_NATIVE) {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
  }
}

// Entrance animation (§9): hero spring + fade, then headline and body slide up.
function useEntrance() {
  const heroScale = useRef(new Animated.Value(0)).current;
  const heroOpacity = useRef(new Animated.Value(0)).current;
  const headline = useRef(new Animated.Value(0)).current;
  const body = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const anim = Animated.parallel([
      Animated.spring(heroScale, { toValue: 1, damping: 12, stiffness: 120, useNativeDriver: NATIVE_DRIVER }),
      Animated.timing(heroOpacity, { toValue: 1, duration: HERO_FADE_MS, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER }),
      Animated.timing(headline, {
        toValue: 1,
        duration: TEXT_ENTER_MS,
        delay: HEADLINE_DELAY_MS,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: NATIVE_DRIVER,
      }),
      Animated.timing(body, {
        toValue: 1,
        duration: TEXT_ENTER_MS,
        delay: BODY_DELAY_MS,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: NATIVE_DRIVER,
      }),
    ]);
    anim.start();
    return () => anim.stop();
  }, [heroScale, heroOpacity, headline, body]);

  const slide = (v) => ({
    opacity: v,
    transform: [{ translateY: v.interpolate({ inputRange: [0, 1], outputRange: [12, 0] }) }],
  });

  return {
    hero: {
      opacity: heroOpacity,
      transform: [{ scale: heroScale.interpolate({ inputRange: [0, 1], outputRange: [0.92, 1] }) }],
    },
    headline: slide(headline),
    body: slide(body),
  };
}

function SavedDeviceCard({ savedDevice, onReconnect, onForget }) {
  const opacity = useRef(new Animated.Value(1)).current;
  const fading = useRef(null);
  const name = (savedDevice && savedDevice.name) || IQ_DEVICE.name;

  useEffect(() => {
    // A new saved device (or a cancelled forget) shows the card at full opacity.
    opacity.setValue(1);
    return () => {
      if (fading.current) fading.current.stop();
    };
  }, [savedDevice, opacity]);

  const forget = useCallback(() => {
    if (fading.current) return;
    const anim = Animated.timing(opacity, { toValue: 0, duration: FORGET_FADE_MS, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER });
    fading.current = anim;
    anim.start(({ finished }) => {
      fading.current = null;
      if (!finished) return;
      layoutAnimate();
      if (onForget) onForget();
    });
  }, [opacity, onForget]);

  return (
    <Animated.View style={{ opacity }}>
      <MghCard onPress={onReconnect} accessibilityLabel={`Reconnect to ${name}`}>
        <View style={styles.savedRow}>
          <View style={styles.savedIconBox}>
            <Icon name="history" size={22} color={Colors.yellow} />
          </View>
          <View style={styles.savedText}>
            <Text style={styles.savedTitle}>{`Reconnect to ${name}`}</Text>
            <Text style={styles.savedSubtitle}>Last connected in this demo</Text>
          </View>
          <IconButton
            icon="close"
            size={20}
            color={Colors.faint}
            hitSlop={12}
            accessibilityLabel="Forget this scanner"
            onPress={forget}
          />
        </View>
      </MghCard>
    </Animated.View>
  );
}

function CheckRow({ text }) {
  return (
    <View style={styles.checkRow}>
      <Icon name="check-circle" size={20} color={Colors.success} />
      <Text style={[Type.body, styles.checkText]}>{text}</Text>
    </View>
  );
}

export default function Welcome({
  savedDevice,
  connection = 'idle',
  onPair,
  onReconnect,
  onForget,
  onGoToDashboard,
  onOpenAbout,
}) {
  const entrance = useEntrance();
  const [portHintOpen, setPortHintOpen] = useState(false);
  const connected = connection === 'connected';

  const pair = useCallback(() => {
    if (onPair) onPair('search');
  }, [onPair]);

  const reconnect = useCallback(() => {
    if (onReconnect) onReconnect();
    else if (onPair) onPair('reconnect');
  }, [onReconnect, onPair]);

  const togglePortHint = useCallback(() => {
    layoutAnimate();
    setPortHintOpen((open) => !open);
  }, []);

  return (
    <ScrollView
      style={styles.screen}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
    >
      <View style={styles.header}>
        <View style={styles.headerBrand}>
          <BrandWordmark />
        </View>
        <Pressable
          onPress={onOpenAbout}
          hitSlop={8}
          accessibilityRole="button"
          accessibilityLabel="How this mockup works"
          style={({ pressed }) => (pressed ? styles.pressed : null)}
        >
          <Pill label="SIMULATED" color={Colors.yellow} filled />
        </Pressable>
      </View>

      <Animated.View style={[styles.heroWrap, entrance.hero]}>
        <IqHeroGraphic size={HERO_SIZE} animate active={false} />
      </Animated.View>

      <Animated.Text style={[Type.headlineMedium, styles.headline, entrance.headline]}>
        Your IQ just got smarter.
      </Animated.Text>
      <Animated.Text style={[Type.bodyLead, styles.bodyText, entrance.body]}>
        Plug the IQ's OBD-II scanner into the port under your dashboard, turn the ignition on and keep your phone
        close. Pairing happens inside the app – like a pair of earphones. Nothing to set up in iOS Settings.
      </Animated.Text>

      {savedDevice ? (
        <View style={styles.savedWrap}>
          <SavedDeviceCard savedDevice={savedDevice} onReconnect={reconnect} onForget={onForget} />
        </View>
      ) : null}

      {connected ? (
        <FilledButton
          icon="speedometer"
          label="Go to dashboard"
          onPress={onGoToDashboard}
          style={savedDevice ? null : styles.primaryAfterBody}
        />
      ) : (
        <FilledButton
          icon="bluetooth-connect"
          label="Pair device"
          onPress={pair}
          style={savedDevice ? null : styles.primaryAfterBody}
        />
      )}

      <TextButton
        label="Where is the OBD-II port?"
        icon={portHintOpen ? 'chevron-up' : 'chevron-down'}
        onPress={togglePortHint}
        style={styles.portHintButton}
      />
      {portHintOpen ? (
        <InfoNote
          icon="lightbulb-outline"
          color={Colors.yellow}
          style={styles.portHint}
          text="The OBD-II port is usually under the dashboard near the steering column. Push the scanner's connector fully in, then turn the ignition on."
        />
      ) : null}

      <InfoNote
        style={styles.expoNote}
        text="Expo Go prototype. Expo Go cannot use Bluetooth, so every device, connection and reading in this mockup is simulated. Nothing here talks to a real IQ or a real car."
      />

      <SectionTitle title="WHAT THIS APP DOES TO YOUR IQ" />
      <MghCard>
        {CHECK_ROWS.map((text) => (
          <CheckRow key={text} text={text} />
        ))}
      </MghCard>

      <Pressable
        onPress={onOpenAbout}
        hitSlop={8}
        accessibilityRole="button"
        accessibilityLabel="How this mockup works"
        style={({ pressed }) => [styles.captionWrap, pressed ? styles.pressed : null]}
      >
        <Text style={[Type.caption, styles.caption]}>
          Tap SIMULATED above to see what is real in this mockup and pick a demo scenario.
        </Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  pressed: { opacity: 0.85 },
  screen: { flex: 1, backgroundColor: Colors.charcoal },
  content: { paddingHorizontal: WELCOME_GUTTER, paddingBottom: 32 },

  header: { flexDirection: 'row', alignItems: 'center', paddingTop: 16 },
  headerBrand: { flex: 1, marginRight: 12 },

  heroWrap: { alignItems: 'center', marginTop: 24 },
  headline: { marginTop: 24, textAlign: 'left' },
  bodyText: { marginTop: 12 },

  savedWrap: { marginTop: 24, marginBottom: 16 },
  savedRow: { flexDirection: 'row', alignItems: 'center' },
  savedIconBox: {
    width: 44,
    height: 44,
    borderRadius: Radii.iconTile,
    backgroundColor: Colors.yellowSoft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  savedText: { flex: 1, marginLeft: 14, marginRight: 4 },
  savedTitle: { fontSize: 16, fontWeight: '700', color: Colors.lightGrey },
  savedSubtitle: { marginTop: 2, fontSize: 13, color: Colors.muted },

  // Without a saved card the button follows the body text at the same 24 px
  // gap; with one, the card's 16 px bottom margin provides the spacing.
  primaryAfterBody: { marginTop: 24 },
  portHintButton: { alignSelf: 'center', marginTop: 8 },
  portHint: { marginTop: 4 },
  expoNote: { marginTop: 20 },

  checkRow: { flexDirection: 'row', alignItems: 'flex-start', paddingVertical: 6 },
  checkText: { flex: 1, marginLeft: 10 },

  captionWrap: { marginTop: 12 },
  caption: { textAlign: 'center' },
});
