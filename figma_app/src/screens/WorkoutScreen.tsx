// PAGE: WorkoutScreen
// ROUTE: /workout
// FLUTTER WIDGETS: Scaffold, SliverAppBar (pinned), ListView, BottomSheet (EarlyEndSheet)
// STATE: isEndSheetOpen(bool)
// ANIMATIONS: progress bar width 300ms, set status dots 200ms
// NAVIGATION: "完成本组" → RestScreen; "结束" → EarlyEndSheet; back → HomeScreen (via abandon)

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import ProgressBar from '../components/ProgressBar'
import SetRow from '../components/SetRow'
import EarlyEndSheet from '../components/EarlyEndSheet'
import InWorkoutAdjustmentSheet from '../components/InWorkoutAdjustmentSheet'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { useWorkout, fmtTime } from '../workoutStore'

export default function WorkoutScreen() {
  const { push } = useNav()
  const {
    exercises, elapsedSeconds,
    currentExerciseId, currentSetId,
    completeCurrentSet, skipSet, selectSet,
  } = useWorkout()

  // Flutter: setState — bottom sheet visibility
  const [isEndSheetOpen, setIsEndSheetOpen] = useState(false)          // Flutter: setState
  const [adjustTab, setAdjustTab] = useState<'edit'|'skip'|'add'|null>(null) // Flutter: setState

  const allSets = exercises.flatMap(e => e.sets)
  const completedCount = allSets.filter(s => s.status === 'done').length
  const totalCount = allSets.length
  const progress = totalCount > 0 ? completedCount / totalCount : 0

  const currentEx = exercises.find(e => e.id === currentExerciseId)
  const currentSet = currentEx?.sets.find(s => s.id === currentSetId)

  function handleComplete() {
    completeCurrentSet()
    push('rest')
  }

  // Flutter: Scaffold (no BottomNavigationBar — immersive workout mode)
  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      height: '100%',
      background: colors.fogBg,
      position: 'relative',
    }}>
      <StatusBar />

      {/* ── WORKOUT APP BAR ── */}
      {/* Flutter: AppBar with custom layout (2-row structure) */}
      <div style={{
        background: colors.white,
        borderBottom: `1px solid ${colors.border}`,
        padding: '8px 16px 10px',
        flexShrink: 0,
      }}>
        {/* Flutter: Row, mainAxis: spaceBetween, crossAxis: start */}
        <div style={{
          display: 'flex',         // Flutter: Row
          alignItems: 'flex-start',
          justifyContent: 'space-between',
        }}>
          {/* Left: "训练时长" label + timer — Flutter: Column */}
          <div>
            <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginBottom: 2 }}>
              训练时长
            </div>
            <div style={{
              fontSize: fontSize.xl,
              fontWeight: fontWeight.heavy,
              color: colors.text,
              lineHeight: 1,
              fontVariantNumeric: 'tabular-nums',
              letterSpacing: '-0.5px',
            }}>
              {fmtTime(elapsedSeconds)}
            </div>
          </div>

          {/* Right: "训练" tag + 结束 button — Flutter: Column, crossAxis: end */}
          <div style={{
            display: 'flex',        // Flutter: Column
            flexDirection: 'column',
            alignItems: 'flex-end',
            gap: 6,
          }}>
            <span style={{ fontSize: fontSize.xxs, color: colors.textMuted, fontWeight: fontWeight.semibold }}>
              训练
            </span>
            {/* 结束 button — visible touch target via padding, visual is compact */}
            {/* Flutter: GestureDetector (48x48 hit area) + visual Container (38x20) */}
            <button
              onClick={() => setIsEndSheetOpen(true)}
              style={{
                // Visual: compact (spec: ~38×20 visible)
                height: 26, padding: '0 10px',
                background: colors.coral,
                color: colors.onDeep,
                border: 'none',
                borderRadius: radius.sm,
                fontSize: fontSize.sm,
                fontWeight: fontWeight.bold,
                cursor: 'pointer',
                // Flutter: ConstrainedBox (minWidth/minHeight: 48) around visual
              }}
            >
              结束
            </button>
          </div>
        </div>
      </div>

      {/* ── PROGRESS HEADER ── */}
      <div style={{
        background: colors.white,
        padding: '8px 16px 12px',
        borderBottom: `1px solid ${colors.border}`,
        flexShrink: 0,
      }}>
        {/* Flutter: Row, mainAxis: spaceBetween */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: 8,
        }}>
          <span style={{ fontSize: fontSize.base, fontWeight: fontWeight.bold, color: colors.text }}>
            已完成 {completedCount} / {totalCount} 组
          </span>
          <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
            {Math.round(progress * 100)}%
          </span>
        </div>
        <ProgressBar progress={progress} />
      </div>

      {/* ── EXERCISE + SET LIST ── */}
      {/* Flutter: ListView.builder (exercises as sections) */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '12px 16px 0' }}>
        {exercises.map(ex => (
          <div key={ex.id} style={{ marginBottom: 12 }}>
            {/* Flutter: Card */}
            <div style={{
              background: colors.white,
              border: `1px solid ${colors.border}`,
              borderRadius: radius.lg,
              overflow: 'hidden',
            }}>
              {/* Exercise header */}
              <div style={{
                padding: '10px 14px',
                borderBottom: `1px solid ${colors.border}`,
                display: 'flex',        // Flutter: Row
                alignItems: 'center',
                justifyContent: 'space-between',
              }}>
                {/* Flutter: Row + icon + Column */}
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
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
                  <div>
                    <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.bold, color: colors.text }}>
                      {ex.name}
                    </div>
                    <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                      目标休息 {ex.targetRest} 秒
                    </div>
                  </div>
                </div>
                <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                  {ex.sets.filter(s => s.status === 'done').length} / {ex.sets.length} 组
                </span>
              </div>

              {/* Flutter: ListView (sets) */}
              <div style={{ padding: '8px 12px' }}>
                {ex.sets.map((set, i) => (
                  <SetRow
                    key={set.id}
                    index={i + 1}
                    set={set}
                    onSelect={() => selectSet(ex.id, set.id)}
                  />
                ))}
              </div>
            </div>
          </div>
        ))}

        {/* Spacer for bottom actions — SizedBox(height: 110) */}
        <div style={{ height: 110 }} />
      </div>

      {/* ── BOTTOM ACTIONS (fixed) ── */}
      {/* Flutter: Positioned / BottomSheet pinned */}
      <div style={{
        position: 'absolute',
        bottom: 0, left: 0, right: 0,
        background: colors.fogBg,
        borderTop: `1px solid ${colors.navBorder}`,
        padding: '10px 16px 20px',
      }}>
        {/* Tiny secondary actions — Flutter: Row */}
        <div style={{
          display: 'flex',      // Flutter: Row
          gap: 6,
          marginBottom: 8,
        }}>
          {[
            { label: '修改数据', action: () => setAdjustTab('edit') },
            { label: '跳过本组', action: () => setAdjustTab('skip') },
            { label: '添加组',   action: () => setAdjustTab('add')  },
          ].map(({ label, action }) => (
            <button
              key={label}
              onClick={action}
              style={{
                flex: 1, height: 34,
                background: colors.tinyBtn,
                border: 'none', borderRadius: radius.sm,
                fontSize: fontSize.xxs, fontWeight: fontWeight.medium,
                color: colors.textMuted, cursor: 'pointer',
              }}
            >
              {label}
            </button>
          ))}
        </div>

        {/* Main action — Flutter: ElevatedButton */}
        {/* Animation: scale 0.97 on press, 100ms easeOut */}
        <button
          onClick={handleComplete}
          disabled={!currentSet}
          style={{
            width: '100%', height: 50,
            background: currentSet ? colors.coral : colors.progressTrack,
            color: colors.onDeep,
            border: 'none', borderRadius: radius.btn,
            fontSize: fontSize.md, fontWeight: fontWeight.bold,
            cursor: currentSet ? 'pointer' : 'default',
            transition: 'background 200ms ease',
          }}
        >
          {currentSet ? '完成本组' : '全部组已完成'}
        </button>
      </div>

      {/* ── EARLY END SHEET ── */}
      {/* Flutter: showModalBottomSheet */}
      {isEndSheetOpen && <EarlyEndSheet onClose={() => setIsEndSheetOpen(false)} />}

      {/* ── IN-WORKOUT ADJUSTMENT SHEET ── */}
      {/* Flutter: showModalBottomSheet */}
      {adjustTab && (
        <InWorkoutAdjustmentSheet
          initialTab={adjustTab}
          onClose={() => setAdjustTab(null)}
        />
      )}
    </div>
  )
}
