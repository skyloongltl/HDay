// PAGE: WorkoutSummaryScreen
// ROUTE: /summary
// FLUTTER WIDGETS: Scaffold, SingleChildScrollView, Card, TextField, ElevatedButton
// STATE: noteText(string)
// ANIMATIONS: none
// NAVIGATION: "保存训练" → HomeScreen (setTab); "返回继续" → WorkoutScreen (pop)

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { useWorkout, fmtTime } from '../workoutStore'

export default function WorkoutSummaryScreen() {
  const { setTab, pop } = useNav()
  const { exercises, elapsedSeconds, abandonWorkout } = useWorkout()

  // Flutter: TextEditingController
  const [noteText, setNoteText] = useState('') // Flutter: setState

  const allSets = exercises.flatMap(e => e.sets)
  const completedSets = allSets.filter(s => s.status === 'done').length
  const skippedSets = allSets.filter(s => s.status === 'skipped').length
  const completedExercises = exercises.filter(e => e.sets.some(s => s.status === 'done')).length

  function handleSave() {
    abandonWorkout() // reset store after saving
    setTab('home')
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
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 16px',
        background: colors.white,
        borderBottom: `1px solid ${colors.border}`,
        flexShrink: 0,
      }}>
        <div style={{ width: 32 }} />{/* spacer */}
        <span style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
          训练总结
        </span>
        <div style={{ width: 32 }} />
      </div>

      {/* Flutter: Expanded + SingleChildScrollView */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '24px 16px 16px' }}>

        {/* Hero summary — Flutter: Center + Column */}
        <div style={{ textAlign: 'center', marginBottom: 24 }}>
          {/* Completion icon — Flutter: Container + Icon */}
          {/* Animation: scalePop 380ms spring — Flutter: AnimatedScale */}
          <div
            className="scale-pop"
            style={{
              width: 64, height: 64,
              background: colors.mintSurface,
              borderRadius: radius.full,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              margin: '0 auto 16px',
              fontSize: 28,
            }}
          >
            ✓
          </div>
          <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginBottom: 6 }}>
            总训练时长
          </div>
          {/* Flutter: Text (headline, tabular nums) */}
          <div style={{
            fontSize: 36,
            fontWeight: fontWeight.heavy,
            color: colors.text,
            fontVariantNumeric: 'tabular-nums',
            letterSpacing: '-1px',
            lineHeight: 1,
            marginBottom: 8,
          }}>
            {fmtTime(elapsedSeconds)}
          </div>
          <div style={{
            display: 'inline-block',
            background: colors.mintSurface,
            color: colors.mintText,
            borderRadius: radius.full,
            padding: '4px 14px',
            fontSize: fontSize.sm,
            fontWeight: fontWeight.bold,
          }}>
            训练完成
          </div>
        </div>

        {/* Stats grid — Flutter: GridView 2×2 */}
        <div style={{
          display: 'grid',           // Flutter: GridView, crossAxisCount: 2
          gridTemplateColumns: '1fr 1fr',
          gap: 8,
          marginBottom: 16,
        }}>
          {[
            { value: String(completedExercises), label: '完成动作' },
            { value: String(completedSets), label: '完成组数' },
            { value: String(skippedSets), label: '跳过组数' },
            { value: '0', label: '未完成' },
          ].map(({ value, label }) => (
            <div key={label} style={{
              background: colors.white,
              border: `1px solid ${colors.border}`,
              borderRadius: radius.md,
              padding: '14px 12px',
              textAlign: 'center',
            }}>
              <div style={{
                fontSize: 26,
                fontWeight: fontWeight.heavy,
                color: colors.text,
                lineHeight: 1,
                marginBottom: 4,
              }}>
                {value}
              </div>
              <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                {label}
              </div>
            </div>
          ))}
        </div>

        {/* Exercise breakdown — Flutter: Card + ListView */}
        <div style={{
          background: colors.white,
          border: `1px solid ${colors.border}`,
          borderRadius: radius.lg,
          overflow: 'hidden',
          marginBottom: 16,
        }}>
          <div style={{
            padding: '12px 14px',
            borderBottom: `1px solid ${colors.border}`,
            fontSize: fontSize.sm,
            fontWeight: fontWeight.bold,
            color: colors.text,
          }}>
            本次训练详情
          </div>
          {exercises.map((ex, i) => {
            const exDone = ex.sets.filter(s => s.status === 'done').length
            const exTotal = ex.sets.length
            return (
              <div key={ex.id} style={{
                padding: '10px 14px',
                display: 'flex',        // Flutter: Row
                alignItems: 'center',
                gap: 10,
                borderBottom: i < exercises.length - 1 ? `1px solid ${colors.border}` : 'none',
              }}>
                <div style={{
                  width: 28, height: 28,
                  background: exDone > 0 ? colors.mintSurface : colors.inputBg,
                  borderRadius: radius.sm,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  color: exDone > 0 ? colors.mintText : colors.textSubtle,
                  fontSize: fontSize.xxs, fontWeight: fontWeight.heavy,
                  flexShrink: 0,
                }}>
                  {ex.iconChar}
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.medium, color: colors.text }}>
                    {ex.name}
                  </div>
                  <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                    {exDone}/{exTotal} 组完成
                  </div>
                </div>
                <span style={{
                  fontSize: fontSize.xxs, fontWeight: fontWeight.bold,
                  color: exDone === exTotal ? colors.mintText : colors.textSubtle,
                }}>
                  {exDone === exTotal ? '✓ 全部完成' : `${exDone}/${exTotal}`}
                </span>
              </div>
            )
          })}
        </div>

        {/* Notes — Flutter: Card + TextField */}
        <div style={{
          background: colors.white,
          border: `1px solid ${colors.border}`,
          borderRadius: radius.lg,
          overflow: 'hidden',
          marginBottom: 16,
        }}>
          <div style={{
            padding: '12px 14px',
            borderBottom: `1px solid ${colors.border}`,
            fontSize: fontSize.sm,
            fontWeight: fontWeight.bold,
            color: colors.text,
          }}>
            训练备注
          </div>
          {/* Flutter: TextField (multiline) */}
          <textarea
            value={noteText}
            onChange={e => setNoteText(e.target.value)}
            placeholder="记录今天的感受、突破或任何想法…"
            style={{
              width: '100%',
              minHeight: 80,
              padding: '12px 14px',
              background: 'transparent',
              border: 'none',
              resize: 'none',
              fontSize: fontSize.base,
              color: colors.text,
              fontFamily: 'inherit',
              outline: 'none',
              boxSizing: 'border-box',
            }}
          />
        </div>

        {/* Spacer: 8px → SizedBox(height: 8) */}
        <div style={{ height: 8 }} />
      </div>

      {/* Flutter: SafeArea bottom + actions */}
      <div style={{
        padding: '12px 16px 20px',
        background: colors.white,
        borderTop: `1px solid ${colors.border}`,
        flexShrink: 0,
        display: 'flex',           // Flutter: Column
        flexDirection: 'column',
        gap: 8,
      }}>
        {/* Zero-completed warning — Flutter: Container + Text */}
        {completedSets === 0 && (
          <div style={{
            padding: '10px 14px',
            background: colors.dangerSurface, borderRadius: radius.md,
            border: `1px solid ${colors.danger}20`,
            fontSize: fontSize.xxs, color: colors.danger, lineHeight: 1.6,
          }}>
            本次训练没有完成任何组，无法保存为有效健身日。
          </div>
        )}
        {/* Primary — hidden when zero completed */}
        {completedSets > 0 && (
          <button
            onClick={handleSave}
            style={{
              width: '100%', height: 50,
              background: colors.coral,
              color: colors.onDeep,
              border: 'none', borderRadius: radius.btn,
              fontSize: fontSize.md, fontWeight: fontWeight.bold,
              cursor: 'pointer',
            }}
          >
            保存训练
          </button>
        )}
        {/* Ghost */}
        <button
          onClick={() => pop()}
          style={{
            width: '100%', height: 44,
            background: 'transparent',
            color: colors.text,
            border: `1.5px solid ${colors.border}`,
            borderRadius: radius.btn,
            fontSize: fontSize.base, fontWeight: fontWeight.medium,
            cursor: 'pointer',
          }}
        >
          返回继续训练
        </button>
      </div>
    </div>
  )
}
