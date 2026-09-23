// PAGE: CreateEditPlanScreen
// ROUTE: /create-plan  |  /edit-plan
// FLUTTER WIDGETS: Scaffold, AppBar, SingleChildScrollView, TextField,
//   SegmentedButton, Switch, DatePicker (inline), ElevatedButton
// STATE: name, cycleLength, execMode, loopCount, endDate, priority, enabled
// ANIMATIONS: conditional fields fade 200ms easeOut (Flutter: AnimatedOpacity)
// NAVIGATION: save → pop to PlanScreen; cancel → pop

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'

type ExecMode = 'infinite' | 'fixedCount' | 'dateRange'

// Flutter: Toggle (reuse pattern from SettingsScreen)
function Toggle({ value, onChange }: { value: boolean; onChange: (v: boolean) => void }) {
  return (
    <div
      onClick={() => onChange(!value)}
      style={{
        width: 42, height: 24,
        background: value ? colors.coral : colors.progressTrack,
        borderRadius: radius.full,
        position: 'relative', cursor: 'pointer',
        transition: 'background 200ms ease-out',
        flexShrink: 0,
      }}
    >
      <div style={{
        position: 'absolute',
        top: 3, left: value ? 21 : 3,
        width: 18, height: 18,
        background: colors.white,
        borderRadius: radius.full,
        transition: 'left 200ms ease-out',
        boxShadow: '0 1px 3px rgba(0,0,0,0.25)',
      }} />
    </div>
  )
}

// Flutter: InputDecorationTheme row
function FieldRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 16 }}>
      <div style={{
        fontSize: fontSize.xxs, fontWeight: fontWeight.semibold,
        color: colors.textSubtle, marginBottom: 6,
        textTransform: 'uppercase' as const, letterSpacing: '0.5px',
      }}>
        {label}
      </div>
      {children}
    </div>
  )
}

// Flutter: TextField (styled)
function TextInput({
  value, onChange, placeholder, type = 'text',
}: {
  value: string; onChange: (v: string) => void
  placeholder?: string; type?: string
}) {
  return (
    <input
      type={type}
      value={value}
      onChange={e => onChange(e.target.value)}
      placeholder={placeholder}
      style={{
        width: '100%', height: 44,
        background: colors.white,
        border: `1px solid ${colors.border}`,
        borderRadius: radius.md,
        padding: '0 14px',
        fontSize: fontSize.base,
        color: colors.text,
        fontFamily: 'inherit',
        outline: 'none',
        boxSizing: 'border-box',
      }}
    />
  )
}

