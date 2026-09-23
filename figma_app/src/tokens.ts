// Design tokens — Theme A: 呼吸节拍
// Flutter: ThemeExtension + ThemeData
// All component colors must reference this file — no inline hex values

export const colors = {
  // Page ground
  fogBg: '#F4F7FA',

  // Hero card — deep sea blue
  deepBlue: '#19344C',
  deepBlueProgressTrack: 'rgba(255,255,255,0.15)',

  // Primary action — gray-toned coral
  coral: '#C76F62',
  coralSurface: '#F7E8E5',
  coralBorder: '#DEB3AE',

  // Active / recovery — breathing mint
  mint: '#62E6CA',
  mintSurface: '#DFF5EE',
  mintText: '#247263',

  // Text hierarchy
  text: '#142A3A',
  textMuted: '#5B7A8E',
  textSubtle: '#94ADB9',
  onDeep: '#FFFFFF',
  onDeepMuted: 'rgba(255,255,255,0.65)',

  // Surfaces
  white: '#FFFFFF',
  border: '#DFE7EC',
  borderStrong: '#C8D4DC',
  progressTrack: '#DCE4E9',
  tinyBtn: '#E8EEF2',
  iconBtn: '#E7EDF1',
  navBorder: '#DDE5EA',
  inputBg: '#EEF3F6',

  // Set row states (workout list)
  setDone: '#48505A',       // filled circle
  setSkipped: '#94A3B0',    // skipped marker
  setPendingBg: '#F1F5F7',  // idle row bg
  setCurrentBg: '#F7E8E5',  // selected row bg (coral tint)
  setCurrentBorder: '#C76F62',

  // Calendar
  calHit: '#414852',        // completed day (filled)
  calToday: '#C76F62',      // today marker

  // Danger actions
  danger: '#B83228',
  dangerSurface: '#FDECEC',
} as const

export const radius = {
  xs: 6,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  hero: 20,
  btn: 13,
  full: 9999,
} as const

// Flutter logical pixel equivalents
export const fontSize = {
  xxs: 10,   // labels, captions, page-tag
  xs: 11,    // set data, secondary text
  sm: 12,    // exercise name, end button text
  base: 13,  // body text, list item
  md: 14,    // main button, section headers
  lg: 16,    // stat numbers, nav items
  xl: 20,    // training timer, card titles
  title: 23, // page title (今天，练得漂亮)
  restTimer: 40, // rest countdown center
} as const

export const fontWeight = {
  regular: 400,
  medium: 500,
  semibold: 600,
  bold: 700,
  heavy: 900,
} as const

// Spacing (px) → SizedBox / EdgeInsets
export const spacing = {
  2: 2, 4: 4, 6: 6, 8: 8, 10: 10, 12: 12,
  14: 14, 16: 16, 18: 18, 20: 20, 24: 24,
  28: 28, 32: 32, 40: 40, 48: 48,
} as const

const T = { colors, radius, fontSize, fontWeight, spacing }
export default T
