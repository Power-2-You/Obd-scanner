// ArcGauge (270° SVG arc with an animated dash offset) and MetricTile
// (value + sparkline). SVG props are animated on the JS driver only;
// gradient ids are unique per mounted instance (web DOM ids are global).

import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Animated, Easing, Pressable, StyleSheet, Text, View, Platform } from 'react-native';
import Svg, { Circle, Defs, Line, LinearGradient, Path, Polygon, Polyline, Stop } from 'react-native-svg';
import { MaterialCommunityIcons as Icon } from '@expo/vector-icons';
import { Colors, alpha, Radii, Type, tabular } from './theme';

const AnimatedPath = Animated.createAnimatedComponent(Path);
const AnimatedCircle = Animated.createAnimatedComponent(Circle);
const IS_NATIVE = Platform.OS !== 'web';

const ARC_START_DEG = 135;
const ARC_SWEEP_DEG = 270;
const TICK_COUNT = 33; // 8 major * 4 + 1
const TWEEN_MS = 450;
const SPARK_HEIGHT = 18;
const SPARK_MAX = 60;

let gaugeSeq = 0;
function useInstanceId(prefix) {
  const ref = useRef(null);
  if (ref.current == null) {
    gaugeSeq += 1;
    ref.current = `${prefix}-${gaugeSeq}`;
  }
  return ref.current;
}

function rad(deg) {
  return (deg * Math.PI) / 180;
}

function clamp(x, lo, hi) {
  return Math.min(hi, Math.max(lo, x));
}

function fmt(value, decimals) {
  return Number(value).toFixed(decimals);
}

// ---------------------------------------------------------------------------
// ArcGauge
// ---------------------------------------------------------------------------

