// Flutter: showModalBottomSheet — exercise picker
// Shared by: PreWorkoutScreen ("＋ 临时添加动作"), PlanEditScreen ("＋ 添加动作")
// NAVIGATION: select item → onSelect(exercise) callback → sheet closes

import { useState } from 'react'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { exerciseLibrary } from '../data/mockData'

export interface PickedExercise {
  id: string
  name: string
  iconChar: string
  category: string
  equipment: string
}

interface Props {
  onSelect: (ex: PickedExercise) => void
  onClose: () => void
  excludeIds?: string[]  // already-added exercises to grey out
}

const CATEGORIES = ['全部', '胸部', '背部', '肩部', '腿部', '手臂', '核心']

export default function ExercisePickerSheet({ onSelect, onClose, excludeIds = [] }: Props) {
  const { push } = useNav()
  // Flutter: TextEditingController
  const [query, setQuery] = useState('')             // Flutter: setState
  const [category, setCategory] = useState('全部')  // Flutter: setState

  const filtered = exerciseLibrary.filter(ex => {
    const matchQ = query === '' || ex.name.includes(query)
    const matchC = category === '全部' || ex.category === category
    return matchQ && matchC
  })

  // Flutter: Stack — dim overlay + BottomSheet
  return (
    <div
      style={{
        position: 'absolute', inset: 0,
        background: 'rgba(15,20,28,0.45)',
        display: 'flex', flexDirection: 'column',
        justifyContent: 'flex-end',
        zIndex: 200,
      }}
      onClick={onClose}
      className="overlay-in"
    >
      {/* Flutter: BottomSheet */}
      {/* Animation: sheetSlideUp 280ms — Flutter: showModalBottomSheet */}
      <div
        onClick={e => e.stopPropagation()}
        className="sheet-up"
        style={{
          background: colors.fogBg,
          borderRadius: `${radius.xl}px ${radius.xl}px 0 0`,
          height: '75%',
          display: 'flex', flexDirection: 'column',
        }}
      >
        {/* Handle */}
        <div style={{
          width: 36, height: 4,
          background: colors.border,
          borderRadius: radius.full,
          margin: '12px auto 0',
          flexShrink: 0,
        }} />

        {/* Header */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '12px 16px 10px', flexShrink: 0,
        }}>
          <span style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
            选择动作
          </span>
          <button
            onClick={onClose}
            style={{
              width: 28, height: 28, background: colors.iconBtn,
              border: 'none', borderRadius: radius.full,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer', fontSize: 14, color: colors.textMuted,
            }}
          >✕</button>
        </div>

        {/* Search bar — Flutter: TextField */}
        <div style={{
          margin: '0 16px 10px',
          background: colors.white, border: `1px solid ${colors.border}`,
          borderRadius: radius.md, padding: '9px 12px',
          display: 'flex', alignItems: 'center', gap: 8,
          flexShrink: 0,
        }}>
          <span style={{ color: colors.textSubtle, fontSize: 14 }}>⌕</span>
          <input
            autoFocus
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="搜索动作名称"
            style={{
              flex: 1, border: 'none', background: 'transparent',
              fontSize: fontSize.base, color: colors.text,
              fontFamily: 'inherit', outline: 'none',
            }}
          />
          {query && (
            <button onClick={() => setQuery('')} style={{
              background: 'transparent', border: 'none',
              cursor: 'pointer', color: colors.textSubtle, fontSize: 13,
            }}>✕</button>
          )}
        </div>

        {/* Category chips — Flutter: SingleChildScrollView horizontal */}
        <div style={{
          display: 'flex', overflowX: 'auto',
          padding: '0 16px 10px', gap: 6,
          flexShrink: 0,
        }}>
          {CATEGORIES.map(cat => (
            <button
              key={cat}
              onClick={() => setCategory(cat)}
              style={{
                flexShrink: 0, height: 26, padding: '0 10px',
                background: category === cat ? colors.text : colors.inputBg,
                color: category === cat ? colors.onDeep : colors.textMuted,
                border: 'none', borderRadius: radius.full,
                fontSize: fontSize.xxs,
                fontWeight: category === cat ? fontWeight.bold : fontWeight.regular,
                cursor: 'pointer',
                transition: 'background 150ms ease-out',
              }}
            >
              {cat}
            </button>
          ))}
        </div>

        {/* Exercise list — Flutter: ListView.builder */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px' }}>
          {filtered.length === 0 ? (
            <div style={{
              textAlign: 'center', padding: '40px 0',
              color: colors.textMuted, fontSize: fontSize.base,
            }}>
              没有找到匹配的动作
            </div>
          ) : (
            filtered.map(ex => {
              const isExcluded = excludeIds.includes(ex.id)
              return (
                <div
                  key={ex.id}
                  onClick={() => {
                    if (isExcluded) return
                    onSelect({
                      id: ex.id, name: ex.name,
                      iconChar: ex.name.slice(0, 1),
                      category: ex.category, equipment: ex.equipment,
                    })
                    onClose()
                  }}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 12,
                    padding: '10px 12px',
                    background: colors.white, border: `1px solid ${colors.border}`,
                    borderRadius: radius.md, marginBottom: 6,
                    cursor: isExcluded ? 'default' : 'pointer',
                    opacity: isExcluded ? 0.4 : 1,
                  }}
                >
                  {/* Icon */}
                  <div style={{
                    width: 34, height: 34,
                    background: colors.mintSurface, borderRadius: radius.sm,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    color: colors.mintText, fontSize: fontSize.xs, fontWeight: fontWeight.heavy,
                    flexShrink: 0,
                  }}>
                    {ex.name.slice(0, 1)}
                  </div>
                  {/* Flutter: Expanded + Column */}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{
                      fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text,
                      overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                    }}>
                      {ex.name}
                    </div>
                    <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                      {ex.category} · {ex.equipment}
                    </div>
                  </div>
                  {isExcluded ? (
                    <span style={{ fontSize: fontSize.xxs, color: colors.textSubtle }}>已添加</span>
                  ) : (
                    <span style={{ fontSize: fontSize.xxs, color: colors.coral, fontWeight: fontWeight.bold }}>＋</span>
                  )}
                </div>
              )
            })
          )}

          {/* Create new exercise shortcut */}
          <div
            onClick={() => { onClose(); push('exerciseCreate') }}
            style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '10px 12px',
              background: 'transparent',
              border: `1.5px dashed ${colors.border}`,
              borderRadius: radius.md, marginBottom: 6,
              cursor: 'pointer',
            }}
          >
            <div style={{
              width: 34, height: 34,
              background: colors.coralSurface, borderRadius: radius.sm,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: colors.coral, fontSize: 18, fontWeight: fontWeight.bold,
              flexShrink: 0,
            }}>
              ＋
            </div>
            <div>
              <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.coral }}>
                新建动作
              </div>
              <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
                创建自定义动作并添加到库
              </div>
            </div>
          </div>

          {/* Spacer: 20px → SizedBox(height: 20) */}
          <div style={{ height: 20 }} />
        </div>
      </div>
    </div>
  )
}
