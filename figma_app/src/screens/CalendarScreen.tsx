// PAGE: CalendarScreen
// ROUTE: /calendar (tab)
// FLUTTER WIDGETS: Scaffold, TableCalendar (custom), ListView, BottomNavigationBar
// STATE: selectedDate(string), currentMonth(Date)
// ANIMATIONS: month slide 250ms easeOut
// NAVIGATION: history row → HistoryDetailScreen

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import BottomNav from '../components/BottomNav'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { completedDays, plannedDays, historyRecords } from '../data/mockData'

// 5 calendar cell states per PRD §13.1
// unfinishedDays: had a session that didn't complete cleanly (amber)
// hadPlanNoDays: planned but user never started (light outlined)
const unfinishedDays = [7]          // Flutter: set from WorkoutRepository
const hadPlanNoDays  = [11, 15]     // Flutter: set from PlanRepository + CalendarService
import { fmtTime } from '../workoutStore'

// Sep 2026 starts on Tuesday = index 1 (Mon=0)
const MONTH_START_DOW = 1  // Tuesday
const MONTH_DAYS = 30
const WEEK_LABELS = ['一', '二', '三', '四', '五', '六', '日']

export default function CalendarScreen() {
  const { push } = useNav()

  // Flutter: setState
  const [selectedDate, setSelectedDate] = useState<number | null>(14)  // Flutter: setState (today=14)
  const [currentMonth] = useState({ year: 2026, month: 9 })            // Flutter: setState

  // Build calendar grid cells
  const cells: (number | null)[] = [
    ...Array(MONTH_START_DOW).fill(null), // leading empty cells
    ...Array.from({ length: MONTH_DAYS }, (_, i) => i + 1),
  ]
  // Pad to complete last week
  while (cells.length % 7 !== 0) cells.push(null)

  const selectedRecord = selectedDate
    ? historyRecords.find(r => {
        const d = new Date(r.date).getDate()
        return d === selectedDate
      })
    : null

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
        {/* Flutter: Row — month nav */}
        <button style={{
          width: 32, height: 32, background: colors.iconBtn,
          border: 'none', borderRadius: radius.full,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer', fontSize: 16, color: colors.text,
        }}>‹</button>
        <span style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
          {currentMonth.year} 年 {currentMonth.month} 月
        </span>
        <button style={{
          width: 32, height: 32, background: colors.iconBtn,
          border: 'none', borderRadius: radius.full,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer', fontSize: 16, color: colors.text,
        }}>›</button>
      </div>

      {/* Flutter: Expanded + SingleChildScrollView */}
      <div style={{ flex: 1, overflowY: 'auto' }}>

        {/* Flutter: Padding + Column */}
        <div style={{ padding: '14px 16px 0' }}>
          {/* Week day labels — Flutter: Row, mainAxis: spaceAround */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(7, 1fr)',
            gap: 4,
            marginBottom: 6,
          }}>
            {WEEK_LABELS.map(d => (
              <div key={d} style={{
                textAlign: 'center',
                fontSize: fontSize.xxs,
                color: colors.textSubtle,
                fontWeight: fontWeight.medium,
              }}>{d}</div>
            ))}
          </div>

          {/* Calendar grid — Flutter: GridView, crossAxisCount: 7 */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(7, 1fr)',
            gap: 4,
            marginBottom: 16,
          }}>
            {cells.map((day, i) => {
              if (!day) return <div key={`empty-${i}`} />

              const isToday = day === 14
              const isSelected = day === selectedDate
              const isCompleted = completedDays.includes(day)
              const isPlanned = plannedDays.includes(day)
              const isUnfinished = unfinishedDays.includes(day)      // amber — session not cleanly ended
              const isHadPlanNo = hadPlanNoDays.includes(day)        // soft outline — planned but never started

              // PRD §13.1: priority: selected > completed > unfinished > planned > hadPlanNo > today > default
              let bg = 'transparent'
              let border = '2px solid transparent'
              let textColor = colors.text
              let dotColor = ''

              if (isSelected) {
                bg = colors.text; textColor = colors.onDeep
              } else if (isCompleted) {
                bg = colors.calHit; textColor = colors.onDeep; dotColor = colors.mint
              } else if (isUnfinished) {
                bg = '#FEF3C7'; textColor = '#92400E'; border = `2px solid #F59E0B`
              } else if (isHadPlanNo) {
                border = `1.5px dashed ${colors.border}`; textColor = colors.textMuted
              } else if (isPlanned) {
                border = `2px solid ${colors.textMuted}`
              } else if (isToday) {
                border = `2px solid ${colors.coral}`; textColor = colors.coral
              }

              // Flutter: GestureDetector + AnimatedContainer
              return (
                <div
                  key={day}
                  onClick={() => setSelectedDate(day === selectedDate ? null : day)}
                  style={{
                    aspectRatio: '1',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    borderRadius: radius.sm,
                    cursor: 'pointer',
                    background: bg,
                    border,
                    // Animation: background 150ms easeOut
                    transition: 'background 150ms ease-out',
                  }}
                >
                  <span style={{
                    fontSize: fontSize.xxs,
                    fontWeight: isToday || isSelected || isCompleted || isUnfinished ? fontWeight.bold : fontWeight.regular,
                    color: textColor,
                  }}>
                    {day}
                  </span>
                  {/* Completion dot — Flutter: Container (dot indicator) */}
                  {dotColor && !isSelected && (
                    <div style={{
                      width: 3, height: 3,
                      background: dotColor,
                      borderRadius: radius.full,
                      marginTop: 1,
                    }} />
                  )}
                </div>
              )
            })}
          </div>
        </div>

        {/* ── SELECTED DAY DETAIL ── */}
        <div style={{ padding: '0 16px' }}>
          {/* Section header */}
          <div style={{
            fontSize: fontSize.sm,
            fontWeight: fontWeight.bold,
            color: colors.text,
            marginBottom: 10,
          }}>
            {selectedDate
              ? `${currentMonth.month} 月 ${selectedDate} 日`
              : '选择日期查看训练'}
          </div>

          {selectedRecord ? (
            /* History record card — Flutter: Card + InkWell */
            <div
              onClick={() => push('historyDetail', { recordId: selectedRecord.id })}
              style={{
                background: colors.white,
                border: `1px solid ${colors.border}`,
                borderRadius: radius.lg,
                overflow: 'hidden',
                cursor: 'pointer',
              }}
            >
              {/* Summary row */}
              <div style={{ padding: '14px 14px 10px' }}>
                <div style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'flex-start',
                  marginBottom: 8,
                }}>
                  <div>
                    <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.bold, color: colors.text }}>
                      {selectedRecord.plan}
                    </div>
                    <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginTop: 2 }}>
                      {fmtTime(selectedRecord.duration)} · {selectedRecord.completedSets}/{selectedRecord.totalSets} 组完成
                    </div>
                  </div>
                  {/* Flutter: Chip */}
                  <span style={{
                    background: colors.mintSurface, color: colors.mintText,
                    fontSize: fontSize.xxs, fontWeight: fontWeight.bold,
                    borderRadius: radius.full, padding: '3px 8px',
                  }}>
                    已完成
                  </span>
                </div>
                {/* Exercise summary chips — Flutter: Wrap */}
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
                  {selectedRecord.exercises.slice(0, 4).map((ex, i) => (
                    <span key={i} style={{
                      background: colors.inputBg,
                      borderRadius: radius.full,
                      padding: '3px 8px',
                      fontSize: fontSize.xxs,
                      color: colors.textMuted,
                    }}>
                      {ex.name}
                    </span>
                  ))}
                  {selectedRecord.exercises.length > 4 && (
                    <span style={{
                      background: colors.inputBg,
                      borderRadius: radius.full,
                      padding: '3px 8px',
                      fontSize: fontSize.xxs,
                      color: colors.textMuted,
                    }}>
                      +{selectedRecord.exercises.length - 4}
                    </span>
                  )}
                </div>
              </div>
              <div style={{
                padding: '8px 14px',
                background: colors.inputBg,
                borderTop: `1px solid ${colors.border}`,
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
              }}>
                <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                  查看完整训练记录
                </span>
                <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>›</span>
              </div>
            </div>
          ) : selectedDate && !completedDays.includes(selectedDate) ? (
            <div style={{
              background: colors.white,
              border: `1px solid ${colors.border}`,
              borderRadius: radius.lg,
              padding: '24px 20px',
              textAlign: 'center',
              color: colors.textMuted,
              fontSize: fontSize.base,
            }}>
              {plannedDays.includes(selectedDate)
                ? '计划训练日 — 尚未完成'
                : '该日无训练记录'}
            </div>
          ) : !selectedDate ? (
            <div style={{
              textAlign: 'center',
              color: colors.textSubtle,
              fontSize: fontSize.base,
              padding: '24px 0',
            }}>
              点击日期查看当天记录
            </div>
          ) : null}
        </div>

        {/* ── ALL HISTORY ── */}
        {/* Spacer: 20px → SizedBox(height: 20) */}
        <div style={{ height: 20 }} />
        <div style={{ padding: '0 16px' }}>
          <div style={{ fontSize: fontSize.sm, fontWeight: fontWeight.bold, color: colors.text, marginBottom: 10 }}>
            近期训练
          </div>
          {historyRecords.map(rec => (
            <div
              key={rec.id}
              onClick={() => push('historyDetail', { recordId: rec.id })}
              style={{
                background: colors.white,
                border: `1px solid ${colors.border}`,
                borderRadius: radius.md,
                padding: '12px 14px',
                marginBottom: 8,
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                cursor: 'pointer',
              }}
            >
              {/* Date pill */}
              <div style={{
                width: 40,
                textAlign: 'center',
                flexShrink: 0,
              }}>
                <div style={{ fontSize: fontSize.lg, fontWeight: fontWeight.heavy, color: colors.text }}>
                  {new Date(rec.date).getDate()}
                </div>
                <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                  {rec.label.split('·')[1]?.trim() ?? ''}
                </div>
              </div>
              <div style={{ width: 1, height: 36, background: colors.border, flexShrink: 0 }} />
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text }}>
                  {rec.plan}
                </div>
                <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                  {fmtTime(rec.duration)} · {rec.completedSets} 组
                </div>
              </div>
              <span style={{ color: colors.textSubtle, fontSize: 14 }}>›</span>
            </div>
          ))}
        </div>

        {/* Spacer: 16px → SizedBox(height: 16) */}
        <div style={{ height: 16 }} />
      </div>

      <BottomNav />
    </div>
  )
}
