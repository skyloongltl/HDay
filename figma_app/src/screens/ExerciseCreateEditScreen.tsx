// PAGE: ExerciseCreateEditScreen
// ROUTE: /exercise-create (new) | /exercise-edit (edit existing)
// FLUTTER WIDGETS: Scaffold, AppBar, Form, TextField, DropdownButton, ElevatedButton
// STATE: name, category, equipment, unit, notes, isEditing(bool), showDeleteConfirm(bool)
// ANIMATIONS: overlay-in + scale-pop for delete confirm
// NAVIGATION: save → pop; delete → pop (edit mode only)
// params: { exerciseId?: string } — present when editing

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { exerciseLibrary } from '../data/mockData'

// PAGE SPEC ────────────────────────────────────────────────────────
// 新建模式: 全空表单, AppBar "新建动作", 保存按钮 "添加动作"
// 编辑模式: 预填字段, AppBar "编辑动作", 保存按钮 "保存修改", 底部有删除按钮
// 字段:
//   动作名称  (必填 TextField)
//   部位分类  (SegmentedChips: 胸部/背部/肩部/腿部/手臂/核心/全身/有氧)
//   器械类型  (SegmentedChips: 自重/杠铃/哑铃/器械/绳索/壶铃/弹力带)
//   计重单位  (SegmentedChips: kg/lb/体重)
//   动作说明  (可选 multiline TextField)
// ──────────────────────────────────────────────────────────────────

const CATEGORIES = ['胸部', '背部', '肩部', '腿部', '手臂', '核心', '全身', '有氧']
const EQUIPMENT  = ['自重', '杠铃', '哑铃', '器械', '绳索', '壶铃', '弹力带']
const UNITS      = ['kg', 'lb', '体重']

// Reusable field label
function FieldLabel({ children }: { children: string }) {
  return (
    <div style={{
      fontSize: fontSize.xxs, fontWeight: fontWeight.semibold,
      color: colors.textSubtle, letterSpacing: '0.5px',
      textTransform: 'uppercase' as const, marginBottom: 8,
    }}>
      {children}
    </div>
  )
}

// Chip group — single select
function ChipGroup({
  options, value, onChange,
}: { options: string[]; value: string; onChange: (v: string) => void }) {
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
      {options.map(opt => {
        const active = value === opt
        return (
          <button
            key={opt}
            onClick={() => onChange(opt)}
            style={{
              height: 30, padding: '0 12px',
              background: active ? colors.text : colors.inputBg,
              color: active ? colors.onDeep : colors.textMuted,
              border: active ? 'none' : `1px solid ${colors.border}`,
              borderRadius: radius.full,
              fontSize: fontSize.xs,
              fontWeight: active ? fontWeight.bold : fontWeight.regular,
              cursor: 'pointer',
              // Animation: background 150ms — Flutter: AnimatedContainer
              transition: 'background 150ms ease-out, color 150ms ease-out',
            }}
          >
            {opt}
          </button>
        )
      })}
    </div>
  )
}

