// Shared primitives lifted from the Flutter app. Every Animated call sets
// useNativeDriver explicitly: native driver only for opacity/transform on
// native, JS driver on web.

import React, { useEffect, useRef, useState } from 'react';
import {
  Animated,
  Easing,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import Svg, { Circle, Defs, LinearGradient, Rect, Stop } from 'react-native-svg';
import { MaterialCommunityIcons as Icon } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors, alpha, YELLOW_GRADIENT, Radii, Type, ButtonHeight, OutlinedHeight } from './theme';

const NATIVE_DRIVER = Platform.OS !== 'web';
const IS_NATIVE = Platform.OS !== 'web';

let instanceSeq = 0;
// Unique id per mounted component – SVG gradient ids are global DOM ids on web.
export function useInstanceId(prefix) {
  const ref = useRef(null);
  if (ref.current == null) {
    instanceSeq += 1;
    ref.current = `${prefix}-${instanceSeq}`;
  }
  return ref.current;
}

// padding: number | [left, top, right, bottom] (Flutter LTRB order, as the
// spec writes it) | { h, v, top, right, bottom, left }.
export function paddingStyle(padding) {
  if (padding == null) return null;
  if (typeof padding === 'number') return { padding };
  if (Array.isArray(padding)) {
    const [left, top, right, bottom] = padding;
    return { paddingLeft: left, paddingTop: top, paddingRight: right, paddingBottom: bottom };
  }
  const out = {};
  if (padding.h != null) out.paddingHorizontal = padding.h;
  if (padding.v != null) out.paddingVertical = padding.v;
  if (padding.top != null) out.paddingTop = padding.top;
  if (padding.right != null) out.paddingRight = padding.right;
  if (padding.bottom != null) out.paddingBottom = padding.bottom;
  if (padding.left != null) out.paddingLeft = padding.left;
  return out;
}

// ---------------------------------------------------------------------------
// Cards and labels
// ---------------------------------------------------------------------------

export function MghCard({ highlight, padding = 18, style, onPress, children, accessibilityLabel }) {
  const base = [
    styles.card,
    highlight ? styles.cardHighlight : null,
    paddingStyle(padding),
    style,
  ];
  if (onPress) {
    return (
      <Pressable
        onPress={onPress}
        accessibilityRole="button"
        accessibilityLabel={accessibilityLabel}
        android_ripple={{ color: alpha(Colors.yellow, 0.12) }}
        style={({ pressed }) => [base, pressed ? styles.pressedCard : null]}
      >
        {children}
      </Pressable>
    );
  }
  return <View style={base}>{children}</View>;
}

export function Pill({ label, color = Colors.muted, icon, filled, style }) {
  const fg = filled ? Colors.charcoal : color;
  return (
    <View
      style={[
        styles.pill,
        filled
          ? { backgroundColor: color }
          : { backgroundColor: alpha(color, 0.13), borderColor: alpha(color, 0.35), borderWidth: 0.8 },
        style,
      ]}
    >
      {icon ? <Icon name={icon} size={13} color={fg} style={styles.pillIcon} /> : null}
      <Text style={[Type.pill, { color: fg }]} numberOfLines={1}>
        {label}
      </Text>
    </View>
  );
}

export function SimulatedBanner({ compact, style }) {
  return (
    <View style={[styles.banner, compact ? styles.bannerCompact : null, style]}>
      <Icon name="flask-outline" size={18} color={Colors.yellow} />
      <Text style={[Type.banner, styles.bannerText]}>
        {compact
          ? 'SIMULATED DATA · demo scanner'
          : 'SIMULATED DATA – from the built-in demo scanner, not a real vehicle.'}
      </Text>
    </View>
  );
}

