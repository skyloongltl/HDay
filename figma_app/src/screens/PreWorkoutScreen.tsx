// PAGE: PreWorkoutScreen
// ROUTE: /pre-workout
// FLUTTER WIDGETS: Scaffold, AppBar, ReorderableListView, ElevatedButton
// STATE: exercises(WorkoutExercise[]), reordering(bool)
// ANIMATIONS: none (drag-to-reorder native)
// NAVIGATION: back → HomeScreen; "确认并开始计时" → WorkoutScreen

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import ExercisePickerSheet, { type PickedExercise } from '../components/ExercisePickerSheet'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { useWorkout, type WorkoutExercise } from '../workoutStore'
import { todayExercises } from '../data/mockData'

function makeEmptySet(id: string) {
  return { id, weight: 0, reps: 10, status: 'pending' as const }
}

export default function PreWorkoutScreen() {
  const { pop, push, params } = useNav()
  const { startWorkout } = useWorkout()

  const isFreeWorkout = !!params.freeWorkout // Flutter: route params

  // Flutter: List<WorkoutExercise> — local copy for pre-workout edits
  const [exercises, setExercises] = useState<WorkoutExercise[]>( // Flutter: setState
    isFreeWorkout
      ? []
      : todayExercises.map(e => ({ ...e, sets: e.sets.map(s => ({ ...s })) }))
  )
  const [showPicker, setShowPicker] = useState(false) // Flutter: setState

  const totalSets = exercises.reduce((s, e) => s + e.sets.length, 0)

  function handleStart() {
    startWorkout(exercises)
    push('workout')
  }

  // Flutter: Scaffold
  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      height: '100%',
      background: colors.fogBg,
    }}>
      <StatusBar />

      {/* Flutter: AppBar */}
      <div style={{
        height: 52,
        display: 'flex',        // Flutter: Row
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 16px',
        background: colors.white,
        borderBottom: `1px solid ${colors.border}`,
        flexShrink: 0,
      }}>
        <button
          onClick={pop}
          style={{
            width: 32, height: 32,
            background: colors.iconBtn,
            border: 'none', borderRadius: radius.full,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', fontSize: 16, color: colors.text,
          }}
        >
          ‹
        </button>
        <span style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
          {isFreeWorkout ? '自由训练' : '训练前准备'}
        </span>
        <button style={{
          background: 'transparent', border: 'none',
          color: colors.textMuted, fontSize: fontSize.base, cursor: 'pointer',
          padding: '4px 6px',
        }}>
          •••
        </button>
      </div>

      {/* Flutter: Expanded + SingleChildScrollView */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 16px' }}>

        {/* Info card — Flutter: Card */}
        <div style={{
          background: colors.white,
          border: `1px solid ${colors.border}`,
          borderRadius: radius.md,
          padding: '12px 14px',
          marginBottom: 14,
        }}>
          <div style={{ fontSize: fontSize.sm, fontWeight: fontWeight.bold, color: colors.text, marginBottom: 4 }}>
            {isFreeWorkout ? '自由训练' : '本次训练'}
          </div>
          <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
            {isFreeWorkout
              ? '添加你想练的动作，自由安排训练'
              : `调整仅影响本次，不修改原计划 · 共 ${totalSets} 组`
            }
          </div>
        </div>

        {/* Flutter: ReorderableListView */}
        {exercises.map((ex, exIdx) => (
          <div key={ex.id} style={{ marginBottom: 8 }}>
            {/* Flutter: Card — exercise item */}
            <div style={{
              background: colors.white,
              border: `1px solid ${colors.border}`,
              borderRadius: radius.md,
              overflow: 'hidden',
            }}>
              {/* Exercise header — Flutter: Row */}
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: 10,
                padding: '10px 12px',
                borderBottom: `1px solid ${colors.border}`,
              }}>
                {/* Drag handle — Flutter: ReorderableDragStartListener */}
                <span style={{ color: colors.textSubtle, fontSize: 14, cursor: 'grab', userSelect: 'none' }}>
                  ⋮⋮
                </span>
                {/* Icon */}
                <div style={{
                  width: 30, height: 30,
                  background: colors.mintSurface,
                  borderRadius: radius.sm,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  color: colors.mintText, fontSize: fontSize.xxs, fontWeight: fontWeight.heavy,
                  flexShrink: 0,
                }}>
                  {ex.iconChar}
                </div>
                {/* Flutter: Expanded + Column */}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text }}>
                    {ex.name}
                  </div>
                  <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                    目标休息 {ex.targetRest} 秒
                  </div>
                </div>
                {/* Set count badge */}
                <div style={{
                  background: colors.inputBg,
                  borderRadius: radius.sm,
                  padding: '3px 8px',
                  fontSize: fontSize.xxs,
                  color: colors.textMuted,
                  fontWeight: fontWeight.medium,
                }}>
                  {ex.sets.length} 组
                </div>
              </div>

              {/* Sets summary — Flutter: ListView */}
              <div style={{ padding: '8px 12px' }}>
                {/* Flutter: Row, mainAxis: spaceBetween */}
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: '24px 1fr 1fr auto',
                  gap: 4,
                  marginBottom: 4,
                }}>
                  {['组', '重量', '次数', ''].map(h => (
                    <span key={h} style={{
                      fontSize: fontSize.xxs, color: colors.textSubtle, fontWeight: fontWeight.medium,
                    }}>{h}</span>
                  ))}
                </div>
                {ex.sets.map((s, si) => (
                  <div key={s.id} style={{
                    display: 'grid',
                    gridTemplateColumns: '24px 1fr 1fr auto',
                    gap: 4,
                    padding: '5px 0',
                    borderTop: `1px solid ${colors.border}`,
                    alignItems: 'center',
                  }}>
                    <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>{si + 1}</span>
                    <span style={{ fontSize: fontSize.xs, color: colors.text, fontWeight: fontWeight.medium }}>
                      {s.weight === 0 ? '体重' : `${s.weight} kg`}
                    </span>
                    <span style={{ fontSize: fontSize.xs, color: colors.text }}>{s.reps} 次</span>
                    {/* Remove set button */}
                    <button
                      onClick={() => {
                        if (ex.sets.length <= 1) return
                        setExercises(prev => prev.map(e =>
                          e.id === ex.id ? { ...e, sets: e.sets.filter(set => set.id !== s.id) } : e
                        ))
                      }}
                      style={{
                        width: 20, height: 20,
                        background: 'transparent',
                        border: `1px solid ${colors.border}`,
                        borderRadius: radius.full,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        cursor: 'pointer', color: colors.textSubtle, fontSize: 10,
                      }}
                    >✕</button>
                  </div>
                ))}

                {/* Add set row */}
                <button
                  onClick={() => {
                    const last = ex.sets[ex.sets.length - 1]
                    setExercises(prev => prev.map(e =>
                      e.id === ex.id ? {
                        ...e,
                        sets: [...e.sets, { id: `${e.id}s${Date.now()}`, weight: last.weight, reps: last.reps, status: 'pending' as const }]
                      } : e
                    ))
                  }}
                  style={{
                    width: '100%', marginTop: 6, padding: '5px 0',
                    background: 'transparent', border: 'none',
                    color: colors.coral, fontSize: fontSize.xxs,
                    fontWeight: fontWeight.semibold, cursor: 'pointer',
                    textAlign: 'left',
                  }}
                >
                  ＋ 添加一组
                </button>
              </div>
            </div>
          </div>
        ))}

        {/* Free workout empty state — Flutter: Center + Column */}
        {isFreeWorkout && exercises.length === 0 && (
          <div style={{
            textAlign: 'center', padding: '32px 0 24px',
            color: colors.textMuted,
          }}>
            <div style={{ fontSize: 36, marginBottom: 10 }}>🏋️</div>
            <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text, marginBottom: 4 }}>
              还没有添加动作
            </div>
            <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
              点击下方按钮从动作库选择
            </div>
          </div>
        )}

        {/* Add exercise button — Flutter: OutlinedButton */}
        <button
          onClick={() => setShowPicker(true)}
          style={{
            width: '100%', height: 44,
            background: 'transparent',
            border: `1.5px dashed ${colors.border}`,
            borderRadius: radius.md,
            color: isFreeWorkout ? colors.coral : colors.textMuted,
            fontSize: fontSize.base,
            cursor: 'pointer',
            marginTop: 4,
          }}
        >
          ＋ {isFreeWorkout ? '添加动作' : '临时添加动作'}
        </button>

        {/* ExercisePickerSheet — Flutter: showModalBottomSheet */}
        {showPicker && (
          <ExercisePickerSheet
            excludeIds={exercises.map(e => e.id)}
            onSelect={(picked: PickedExercise) => {
              setExercises(prev => [...prev, {
                id: picked.id, name: picked.name,
                iconChar: picked.iconChar,
                targetRest: 90,
                sets: [makeEmptySet(`${picked.id}s1`)],
              }])
              setShowPicker(false)
            }}
            onClose={() => setShowPicker(false)}
          />
        )}

        {/* Spacer: 16px → SizedBox(height: 16) */}
        <div style={{ height: 16 }} />
      </div>

      {/* Flutter: BottomAppBar / SafeArea bottom */}
      <div style={{
        padding: '12px 16px 20px',
        background: colors.white,
        borderTop: `1px solid ${colors.border}`,
        flexShrink: 0,
      }}>
        <button
          onClick={handleStart}
          disabled={exercises.length === 0}
          style={{
            width: '100%', height: 50,
            background: exercises.length === 0 ? colors.progressTrack : colors.coral,
            color: colors.onDeep,
            border: 'none', borderRadius: radius.btn,
            fontSize: fontSize.md, fontWeight: fontWeight.bold,
            cursor: exercises.length === 0 ? 'default' : 'pointer',
            transition: 'background 200ms ease',
          }}
        >
          确认并开始计时
        </button>
      </div>
    </div>
  )
}
