// PAGE: SettingsScreen
// ROUTE: /settings
// FLUTTER WIDGETS: Scaffold, AppBar, ListView, Switch, RadioListTile
// STATE: weightUnit, defaultRest, restReminder, vibration, screenAwake, weekStart
// ANIMATIONS: Switch slide 200ms easeOut
// NAVIGATION: back → HomeScreen; theme row → (in-page theme picker)

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'

function Toggle({ value, onChange }: { value: boolean; onChange: (v: boolean) => void }) {
  return (
    <div
      onClick={() => onChange(!value)}
      style={{
        width: 42, height: 24,
        background: value ? colors.coral : colors.progressTrack,
        borderRadius: radius.full,
        position: 'relative',
        cursor: 'pointer',
        // Animation: background 200ms easeOut — Flutter: AnimatedContainer
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
        // Animation: left 200ms easeOut — Flutter: AnimatedPositioned
        transition: 'left 200ms ease-out',
        boxShadow: '0 1px 3px rgba(0,0,0,0.25)',
      }} />
    </div>
  )
}

function SettingRow({
  label, value, onTap, children
}: { label: string; value?: string; onTap?: () => void; children?: React.ReactNode }) {
  return (
    <div
      onClick={onTap}
      style={{
        display: 'flex',         // Flutter: Row
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: '14px 16px',
        cursor: onTap ? 'pointer' : 'default',
      }}
    >
      <span style={{ fontSize: fontSize.base, color: colors.text }}>{label}</span>
      {children ?? (
        <span style={{
          fontSize: fontSize.base,
          color: colors.textMuted,
          fontWeight: fontWeight.medium,
        }}>
          {value} ›
        </span>
      )}
    </div>
  )
}

function SettingGroup({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 20 }}>
      <div style={{
        fontSize: fontSize.xxs,
        fontWeight: fontWeight.semibold,
        color: colors.textSubtle,
        padding: '0 16px',
        marginBottom: 6,
        textTransform: 'uppercase' as const,
        letterSpacing: '0.6px',
      }}>
        {title}
      </div>
      <div style={{
        background: colors.white,
        border: `1px solid ${colors.border}`,
        borderRadius: radius.lg,
        overflow: 'hidden',
        margin: '0 0',
        // Flutter: Card
      }}>
        {children}
      </div>
    </div>
  )
}

function Divider() {
  return <div style={{ height: 1, background: colors.border, margin: '0 16px' }} />
}

