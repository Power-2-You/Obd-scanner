// Stylised Boost N' Inflate IQ: three native-driver signal rings, a soft glow,
// an optional radar sweep and a static SVG device body. Nothing here is
// driven per frame through SVG props.

import React, { useEffect, useMemo, useRef } from 'react';
import { Animated, Easing, Platform, StyleSheet, View } from 'react-native';
import Svg, { Circle, Defs, LinearGradient, Path, RadialGradient, Rect, Stop } from 'react-native-svg';
import { Colors, alpha, YELLOW_GRADIENT } from './theme';

const NATIVE_DRIVER = Platform.OS !== 'web';
const RING_PERIOD_MS = 2600;
const RING_DELAYS_MS = [0, 866, 1733];
const RADAR_PERIOD_MS = 2400;
const GLOW_IDLE = 0.18;
const GLOW_ACTIVE = 0.35;
const MINI_ARC_SWEEP_DEG = 139.5;

let heroSeq = 0;

function rad(deg) {
  return (deg * Math.PI) / 180;
}

function polar(cx, cy, radius, deg) {
  return { x: cx + radius * Math.cos(rad(deg)), y: cy + radius * Math.sin(rad(deg)) };
}

function useInstanceId() {
  const ref = useRef(null);
  if (ref.current == null) {
    heroSeq += 1;
    ref.current = `hero${heroSeq}`;
  }
  return ref.current;
}

function SignalRing({ value, r }) {
  const scale = value.interpolate({ inputRange: [0, 1], outputRange: [0.42, 1] });
  const opacity = value.interpolate({ inputRange: [0, 1], outputRange: [0.45, 0] });
  return (
    <Animated.View
      pointerEvents="none"
      style={[
        styles.abs,
        {
          left: 0,
          top: 0,
          width: r * 2,
          height: r * 2,
          borderRadius: r,
          borderWidth: 1.4,
          borderColor: Colors.yellow,
          transform: [{ scale }],
          opacity,
        },
      ]}
    />
  );
}