// Global strip mounted above every screen in App.js.
export function SimStrip({ onWhatsReal }) {
  return (
    <View style={styles.simStrip}>
      <Icon name="flask-outline" size={14} color={Colors.yellow} />
      {/* The copy cannot fit one line at phone width (360 px) without shrinking
          below legibility, and truncating would hide the word "simulated", so
          the strip wraps to two lines on narrow screens instead. */}
      <Text style={styles.simStripText} numberOfLines={2}>
        UI PROTOTYPE · Bluetooth and devices are simulated
      </Text>
      <Pressable
        onPress={onWhatsReal}
        hitSlop={10}
        accessibilityRole="button"
        accessibilityLabel="What's real? How this mockup works"
      >
        <Text style={styles.simStripLink}>What's real?</Text>
      </Pressable>
    </View>
  );
}

export function InfoNote({ text, icon = 'information-outline', color = Colors.muted, style, children }) {
  return (
    <View style={[styles.infoNote, style]}>
      <Icon name={icon} size={16} color={color} style={styles.infoNoteIcon} />
      <Text style={[styles.infoNoteText, { color }]}>{text != null ? text : children}</Text>
    </View>
  );
}

export function SectionTitle({ title, trailing, style }) {
  return (
    <View style={[styles.sectionTitle, style]}>
      <Text style={[Type.sectionTitle, styles.sectionTitleText]}>{title}</Text>
      {trailing || null}
    </View>
  );
}

export function StatusDot({ color, size = 9, pulse, style }) {
  const opacity = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    if (!pulse) {
      opacity.setValue(1);
      return undefined;
    }
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(opacity, { toValue: 0.35, duration: 900, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER }),
        Animated.timing(opacity, { toValue: 1, duration: 900, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [pulse, opacity]);

  const glow = Platform.select({
    web: { boxShadow: `0 0 8px ${alpha(color, 0.6)}` },
    default: { shadowColor: color, shadowOpacity: 0.6, shadowRadius: 8, shadowOffset: { width: 0, height: 0 } },
  });
  return (
    <Animated.View
      style={[
        { width: size, height: size, borderRadius: size / 2, backgroundColor: color, opacity },
        glow,
        style,
      ]}
    />
  );
}

export function KeyValueRow({ k, v }) {
  return (
    <View style={styles.kvRow}>
      <View style={styles.kvKey}>
        <Text style={styles.kvKeyText}>{k}</Text>
      </View>
      <Text style={styles.kvValue}>{v}</Text>
    </View>
  );
}

export function Divider({ style }) {
  return <View style={[styles.divider, style]} />;
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

export function FilledButton({ label, icon, onPress, disabled, loading, style, accessibilityLabel }) {
  const inert = disabled || loading;
  const fg = inert ? Colors.faint : Colors.charcoal;
  return (
    <Pressable
      onPress={onPress}
      disabled={inert}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel || label}
      accessibilityState={{ disabled: !!inert, busy: !!loading }}
      aria-busy={!!loading}
      style={({ pressed }) => [
        styles.filledButton,
        inert ? styles.filledButtonDisabled : null,
        pressed && !inert ? styles.pressed : null,
        style,
      ]}
    >
      {loading ? (
        <Spinner size={18} color={Colors.faint} />
      ) : icon ? (
        <Icon name={icon} size={20} color={fg} />
      ) : null}
      <Text style={[Type.button, { color: fg }, icon || loading ? styles.buttonLabelGap : null]}>{label}</Text>
    </Pressable>
  );
}

export function OutlinedButton({ label, icon, onPress, disabled, style, accessibilityLabel }) {
  const fg = disabled ? Colors.faint : Colors.white;
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel || label}
      accessibilityState={{ disabled: !!disabled }}
      style={({ pressed }) => [styles.outlinedButton, pressed && !disabled ? styles.pressed : null, style]}
    >
      {icon ? <Icon name={icon} size={18} color={fg} /> : null}
      <Text style={[Type.buttonOutlined, { color: fg }, icon ? styles.buttonLabelGap : null]}>{label}</Text>
    </Pressable>
  );
}

// `icon` (optional, 16 px) renders after the label – used for Show/Hide chevrons.
export function TextButton({ label, icon, onPress, style, textStyle, color = Colors.yellow, accessibilityLabel }) {
  return (
    <Pressable
      onPress={onPress}
      hitSlop={8}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel || label}
      style={({ pressed }) => [styles.textButton, pressed ? styles.pressed : null, style]}
    >
      <Text style={[Type.textButton, { color }, textStyle]}>{label}</Text>
      {icon ? <Icon name={icon} size={16} color={color} style={styles.textButtonIcon} /> : null}
    </Pressable>
  );
}

