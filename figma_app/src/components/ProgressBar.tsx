// Flutter: LinearProgressIndicator (custom styled)
// Used in: HomeScreen hero card, WorkoutScreen header

import { colors } from '../tokens'

interface Props {
  progress: number       // 0–1
  trackColor?: string
  barColor?: string
  height?: number
  borderRadius?: number
}

export default function ProgressBar({
  progress,
  trackColor = colors.progressTrack,
  barColor = colors.coral,
  height = 5,
  borderRadius = 4,
}: Props) {
  const clamped = Math.max(0, Math.min(1, progress))

  return (
    <div style={{
      height,
      background: trackColor,
      borderRadius,
      overflow: 'hidden',
    }}>
      {/* Flutter: FractionallySizedBox / AnimatedContainer */}
      {/* Animation: width transition 300ms easeOut */}
      <div style={{
        height: '100%',
        width: `${clamped * 100}%`,
        background: barColor,
        borderRadius,
        transition: 'width 300ms ease-out',
      }} />
    </div>
  )
}