export default function IqHeroGraphic({ size = 220, animate = true, active = false, radar = false, style }) {
  const id = useInstanceId();
  const r = size / 2;
  const c = r;

  const rings = useRef(RING_DELAYS_MS.map(() => new Animated.Value(0))).current;
  const sweep = useRef(new Animated.Value(0)).current;
  const glow = useRef(new Animated.Value(active ? GLOW_ACTIVE : GLOW_IDLE)).current;

  useEffect(() => {
    if (!animate) return undefined;
    const timers = [];
    const loops = [];
    rings.forEach((value, i) => {
      timers.push(
        setTimeout(() => {
          value.setValue(0);
          const loop = Animated.loop(
            Animated.timing(value, {
              toValue: 1,
              duration: RING_PERIOD_MS,
              easing: Easing.linear,
              useNativeDriver: NATIVE_DRIVER,
            }),
          );
          loops.push(loop);
          loop.start();
        }, RING_DELAYS_MS[i]),
      );
    });
    return () => {
      timers.forEach(clearTimeout);
      loops.forEach((loop) => loop.stop());
      rings.forEach((value) => value.setValue(0));
    };
  }, [animate, rings]);

  useEffect(() => {
    if (!radar) return undefined;
    sweep.setValue(0);
    const loop = Animated.loop(
      Animated.timing(sweep, {
        toValue: 1,
        duration: RADAR_PERIOD_MS,
        easing: Easing.linear,
        useNativeDriver: NATIVE_DRIVER,
      }),
    );
    loop.start();
    return () => loop.stop();
  }, [radar, sweep]);

  useEffect(() => {
    const anim = Animated.timing(glow, {
      toValue: active ? GLOW_ACTIVE : GLOW_IDLE,
      duration: 300,
      easing: Easing.out(Easing.quad),
      useNativeDriver: NATIVE_DRIVER,
    });
    anim.start();
    return () => anim.stop();
  }, [active, glow]);

  // Geometry is computed once per size, never per frame.
  const geo = useMemo(() => {
    const wedgeEnd = polar(c, c, r, -30); // 60° wedge from 12 o'clock, clockwise
    const radarPath = `M ${c} ${c} L ${c} 0 A ${r} ${r} 0 0 1 ${wedgeEnd.x} ${wedgeEnd.y} Z`;

    const bodyW = r * 0.62;
    const bodyH = r * 0.86;
    const winW = r * 0.44;
    const winH = r * 0.3;
    const winCy = c - r * 0.12;
    const arcCx = c;
    const arcCy = winCy + r * 0.05;
    const arcR = r * 0.1;
    const arcStart = polar(arcCx, arcCy, arcR, 180);
    const arcEnd = polar(arcCx, arcCy, arcR, 180 + MINI_ARC_SWEEP_DEG);
    const miniArc = `M ${arcStart.x} ${arcStart.y} A ${arcR} ${arcR} 0 0 1 ${arcEnd.x} ${arcEnd.y}`;
    const stripW = r * 0.3;
    const stripH = r * 0.035;

    return {
      radarPath,
      body: { x: c - bodyW / 2, y: c - bodyH / 2, w: bodyW, h: bodyH, rx: r * 0.14 },
      win: { x: c - winW / 2, y: winCy - winH / 2, w: winW, h: winH, rx: r * 0.05 },
      miniArc,
      miniArcWidth: r * 0.025,
      strip: { x: c - stripW / 2, y: c + r * 0.16 - stripH / 2, w: stripW, h: stripH, rx: r * 0.02 },
      buttons: [c - 0.1 * r, c, c + 0.1 * r].map((x) => ({ x, y: c + r * 0.28, r: r * 0.028 })),
    };
  }, [r, c]);

  const sweepRotate = sweep.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '360deg'] });
  const glowD = r * 0.92;

  return (
    <View style={[{ width: size, height: size }, styles.container, style]} pointerEvents="none">
      {radar ? (
        <Animated.View style={[styles.abs, { left: 0, top: 0, width: r * 2, height: r * 2, transform: [{ rotate: sweepRotate }] }]}>
          <Svg width={r * 2} height={r * 2} viewBox={`0 0 ${r * 2} ${r * 2}`}>
            <Defs>
              <LinearGradient id={`radarGrad-${id}`} x1="0" y1="0" x2="1" y2="0">
                <Stop offset="0" stopColor={Colors.yellow} stopOpacity="0" />
                <Stop offset="1" stopColor={Colors.yellow} stopOpacity="0.22" />
              </LinearGradient>
            </Defs>
            <Path d={geo.radarPath} fill={`url(#radarGrad-${id})`} />
          </Svg>
        </Animated.View>
      ) : null}

      {animate ? rings.map((value, i) => <SignalRing key={RING_DELAYS_MS[i]} value={value} r={r} />) : null}

      <Animated.View style={[styles.abs, { left: (size - glowD) / 2, top: (size - glowD) / 2, width: glowD, height: glowD, opacity: glow }]}>
        <Svg width={glowD} height={glowD} viewBox={`0 0 ${glowD} ${glowD}`}>
          <Defs>
            <RadialGradient id={`heroGlow-${id}`} cx="50%" cy="50%" r="50%">
              <Stop offset="0" stopColor={Colors.yellow} stopOpacity="1" />
              <Stop offset="1" stopColor={Colors.yellow} stopOpacity="0.2" />
            </RadialGradient>
          </Defs>
          <Circle cx={glowD / 2} cy={glowD / 2} r={glowD / 2} fill={`url(#heroGlow-${id})`} />
        </Svg>
      </Animated.View>

      <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <Defs>
          <LinearGradient id={`heroBody-${id}`} x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor={Colors.heroBodyA} />
            <Stop offset="1" stopColor={Colors.heroBodyB} />
          </LinearGradient>
          <LinearGradient id={`heroAccent-${id}`} x1="0" y1="0" x2="1" y2="0">
            {YELLOW_GRADIENT.map((colour, i) => (
              <Stop key={colour} offset={i / (YELLOW_GRADIENT.length - 1)} stopColor={colour} />
            ))}
          </LinearGradient>
        </Defs>
        <Rect
          x={geo.body.x}
          y={geo.body.y}
          width={geo.body.w}
          height={geo.body.h}
          rx={geo.body.rx}
          fill={`url(#heroBody-${id})`}
          stroke={alpha(Colors.yellow, 0.65)}
          strokeWidth={1.2}
        />
        <Rect x={geo.win.x} y={geo.win.y} width={geo.win.w} height={geo.win.h} rx={geo.win.rx} fill={Colors.charcoal} />
        <Path d={geo.miniArc} stroke={Colors.yellow} strokeWidth={geo.miniArcWidth} strokeLinecap="round" fill="none" />
        <Rect
          x={geo.strip.x}
          y={geo.strip.y}
          width={geo.strip.w}
          height={geo.strip.h}
          rx={geo.strip.rx}
          fill={`url(#heroAccent-${id})`}
        />
        {geo.buttons.map((b) => (
          <Circle key={b.x} cx={b.x} cy={b.y} r={b.r} fill={Colors.heroButton} />
        ))}
      </Svg>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', justifyContent: 'center', overflow: 'visible' },
  abs: { position: 'absolute' },
});
