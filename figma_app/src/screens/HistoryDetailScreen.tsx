// PAGE: HistoryDetailScreen (= DayDetailScreen per PRD §13.2–13.4)
// ROUTE: /history-detail
// FLUTTER WIDGETS: Scaffold, AppBar, ListView (sessions), ExpansionTile (sets)
// STATE: expandedSessionIdx(number|null), showDeleteConfirm(bool)
// ANIMATIONS: overlay-in + scale-pop for delete confirm; ExpansionTile 200ms easeOut
// NAVIGATION: back → CalendarScreen
// NOTE: read-only snapshot — no inline editing of past set data

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { historyRecords } from '../data/mockData'
import { fmtTime } from '../workoutStore'

export default function HistoryDetailScreen() {
  const { pop, params } = useNav()
  const recordId = (params.recordId as string) ?? historyRecords[0].id
  const record = historyRecords.find(r => r.id === recordId) ?? historyRecords[0]

  // Flutter: setState — UI state
  const [expandedSessionIdx, setExpandedSessionIdx] = useState<number | null>(0) // Flutter: setState
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)               // Flutter: setState

  // Mock: treat record as one session
  const sessions = [
    {
      id: 'session-1',
      label: record.plan,
      startTime: '09:42',
      endTime: '10:35',
      duration: record.duration,
      completedSets: record.completedSets,
      totalSets: record.totalSets,
      exercises: record.exercises,
    }
  ]

  // Flutter: Scaffold
  return (
    <div style={{
      display: 'flex', flexDirection: 'column',
      height: '100%', background: colors.fogBg,
      position: 'relative',
    }}>
      <StatusBar />

      {/* Flutter: AppBar */}
      <div style={{
        height: 52,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '0 16px',
        background: colors.white, borderBottom: `1px solid ${colors.border}`,
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
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
            {record.label}
          </div>
          <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
            训练快照
          </div>
        </div>
        <div style={{ width: 32 }} />
      </div>

      {/* Flutter: Expanded + ListView */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 16px' }}>

        {/* Day summary hero — Flutter: Card */}
        <div style={{
          background: colors.deepBlue,
          borderRadius: radius.hero, padding: '18px 20px',
          marginBottom: 16,
        }}>
          {/* Flutter: Row, mainAxis: spaceAround */}
          <div style={{ display: 'flex', justifyContent: 'space-around', textAlign: 'center' }}>
            {[
              { value: fmtTime(record.duration), label: '总时长' },
              { value: `${record.completedSets}/${record.totalSets}`, label: '完成组数' },
              { value: String(record.exercises.length), label: '训练动作' },
            ].map(({ value, label }) => (
              <div key={label}>
                <div style={{ fontSize: fontSize.xl, fontWeight: fontWeight.heavy, color: colors.onDeep }}>
                  {value}
                </div>
                <div style={{ fontSize: fontSize.xxs, color: colors.onDeepMuted, marginTop: 2 }}>{label}</div>
              </div>
            ))}
          </div>
        </div>

        {/* ── SESSIONS ── Flutter: ListView.builder */}
        {sessions.map((session, sIdx) => {
          const isExpanded = expandedSessionIdx === sIdx

          return (
            <div key={session.id} style={{ marginBottom: 12 }}>
              {/* Session card — Flutter: Card + ExpansionTile */}
              <div style={{
                background: colors.white, border: `1px solid ${colors.border}`,
                borderRadius: radius.lg, overflow: 'hidden',
              }}>
                {/* Session header — Flutter: ListTile */}
                <div style={{
                  padding: '12px 14px',
                  borderBottom: isExpanded ? `1px solid ${colors.border}` : 'none',
                }}>
                  {/* Flutter: Row, mainAxis: spaceBetween */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 }}>
                    <div>
                      <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.bold, color: colors.text }}>
                        {session.label}
                      </div>
                      <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginTop: 2 }}>
                        {session.startTime} – {session.endTime} · {fmtTime(session.duration)}
                      </div>
                    </div>
                    {/* Flutter: Chip */}
                    <span style={{
                      background: colors.mintSurface, color: colors.mintText,
                      fontSize: fontSize.xxs, fontWeight: fontWeight.bold,
                      borderRadius: radius.full, padding: '3px 8px',
                    }}>
                      {session.completedSets}/{session.totalSets} 组
                    </span>
                  </div>

                  {/* Flutter: Row — expand toggle + delete */}
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button
                      onClick={() => setExpandedSessionIdx(isExpanded ? null : sIdx)}
                      style={{
                        flex: 1, height: 32,
                        background: colors.inputBg, border: 'none',
                        borderRadius: radius.sm,
                        fontSize: fontSize.xxs, color: colors.textMuted,
                        cursor: 'pointer',
                        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4,
                      }}
                    >
                      {isExpanded ? '收起详情' : '展开详情'}
                      {/* Animation: rotate 200ms — Flutter: AnimatedRotation */}
                      <span style={{
                        transform: isExpanded ? 'rotate(180deg)' : 'rotate(0deg)',
                        transition: 'transform 200ms ease-out',
                        display: 'inline-block',
                      }}>▾</span>
                    </button>
                    <button
                      onClick={() => setShowDeleteConfirm(true)}
                      style={{
                        width: 32, height: 32,
                        background: colors.dangerSurface, border: 'none',
                        borderRadius: radius.sm,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        cursor: 'pointer', fontSize: 14, color: colors.danger,
                      }}
                    >🗑</button>
                  </div>
                </div>

                {/* ── EXPANDED SET LIST (read-only snapshot) ── Flutter: AnimatedSize */}
                {isExpanded && (
                  <div>
                    {session.exercises.map((ex, exIdx) => (
                      <div key={exIdx} style={{
                        borderTop: exIdx > 0 ? `1px solid ${colors.border}` : 'none',
                      }}>
                        {/* Exercise label row */}
                        <div style={{
                          padding: '10px 14px 6px',
                          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                          background: colors.inputBg,
                        }}>
                          <span style={{ fontSize: fontSize.base, fontWeight: fontWeight.bold, color: colors.text }}>
                            {ex.name}
                          </span>
                          <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                            {ex.sets.filter((s: { reps: number }) => s.reps > 0).length}/{ex.sets.length} 组
                          </span>
                        </div>

                        {/* Set rows — read-only */}
                        <div style={{ padding: '6px 14px 10px' }}>
                          {/* Column headers */}
                          <div style={{
                            display: 'grid',
                            gridTemplateColumns: '20px 1fr 1fr 64px',
                            gap: 4, padding: '2px 0', marginBottom: 2,
                          }}>
                            {['组', '重量', '次数', '状态'].map(h => (
                              <span key={h} style={{
                                fontSize: fontSize.xxs, color: colors.textSubtle,
                                fontWeight: fontWeight.medium,
                              }}>{h}</span>
                            ))}
                          </div>

                          {ex.sets.map((s: { weight: number; reps: number }, si: number) => {
                            const isSkipped = s.reps === 0
                            return (
                              <div key={si} style={{
                                display: 'grid',
                                gridTemplateColumns: '20px 1fr 1fr 64px',
                                gap: 4, padding: '7px 0',
                                borderTop: `1px solid ${colors.border}`,
                                alignItems: 'center',
                                opacity: isSkipped ? 0.4 : 1,
                              }}>
                                {/* Status dot */}
                                <div style={{
                                  width: 14, height: 14,
                                  background: isSkipped ? colors.inputBg : colors.setDone,
                                  borderRadius: radius.full,
                                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                                }}>
                                  {isSkipped && <span style={{ fontSize: 8, color: colors.textSubtle }}>✕</span>}
                                </div>

                                {/* Weight — static */}
                                <span style={{ fontSize: fontSize.xs, color: colors.text, fontWeight: fontWeight.medium }}>
                                  {s.weight === 0 ? '体重' : `${s.weight} kg`}
                                </span>

                                {/* Reps — static */}
                                <span style={{ fontSize: fontSize.xs, color: colors.text }}>
                                  {isSkipped ? '—' : `${s.reps} 次`}
                                </span>

                                {/* Status badge */}
                                <span style={{
                                  fontSize: fontSize.xxs,
                                  color: isSkipped ? colors.textSubtle : colors.mintText,
                                  fontWeight: fontWeight.bold,
                                }}>
                                  {isSkipped ? '已跳过' : '已完成'}
                                </span>
                              </div>
                            )
                          })}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )
        })}

        {/* Spacer: 16px → SizedBox(height: 16) */}
        <div style={{ height: 16 }} />
      </div>

      {/* ── DELETE CONFIRM DIALOG ── Flutter: AlertDialog */}
      {/* Animation: overlay-in 200ms — Flutter: AnimatedOpacity */}
      {showDeleteConfirm && (
        <div
          className="overlay-in"
          style={{
            position: 'absolute', inset: 0,
            background: 'rgba(15,20,28,0.45)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 100, padding: '0 32px',
          }}
        >
          <div
            className="scale-pop"
            style={{
              background: colors.white, borderRadius: radius.xl,
              padding: '24px 20px', width: '100%',
              animationDuration: '250ms',
            }}
          >
            <div style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text, marginBottom: 10 }}>
              删除此训练场次？
            </div>
            <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, lineHeight: 1.6, marginBottom: 20 }}>
              这是当天的唯一训练场次。删除后，该日期将从健身日统计中移除。此操作无法撤销。
            </div>
            {/* Flutter: Row, mainAxis: end */}
            <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
              <button
                onClick={() => setShowDeleteConfirm(false)}
                style={{
                  height: 38, padding: '0 16px',
                  background: colors.inputBg, border: 'none', borderRadius: radius.sm,
                  fontSize: fontSize.base, color: colors.textMuted, cursor: 'pointer',
                }}
              >
                取消
              </button>
              <button
                onClick={() => { setShowDeleteConfirm(false); pop() }}
                style={{
                  height: 38, padding: '0 16px',
                  background: colors.danger, border: 'none', borderRadius: radius.sm,
                  fontSize: fontSize.base, fontWeight: fontWeight.bold,
                  color: colors.onDeep, cursor: 'pointer',
                }}
              >
                确认删除
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