export function ArcGauge({ label, unit, min = 0, max = 100, value = 0, decimals = 0, size = 180, warnAbove, style }) {
  const id = useInstanceId('arc');
  const span = max - min || 1;
  const fraction = clamp((Number(value) - min) / span, 0, 1);
  const warn = warnAbove != null && Number(value) >= warnAbove;
  const frac = useRef(new Animated.Value(fraction)).current;

  useEffect(() => {
    const anim = Animated.timing(frac, {
      toValue: fraction,
      duration: TWEEN_MS,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: false,
    });
    anim.start();
    return () => anim.stop();
  }, [fraction, frac]);

  const geo = useMemo(() => {
    const stroke = size * 0.06;
    const cx = size / 2;
    const cy = size / 2;
    const R = size / 2 - stroke;
    const L = 2 * Math.PI * R * 0.75;
    const start = { x: cx + R * Math.cos(rad(ARC_START_DEG)), y: cy + R * Math.sin(rad(ARC_START_DEG)) };
    const end = {
      x: cx + R * Math.cos(rad(ARC_START_DEG + ARC_SWEEP_DEG)),
      y: cy + R * Math.sin(rad(ARC_START_DEG + ARC_SWEEP_DEG)),
    };
    const arcPath = `M ${start.x} ${start.y} A ${R} ${R} 0 1 1 ${end.x} ${end.y}`;
    const ticks = [];
    const rOuter = R - stroke * 0.95;
    for (let i = 0; i < TICK_COUNT; i += 1) {
      const major = i % 4 === 0;
      const theta = rad(ARC_START_DEG + (ARC_SWEEP_DEG * i) / (TICK_COUNT - 1));
      const len = major ? stroke * 0.7 : stroke * 0.35;
      ticks.push({
        major,
        at: i / (TICK_COUNT - 1),
        x1: cx + rOuter * Math.cos(theta),
        y1: cy + rOuter * Math.sin(theta),
        x2: cx + (rOuter - len) * Math.cos(theta),
        y2: cy + (rOuter - len) * Math.sin(theta),
      });
    }
    const inputRange = [];
    const xs = [];
    const ys = [];
    for (let k = 0; k < TICK_COUNT; k += 1) {
      const theta = rad(ARC_START_DEG + (ARC_SWEEP_DEG * k) / (TICK_COUNT - 1));
      inputRange.push(k / (TICK_COUNT - 1));
      xs.push(cx + R * Math.cos(theta));
      ys.push(cy + R * Math.sin(theta));
    }
    return { stroke, cx, cy, R, L, arcPath, ticks, tip: { inputRange, xs, ys } };
  }, [size]);

  const dashOffset = frac.interpolate({ inputRange: [0, 1], outputRange: [geo.L, 0] });
  const tipX = frac.interpolate({ inputRange: geo.tip.inputRange, outputRange: geo.tip.xs });
  const tipY = frac.interpolate({ inputRange: geo.tip.inputRange, outputRange: geo.tip.ys });
  const arcColour = warn ? Colors.caution : Colors.yellow;
  const stops = warn ? [Colors.yellow, Colors.caution] : [Colors.yellowDeep, Colors.yellow, Colors.gradArcTip];
  const valueText = fmt(value, decimals);
  const height = size * 0.86;

  return (
    <View style={[{ width: size, height }, styles.gaugeBox, style]} accessibilityLabel={`${label} ${valueText} ${unit}`}>
      <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={styles.gaugeSvg}>
        <Defs>
          <LinearGradient id={id} x1="0" y1="1" x2="1" y2="0">
            {stops.map((colour, i) => (
              <Stop key={colour} offset={stops.length === 1 ? 0 : i / (stops.length - 1)} stopColor={colour} />
            ))}
          </LinearGradient>
        </Defs>
        <Path d={geo.arcPath} stroke={Colors.surfaceHigh} strokeWidth={geo.stroke} strokeLinecap="round" fill="none" />
        {geo.ticks.map((t, i) => {
          const lit = t.at <= fraction;
          const colour = lit
            ? alpha(Colors.yellow, t.major ? 0.9 : 0.5)
            : t.major
              ? Colors.outline
              : alpha(Colors.outline, 0.6);
          return <Line key={i} x1={t.x1} y1={t.y1} x2={t.x2} y2={t.y2} stroke={colour} strokeWidth={1.4} strokeLinecap="round" />;
        })}
        {fraction > 0 ? (
          <>
            <AnimatedPath
              d={geo.arcPath}
              stroke={alpha(arcColour, 0.18)}
              strokeWidth={geo.stroke * 1.6}
              strokeLinecap="round"
              fill="none"
              strokeDasharray={[geo.L, geo.L]}
              strokeDashoffset={dashOffset}
            />
            <AnimatedPath
              d={geo.arcPath}
              stroke={`url(#${id})`}
              strokeWidth={geo.stroke}
              strokeLinecap="round"
              fill="none"
              strokeDasharray={[geo.L, geo.L]}
              strokeDashoffset={dashOffset}
            />
            <AnimatedCircle cx={tipX} cy={tipY} r={geo.stroke * 0.42} fill={Colors.white} />
          </>
        ) : null}
      </Svg>
      <View style={[styles.gaugeText, { paddingTop: size * 0.2 }]} pointerEvents="none">
        <Text
          style={[
            styles.gaugeValue,
            tabular,
            { fontSize: size * 0.2, lineHeight: size * 0.2, color: warn ? Colors.caution : Colors.white },
          ]}
        >
          {valueText}
        </Text>
        <Text style={[styles.gaugeUnit, { fontSize: size * 0.07, marginTop: size * 0.025 }]}>{unit}</Text>
        <Text style={[styles.gaugeLabel, { fontSize: size * 0.058, marginTop: size * 0.07 }]}>{String(label).toUpperCase()}</Text>
      </View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// MetricTile
// ---------------------------------------------------------------------------

function Sparkline({ history, accent, id }) {
  const [width, setWidth] = useState(0);
  const values = history.length > SPARK_MAX ? history.slice(history.length - SPARK_MAX) : history;
  const n = values.length;

  let line = null;
  let area = null;
  if (width > 0 && n >= 2) {
    let lo = Math.min(...values);
    let hi = Math.max(...values);
    if (hi - lo === 0) {
      lo -= 1;
      hi += 1;
    }
    const pts = values.map((v, i) => {
      const x = (width * i) / (n - 1);
      const y = SPARK_HEIGHT - 1 - ((v - lo) / (hi - lo)) * (SPARK_HEIGHT - 2);
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    });
    line = pts.join(' ');
    area = `${line} ${width},${SPARK_HEIGHT} 0,${SPARK_HEIGHT}`;
  }

  return (
    <View style={styles.spark} onLayout={(e) => setWidth(e.nativeEvent.layout.width)}>
      {width > 0 ? (
        <Svg width={width} height={SPARK_HEIGHT} viewBox={`0 0 ${width} ${SPARK_HEIGHT}`}>
          <Defs>
            <LinearGradient id={id} x1="0" y1="0" x2="0" y2="1">
              <Stop offset="0" stopColor={accent} stopOpacity="0.25" />
              <Stop offset="1" stopColor={accent} stopOpacity="0" />
            </LinearGradient>
          </Defs>
          {line ? (
            <>
              <Polygon points={area} fill={`url(#${id})`} />
              <Polyline points={line} fill="none" stroke={accent} strokeWidth={1.6} strokeLinejoin="round" strokeLinecap="round" />
            </>
          ) : (
            <Line x1={0} y1={SPARK_HEIGHT - 1} x2={width} y2={SPARK_HEIGHT - 1} stroke={Colors.outline} strokeWidth={1} />
          )}
        </Svg>
      ) : null}
    </View>
  );
}

export function MetricTile({
  icon,
  label,
  unit,
  value,
  decimals = 0,
  history = [],
  statusText,
  accent = Colors.yellow,
  onPress,
  width,
  style,
}) {
  const id = useInstanceId('spark');
  const available = value != null && !Number.isNaN(Number(value));
  const valueText = available ? fmt(value, decimals) : null;
  const a11y = available ? `${label} ${valueText} ${unit}${statusText ? `. ${statusText}` : ''}` : `${label} ${statusText || 'Unavailable'}`;

  const content = (
    <>
      <View style={styles.tileHeader}>
        <Icon name={icon} size={18} color={available ? accent : Colors.faint} />
        <Text style={[Type.metricLabel, styles.tileLabel]} numberOfLines={1}>
          {label}
        </Text>
      </View>
      <View>
        {available ? (
          <View style={styles.tileValueRow}>
            <Text style={[Type.metricValue, styles.tileValue]} numberOfLines={1} adjustsFontSizeToFit={IS_NATIVE}>
              {valueText}
            </Text>
            <Text style={styles.tileUnit}>{unit}</Text>
          </View>
        ) : (
          <Text style={styles.tileUnavailable} numberOfLines={2}>
            {statusText || 'Unavailable'}
          </Text>
        )}
        {available && statusText ? <Text style={styles.tileStatus}>{statusText}</Text> : null}
      </View>
      <Sparkline history={history} accent={accent} id={id} />
    </>
  );

  const box = [styles.tile, width != null ? { width } : styles.tileFlex, style];
  if (onPress) {
    return (
      <Pressable
        onPress={onPress}
        accessibilityRole="button"
        accessibilityLabel={a11y}
        android_ripple={{ color: alpha(Colors.yellow, 0.12) }}
        style={({ pressed }) => [box, pressed ? styles.tilePressed : null]}
      >
        {content}
      </Pressable>
    );
  }
  return (
    <View style={box} accessibilityLabel={a11y}>
      {content}
    </View>
  );
}

const styles = StyleSheet.create({
  gaugeBox: { overflow: 'visible' },
  gaugeSvg: { position: 'absolute', left: 0, top: 0 },
  gaugeText: { position: 'absolute', left: 0, right: 0, top: 0, alignItems: 'center' },
  gaugeValue: { fontWeight: '700', letterSpacing: -1 },
  gaugeUnit: { color: Colors.muted, fontWeight: '600' },
  gaugeLabel: { color: Colors.yellow, fontWeight: '800', letterSpacing: 1.6 },

  tile: {
    backgroundColor: Colors.surface,
    borderRadius: Radii.tile,
    borderWidth: 0.6,
    borderColor: Colors.outline,
    paddingLeft: 14,
    paddingTop: 12,
    paddingRight: 14,
    paddingBottom: 12,
    aspectRatio: 1.2,
    justifyContent: 'space-between',
    overflow: 'hidden',
  },
  tileFlex: { flex: 1 },
  tilePressed: { opacity: 0.92 },
  tileHeader: { flexDirection: 'row', alignItems: 'center' },
  tileLabel: { flex: 1, marginLeft: 8 },
  tileValueRow: { flexDirection: 'row', alignItems: 'baseline' },
  tileValue: { flexShrink: 1 },
  tileUnit: { marginLeft: 4, fontSize: 14, fontWeight: '600', color: Colors.muted },
  tileUnavailable: { fontSize: 14, fontWeight: '600', color: Colors.faint },
  tileStatus: { marginTop: 2, fontSize: 12, color: Colors.faint },
  spark: { height: SPARK_HEIGHT, width: '100%' },
});
