// Flutter: showModalBottomSheet — in-workout set adjustment (PRD §11.7)
// Replaces the 3 no-op tiny-action buttons in WorkoutScreen
// NAVIGATION: "添加临时动作" → ExercisePickerSheet (nested)

import { useState } from 'react'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useWorkout } from '../workoutStore'
import ExercisePickerSheet, { type PickedExercise } from './ExercisePickerSheet'

interface Props {
  onClose: () => void
  initialTab?: 'edit' | 'skip' | 'add'
}

export default function InWorkoutAdjustmentSheet({ onClose, initialTab = 'edit' }: Props) {
  const {
    exercises, currentExerciseId, currentSetId,
    skipSet,
  } = useWorkout()

  // Flutter: setState
  const [activeTab, setActiveTab] = useState<'edit' | 'skip' | 'add'>(initialTab) // Flutter: setState
  const [showPicker, setShowPicker] = useState(false)                              // Flutter: setState

  // Editable values for current set
  const currentEx = exercises.find(e => e.id === currentExerciseId)
  const currentSet = currentEx?.sets.find(s => s.id === currentSetId)

  const [editWeight, setEditWeight] = useState(
    String(currentSet?.weight ?? 0)
  ) // Flutter: TextEditingController
  const [editReps, setEditReps] = useState(
    String(currentSet?.reps ?? 0)
  ) // Flutter: TextEditingController

  const existingIds = exercises.map(e => e.id)

  // Flutter: Stack — overlay + BottomSheet
  return (
    <div
      style={{
        position: 'absolute', inset: 0,
        background: 'rgba(15,20,28,0.45)',
        display: 'flex', flexDirection: 'column',
        justifyContent: 'flex-end',
        zIndex: 150,
      }}
      onClick={onClose}
      className="overlay-in"
    >
      {/* Flutter: BottomSheet */}
      {/* Animation: sheetSlideUp 280ms — Flutter: BottomSheet built-in */}
      <div
        onClick={e => e.stopPropagation()}
        className="sheet-up"
        style={{
          background: colors.white,
          borderRadius: `${radius.xl}px ${radius.xl}px 0 0`,
          padding: '0 0 28px',
        }}
      >
        {/* Handle */}
        <div style={{
          width: 36, height: 4, background: colors.border,
          borderRadius: radius.full, margin: '12px auto 0',
        }} />

        {/* Tab bar — Flutter: TabBar (3 tabs) */}
        <div style={{
          display: 'flex', padding: '12px 16px 0',
          borderBottom: `1px solid ${colors.border}`,
        }}>
          {([
            { key: 'edit' as const, label: '修改数据' },
            { key: 'skip' as const, label: '跳过操作' },
            { key: 'add' as const, label: '添加/删除' },
          ]).map(({ key, label }) => (
            <button
              key={key}
              onClick={() => setActiveTab(key)}
              style={{
                flex: 1, height: 36, border: 'none',
                background: 'transparent',
                fontSize: fontSize.xs,
                fontWeight: activeTab === key ? fontWeight.bold : fontWeight.regular,
                color: activeTab === key ? colors.coral : colors.textMuted,
                cursor: 'pointer',
                borderBottom: activeTab === key ? `2px solid ${colors.coral}` : '2px solid transparent',
                // Animation: border-color 150ms easeOut — Flutter: TabBar indicator
                transition: 'border-color 150ms ease-out, color 150ms ease-out',
              }}
            >
              {label}
            </button>
          ))}
        </div>

        {/* ── TAB: 修改数据 ── */}
        {activeTab === 'edit' && (
          <div style={{ padding: '16px 20px' }}>
            {currentEx && currentSet ? (
              <>
                <div style={{
                  fontSize: fontSize.sm, color: colors.textMuted, marginBottom: 14,
                }}>
                  当前组：{currentEx.name} · 第 {currentEx.sets.findIndex(s => s.id === currentSetId) + 1} 组
                </div>

                {/* Weight input — Flutter: TextField (number keyboard) */}
                <div style={{ marginBottom: 14 }}>
                  <div style={{
                    fontSize: fontSize.xxs, fontWeight: fontWeight.semibold,
                    color: colors.textSubtle, marginBottom: 6,
                    textTransform: 'uppercase' as const, letterSpacing: '0.5px',
                  }}>
                    实际重量
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <input
                      type="number"
                      value={editWeight}
                      onChange={e => setEditWeight(e.target.value)}
                      style={{
                        flex: 1, height: 44,
                        background: colors.inputBg, border: `1px solid ${colors.border}`,
                        borderRadius: radius.md, padding: '0 14px',
                        fontSize: fontSize.xl, fontWeight: fontWeight.bold,
                        color: colors.text, fontFamily: 'inherit', outline: 'none',
                        textAlign: 'center',
                      }}
                    />
                    <span style={{ fontSize: fontSize.base, color: colors.textMuted, width: 24 }}>kg</span>
                  </div>
                </div>

                {/* Reps input */}
                <div style={{ marginBottom: 20 }}>
                  <div style={{
                    fontSize: fontSize.xxs, fontWeight: fontWeight.semibold,
                    color: colors.textSubtle, marginBottom: 6,
                    textTransform: 'uppercase' as const, letterSpacing: '0.5px',
                  }}>
                    实际次数
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <input
                      type="number"
                      value={editReps}
                      onChange={e => setEditReps(e.target.value)}
                      style={{
                        flex: 1, height: 44,
                        background: colors.inputBg, border: `1px solid ${colors.border}`,
                        borderRadius: radius.md, padding: '0 14px',
                        fontSize: fontSize.xl, fontWeight: fontWeight.bold,
                        color: colors.text, fontFamily: 'inherit', outline: 'none',
                        textAlign: 'center',
                      }}
                    />
                    <span style={{ fontSize: fontSize.base, color: colors.textMuted, width: 24 }}>次</span>
                  </div>
                </div>

                <button
                  onClick={onClose}
                  style={{
                    width: '100%', height: 46,
                    background: colors.coral, color: colors.onDeep,
                    border: 'none', borderRadius: radius.btn,
                    fontSize: fontSize.md, fontWeight: fontWeight.bold,
                    cursor: 'pointer',
                  }}
                >
                  确认修改
                </button>
              </>
            ) : (
              <div style={{ textAlign: 'center', padding: '24px 0', color: colors.textMuted }}>
                暂无进行中的训练组
              </div>
            )}
          </div>
        )}

        {/* ── TAB: 跳过操作 ── */}
        {activeTab === 'skip' && (
          <div style={{ padding: '16px 20px' }}>
            {/* Skip options — Flutter: Column */}
            {[
              {
                label: '跳过本组',
                desc: '标记当前选中组为已跳过，进入下一组',
                action: () => {
                  if (currentExerciseId && currentSetId) skipSet(currentExerciseId, currentSetId)
                  onClose()
                },
              },
              {
                label: `跳过 ${currentEx?.name ?? ''} 剩余所有组`,
                desc: '将该动作所有未完成的组标记为跳过',
                action: () => {
                  if (!currentEx) return
                  currentEx.sets.forEach(s => {
                    if (s.status === 'pending' || s.status === 'current') {
                      skipSet(currentEx.id, s.id)
                    }
                  })
                  onClose()
                },
              },
            ].map(({ label, desc, action }) => (
              <button
                key={label}
                onClick={action}
                style={{
                  width: '100%',
                  display: 'flex', flexDirection: 'column', alignItems: 'flex-start',
                  padding: '14px 16px', marginBottom: 8,
                  background: colors.inputBg, border: `1px solid ${colors.border}`,
                  borderRadius: radius.md, cursor: 'pointer', textAlign: 'left',
                }}
              >
                <span style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text }}>
                  {label}
                </span>
                {/* Spacer: 2px → SizedBox(height: 2) */}
                <div style={{ height: 2 }} />
                <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>{desc}</span>
              </button>
            ))}
          </div>
        )}

        {/* ── TAB: 添加/删除 ── */}
        {activeTab === 'add' && (
          <div style={{ padding: '16px 20px' }}>
            {/* Add temporary exercise */}
            <button
              onClick={() => setShowPicker(true)}
              style={{
                width: '100%',
                display: 'flex', alignItems: 'center', gap: 12,
                padding: '14px 16px', marginBottom: 8,
                background: colors.coralSurface, border: `1px solid ${colors.coralBorder}`,
                borderRadius: radius.md, cursor: 'pointer', textAlign: 'left',
              }}
            >
              <div style={{
                width: 32, height: 32, background: colors.coral,
                borderRadius: radius.sm,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: colors.onDeep, fontSize: 18, fontWeight: fontWeight.bold,
                flexShrink: 0,
              }}>＋</div>
              <div>
                <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.coral }}>
                  临时添加动作
                </div>
                <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                  从动作库选择，仅影响本次训练
                </div>
              </div>
            </button>

            {/* Add set to current exercise */}
            {currentEx && (
              <button
                onClick={onClose}
                style={{
                  width: '100%',
                  display: 'flex', alignItems: 'center', gap: 12,
                  padding: '14px 16px', marginBottom: 8,
                  background: colors.inputBg, border: `1px solid ${colors.border}`,
                  borderRadius: radius.md, cursor: 'pointer', textAlign: 'left',
                }}
              >
                <div style={{
                  width: 32, height: 32, background: colors.mintSurface,
                  borderRadius: radius.sm,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  color: colors.mintText, fontSize: 18, fontWeight: fontWeight.bold,
                  flexShrink: 0,
                }}>＋</div>
                <div>
                  <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text }}>
                    为「{currentEx.name}」添加一组
                  </div>
                  <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                    复制最近一组的计划重量和次数
                  </div>
                </div>
              </button>
            )}
          </div>
        )}
      </div>

      {/* Nested ExercisePickerSheet — Flutter: Navigator.push (modal route) */}
      {showPicker && (
        <ExercisePickerSheet
          excludeIds={existingIds}
          onSelect={(_ex: PickedExercise) => {
            // In real impl: dispatch addTemporaryExercise action to WorkoutStore
            setShowPicker(false)
            onClose()
          }}
          onClose={() => setShowPicker(false)}
        />
      )}
    </div>
  )
}
