// Flutter: BottomNavigationBar (4 items)
// NAVIGATION: tapping item → setTab(key)

import { colors, fontSize, fontWeight } from '../tokens'
import { useNav, type TabKey } from '../navigation'

const TABS: { key: TabKey; label: string; icon: string }[] = [
  { key: 'home',      label: '今日', icon: '◉' },
  { key: 'plan',      label: '计划', icon: '☰' },
  { key: 'calendar',  label: '日历', icon: '◻' },
  { key: 'exercises', label: '动作', icon: '◇' },
]

const TAB_KEYS: TabKey[] = ['home', 'plan', 'calendar', 'exercises']

export default function BottomNav() {
  const { activeTab, setTab } = useNav()

  const activeIdx = TAB_KEYS.indexOf(activeTab)

  // Flutter: BottomNavigationBar, type: fixed
  return (
    <div style={{
      height: 56,
      background: colors.fogBg,
      borderTop: `1px solid ${colors.navBorder}`,
      position: 'relative',
      flexShrink: 0,
    }}>
      {/* Sliding active indicator pill — Flutter: AnimatedPositioned */}
      {/* Animation: left transition 250ms easeOut — Flutter: AnimatedPositioned */}
      <div style={{
        position: 'absolute',
        top: 6,
        left: `calc(${activeIdx} * 25% + 12.5% - 22px)`,
        width: 44,
        height: 3,
        background: colors.coral,
        borderRadius: 2,
        transition: 'left 250ms cubic-bezier(0.25, 0.46, 0.45, 0.94)',
      }} />

      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-around',
        height: '100%',
      }}>
        {TABS.map(tab => {
          // Flutter: setState / ValueNotifier<bool>
          const isActive = activeTab === tab.key // Flutter: selectedIndex == index

          return (
            <button
              key={tab.key}
              onClick={() => setTab(tab.key)}
              style={{
                flex: 1,
                display: 'flex',         // Flutter: Column
                flexDirection: 'column',
                alignItems: 'center',    // crossAxis: center
                justifyContent: 'center',
                gap: 2,
                border: 'none',
                background: 'transparent',
                cursor: 'pointer',
                padding: '10px 0 6px',
                // Animation: color transition 200ms easeOut
                // Flutter: AnimatedDefaultTextStyle
                color: isActive ? colors.text : colors.textSubtle,
                transition: 'color 200ms ease-out, transform 80ms ease-out',
              }}
            >
              {/* Flutter: Icon */}
              <span style={{
                fontSize: 18,
                lineHeight: 1,
                fontWeight: isActive ? fontWeight.bold : fontWeight.regular,
                transition: 'font-weight 0ms, transform 200ms ease',
                transform: isActive ? 'scale(1.1)' : 'scale(1)',
              }}>
                {tab.icon}
              </span>
              {/* Flutter: Text */}
              <span style={{
                fontSize: fontSize.xxs,
                fontWeight: isActive ? fontWeight.bold : fontWeight.regular,
              }}>
                {tab.label}
              </span>
            </button>
          )
        })}
      </div>
    </div>
  )
}
