// PAGE: ExerciseDetailScreen
// ROUTE: /exercise-detail
// FLUTTER WIDGETS: Scaffold, AppBar, ListView
// STATE: none
// ANIMATIONS: none
// NAVIGATION: back → caller screen

import StatusBar from '../components/StatusBar'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { exerciseLibrary } from '../data/mockData'

// Historical personal bests per exercise (mock)
const history: Record<string, { date: string; weight: number; reps: number }[]> = {
  ex1: [
    { date: '9月12日', weight: 62.5, reps: 8 },
    { date: '9月10日', weight: 60, reps: 10 },
    { date: '9月8日', weight: 60, reps: 10 },
    { date: '9月5日', weight: 57.5, reps: 10 },
    { date: '9月3日', weight: 57.5, reps: 8 },
  ],
  ex2: [
    { date: '9月12日', weight: 45, reps: 12 },
    { date: '9月10日', weight: 45, reps: 12 },
    { date: '9月6日', weight: 42.5, reps: 12 },
  ],
}

export default function ExerciseDetailScreen() {
  const { pop, push, params } = useNav()
  const exerciseId = (params.exerciseId as string) ?? 'ex1'
  const ex = exerciseLibrary.find(e => e.id === exerciseId) ?? exerciseLibrary[0]
  const records = history[exerciseId] ?? history.ex1

  const personalBest = records.reduce((best, r) => r.weight > best.weight ? r : best, records[0])

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
        <button
          onClick={pop}
          style={{
            width: 32, height: 32, background: colors.iconBtn,
            border: 'none', borderRadius: radius.full,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', fontSize: 16, color: colors.text,
          }}
        >‹</button>
        <span style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
          动作详情
        </span>
        <button
          onClick={() => push('exerciseEdit', { exerciseId })}
          style={{
            height: 28, padding: '0 10px', background: colors.iconBtn,
            border: 'none', borderRadius: radius.sm,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4,
            cursor: 'pointer', fontSize: fontSize.xxs,
            color: colors.textMuted, fontWeight: fontWeight.medium,
          }}
        >
          ✎ 编辑
        </button>
      </div>

      {/* Flutter: Expanded + SingleChildScrollView */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 16px' }}>

        {/* Exercise header card — Flutter: Card */}
        <div style={{
          background: colors.white,
          border: `1px solid ${colors.border}`,
          borderRadius: radius.lg,
          padding: '16px 18px',
          marginBottom: 14,
          display: 'flex',       // Flutter: Row
          alignItems: 'center',
          gap: 14,
        }}>
          {/* Icon */}
          <div style={{
            width: 52, height: 52,
            background: colors.mintSurface,
            borderRadius: radius.md,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: colors.mintText,
            fontSize: 22,
            fontWeight: fontWeight.heavy,
            flexShrink: 0,
          }}>
            {ex.name.slice(0, 1)}
          </div>
          {/* Flutter: Column */}
          <div>
            <div style={{ fontSize: fontSize.xl, fontWeight: fontWeight.heavy, color: colors.text }}>
              {ex.name}
            </div>
            <div style={{ height: 4 }} />
            {/* Chips — Flutter: Wrap */}
            <div style={{ display: 'flex', gap: 6 }}>
              {[ex.category, ex.equipment].map(label => (
                <span key={label} style={{
                  background: colors.inputBg,
                  borderRadius: radius.full,
                  padding: '3px 10px',
                  fontSize: fontSize.xxs,
                  color: colors.textMuted,
                }}>
                  {label}
                </span>
              ))}
            </div>
          </div>
        </div>

        {/* Personal best — Flutter: Card */}
        <div style={{
          background: colors.deepBlue,
          borderRadius: radius.lg,
          padding: '16px 18px',
          marginBottom: 14,
          display: 'flex',        // Flutter: Row
          justifyContent: 'space-between',
          alignItems: 'center',
        }}>
          <div>
            <div style={{ fontSize: fontSize.xxs, color: colors.onDeepMuted, marginBottom: 4 }}>
              个人最佳
            </div>
            <div style={{ fontSize: fontSize.xl, fontWeight: fontWeight.heavy, color: colors.onDeep }}>
              {personalBest.weight === 0 ? '体重' : `${personalBest.weight} kg`} × {personalBest.reps} 次
            </div>
            <div style={{ fontSize: fontSize.xxs, color: colors.onDeepMuted, marginTop: 4 }}>
              {personalBest.date}
            </div>
          </div>
          <div style={{ fontSize: 32 }}>🏆</div>
        </div>

        {/* Progress chart (simplified) — Flutter: CustomPaint / fl_chart */}
        <div style={{
          background: colors.white,
          border: `1px solid ${colors.border}`,
          borderRadius: radius.lg,
          padding: '14px 16px',
          marginBottom: 14,
        }}>
          <div style={{ fontSize: fontSize.sm, fontWeight: fontWeight.bold, color: colors.text, marginBottom: 14 }}>
            重量趋势
          </div>
          {/* Simplified bar chart — Flutter: fl_chart BarChart */}
          <div style={{
            display: 'flex',        // Flutter: Row
            alignItems: 'flex-end',
            gap: 6,
            height: 60,
          }}>
            {records.slice().reverse().map((r, i) => {
              const maxWeight = Math.max(...records.map(x => x.weight || 1))
              const h = ((r.weight || 1) / maxWeight) * 50 + 10
              return (
                <div key={i} style={{
                  flex: 1,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  gap: 4,
                }}>
                  <div style={{
                    width: '100%',
                    height: h,
                    background: i === records.length - 1 ? colors.coral : colors.progressTrack,
                    borderRadius: `${radius.xs}px ${radius.xs}px 0 0`,
                    transition: 'height 300ms ease-out',
                  }} />
                  <div style={{ fontSize: 8, color: colors.textSubtle, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: '100%' }}>
                    {r.date.slice(0, 4)}
                  </div>
                </div>
              )
            })}
          </div>
        </div>

        {/* History log — Flutter: ListView */}
        <div style={{
          background: colors.white,
          border: `1px solid ${colors.border}`,
          borderRadius: radius.lg,
          overflow: 'hidden',
          marginBottom: 14,
        }}>
          <div style={{
            padding: '12px 14px',
            borderBottom: `1px solid ${colors.border}`,
            fontSize: fontSize.sm,
            fontWeight: fontWeight.bold,
            color: colors.text,
          }}>
            历史记录
          </div>
          {records.map((r, i) => (
            <div key={i} style={{
              padding: '10px 14px',
              borderBottom: i < records.length - 1 ? `1px solid ${colors.border}` : 'none',
              display: 'flex',       // Flutter: Row
              justifyContent: 'space-between',
              alignItems: 'center',
            }}>
              <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>{r.date}</span>
              <span style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text }}>
                {r.weight === 0 ? '体重' : `${r.weight} kg`} × {r.reps} 次
              </span>
              {i === 0 && (
                <span style={{
                  background: colors.coralSurface, color: colors.coral,
                  fontSize: fontSize.xxs, fontWeight: fontWeight.bold,
                  borderRadius: radius.full, padding: '2px 6px',
                }}>
                  最近
                </span>
              )}
            </div>
          ))}
        </div>

        {/* Spacer: 16px → SizedBox(height: 16) */}
        <div style={{ height: 16 }} />
      </div>
    </div>
  )
}