export function IconButton({
  icon,
  size = 22,
  color = Colors.lightGrey,
  filled,
  filledBg = Colors.surfaceHigh,
  onPress,
  accessibilityLabel,
  hitSlop = 8,
  disabled,
  style,
}) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      hitSlop={hitSlop}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      style={({ pressed }) => [
        styles.iconButton,
        filled ? { backgroundColor: filledBg, borderRadius: 20 } : null,
        pressed ? styles.pressed : null,
        style,
      ]}
    >
      <Icon name={icon} size={size} color={color} />
    </Pressable>
  );
}

// ---------------------------------------------------------------------------
// Composite pieces
// ---------------------------------------------------------------------------

export function EmptyState({ icon, title, message, style }) {
  return (
    <View style={[styles.emptyState, style]}>
      <View style={styles.emptyRing}>
        <Icon name={icon} size={32} color={Colors.yellow} />
      </View>
      <Text style={[Type.titleLarge, styles.emptyTitle]}>{title}</Text>
      <Text style={[Type.bodyMuted, styles.emptyMessage]}>{message}</Text>
    </View>
  );
}

// Always the simulated-ready state: yellow dot, no pulse, label "Demo".
export function ConnectionPill({ onPress, style }) {
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel="Scanner connection: Demo connected"
      style={({ pressed }) => [styles.connectionPill, pressed ? styles.pressed : null, style]}
    >
      <StatusDot color={Colors.yellow} size={9} />
      <Text style={styles.connectionPillLabel}>Demo</Text>
    </Pressable>
  );
}

export function IqBadge({ size = 1 }) {
  const id = useInstanceId('iqBadge');
  const [box, setBox] = useState(null);
  const radius = Radii.iqBadge * size;
  return (
    <View
      style={[styles.iqBadge, { paddingHorizontal: 7 * size, paddingVertical: 2.5 * size, borderRadius: radius }]}
      onLayout={(e) => {
        const { width, height } = e.nativeEvent.layout;
        setBox({ width, height });
      }}
    >
      {box ? (
        <Svg width={box.width} height={box.height} style={StyleSheet.absoluteFill} pointerEvents="none">
          <Defs>
            <LinearGradient id={id} x1="0" y1="0" x2="1" y2="1">
              {YELLOW_GRADIENT.map((c, i) => (
                <Stop key={c} offset={i / (YELLOW_GRADIENT.length - 1)} stopColor={c} />
              ))}
            </LinearGradient>
          </Defs>
          <Rect x="0" y="0" width={box.width} height={box.height} rx={radius} fill={`url(#${id})`} />
        </Svg>
      ) : null}
      <Text style={[Type.iqBadge, { fontSize: 12 * size }]}>IQ</Text>
    </View>
  );
}

// Text-based placeholder until official logo artwork is supplied.
export function BrandWordmark({ size = 1, style }) {
  return (
    <View style={[styles.wordmark, style]}>
      <Text
        style={[Type.wordmark, { fontSize: 13 * size, letterSpacing: 2.4 * size }]}
        numberOfLines={1}
        adjustsFontSizeToFit={IS_NATIVE}
      >
        MY GARAGE HERO
      </Text>
      <View style={{ width: 8 * size }} />
      <IqBadge size={size} />
    </View>
  );
}

const BAR_HEIGHTS = [6, 10, 14, 18];