export default function CreateEditPlanScreen() {
  const { pop, params } = useNav()
  const isEdit = !!params.planId
  const planId = params.planId as string | undefined

  // Flutter: TextEditingController / setState
  const [name, setName] = useState(isEdit ? '推拉基础计划' : '')           // Flutter: setState
  const [cycleLength, setCycleLength] = useState(isEdit ? '6' : '7')      // Flutter: setState
  const [execMode, setExecMode] = useState<ExecMode>('infinite')           // Flutter: setState
  const [loopCount, setLoopCount] = useState('12')                         // Flutter: setState
  const [endDate, setEndDate] = useState('2026-12-31')                     // Flutter: setState
  const [enabled, setEnabled] = useState(true)                             // Flutter: setState
  const [nameError, setNameError] = useState('')                           // Flutter: setState (validation)

  // Computed display values
  const cycleLengthNum = parseInt(cycleLength) || 1
  const loopCountNum = parseInt(loopCount) || 1
  // Estimated end date for fixed-count mode
  const computedEndDate = (() => {
    const start = new Date('2026-09-14')
    start.setDate(start.getDate() + cycleLengthNum * loopCountNum)
    return `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}-${String(start.getDate()).padStart(2, '0')}`
  })()
  // Computed cycles for date range mode
  const computedCycles = (() => {
    if (!endDate) return null
    const start = new Date('2026-09-14')
    const end = new Date(endDate)
    const days = Math.max(0, Math.floor((end.getTime() - start.getTime()) / 86400000))
    const full = Math.floor(days / cycleLengthNum)
    const rem = days % cycleLengthNum
    return { full, rem }
  })()

  function handleSave() {
    if (!name.trim()) {
      setNameError('请输入计划名称')
      return
    }
    // Flutter: call repository save → pop with result
    pop()
  }

  // Flutter: Scaffold
  return (
    <div style={{
      display: 'flex', flexDirection: 'column',
      height: '100%', background: colors.fogBg,
    }}>
      <StatusBar />

      {/* Flutter: AppBar */}
      <div style={{
        height: 52,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '0 16px',
        background: colors.white,
        borderBottom: `1px solid ${colors.border}`,
        flexShrink: 0,
      }}>
        <button
          onClick={pop}
          style={{
            background: 'transparent', border: 'none',
            color: colors.textMuted, fontSize: fontSize.base,
            cursor: 'pointer', padding: '4px 0',
          }}
        >
          取消
        </button>
        <span style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
          {isEdit ? '编辑计划' : '新建计划'}
        </span>
        <button
          onClick={handleSave}
          style={{
            background: 'transparent', border: 'none',
            color: colors.coral, fontSize: fontSize.base,
            fontWeight: fontWeight.bold, cursor: 'pointer',
          }}
        >
          保存
        </button>
      </div>

      {/* Flutter: Expanded + SingleChildScrollView */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 16px' }}>

        {/* ── SECTION: 基本信息 ── */}
        <div style={{
          background: colors.white, border: `1px solid ${colors.border}`,
          borderRadius: radius.lg, padding: '16px',
          marginBottom: 20,
        }}>
          <div style={{
            fontSize: fontSize.xxs, fontWeight: fontWeight.semibold,
            color: colors.textSubtle, marginBottom: 14,
            textTransform: 'uppercase' as const, letterSpacing: '0.5px',
          }}>
            基本信息
          </div>

          <FieldRow label="计划名称">
            <TextInput
              value={name}
              onChange={v => { setName(v); setNameError('') }}
              placeholder="例如：推拉腿计划"
            />
            {/* Flutter: AnimatedOpacity for error text */}
            {nameError && (
              <div style={{
                fontSize: fontSize.xxs, color: colors.danger, marginTop: 4,
              }}>{nameError}</div>
            )}
          </FieldRow>

          <FieldRow label="周期天数 N（1–365）">
            {/* Flutter: Row — input + computed label */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <TextInput
                value={cycleLength}
                onChange={v => setCycleLength(v.replace(/\D/g, ''))}
                placeholder="7"
                type="number"
              />
              <span style={{
                fontSize: fontSize.xxs, color: colors.textMuted,
                whiteSpace: 'nowrap', flexShrink: 0,
              }}>
                天 / 轮
              </span>
            </div>
            <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginTop: 6 }}>
              系统将生成 {cycleLengthNum} 个周期日（D1–D{cycleLengthNum}），可单独配置训练或休息
            </div>
          </FieldRow>

          {/* Flutter: Row — label + Toggle */}
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          }}>
            <div>
              <div style={{ fontSize: fontSize.base, color: colors.text }}>启用此计划</div>
              <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginTop: 2 }}>
                启用后纳入今日首页计算
              </div>
            </div>
            <Toggle value={enabled} onChange={setEnabled} />
          </div>
        </div>

        {/* ── SECTION: 执行模式 ── */}
        <div style={{
          background: colors.white, border: `1px solid ${colors.border}`,
          borderRadius: radius.lg, padding: '16px',
          marginBottom: 20,
        }}>
          <div style={{
            fontSize: fontSize.xxs, fontWeight: fontWeight.semibold,
            color: colors.textSubtle, marginBottom: 14,
            textTransform: 'uppercase' as const, letterSpacing: '0.5px',
          }}>
            执行模式
          </div>

          {/* Flutter: SegmentedButton (3 options) */}
          <div style={{
            display: 'flex', // Flutter: Row
            background: colors.inputBg,
            borderRadius: radius.md,
            padding: 3,
            marginBottom: 16,
          }}>
            {([
              { key: 'infinite' as ExecMode, label: '无限循环' },
              { key: 'fixedCount' as ExecMode, label: '固定次数' },
              { key: 'dateRange' as ExecMode, label: '日期范围' },
            ]).map(({ key, label }) => (
              <button
                key={key}
                onClick={() => setExecMode(key)}
                style={{
                  flex: 1, height: 32,
                  background: execMode === key ? colors.white : 'transparent',
                  border: 'none', borderRadius: radius.sm,
                  fontSize: fontSize.xxs, fontWeight: execMode === key ? fontWeight.bold : fontWeight.regular,
                  color: execMode === key ? colors.text : colors.textMuted,
                  cursor: 'pointer',
                  boxShadow: execMode === key ? '0 1px 3px rgba(0,0,0,0.12)' : 'none',
                  // Animation: background/shadow 150ms easeOut — Flutter: AnimatedContainer
                  transition: 'background 150ms ease-out, box-shadow 150ms ease-out',
                }}
              >
                {label}
              </button>
            ))}
          </div>

          {/* Flutter: AnimatedSwitcher / AnimatedOpacity — conditional fields */}

          {/* Infinite loop — no extra fields */}
          {execMode === 'infinite' && (
            <div style={{
              background: colors.inputBg, borderRadius: radius.md,
              padding: '12px 14px',
              fontSize: fontSize.xxs, color: colors.textMuted, lineHeight: 1.6,
            }}>
              计划将无限循环，直到手动停用。每轮结束后自动从 D1 重新开始。
            </div>
          )}

          {/* Fixed loop count */}
          {/* Animation: fade in 200ms easeOut — Flutter: AnimatedOpacity */}
          {execMode === 'fixedCount' && (
            <div>
              <FieldRow label="循环次数">
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <TextInput
                    value={loopCount}
                    onChange={v => setLoopCount(v.replace(/\D/g, ''))}
                    type="number"
                  />
                  <span style={{
                    fontSize: fontSize.xxs, color: colors.textMuted, flexShrink: 0,
                  }}>次</span>
                </div>
              </FieldRow>
              {/* Computed end date (read-only) */}
              <div style={{
                background: colors.inputBg, borderRadius: radius.md,
                padding: '10px 14px',
                display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              }}>
                <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>预计结束日期</span>
                <span style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text }}>
                  {computedEndDate}
                </span>
              </div>
            </div>
          )}

          {/* Date range */}
          {execMode === 'dateRange' && (
            <div>
              <FieldRow label="结束日期">
                <input
                  type="date"
                  value={endDate}
                  onChange={e => setEndDate(e.target.value)}
                  min="2026-09-15"
                  style={{
                    width: '100%', height: 44,
                    background: colors.white,
                    border: `1px solid ${colors.border}`,
                    borderRadius: radius.md,
                    padding: '0 14px',
                    fontSize: fontSize.base,
                    color: colors.text,
                    fontFamily: 'inherit',
                    outline: 'none',
                    boxSizing: 'border-box',
                  }}
                />
              </FieldRow>
              {/* Computed cycle info (read-only) */}
              {computedCycles && (
                <div style={{
                  background: colors.inputBg, borderRadius: radius.md,
                  padding: '10px 14px',
                }}>
                  <div style={{
                    display: 'flex', justifyContent: 'space-between',
                    marginBottom: 4,
                  }}>
                    <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>完整轮次</span>
                    <span style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text }}>
                      {computedCycles.full} 轮
                    </span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>剩余天数</span>
                    <span style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text }}>
                      {computedCycles.rem} 天
                    </span>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {/* ── SECTION: 周期日配置入口 ── */}
        {isEdit && (
          <div style={{
            background: colors.white, border: `1px solid ${colors.border}`,
            borderRadius: radius.lg, overflow: 'hidden',
            marginBottom: 20,
          }}>
            <div style={{
              padding: '14px 16px',
              borderBottom: `1px solid ${colors.border}`,
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            }}>
              <div>
                <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.bold, color: colors.text }}>
                  周期日配置
                </div>
                <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginTop: 2 }}>
                  {cycleLengthNum} 个训练日，点击进入详细配置
                </div>
              </div>
              <span style={{ color: colors.textSubtle, fontSize: 14 }}>›</span>
            </div>
            {/* Days preview chips */}
            <div style={{ padding: '10px 16px', display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {Array.from({ length: Math.min(cycleLengthNum, 7) }, (_, i) => (
                <div key={i} style={{
                  background: colors.inputBg, borderRadius: radius.full,
                  padding: '4px 10px',
                  fontSize: fontSize.xxs, color: colors.textMuted,
                }}>
                  D{i + 1}
                </div>
              ))}
              {cycleLengthNum > 7 && (
                <div style={{
                  background: colors.inputBg, borderRadius: radius.full,
                  padding: '4px 10px',
                  fontSize: fontSize.xxs, color: colors.textMuted,
                }}>
                  +{cycleLengthNum - 7}
                </div>
              )}
            </div>
          </div>
        )}

        {/* Spacer: 16px → SizedBox(height: 16) */}
        <div style={{ height: 16 }} />
      </div>

      {/* Flutter: SafeArea bottom — primary action */}
      <div style={{
        padding: '12px 16px 20px',
        background: colors.white,
        borderTop: `1px solid ${colors.border}`,
        flexShrink: 0,
      }}>
        <button
          onClick={handleSave}
          style={{
            width: '100%', height: 50,
            background: colors.coral, color: colors.onDeep,
            border: 'none', borderRadius: radius.btn,
            fontSize: fontSize.md, fontWeight: fontWeight.bold,
            cursor: 'pointer',
          }}
        >
          {isEdit ? '保存修改' : '创建计划'}
        </button>
        {isEdit && (
          <>
            {/* Spacer: 8px → SizedBox(height: 8) */}
            <div style={{ height: 8 }} />
            <button style={{
              width: '100%', height: 40,
              background: 'transparent', border: 'none',
              color: colors.danger, fontSize: fontSize.xxs,
              fontWeight: fontWeight.bold, cursor: 'pointer',
            }}>
              删除此计划
            </button>
          </>
        )}
      </div>
    </div>
  )
}
