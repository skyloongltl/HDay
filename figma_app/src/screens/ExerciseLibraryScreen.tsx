// PAGE: ExerciseLibraryScreen
// ROUTE: /exercises (tab)
// FLUTTER WIDGETS: Scaffold, TextField (search), SliverList, BottomNavigationBar
// STATE: searchQuery(string)
// ANIMATIONS: none
// NAVIGATION: exercise item → ExerciseDetailScreen; "＋" → new exercise

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import BottomNav from '../components/BottomNav'
import ExerciseTile from '../components/ExerciseTile'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { exerciseLibrary } from '../data/mockData'

const CATEGORIES = ['全部', '胸部', '背部', '肩部', '腿部', '手臂', '核心']

export default function ExerciseLibraryScreen() {
  const { push } = useNav()

  // Flutter: TextEditingController
  const [searchQuery, setSearchQuery] = useState('')     // Flutter: setState
  const [activeCategory, setActiveCategory] = useState('全部') // Flutter: setState

  const recentExercises = exerciseLibrary.filter(e => e.recent)
  const allExercises = exerciseLibrary

  const filtered = allExercises.filter(ex => {
    const matchesSearch = searchQuery === '' || ex.name.includes(searchQuery)
    const matchesCategory = activeCategory === '全部' || ex.category === activeCategory
    return matchesSearch && matchesCategory
  })

  const isSearching = searchQuery !== '' || activeCategory !== '全部'

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
        background: colors.white,
        borderBottom: `1px solid ${colors.border}`,
        flexShrink: 0,
      }}>
        <div style={{
          height: 52,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 16px',
        }}>
          <span style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
            动作库
          </span>
          <button
            onClick={() => push('exerciseCreate')}
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

        {/* Flutter: TextField (search bar) */}
        <div style={{
          margin: '0 16px 12px',
          background: colors.inputBg,
          borderRadius: radius.md,
          padding: '9px 14px',
          display: 'flex',
          alignItems: 'center',
          gap: 8,
        }}>
          <span style={{ color: colors.textSubtle, fontSize: 14 }}>⌕</span>
          <input
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            placeholder="搜索动作名称"
            style={{
              flex: 1, border: 'none', background: 'transparent',
              fontSize: fontSize.base, color: colors.text,
              fontFamily: 'inherit', outline: 'none',
            }}
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              style={{
                background: 'transparent', border: 'none',
                cursor: 'pointer', color: colors.textSubtle, fontSize: 14,
              }}
            >✕</button>
          )}
        </div>

        {/* Category chips — Flutter: SingleChildScrollView (horizontal) + Wrap */}
        <div style={{
          display: 'flex',
          overflowX: 'auto',
          padding: '0 16px 12px',
          gap: 6,
        }}>
          {CATEGORIES.map(cat => {
            const isActive = activeCategory === cat
            return (
              <button
                key={cat}
                onClick={() => setActiveCategory(cat)}
                style={{
                  flexShrink: 0,
                  height: 28,
                  padding: '0 12px',
                  background: isActive ? colors.text : colors.inputBg,
                  color: isActive ? colors.onDeep : colors.textMuted,
                  border: 'none',
                  borderRadius: radius.full,
                  fontSize: fontSize.xxs,
                  fontWeight: isActive ? fontWeight.bold : fontWeight.regular,
                  cursor: 'pointer',
                  transition: 'background 150ms ease-out, color 150ms ease-out',
                }}
              >
                {cat}
              </button>
            )
          })}
        </div>
      </div>

      {/* Flutter: Expanded + ListView */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '12px 16px' }}>
        {/* Empty library state — Flutter: Center + Column */}
        {allExercises.length === 0 && !isSearching && (
          <div style={{ textAlign: 'center', padding: '60px 24px 24px' }}>
            <div style={{ fontSize: 40, marginBottom: 14 }}>🏋️</div>
            <div style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text, marginBottom: 6 }}>
              动作库是空的
            </div>
            <div style={{ fontSize: fontSize.sm, color: colors.textMuted, lineHeight: 1.6, marginBottom: 20 }}>
              添加你的第一个动作，开始构建你的专属动作库
            </div>
            <button
              style={{
                height: 46, padding: '0 28px',
                background: colors.coral, color: colors.onDeep,
                border: 'none', borderRadius: radius.btn,
                fontSize: fontSize.base, fontWeight: fontWeight.bold, cursor: 'pointer',
              }}
            >
              添加动作
            </button>
          </div>
        )}
        {!isSearching && allExercises.length > 0 ? (
          <>
            {/* Recent section — Flutter: SliverToBoxAdapter + SliverList */}
            <div style={{ marginBottom: 20 }}>
              <div style={{
                fontSize: fontSize.sm,
                fontWeight: fontWeight.bold,
                color: colors.text,
                marginBottom: 10,
              }}>
                最近使用
              </div>
              {recentExercises.map(ex => (
                <ExerciseTile
                  key={ex.id}
                  iconChar={ex.name.slice(0, 1)}
                  name={ex.name}
                  subtitle={`${ex.category} · ${ex.equipment}`}
                  trailing={ex.recentWeight}
                  onTap={() => push('exerciseDetail', { exerciseId: ex.id, exerciseName: ex.name })}
                />
              ))}
            </div>

            {/* All section */}
            <div>
              <div style={{
                fontSize: fontSize.sm,
                fontWeight: fontWeight.bold,
                color: colors.text,
                marginBottom: 10,
              }}>
                全部动作
              </div>
              {allExercises.map(ex => (
                <ExerciseTile
                  key={ex.id}
                  iconChar={ex.name.slice(0, 1)}
                  name={ex.name}
                  subtitle={`${ex.category} · ${ex.equipment}`}
                  trailing="›"
                  onTap={() => push('exerciseDetail', { exerciseId: ex.id, exerciseName: ex.name })}
                />
              ))}
            </div>
          </>
        ) : (
          <>
            <div style={{
              fontSize: fontSize.sm, fontWeight: fontWeight.bold,
              color: colors.text, marginBottom: 10,
            }}>
              {filtered.length} 个动作
            </div>
            {filtered.length > 0
              ? filtered.map(ex => (
                  <ExerciseTile
                    key={ex.id}
                    iconChar={ex.name.slice(0, 1)}
                    name={ex.name}
                    subtitle={`${ex.category} · ${ex.equipment}`}
                    trailing={ex.recentWeight}
                    onTap={() => push('exerciseDetail', { exerciseId: ex.id, exerciseName: ex.name })}
                  />
                ))
              : (
                <div style={{
                  textAlign: 'center', padding: '40px 0',
                  color: colors.textMuted, fontSize: fontSize.base,
                }}>
                  没有找到匹配的动作
                </div>
              )
            }
          </>
        )}

        {/* Spacer: 16px → SizedBox(height: 16) */}
        <div style={{ height: 16 }} />
      </div>

      <BottomNav />
    </div>
  )
}