export function SignalBars({ bars = 0, lit = Colors.yellow, animateIn, style }) {
  const values = useRef(BAR_HEIGHTS.map(() => new Animated.Value(animateIn ? 0 : 1))).current;
  useEffect(() => {
    if (!animateIn) {
      values.forEach((v) => v.setValue(1));
      return undefined;
    }
    const litValues = values.slice(0, Math.max(0, Math.min(bars, values.length)));
    values.forEach((v, i) => v.setValue(i < bars ? 0 : 1));
    const anim = Animated.stagger(
      60,
      litValues.map((v) => Animated.timing(v, { toValue: 1, duration: 120, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER })),
    );
    anim.start();
    return () => anim.stop();
  }, [bars, animateIn, values]);

  return (
    <View style={[styles.signalBars, style]} accessibilityLabel={`Signal ${bars} of 4`}>
      {BAR_HEIGHTS.map((h, i) => (
        <Animated.View
          key={h}
          style={[styles.signalBar, { height: h, backgroundColor: i < bars ? lit : Colors.outline, opacity: values[i] }]}
        />
      ))}
    </View>
  );
}

// SVG ring rotated by an Animated.View – no JS-driven SVG props.
export function Spinner({ size = 22, color = Colors.yellow, stroke = 2.2, style }) {
  const spin = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.timing(spin, { toValue: 1, duration: 900, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER }),
    );
    loop.start();
    return () => loop.stop();
  }, [spin]);
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const rotate = spin.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '360deg'] });
  return (
    <Animated.View style={[{ width: size, height: size, transform: [{ rotate }] }, style]}>
      <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          stroke={color}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={[c * 0.75, c * 0.25]}
          fill="none"
        />
      </Svg>
    </Animated.View>
  );
}

export function Chip({ label, selected, onPress, style }) {
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityState={{ selected: !!selected }}
      aria-selected={!!selected}
      style={({ pressed }) => [styles.chip, selected ? styles.chipSelected : null, pressed ? styles.pressed : null, style]}
    >
      <Text style={[styles.chipLabel, selected ? styles.chipLabelSelected : null]}>{label}</Text>
    </Pressable>
  );
}

export function ChipRow({ options, value, onChange, style }) {
  return (
    <View style={[styles.chipRow, style]}>
      {options.map((opt) => (
        <Chip
          key={opt.key}
          label={opt.label}
          selected={opt.key === value}
          onPress={() => onChange && onChange(opt.key)}
          style={styles.chipRowItem}
        />
      ))}
    </View>
  );
}

// ---------------------------------------------------------------------------
// Entrance animation shared by device rows (PairSheet) and fault cards (Faults)
// ---------------------------------------------------------------------------

const FADE_IN_MS = 220;
const FADE_IN_RISE = 8;

// Opacity 0->1 + translateY 8->0 over 220 ms Easing.out(quad); `delay` gives
// the stagger. Runs once on mount and is stopped on unmount.
export function FadeIn({ delay = 0, children, style }) {
  const v = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const anim = Animated.timing(v, {
      toValue: 1,
      duration: FADE_IN_MS,
      delay,
      easing: Easing.out(Easing.quad),
      useNativeDriver: NATIVE_DRIVER,
    });
    anim.start();
    return () => anim.stop();
  }, [v, delay]);
  const translateY = v.interpolate({ inputRange: [0, 1], outputRange: [FADE_IN_RISE, 0] });
  return <Animated.View style={[{ opacity: v, transform: [{ translateY }] }, style]}>{children}</Animated.View>;
}

// ---------------------------------------------------------------------------
// Bottom sheet chrome shared by PairSheet and AboutSheet
// ---------------------------------------------------------------------------

const SHEET_OPEN_MS = 320;
const SHEET_CLOSE_MS = 240;
const BACKDROP_MS = 200;

