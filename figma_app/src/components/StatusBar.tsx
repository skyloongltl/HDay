// Flutter: SystemUiOverlayStyle / status bar area
// Simulates Android status bar inside the phone frame prototype

import { colors, fontSize, fontWeight } from '../tokens'

interface Props {
  dark?: boolean  // true = light text (for dark backgrounds)
}

export default function StatusBar({ dark = false }: Props) {
  const fg = dark ? colors.onDeep : colors.text

  // Flutter: Row, mainAxis: spaceBetween, crossAxis: center
  return (
    <div style={{
      height: 25,
      paddingLeft: 16,
      paddingRight: 16,
      paddingTop: 6,
      display: 'flex',           // Flutter: Row
      alignItems: 'center',      // crossAxis: center
      justifyContent: 'space-between', // mainAxis: spaceBetween
      flexShrink: 0,
      color: fg,
      fontSize: fontSize.xxs,
      fontWeight: fontWeight.bold,
      background: 'transparent',
      zIndex: 10,
    }}>
      <span>9:41</span>
      {/* Flutter: Row — signal + wifi + battery icons */}
      <span style={{ letterSpacing: '0.5px' }}>5G ▰</span>
    </div>
  )
}