export default function SettingsScreen() {
  const { pop } = useNav()

  // Flutter: setState — all settings values
  const [weightUnit, setWeightUnit] = useState<'kg' | 'lb'>('kg')   // Flutter: setState
  const [defaultRest, setDefaultRest] = useState(90)                  // Flutter: setState
  const [restReminder, setRestReminder] = useState(true)              // Flutter: setState
  const [vibration, setVibration] = useState(true)                    // Flutter: setState
  const [screenAwake, setScreenAwake] = useState(true)                // Flutter: setState
  const [weekStart, setWeekStart] = useState<'mon' | 'sun'>('mon')    // Flutter: setState
  const [selectedTheme, setSelectedTheme] = useState<'A' | 'B' | 'C'>('A') // Flutter: setState

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
          设置
        </span>
        <div style={{ width: 32 }} />
      </div>

      {/* Flutter: Expanded + ListView */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px' }}>

        {/* TRAINING PREFERENCES */}
        <SettingGroup title="训练偏好">
          <SettingRow label="默认重量单位" value={weightUnit.toUpperCase()} />
          <Divider />
          <SettingRow label="默认休息时长" value={`${defaultRest} 秒`} />
        </SettingGroup>

        {/* TRAINING EXPERIENCE */}
        <SettingGroup title="训练体验">
          <SettingRow label="休息提醒">
            <Toggle value={restReminder} onChange={setRestReminder} />
          </SettingRow>
          <Divider />
          <SettingRow label="震动反馈">
            <Toggle value={vibration} onChange={setVibration} />
          </SettingRow>
          <Divider />
          <SettingRow label="保持屏幕常亮">
            <Toggle value={screenAwake} onChange={setScreenAwake} />
          </SettingRow>
        </SettingGroup>

        {/* CALENDAR */}
        <SettingGroup title="日历">
          <SettingRow label="一周起始日" value={weekStart === 'mon' ? '周一' : '周日'} />
        </SettingGroup>

        {/* THEME — Flutter: RadioListTile (custom) */}
        <SettingGroup title="界面风格">
          <div style={{ padding: '14px 16px 10px' }}>
            <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text, marginBottom: 14 }}>
              选择主题
            </div>
            {/* Flutter: Column */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {[
                {
                  id: 'A' as const,
                  name: '呼吸节拍',
                  desc: '灰调珊瑚 · 柔和克制',
                  tag: '默认',
                  colors: ['#19344C', '#C76F62', '#62E6CA', '#F4F7FA'],
                },
                {
                  id: 'B' as const,
                  name: '训练贴纸册',
                  desc: '硬边日志 · 盖章反馈',
                  tag: null,
                  colors: ['#FFDF3D', '#6956DF', '#FF655F', '#8CE6CF'],
                },
                {
                  id: 'C' as const,
                  name: '夜训仪表',
                  desc: '深色仪表 · 荧光状态',
                  tag: null,
                  colors: ['#131720', '#5D85FF', '#C8FF5A', '#1D222C'],
                },
              ].map(theme => {
                const isSelected = selectedTheme === theme.id
                return (
                  // Flutter: InkWell + AnimatedContainer (theme card)
                  <div
                    key={theme.id}
                    onClick={() => setSelectedTheme(theme.id)}
                    style={{
                      border: `2px solid ${isSelected ? colors.coral : colors.border}`,
                      borderRadius: radius.md,
                      padding: '12px 14px',
                      cursor: 'pointer',
                      // Animation: border-color 200ms easeOut — Flutter: AnimatedContainer
                      transition: 'border-color 200ms ease-out',
                    }}
                  >
                    {/* Flutter: Row */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                      {/* Palette dots — Flutter: Row */}
                      <div style={{ display: 'flex', gap: 4 }}>
                        {theme.colors.map(c => (
                          <div key={c} style={{
                            width: 16, height: 16,
                            background: c,
                            borderRadius: radius.full,
                            border: '1px solid rgba(0,0,0,0.08)',
                          }} />
                        ))}
                      </div>
                      {/* Flutter: Expanded + Column */}
                      <div style={{ flex: 1 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                          <span style={{ fontSize: fontSize.base, fontWeight: fontWeight.bold, color: colors.text }}>
                            {theme.name}
                          </span>
                          {theme.tag && (
                            <span style={{
                              background: colors.coralSurface, color: colors.coral,
                              fontSize: fontSize.xxs, fontWeight: fontWeight.bold,
                              borderRadius: radius.full, padding: '1px 6px',
                            }}>
                              {theme.tag}
                            </span>
                          )}
                        </div>
                        <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginTop: 2 }}>
                          {theme.desc}
                        </div>
                      </div>
                      {/* Radio indicator — Flutter: Radio */}
                      <div style={{
                        width: 20, height: 20,
                        borderRadius: radius.full,
                        border: `2px solid ${isSelected ? colors.coral : colors.border}`,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        flexShrink: 0,
                        transition: 'border-color 200ms ease-out',
                      }}>
                        {isSelected && (
                          <div style={{
                            width: 10, height: 10,
                            background: colors.coral,
                            borderRadius: radius.full,
                          }} />
                        )}
                      </div>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        </SettingGroup>

        {/* ABOUT */}
        <SettingGroup title="关于">
          <SettingRow label="版本" value="1.0.0 (1)" />
          <Divider />
          <SettingRow label="隐私政策" value="" onTap={() => {}} />
          <Divider />
          <SettingRow label="用户协议" value="" onTap={() => {}} />
        </SettingGroup>

        {/* Spacer: 32px → SizedBox(height: 32) */}
        <div style={{ height: 32 }} />
      </div>
    </div>
  )
}