export default function ExerciseCreateEditScreen() {
  const { pop, params, currentScreen } = useNav()

  const isEditing = currentScreen === 'exerciseEdit'
  const exerciseId = params.exerciseId as string | undefined
  const existing = exerciseId ? exerciseLibrary.find(e => e.id === exerciseId) : undefined

  // Flutter: TextEditingController / setState
  const [name, setName]           = useState(existing?.name ?? '')                          // Flutter: setState
  const [category, setCategory]   = useState(existing?.category ?? '胸部')                 // Flutter: setState
  const [equipment, setEquipment] = useState(existing?.equipment ?? '杠铃')                // Flutter: setState
  const [unit, setUnit]           = useState<string>('kg')                                  // Flutter: setState
  const [notes, setNotes]         = useState('')                                             // Flutter: setState
  const [nameError, setNameError] = useState(false)                                         // Flutter: setState
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)                         // Flutter: setState

  function handleSave() {
    if (!name.trim()) { setNameError(true); return }
    // In real impl: dispatch createExercise / updateExercise action
    pop()
  }

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
        height: 52, display: 'flex', alignItems: 'center',
        justifyContent: 'space-between', padding: '0 16px',
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
        <span style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
          {isEditing ? '编辑动作' : '新建动作'}
        </span>
        {/* Save shortcut — Flutter: TextButton in actions */}
        <button
          onClick={handleSave}
          style={{
            background: 'transparent', border: 'none',
            color: colors.coral, fontSize: fontSize.base,
            fontWeight: fontWeight.bold, cursor: 'pointer', padding: '4px 6px',
          }}
        >
          {isEditing ? '保存' : '添加'}
        </button>
      </div>

      {/* Flutter: Expanded + SingleChildScrollView */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px 24px' }}>

        {/* ── FIELD: 动作名称 ── Flutter: TextField */}
        <div style={{
          background: colors.white, border: `1px solid ${nameError ? colors.danger : colors.border}`,
          borderRadius: radius.lg, padding: '12px 14px', marginBottom: 12,
          transition: 'border-color 150ms ease',
        }}>
          <FieldLabel>动作名称 *</FieldLabel>
          <input
            autoFocus
            value={name}
            onChange={e => { setName(e.target.value); setNameError(false) }}
            placeholder="例如：杠铃卧推"
            style={{
              width: '100%', border: 'none', background: 'transparent',
              fontSize: fontSize.md, fontWeight: fontWeight.semibold,
              color: colors.text, fontFamily: 'inherit', outline: 'none',
            }}
          />
          {nameError && (
            <div style={{ fontSize: fontSize.xxs, color: colors.danger, marginTop: 4 }}>
              动作名称不能为空
            </div>
          )}
        </div>

        {/* ── FIELD: 部位分类 ── Flutter: Wrap + FilterChip */}
        <div style={{
          background: colors.white, border: `1px solid ${colors.border}`,
          borderRadius: radius.lg, padding: '12px 14px', marginBottom: 12,
        }}>
          <FieldLabel>部位分类</FieldLabel>
          <ChipGroup options={CATEGORIES} value={category} onChange={setCategory} />
        </div>

        {/* ── FIELD: 器械类型 ── Flutter: Wrap + FilterChip */}
        <div style={{
          background: colors.white, border: `1px solid ${colors.border}`,
          borderRadius: radius.lg, padding: '12px 14px', marginBottom: 12,
        }}>
          <FieldLabel>器械类型</FieldLabel>
          <ChipGroup options={EQUIPMENT} value={equipment} onChange={setEquipment} />
        </div>

        {/* ── FIELD: 计重单位 ── Flutter: SegmentedButton */}
        <div style={{
          background: colors.white, border: `1px solid ${colors.border}`,
          borderRadius: radius.lg, padding: '12px 14px', marginBottom: 12,
        }}>
          <FieldLabel>计重单位</FieldLabel>
          {/* Flutter: Row — SegmentedButton style */}
          <div style={{
            display: 'flex',
            background: colors.inputBg, borderRadius: radius.md,
            padding: 3, gap: 3,
          }}>
            {UNITS.map(u => {
              const active = unit === u
              return (
                <button
                  key={u}
                  onClick={() => setUnit(u)}
                  style={{
                    flex: 1, height: 34,
                    background: active ? colors.white : 'transparent',
                    border: 'none', borderRadius: radius.sm,
                    fontSize: fontSize.base,
                    fontWeight: active ? fontWeight.bold : fontWeight.regular,
                    color: active ? colors.text : colors.textMuted,
                    cursor: 'pointer',
                    boxShadow: active ? '0 1px 3px rgba(0,0,0,0.10)' : 'none',
                    // Animation: background 150ms — Flutter: AnimatedContainer
                    transition: 'background 150ms ease-out, box-shadow 150ms ease-out',
                  }}
                >
                  {u}
                </button>
              )
            })}
          </div>
        </div>

        {/* ── FIELD: 动作说明 ── Flutter: TextField (multiline) */}
        <div style={{
          background: colors.white, border: `1px solid ${colors.border}`,
          borderRadius: radius.lg, padding: '12px 14px', marginBottom: 20,
        }}>
          <FieldLabel>动作说明（可选）</FieldLabel>
          <textarea
            value={notes}
            onChange={e => setNotes(e.target.value)}
            placeholder="描述动作要点、注意事项或个人笔记…"
            style={{
              width: '100%', minHeight: 80, border: 'none', resize: 'none',
              background: 'transparent', fontSize: fontSize.base,
              color: colors.text, fontFamily: 'inherit', outline: 'none',
              lineHeight: 1.6, boxSizing: 'border-box',
            }}
          />
        </div>

        {/* Preview chip — shows how this exercise will appear in the library */}
        <div style={{
          background: colors.mintSurface, border: `1px solid ${colors.border}`,
          borderRadius: radius.md, padding: '10px 14px', marginBottom: 20,
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <div style={{
            width: 36, height: 36, background: colors.mint,
            borderRadius: radius.sm, flexShrink: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: colors.white, fontSize: fontSize.sm, fontWeight: fontWeight.heavy,
          }}>
            {name.slice(0, 1) || '…'}
          </div>
          <div>
            <div style={{ fontSize: fontSize.base, fontWeight: fontWeight.semibold, color: colors.text }}>
              {name || '动作名称预览'}
            </div>
            <div style={{ fontSize: fontSize.xxs, color: colors.textMuted, marginTop: 1 }}>
              {category} · {equipment} · {unit}
            </div>
          </div>
        </div>

        {/* ── PRIMARY SAVE BUTTON ── Flutter: ElevatedButton */}
        <button
          onClick={handleSave}
          style={{
            width: '100%', height: 50,
            background: colors.coral, color: colors.onDeep,
            border: 'none', borderRadius: radius.btn,
            fontSize: fontSize.md, fontWeight: fontWeight.bold,
            cursor: 'pointer', marginBottom: isEditing ? 12 : 0,
          }}
        >
          {isEditing ? '保存修改' : '添加动作'}
        </button>

        {/* ── DELETE BUTTON (edit mode only) ── Flutter: OutlinedButton (danger) */}
        {isEditing && (
          <button
            onClick={() => setShowDeleteConfirm(true)}
            style={{
              width: '100%', height: 44,
              background: colors.dangerSurface,
              border: `1px solid ${colors.danger}30`,
              borderRadius: radius.btn,
              fontSize: fontSize.base, fontWeight: fontWeight.semibold,
              color: colors.danger, cursor: 'pointer',
            }}
          >
            删除此动作
          </button>
        )}

        {/* Spacer: 16px → SizedBox(height: 16) */}
        <div style={{ height: 16 }} />
      </div>

      {/* ── DELETE CONFIRM DIALOG ── Flutter: AlertDialog */}
      {/* Animation: overlay-in + scale-pop */}
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
            <div style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text, marginBottom: 8 }}>
              删除「{name}」？
            </div>
            <div style={{ fontSize: fontSize.xs, color: colors.textMuted, lineHeight: 1.6, marginBottom: 20 }}>
              该动作将从动作库中移除。历史训练记录中已有的数据不受影响。此操作无法撤销。
            </div>
            {/* Flutter: Row, mainAxis: end */}
            <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
              <button
                onClick={() => setShowDeleteConfirm(false)}
                style={{
                  height: 38, padding: '0 16px',
                  background: colors.inputBg, border: 'none',
                  borderRadius: radius.sm,
                  fontSize: fontSize.base, color: colors.textMuted, cursor: 'pointer',
                }}
              >
                取消
              </button>
              <button
                onClick={() => { setShowDeleteConfirm(false); pop() }}
                style={{
                  height: 38, padding: '0 16px',
                  background: colors.danger, border: 'none',
                  borderRadius: radius.sm,
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