// Modal + backdrop + sliding sheet. `onRequestClose` is called for the close
// button, the backdrop and the Android back button; the parent decides whether
// to actually set `visible` false (PairSheet turns a tap into Cancel while
// connecting). `headerExtra` renders between the title and the close button.
export function SheetFrame({
  visible,
  title,
  titleStyle,
  headerExtra,
  onRequestClose,
  children,
  scroll = true,
  contentStyle,
  closeAccessibilityLabel = 'Close',
}) {
  const { height: windowHeight } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const [mounted, setMounted] = useState(!!visible);
  const backdrop = useRef(new Animated.Value(0)).current;
  const translateY = useRef(new Animated.Value(windowHeight)).current;
  const running = useRef(null);

  useEffect(() => {
    if (running.current) {
      running.current.stop();
      running.current = null;
    }
    if (visible) {
      setMounted(true);
      translateY.setValue(windowHeight);
      const anim = Animated.parallel([
        Animated.timing(backdrop, { toValue: 1, duration: BACKDROP_MS, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER }),
        Animated.timing(translateY, { toValue: 0, duration: SHEET_OPEN_MS, easing: Easing.out(Easing.cubic), useNativeDriver: NATIVE_DRIVER }),
      ]);
      running.current = anim;
      anim.start(() => {
        running.current = null;
      });
    } else if (mounted) {
      const anim = Animated.parallel([
        Animated.timing(backdrop, { toValue: 0, duration: BACKDROP_MS, easing: Easing.linear, useNativeDriver: NATIVE_DRIVER }),
        Animated.timing(translateY, { toValue: windowHeight, duration: SHEET_CLOSE_MS, easing: Easing.in(Easing.cubic), useNativeDriver: NATIVE_DRIVER }),
      ]);
      running.current = anim;
      anim.start(({ finished }) => {
        running.current = null;
        if (finished) setMounted(false);
      });
    }
    return undefined;
    // windowHeight changes mid-animation are rare; mounted is intentionally
    // not a dependency so a finished close does not restart the animation.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  useEffect(() => () => {
    if (running.current) running.current.stop();
  }, []);

  if (!mounted) return null;

  const body = scroll ? (
    <ScrollView
      style={styles.sheetScroll}
      contentContainerStyle={[styles.sheetContent, contentStyle]}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
    >
      {children}
    </ScrollView>
  ) : (
    <View style={[styles.sheetContent, contentStyle]}>{children}</View>
  );

  return (
    <Modal transparent animationType="none" visible={mounted} onRequestClose={onRequestClose} statusBarTranslucent>
      <View style={styles.sheetRoot}>
        <Animated.View style={[styles.backdrop, { opacity: backdrop }]}>
          <Pressable style={StyleSheet.absoluteFill} onPress={onRequestClose} accessibilityLabel="Dismiss" />
        </Animated.View>
        <Animated.View
          style={[
            styles.sheet,
            { maxHeight: windowHeight * 0.88, paddingBottom: insets.bottom + 16, transform: [{ translateY }] },
          ]}
        >
          <View style={styles.dragHandle} />
          <View style={styles.sheetHeader}>
            <Text style={[Type.sheetTitle, styles.sheetTitle, titleStyle]}>{title}</Text>
            {headerExtra || null}
            <IconButton icon="close" accessibilityLabel={closeAccessibilityLabel} onPress={onRequestClose} />
          </View>
          {body}
        </Animated.View>
      </View>
    </Modal>
  );
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const styles = StyleSheet.create({
  pressed: { opacity: 0.85 },
  pressedCard: { opacity: 0.92 },

  card: {
    backgroundColor: Colors.surface,
    borderRadius: Radii.card,
    borderWidth: 0.6,
    borderColor: Colors.outline,
    overflow: 'hidden',
  },
  cardHighlight: { borderWidth: 1.2, borderColor: alpha(Colors.yellow, 0.7) },

  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    paddingHorizontal: 9,
    paddingVertical: 4,
    borderRadius: Radii.pill,
  },
  pillIcon: { marginRight: 4 },

  banner: {
    flexDirection: 'row',
    alignItems: 'center',
    width: '100%',
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: Radii.banner,
    backgroundColor: alpha(Colors.yellow, 0.1),
    borderWidth: 1,
    borderColor: alpha(Colors.yellow, 0.5),
  },
  bannerCompact: { paddingVertical: 7 },
  bannerText: { flex: 1, marginLeft: 10 },

  simStrip: {
    minHeight: 30,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 4,
    backgroundColor: Colors.surfaceRaised,
    borderBottomWidth: 0.6,
    borderBottomColor: Colors.outline,
  },
  simStripText: {
    flex: 1,
    marginLeft: 6,
    fontSize: 11,
    lineHeight: 14,
    fontWeight: '800',
    letterSpacing: 1,
    color: Colors.yellow,
  },
  simStripLink: {
    fontSize: 12,
    fontWeight: '700',
    color: Colors.yellow,
    textDecorationLine: 'underline',
    marginLeft: 8,
  },

  infoNote: { flexDirection: 'row', alignItems: 'flex-start' },
  infoNoteIcon: { marginTop: 1, marginRight: 8 },
  infoNoteText: { flex: 1, fontSize: 13, lineHeight: 18 },

  sectionTitle: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingLeft: 4,
    paddingTop: 22,
    paddingRight: 4,
    paddingBottom: 10,
  },
  sectionTitleText: { flex: 1 },

  kvRow: { flexDirection: 'row', alignItems: 'flex-start', paddingVertical: 3 },
  kvKey: { width: 120 },
  kvKeyText: { fontSize: 14, color: Colors.muted },
  kvValue: { flex: 1, fontSize: 14, fontWeight: '600', color: Colors.lightGrey },

  divider: { height: 0.6, backgroundColor: Colors.outline, marginVertical: 12 },

  filledButton: {
    minHeight: ButtonHeight,
    borderRadius: Radii.button,
    backgroundColor: Colors.yellow,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 18,
  },
  filledButtonDisabled: { backgroundColor: Colors.surfaceHigh },
  outlinedButton: {
    minHeight: OutlinedHeight,
    borderRadius: Radii.button,
    borderWidth: 1,
    borderColor: Colors.outline,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
  },
  buttonLabelGap: { marginLeft: 8 },
  textButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 8,
    paddingHorizontal: 12,
  },
  textButtonIcon: { marginLeft: 2 },
  iconButton: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center' },

  emptyState: { paddingHorizontal: 28, paddingVertical: 36, alignItems: 'center' },
  emptyRing: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: alpha(Colors.yellow, 0.1),
    borderWidth: 1,
    borderColor: alpha(Colors.yellow, 0.35),
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyTitle: { marginTop: 18, textAlign: 'center' },
  emptyMessage: { marginTop: 8, textAlign: 'center', lineHeight: 20 },

  connectionPill: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 7,
    backgroundColor: Colors.surfaceRaised,
    borderRadius: Radii.pill,
    borderWidth: 1,
    borderColor: alpha(Colors.yellow, 0.45),
  },
  connectionPillLabel: { marginLeft: 8, fontSize: 13, fontWeight: '700', color: Colors.white },

  wordmark: { flexDirection: 'row', alignItems: 'center', alignSelf: 'flex-start' },
  iqBadge: {
    alignSelf: 'flex-start',
    backgroundColor: Colors.yellow,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },

  signalBars: { flexDirection: 'row', alignItems: 'flex-end' },
  signalBar: { width: 4, borderRadius: 2, marginLeft: 2 },

  chip: {
    alignSelf: 'flex-start',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: Radii.chip,
    backgroundColor: Colors.surfaceRaised,
    borderWidth: 1,
    borderColor: Colors.outline,
  },
  chipSelected: { backgroundColor: Colors.yellow, borderColor: Colors.yellow },
  chipLabel: { fontSize: 13, color: Colors.lightGrey },
  chipLabelSelected: { color: Colors.charcoal, fontWeight: '700' },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', marginRight: -8, marginBottom: -8 },
  chipRowItem: { marginRight: 8, marginBottom: 8 },

  sheetRoot: { flex: 1, justifyContent: 'flex-end' },
  backdrop: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.55)' },
  sheet: {
    backgroundColor: Colors.surface,
    borderTopLeftRadius: Radii.sheet,
    borderTopRightRadius: Radii.sheet,
    width: '100%',
    overflow: 'hidden',
  },
  dragHandle: {
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: Colors.outline,
    alignSelf: 'center',
    marginTop: 10,
  },
  sheetHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingLeft: 20,
    paddingTop: 12,
    paddingRight: 12,
    paddingBottom: 0,
  },
  sheetTitle: { flex: 1, marginRight: 8 },
  sheetScroll: { flexGrow: 0 },
  sheetContent: { paddingHorizontal: 20, paddingTop: 12, paddingBottom: 8 },
});
