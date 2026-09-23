// PAGE: PlanEditScreen
// ROUTE: /plan-edit
// FLUTTER WIDGETS: Scaffold, AppBar, TabBar, TabBarView, ListView
// STATE: selectedDayIndex(number)
// ANIMATIONS: tab slide 200ms easeOut
// NAVIGATION: back → PlanScreen

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import ExercisePickerSheet, { type PickedExercise } from '../components/ExercisePickerSheet'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { plans } from '../data/mockData'

export default function PlanEditScreen() {
  const { pop, params } = useNav()
  const planId = (params.planId as string) ?? 'p1'
  const plan = plans.find(p => p.id === planId) ?? plans[0]

  // Flutter: TabController.index / setState
  const [selectedDayIndex, setSelectedDayIndex] = useState(plan.currentDay - 1) // Flutter: setState
  const [showPicker, setShowPicker] = useState(false)                            // Flutter: setState

  const selectedDay = plan.days[selectedDayIndex]
  const dayExercises = plan.exercises[selectedDay.day] ?? []

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
        background: colors.white,
        borderBottom: `1px solid ${colors.border}`,
        flexShrink: 0,
      }}>
        <div style={{
          height: 52,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 16px',
        }}>
          <button
            onClick={pop}
            style={{
              width: 32, height: 32,
              background: colors.iconBtn, border: 'none', borderRadius: radius.full,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer', fontSize: 16, color: colors.text,
            }}
          >‹</button>
          <span style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
            {plan.name}
          </span>
          <button style={{
            background: 'transparent', border: 'none',
            color: colors.coral, fontSize: fontSize.base,
            fontWeight: fontWeight.bold, cursor: 'pointer',
          }}>
            完成
          </button>
        </div>

        {/* Flutter: TabBar — day tabs (horizontal scroll) */}
        <div style={{
          display: 'flex',        // Flutter: Row
          overflowX: 'auto',
          padding: '0 16px 12px',
          gap: 6,
        }}>
          {plan.days.map((day, i) => {
            const isActive = selectedDayIndex === i
            return (
              <button
                key={day.day}
                onClick={() => setSelectedDayIndex(i)}
                style={{
                  flexShrink: 0,
                  height: 32,
                  padding: '0 14px',
                  background: isActive ? colors.coral : colors.inputBg,
                  color: isActive ? colors.onDeep : colors.textMuted,
                  border: 'none',
                  borderRadius: radius.full,
                  fontSize: fontSize.xxs,
                  fontWeight: isActive ? fontWeight.bold : fontWeight.medium,
                  cursor: 'pointer',
                  // Animation: background 150ms easeOut
                  transition: 'background 150ms ease-out, color 150ms ease-out',
                  whiteSpace: 'nowrap',
                }}
              >
                D{day.day}
              </button>
            )
          })}
        </div>
      </div>

      {/* ── SELECTED DAY CONTENT ── */}
      {/* Flutter: Expanded + TabBarView (index driven) */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 16px' }}>
        {/* Day header */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: 14,
        }}>
          <div>
            <div style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
              {selectedDay.label}
            </div>
            <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginTop: 2 }}>
              {selectedDay.type === 'rest' ? '休息日' : `${dayExercises.length} 个动作 · ${selectedDay.sets} 组`}
            </div>
          </div>
          {selectedDay.type === 'workout' && (
            <button
              onClick={() => setShowPicker(true)}
              style={{
                height: 32, padding: '0 12px',
                background: colors.coralSurface,
                border: `1px solid ${colors.coralBorder}`,
                borderRadius: radius.full,
                color: colors.coral, fontSize: fontSize.xxs,
                fontWeight: fontWeight.bold, cursor: 'pointer',
              }}
            >
              ＋ 添加动作
            </button>
          )}
        </div>

        {selectedDay.type === 'rest' ? (
          /* Rest day placeholder */
          <div style={{
            background: colors.white,
            border: `1px solid ${colors.border}`,
            borderRadius: radius.lg,
            padding: '40px 20px',
            textAlign: 'center',
          }}>
            <div style={{ fontSize: 32, marginBottom: 12 }}>😴</div>
            <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.medium, color: colors.textMuted }}>
              休息日 — 好好休息
            </div>
            <button style={{
              marginTop: 16, padding: '8px 20px',
              background: 'transparent',
              border: `1px solid ${colors.border}`,
              borderRadius: radius.full,
              color: colors.textMuted, fontSize: fontSize.xxs,
              cursor: 'pointer',
            }}>
              改为训练日
            </button>
          </div>
        ) : (
          /* Flutter: ListView.builder (exercises) */
          <>
            {dayExercises.map((ex, i) => (
              <div key={i} style={{ marginBottom: 8 }}>
                {/* Flutter: Card (ListTile + drag handle) */}
                <div style={{
                  background: colors.white,
                  border: `1px solid ${colors.border}`,
                  borderRadius: radius.md,
                  padding: '12px 14px',
                  display: 'flex',    // Flutter: Row
                  alignItems: 'center',
                  gap: 10,
                }}>
                  {/* Drag handle — Flutter: ReorderableListView handle */}
                  <span style={{ color: colors.textSubtle, fontSize: 14, cursor: 'grab' }}>⋮⋮</span>
                  {/* Exercise number */}
                  <div style={{
                    width: 26, height: 26,
                    background: colors.mintSurface,
                    borderRadius: radius.sm,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    color: colors.mintText, fontSize: fontSize.xxs, fontWeight: fontWeight.heavy,
                    flexShrink: 0,
                  }}>
                    {String(i + 1).padStart(2, '0')}
                  </div>
                  {/* Flutter: Expanded + Column */}
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text }}>
                      {ex.name}
                    </div>
                    <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                      {ex.sets} 组 · {ex.weight}
                    </div>
                  </div>
                  {/* Remove */}
                  <button style={{
                    width: 26, height: 26,
                    background: 'transparent',
                    border: `1px solid ${colors.border}`,
                    borderRadius: radius.full,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    cursor: 'pointer', color: colors.textSubtle, fontSize: 11,
                  }}>✕</button>
                </div>
              </div>
            ))}

            {dayExercises.length === 0 && (
              <div style={{
                background: colors.white,
                border: `1.5px dashed ${colors.border}`,
                borderRadius: radius.lg,
                padding: '32px 20px',
                textAlign: 'center',
                color: colors.textMuted,
                fontSize: fontSize.base,
              }}>
                点击"添加动作"开始安排今日训练
              </div>
            )}
          </>
        )}

        {/* Spacer: 16px → SizedBox(height: 16) */}
        <div style={{ height: 16 }} />
      </div>

      {/* ExercisePickerSheet — Flutter: showModalBottomSheet */}
      {showPicker && (
        <ExercisePickerSheet
          excludeIds={[]}
          onSelect={(_ex: PickedExercise) => {
            // In real impl: dispatch addExerciseToDay action
            setShowPicker(false)
          }}
          onClose={() => setShowPicker(false)}
        />
      )}
    </div>
  )
}
