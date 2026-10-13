// Design tokens for the My Garage Hero IQ mockup (brand colours, radii,
// type scale, layout constants). Plain objects only – no React imports.

export const Colors = {
  yellow: '#EBC565',
  lightGrey: '#F3F3F3',
  white: '#FFFFFF',
  charcoal: '#17191C',
  surface: '#1E2125',
  surfaceRaised: '#262A2F',
  surfaceHigh: '#2F343A',
  outline: '#353A41',
  muted: '#9AA1A9',
  faint: '#6B727A',
  yellowDeep: '#C79E3F',
  yellowSoft: 'rgba(235,197,101,0.15)',
  success: '#4FD08C',
  caution: '#FFA24A',
  danger: '#FF5E55',
  info: '#7DB7FF',
  gradLight: '#F4D98C',
  gradArcTip: '#F7E3A8',
  heroBodyA: '#34393F',
  heroBodyB: '#1B1E22',
  heroButton: '#41474E',
};

// alpha('#EBC565', 0.5) -> 'rgba(235,197,101,0.5)'. Accepts #RGB or #RRGGBB.
// Anything that is not a hex colour is returned unchanged.
export function alpha(hex, a) {
  if (typeof hex !== 'string' || hex[0] !== '#') {
    return hex;
  }
  let h = hex.slice(1);
  if (h.length === 3) {
    h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
  }
  if (h.length !== 6) {
    return hex;
  }
  const n = parseInt(h, 16);
  const r = (n >> 16) & 255;
  const g = (n >> 8) & 255;
  const b = n & 255;
  return `rgba(${r},${g},${b},${a})`;
}

// Start {x:0,y:0} -> end {x:1,y:1}.
export const YELLOW_GRADIENT = ['#F4D98C', '#EBC565', '#C79E3F'];

export const Radii = {
  card: 22,
  tile: 20,
  button: 16,
  banner: 14,
  chip: 12,
  sheet: 28,
  pill: 999,
  iqBadge: 6,
  iconTile: 14,
};

export const tabular = { fontVariant: ['tabular-nums'] };

export const Type = {
  headlineMedium: { fontSize: 28, fontWeight: '700', letterSpacing: -0.6, color: Colors.white },
  headlineSmall: { fontSize: 24, fontWeight: '700', letterSpacing: -0.4, color: Colors.lightGrey },
  titleLarge: { fontSize: 22, fontWeight: '700', letterSpacing: -0.3, color: Colors.lightGrey },
  sheetTitle: { fontSize: 20, fontWeight: '700', letterSpacing: -0.3, color: Colors.white },
  titleMedium: { fontSize: 16, fontWeight: '600', letterSpacing: 0, color: Colors.lightGrey },
  body: { fontSize: 14, fontWeight: '400', letterSpacing: 0, color: Colors.lightGrey, lineHeight: 19.6 },
  bodyLead: { fontSize: 16, fontWeight: '400', letterSpacing: 0, color: Colors.muted, lineHeight: 24 },
  bodyMuted: { fontSize: 14, fontWeight: '400', letterSpacing: 0, color: Colors.muted, lineHeight: 20 },
  small: { fontSize: 13, fontWeight: '400', letterSpacing: 0, color: Colors.muted, lineHeight: 18 },
  caption: { fontSize: 12, fontWeight: '400', letterSpacing: 0, color: Colors.faint, lineHeight: 16 },
  sectionTitle: { fontSize: 12, fontWeight: '800', letterSpacing: 1.6, color: Colors.muted, textTransform: 'uppercase' },
  pill: { fontSize: 11.5, fontWeight: '700', letterSpacing: 0.2 },
  banner: { fontSize: 12.5, fontWeight: '700', letterSpacing: 0.2, color: Colors.yellow },
  button: { fontSize: 16, fontWeight: '700', letterSpacing: 0.2, color: Colors.charcoal },
  buttonOutlined: { fontSize: 15, fontWeight: '600', letterSpacing: 0, color: Colors.white },
  textButton: { fontSize: 14, fontWeight: '600', letterSpacing: 0, color: Colors.yellow },
  wordmark: { fontSize: 13, fontWeight: '800', letterSpacing: 2.4, color: Colors.white },
  iqBadge: { fontSize: 12, fontWeight: '900', letterSpacing: 0.5, color: Colors.charcoal },
  navLabel: { fontSize: 11.5, fontWeight: '500', color: Colors.muted },
  navLabelSelected: { fontSize: 11.5, fontWeight: '700', color: Colors.yellow },
  metricLabel: { fontSize: 12.5, fontWeight: '600', color: Colors.muted },
  metricValue: { fontSize: 28, fontWeight: '700', letterSpacing: -0.5, color: Colors.white, ...tabular },
  faultCode: { fontSize: 22, fontWeight: '800', letterSpacing: 1, color: Colors.white, ...tabular },
};

export const Gutter = 20;
export const TabBarHeight = 68;
export const ButtonHeight = 54;
export const OutlinedHeight = 50;
