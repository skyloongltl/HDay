// PAGE: RestScreen
// ROUTE: /rest
// FLUTTER WIDGETS: Scaffold, CustomPaint (RestRing), Card, ElevatedButton
// STATE: isEndSheetOpen(bool)
// ANIMATIONS: RestRing stroke 1s linear; mint color when overtime (300ms easeOut)
// NAVIGATION: "结束休息" → WorkoutScreen (pop); "结束" → EarlyEndSheet; "选择其他组" → WorkoutScreen (pop, selectSet)

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import RestRing from '../components/RestRing'
import EarlyEndSheet from '../components/EarlyEndSheet'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { useWorkout, fmtTime } from '../workoutStore'

export default function RestScreen() {
  const { pop } = useNav()
  const {
    exercises, elapsedSeconds, restElapsedSeconds, targetRestSeconds,
    currentExerciseId, currentSetId,
    endRest,
  } = useWorkout()

  // Flutter: setState — sheet visibility
  const [isEndSheetOpen, setIsEndSheetOpen] = useState(false) // Flutter: setState

  const currentEx = exercises.find(e => e.id === currentExerciseId)
  const currentSet = currentEx?.sets.find(s => s.id === currentSetId)

  // "随后" — the set after the current next one
  const allPending = exercises
    .flatMap(e => e.sets.map(s => ({ ...s, exName: e.name })))
    .filter(s => s.status === 'pending' || s.status === 'current')

  const upNextSet = allPending.length > 1 ? allPending[1] : null

  // Find which set number the current set is within its exercise
  const currentSetIndex = currentEx ? currentEx.sets.findIndex(s => s.id === currentSetId) : -1

  function handleEndRest() {
    endRest()
    pop()
  }

  // Flutter: Scaffold (no BottomNavigationBar)
  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      height: '100%',
      background: colors.fogBg,
      position: 'relative',
    }}>
      <StatusBar />

      {/* ── REST APP BAR ── same structure as WorkoutAppBar, tag changes to "休息" */}
      <div style={{
        background: colors.white,
        borderBottom: `1px solid ${colors.border}`,
        padding: '8px 16px 10px',
        flexShrink: 0,
      }}>
        {/* Flutter: Row, mainAxis: spaceBetween, crossAxis: start */}
        <div style={{
          display: 'flex',
          alignItems: 'flex-start',
          justifyContent: 'space-between',
        }}>
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
          {/* Right: "休息" tag + 结束 button */}
          <div style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'flex-end',
            gap: 6,
          }}>
            <span style={{ fontSize: fontSize.xxs, color: colors.textMuted, fontWeight: fontWeight.semibold }}>
              休息
            </span>
            <button
              onClick={() => setIsEndSheetOpen(true)}
              style={{
                height: 26, padding: '0 10px',
                background: colors.coral,
                color: colors.onDeep,
                border: 'none', borderRadius: radius.sm,
                fontSize: fontSize.sm, fontWeight: fontWeight.bold,
                cursor: 'pointer',
              }}
            >
              结束
            </button>
          </div>
        </div>
      </div>

      {/* ── MAIN CONTENT ── */}
      {/* Flutter: Expanded + SingleChildScrollView */}
      <div style={{ flex: 1, overflowY: 'auto' }}>
        {/* Rest ring area — Flutter: Center + Column */}
        <div style={{
          display: 'flex',         // Flutter: Column
          flexDirection: 'column',
          alignItems: 'center',    // crossAxis: center
          padding: '20px 16px 0',
        }}>
          <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginBottom: 4 }}>
            目标休息 {targetRestSeconds} 秒
          </div>

          {/* Flutter: CustomPaint ring */}
          {/* Animation: scale-pop on mount — draws attention to the ring */}
          <div className="scale-pop" style={{ animationDuration: '320ms' }}>
            <RestRing elapsed={restElapsedSeconds} target={targetRestSeconds} />
          </div>
        </div>

        {/* Spacer: 20px → SizedBox(height: 20) */}
        <div style={{ height: 20 }} />

        {/* Next set card — Flutter: Padding + Card */}
        <div style={{ padding: '0 16px' }}>
          {currentEx && currentSet ? (
            <div style={{
              background: colors.white,
              border: `1px solid ${colors.border}`,
              borderRadius: radius.lg,
              padding: '14px 16px',
            }}>
              {/* Flutter: Column, crossAxis: start */}
              <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginBottom: 6 }}>
                下一组
              </div>
              <div style={{
                fontSize: fontSize.xl,
                fontWeight: fontWeight.bold,
                color: colors.text,
                marginBottom: 4,
              }}>
                {currentEx.name} · 第 {currentSetIndex + 1} 组
              </div>
              <div style={{
                fontSize: fontSize.base,
                fontWeight: fontWeight.semibold,
                color: colors.textMuted,
              }}>
                {currentSet.weight === 0 ? '体重' : `${currentSet.weight} kg`} × {currentSet.reps} 次
              </div>
            </div>
          ) : (
            <div style={{
              background: colors.white,
              border: `1px solid ${colors.border}`,
              borderRadius: radius.lg,
              padding: '14px 16px',
              textAlign: 'center',
            }}>
              <div style={{ fontSize: fontSize.base, color: colors.textMuted }}>
                全部组已完成
              </div>
            </div>
          )}
        </div>

        {/* "随后" up-next hint — Flutter: Padding + Text */}
        {upNextSet && (
          <div style={{ padding: '10px 20px 0' }}>
            <span style={{ fontSize: fontSize.xxs, color: colors.textSubtle }}>
              随后：{upNextSet.exName} · {upNextSet.weight === 0 ? '体重' : `${upNextSet.weight} kg`} × {upNextSet.reps} 次
            </span>
          </div>
        )}

        {/* Spacer: 100px for bottom actions */}
        <div style={{ height: 100 }} />
      </div>

      {/* ── BOTTOM ACTIONS ── */}
      <div style={{
        position: 'absolute',
        bottom: 0, left: 0, right: 0,
        background: colors.fogBg,
        borderTop: `1px solid ${colors.navBorder}`,
        padding: '10px 16px 20px',
      }}>
        {/* Flutter: TextButton (secondary) */}
        <button
          onClick={() => pop()}
          style={{
            width: '100%', height: 36,
            background: colors.tinyBtn,
            border: 'none', borderRadius: radius.sm,
            fontSize: fontSize.xxs, fontWeight: fontWeight.medium,
            color: colors.textMuted, cursor: 'pointer',
            marginBottom: 8,
          }}
        >
          选择其他未完成组
        </button>

        {/* Flutter: ElevatedButton (primary) */}
        <button
          onClick={handleEndRest}
          style={{
            width: '100%', height: 50,
            background: colors.coral,
            color: colors.onDeep,
            border: 'none', borderRadius: radius.btn,
            fontSize: fontSize.md, fontWeight: fontWeight.bold,
            cursor: 'pointer',
          }}
        >
          结束休息并开始下一组
        </button>
      </div>

      {/* Flutter: showModalBottomSheet */}
      {isEndSheetOpen && <EarlyEndSheet onClose={() => setIsEndSheetOpen(false)} />}
    </div>
  )
}
