// Flutter: showModalBottomSheet — early-end confirmation
// NAVIGATION: "结束并保存" → WorkoutSummaryScreen; "放弃" → abandonWorkout → HomeScreen

import { useState } from 'react'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useWorkout, fmtTime } from '../workoutStore'
import { useNav } from '../navigation'

interface Props {
  onClose: () => void  // dismiss sheet (cancel)
}

export default function EarlyEndSheet({ onClose }: Props) {
  const { exercises, elapsedSeconds, earlyFinish, abandonWorkout } = useWorkout()
  const { push, setTab } = useNav()

  // Flutter: setState — abandon confirmation state
  const [showAbandonConfirm, setShowAbandonConfirm] = useState(false) // Flutter: setState

  const completedSets = exercises.flatMap(e => e.sets).filter(s => s.status === 'done').length
  const totalSets = exercises.flatMap(e => e.sets).length
  const remainingSets = totalSets - completedSets

  function handleSave() {
    earlyFinish()
    push('summary')
    onClose()
  }

  function handleAbandon() {
    abandonWorkout()
    setTab('home')
  }

  // Flutter: Stack — dim overlay + BottomSheet
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: 'rgba(15,20,28,0.45)',
        display: 'flex',        // Flutter: Column
        flexDirection: 'column',
        justifyContent: 'flex-end',
        zIndex: 100,
      }}
      onClick={onClose}   // tap outside to dismiss
      className="overlay-in"
    >
      {/* Flutter: BottomSheet container */}
      {/* Animation: sheetSlideUp 280ms — Flutter: BottomSheet built-in */}
      <div
        onClick={e => e.stopPropagation()}
        className="sheet-up"
        style={{
          background: colors.white,
          borderRadius: `${radius.xl}px ${radius.xl}px 0 0`,
          padding: '16px 20px 32px',
        }}
      >
        {/* Handle — Flutter: Container (drag indicator) */}
        <div style={{
          width: 36, height: 4,
          background: colors.border,
          borderRadius: radius.full,
          margin: '0 auto 20px',
        }} />

        {/* Title */}
        <div style={{ fontSize: fontSize.xl, fontWeight: fontWeight.bold, color: colors.text, marginBottom: 6 }}>
          现在结束训练？
        </div>
        <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, lineHeight: 1.6, marginBottom: 16 }}>
          已完成的数据会保存，其余 {remainingSets} 组将标记为跳过。
          {completedSets > 0 ? `此次训练已完成 ${completedSets} 组，可以计入健身日。` : ''}
        </div>

        {/* Stats summary — Flutter: Row, mainAxis: spaceAround */}
        <div style={{
          display: 'flex',     // Flutter: Row
          gap: 8,
          marginBottom: 20,
        }}>
          {[
            { value: fmtTime(elapsedSeconds), label: '训练时长' },
            { value: String(completedSets), label: '完成组' },
            { value: String(remainingSets), label: '剩余组' },
          ].map(({ value, label }) => (
            <div key={label} style={{
              flex: 1,
              background: colors.inputBg,
              borderRadius: radius.md,
              padding: '10px 4px',
              textAlign: 'center',
            }}>
              <div style={{ fontSize: fontSize.xl, fontWeight: fontWeight.heavy, color: colors.text }}>
                {value}
              </div>
              {/* Spacer: 2px → SizedBox(height: 2) */}
              <div style={{ height: 2 }} />
              <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>{label}</div>
            </div>
          ))}
        </div>

        {/* Primary danger action */}
        <button
          onClick={handleSave}
          style={{
            width: '100%', height: 48,
            background: colors.coral,
            color: colors.onDeep,
            border: 'none', borderRadius: radius.btn,
            fontSize: fontSize.md,
            fontWeight: fontWeight.bold,
            cursor: 'pointer',
            marginBottom: 10,
            // Animation: scale 0.97 on press, 100ms easeOut
            transition: 'opacity 150ms',
          }}
        >
          结束并保存已完成内容
        </button>

        {/* Ghost button */}
        <button
          onClick={onClose}
          style={{
            width: '100%', height: 44,
            background: 'transparent',
            color: colors.text,
            border: `1.5px solid ${colors.border}`,
            borderRadius: radius.btn,
            fontSize: fontSize.base,
            fontWeight: fontWeight.medium,
            cursor: 'pointer',
            marginBottom: 6,
          }}
        >
          返回继续训练
        </button>

        {/* Abandon — destructive text button */}
        {showAbandonConfirm ? (
          <div style={{ textAlign: 'center', marginTop: 8 }}>
            <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginBottom: 8 }}>
              确认放弃？此次训练不会保存。
            </div>
            {/* Flutter: Row, mainAxis: center */}
            <div style={{ display: 'flex', gap: 10, justifyContent: 'center' }}>
              <button onClick={() => setShowAbandonConfirm(false)} style={{
                background: 'transparent', border: `1px solid ${colors.border}`,
                borderRadius: radius.sm, padding: '6px 16px',
                fontSize: fontSize.xxs, cursor: 'pointer', color: colors.textMuted,
              }}>取消</button>
              <button onClick={handleAbandon} style={{
                background: colors.danger, border: 'none', color: colors.onDeep,
                borderRadius: radius.sm, padding: '6px 16px',
                fontSize: fontSize.xxs, fontWeight: fontWeight.bold, cursor: 'pointer',
              }}>确认放弃</button>
            </div>
          </div>
        ) : (
          <button
            onClick={() => setShowAbandonConfirm(true)}
            style={{
              width: '100%', padding: '8px 0',
              background: 'transparent', border: 'none',
              color: colors.danger, fontSize: fontSize.xxs,
              fontWeight: fontWeight.bold, cursor: 'pointer',
              textAlign: 'center',
            }}
          >
            放弃本次训练
          </button>
        )}
      </div>
    </div>
  )
}
