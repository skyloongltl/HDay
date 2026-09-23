// PAGE: PlanScreen
// ROUTE: /plan (tab)
// FLUTTER WIDGETS: Scaffold, ListView, ExpansionTile, Switch, BottomNavigationBar
// STATE: expandedPlanId(string|null), searchQuery(string), enabledPlanIds(Set<string>)
// ANIMATIONS: expansion 200ms easeOut
// NAVIGATION: plan edit icon → PlanEditScreen; "＋" → new plan

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import BottomNav from '../components/BottomNav'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { plans } from '../data/mockData'

export default function PlanScreen() {
  const { push } = useNav()

  // Flutter: setState
  const [expandedPlanId, setExpandedPlanId] = useState<string | null>('p1') // Flutter: setState
  const [searchQuery, setSearchQuery] = useState('')                          // Flutter: TextEditingController
  const [enabledPlanIds, setEnabledPlanIds] = useState<Set<string>>(         // Flutter: setState
    new Set(plans.filter(p => p.enabled).map(p => p.id))
  )

  const filtered = plans.filter(p =>
    p.name.includes(searchQuery) || searchQuery === ''
  )

  function toggleEnabled(planId: string) {
    setEnabledPlanIds(prev => {
      const next = new Set(prev)
      next.has(planId) ? next.delete(planId) : next.add(planId)
      return next
    })
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
        <span style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
          训练计划
        </span>
        <button
          onClick={() => push('createPlan')}
          style={{
            width: 32, height: 32,
            background: colors.coral,
            border: 'none', borderRadius: radius.full,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', color: colors.onDeep, fontSize: 18, fontWeight: fontWeight.bold,
          }}
        >
          ＋
        </button>
      </div>

      {/* Flutter: Expanded + ListView */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '12px 16px' }}>

        {/* Search — Flutter: TextField */}
        <div style={{
          background: colors.white,
          border: `1px solid ${colors.border}`,
          borderRadius: radius.md,
          padding: '10px 14px',
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          marginBottom: 14,
        }}>
          <span style={{ color: colors.textSubtle, fontSize: 14 }}>⌕</span>
          <input
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            placeholder="搜索计划名称"
            style={{
              flex: 1, border: 'none', background: 'transparent',
              fontSize: fontSize.base, color: colors.text,
              fontFamily: 'inherit', outline: 'none',
            }}
          />
        </div>

        {/* Empty list state — Flutter: Center + Column (EmptyState widget) */}
        {filtered.length === 0 && (
          <div style={{ textAlign: 'center', padding: '48px 16px 24px' }}>
            <div style={{ fontSize: 40, marginBottom: 14 }}>📋</div>
            <div style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text, marginBottom: 6 }}>
              {searchQuery ? "没有找到匹配的计划" : "还没有训练计划"}
            </div>
            <div style={{ fontSize: fontSize.sm, color: colors.textMuted, lineHeight: 1.6, marginBottom: 20 }}>
              {searchQuery
                ? "试试其他关键词"
                : "创建你的第一个训练计划，开始有计划地健身"}
            </div>
            {!searchQuery && (
              <button
                onClick={() => push('createPlan')}
                style={{
                  height: 46, padding: '0 28px',
                  background: colors.coral, color: colors.onDeep,
                  border: 'none', borderRadius: radius.btn,
                  fontSize: fontSize.base, fontWeight: fontWeight.bold, cursor: 'pointer',
                }}
              >
                创建训练计划
              </button>
            )}
          </div>
        )}

        {/* Flutter: ListView.builder */}
        {filtered.map(plan => {
          const isExpanded = expandedPlanId === plan.id
          const isEnabled = enabledPlanIds.has(plan.id)

          return (
            <div key={plan.id} style={{ marginBottom: 10 }}>
              {/* Flutter: Card + ExpansionTile */}
              <div style={{
                background: colors.white,
                border: `1px solid ${colors.border}`,
                borderRadius: radius.lg,
                overflow: 'hidden',
              }}>
                {/* Plan header — Flutter: ListTile */}
                <div style={{
                  padding: '14px 14px 12px',
                  display: 'flex',
                  alignItems: 'flex-start',
                  gap: 10,
                }}>
                  {/* Flutter: Column (Expanded) */}
                  <div style={{ flex: 1 }}>
                    {/* Flutter: Row */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                      <span style={{ fontSize: fontSize.base, fontWeight: fontWeight.bold, color: colors.text }}>
                        {plan.name}
                      </span>
                      {plan.currentDay === 3 && (
                        <span style={{
                          background: colors.coralSurface, color: colors.coral,
                          fontSize: fontSize.xxs, fontWeight: fontWeight.bold,
                          borderRadius: radius.full, padding: '2px 7px',
                        }}>
                          进行中
                        </span>
                      )}
                    </div>
                    <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                      {plan.cycle} · 当前 D{plan.currentDay}
                    </div>
                  </div>

                  {/* Flutter: Row — edit + toggle */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <button
                      onClick={() => push('planEdit', { planId: plan.id })}
                      style={{
                        width: 28, height: 28,
                        background: colors.iconBtn,
                        border: 'none', borderRadius: radius.sm,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        cursor: 'pointer', fontSize: 12, color: colors.textMuted,
                      }}
                    >
                      ✎
                    </button>
                    {/* Flutter: Switch */}
                    <div
                      onClick={() => toggleEnabled(plan.id)}
                      style={{
                        width: 36, height: 20,
                        background: isEnabled ? colors.coral : colors.progressTrack,
                        borderRadius: radius.full,
                        position: 'relative',
                        cursor: 'pointer',
                        // Animation: background 200ms easeOut, thumb position 200ms easeOut
                        // Flutter: AnimatedContainer
                        transition: 'background 200ms ease-out',
                        flexShrink: 0,
                      }}
                    >
                      <div style={{
                        position: 'absolute',
                        top: 2, left: isEnabled ? 18 : 2,
                        width: 16, height: 16,
                        background: colors.white,
                        borderRadius: radius.full,
                        transition: 'left 200ms ease-out',
                        boxShadow: '0 1px 3px rgba(0,0,0,0.2)',
                      }} />
                    </div>
                  </div>
                </div>

                {/* Expand toggle — Flutter: ExpansionTile trigger */}
                <button
                  onClick={() => setExpandedPlanId(isExpanded ? null : plan.id)}
                  style={{
                    width: '100%',
                    padding: '8px 14px',
                    background: colors.inputBg,
                    border: 'none',
                    borderTop: `1px solid ${colors.border}`,
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    cursor: 'pointer',
                    fontSize: fontSize.xxs,
                    color: colors.textMuted,
                    fontWeight: fontWeight.medium,
                  }}
                >
                  <span>查看 {plan.days.length} 个训练日</span>
                  {/* Animation: rotate 200ms easeOut on expand */}
                  {/* Flutter: AnimatedRotation */}
                  <span style={{
                    transform: isExpanded ? 'rotate(180deg)' : 'rotate(0deg)',
                    transition: 'transform 200ms ease-out',
                  }}>▾</span>
                </button>

                {/* Expanded days — Flutter: AnimatedSize */}
                {/* Animation: height 200ms easeOut on expand/collapse */}
                {isExpanded && (
                  <div>
                    {plan.days.map((day, i) => (
                      <div
                        key={day.day}
                        style={{
                          padding: '10px 14px',
                          borderTop: `1px solid ${colors.border}`,
                          display: 'flex',       // Flutter: Row
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          background: day.day === plan.currentDay ? colors.coralSurface : colors.white,
                        }}
                      >
                        {/* Flutter: Row + Column */}
                        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                          {/* Current day indicator */}
                          {day.day === plan.currentDay && (
                            <div style={{
                              width: 6, height: 6,
                              background: colors.coral,
                              borderRadius: radius.full,
                              flexShrink: 0,
                            }} />
                          )}
                          {day.day !== plan.currentDay && <div style={{ width: 6 }} />}
                          <div>
                            <div style={{
                              fontSize: fontSize.base,
                              fontWeight: day.day === plan.currentDay ? fontWeight.bold : fontWeight.medium,
                              color: colors.text,
                            }}>
                              {day.label}
                            </div>
                            {day.type === 'workout' && (
                              <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                                {day.sets} 组
                              </div>
                            )}
                          </div>
                        </div>
                        <span style={{
                          fontSize: fontSize.xxs,
                          color: day.type === 'rest' ? colors.textSubtle : colors.textMuted,
                          fontWeight: day.type === 'rest' ? fontWeight.regular : fontWeight.medium,
                        }}>
                          {day.type === 'rest' ? '休息日' : `${day.sets} 组 ›`}
                        </span>
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

      <BottomNav />
    </div>
  )
}
