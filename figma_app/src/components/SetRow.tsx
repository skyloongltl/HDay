// Flutter: ListTile (custom) — one training set row
// STATUS SEMANTICS: done=●filled  current=outlined+coral  pending=○empty  skipped=✕

import { useState } from 'react'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import type { WorkoutSet } from '../workoutStore'

interface Props {
  index: number       // 1-based set number
  set: WorkoutSet
  onSelect: () => void
}

function StatusDot({ status }: { status: WorkoutSet['status'] }) {
  // Flutter: AnimatedContainer for status transitions
  const base: React.CSSProperties = {
    width: 18, height: 18,
    borderRadius: radius.full,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    flexShrink: 0,
    // Animation: background/border color 200ms easeOut
    // Flutter: AnimatedContainer
    transition: 'background 200ms ease-out, border-color 200ms ease-out',
  }

  if (status === 'done') return (
    <div style={{ ...base, background: colors.setDone }} />
  )
  if (status === 'current') return (
    // Animation: pulseRing 1.8s — Flutter: AnimatedContainer with periodic animation
    <div className="pulse-ring" style={{ ...base, border: `2px solid ${colors.coral}`, background: colors.coralSurface, borderRadius: radius.full }}>
      <div style={{ width: 8, height: 8, borderRadius: radius.full, background: colors.coral }} />
    </div>
  )
  if (status === 'skipped') return (
    <div style={{ ...base, border: `2px solid ${colors.setSkipped}`, background: 'transparent' }}>
      <span style={{ fontSize: 10, color: colors.setSkipped, fontWeight: fontWeight.bold, lineHeight: 1 }}>✕</span>
    </div>
  )
  // pending
  return (
    <div style={{ ...base, border: `1.5px solid ${colors.borderStrong}`, background: 'transparent' }} />
  )
}

export default function SetRow({ index, set, onSelect }: Props) {
  // Flutter: setState — pressed animation state
  const [pressed, setPressed] = useState(false) // Flutter: GestureDetector onTapDown/Up

  const isCurrent = set.status === 'current'
  const isDone = set.status === 'done'
  const isSkipped = set.status === 'skipped'
  const interactive = !isDone && !isSkipped

  const weightLabel = set.weight === 0 ? '体重' : `${set.weight} kg`

  // Flutter: GestureDetector + AnimatedContainer
  return (
    <div
      onMouseDown={() => setPressed(true)}
      onMouseUp={() => setPressed(false)}
      onMouseLeave={() => setPressed(false)}
      onClick={interactive ? onSelect : undefined}
      style={{
        // Flutter: Row, mainAxis: start, crossAxis: center
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        padding: '8px 10px',
        borderRadius: radius.sm,
        background: isCurrent ? colors.setCurrentBg
          : isDone ? colors.setPendingBg
          : colors.setPendingBg,
        border: isCurrent ? `2px solid ${colors.setCurrentBorder}` : '2px solid transparent',
        cursor: interactive ? 'pointer' : 'default',
        // Animation: scale 0.97 on press, 100ms easeOut
        // Flutter: GestureDetector + AnimatedScale
        transform: pressed && interactive ? 'scale(0.97)' : 'scale(1)',
        transition: 'transform 100ms ease-out, background 150ms ease-out',
        marginBottom: 4,
        opacity: isSkipped ? 0.5 : 1,
      }}
    >
      <StatusDot status={set.status} />

      {/* Flutter: Row → Expanded: set number */}
      <span style={{
        fontSize: fontSize.xs,
        color: colors.textMuted,
        fontWeight: fontWeight.medium,
        width: 16,
        textAlign: 'center',
        flexShrink: 0,
      }}>
        {index}
      </span>

      {/* Weight — Flutter: Expanded */}
      <span style={{
        flex: 1,
        fontSize: fontSize.sm,
        color: isSkipped ? colors.textSubtle : colors.text,
        fontWeight: fontWeight.medium,
      }}>
        {weightLabel}
      </span>

      {/* Reps — Flutter: Text */}
      <span style={{
        fontSize: fontSize.sm,
        color: isSkipped ? colors.textSubtle : colors.text,
        fontWeight: fontWeight.medium,
        minWidth: 40,
        textAlign: 'right',
      }}>
        {isDone || isSkipped
          ? (set.actualReps ?? set.reps) + ' 次'
          : set.reps + ' 次'
        }
      </span>

      {/* Status badge — Flutter: Text or Icon */}
      <span style={{
        fontSize: fontSize.xxs,
        color: isDone ? colors.mintText
          : isCurrent ? colors.coral
          : isSkipped ? colors.setSkipped
          : colors.textSubtle,
        fontWeight: fontWeight.bold,
        width: 32,
        textAlign: 'right',
        flexShrink: 0,
      }}>
        {isDone ? '完成' : isCurrent ? '进行' : isSkipped ? '跳过' : '待练'}
      </span>
    </div>
  )
}
