// Flutter: CustomPaint + AnimationController (circular progress ring)
// Used in: RestScreen

import { colors, fontSize, fontWeight } from '../tokens'
import { fmtTime } from '../workoutStore'

interface Props {
  elapsed: number    // seconds elapsed so far
  target: number     // target rest duration in seconds
}

const CX = 70
const CY = 70
const R  = 54
const CIRCUMFERENCE = 2 * Math.PI * R  // ≈ 339.3

export default function RestRing({ elapsed, target }: Props) {
  const progress = Math.min(elapsed / Math.max(target, 1), 1)
  // Flutter: Animation<double> drives strokeDashoffset
  // Animation: smooth stroke update 1000ms linear (driven by timer)
  const dashOffset = CIRCUMFERENCE * (1 - progress)
  const remaining = Math.max(target - elapsed, 0)
  const isOver = elapsed >= target

  return (
    // Flutter: SizedBox + CustomPaint + Stack (center text over ring)
    <div style={{ position: 'relative', width: 140, height: 140, margin: '0 auto' }}>
      {/* SVG ring — Flutter: CustomPainter */}
      <svg width={140} height={140} style={{ transform: 'rotate(-90deg)' }}>
        {/* Track circle */}
        <circle
          cx={CX} cy={CY} r={R}
          fill="none"
          stroke={colors.progressTrack}
          strokeWidth={10}
        />
        {/* Progress circle */}
        {/* Animation: strokeDashoffset transitions with elapsed, 1000ms linear */}
        {/* Flutter: AnimatedBuilder on AnimationController */}
        <circle
          cx={CX} cy={CY} r={R}
          fill="none"
          stroke={isOver ? colors.mint : colors.coral}
          strokeWidth={10}
          strokeLinecap="round"
          strokeDasharray={CIRCUMFERENCE}
          strokeDashoffset={dashOffset}
          style={{ transition: 'stroke-dashoffset 1s linear, stroke 300ms ease' }}
        />
      </svg>

      {/* Center content — Flutter: Stack + Center */}
      <div style={{
        position: 'absolute',
        inset: 0,
        display: 'flex',        // Flutter: Column
        flexDirection: 'column',
        alignItems: 'center',   // crossAxis: center
        justifyContent: 'center', // mainAxis: center
      }}>
        {/* Flutter: Text (timerTextStyle, fontSize 40) */}
        <span style={{
          fontSize: fontSize.restTimer,
          fontWeight: fontWeight.heavy,
          color: isOver ? colors.mint : colors.text,
          lineHeight: 1,
          // Animation: color transitions 300ms when isOver changes
          transition: 'color 300ms ease',
        }}>
          {fmtTime(elapsed)}
        </span>
        {/* Flutter: Text (caption) */}
        <span style={{
          fontSize: fontSize.xxs,
          color: colors.textMuted,
          marginTop: 2,
        }}>
          {isOver ? '已超目标' : `还剩 ${fmtTime(remaining)}`}
        </span>
      </div>
    </div>
  )
}
