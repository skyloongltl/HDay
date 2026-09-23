// PAGE: HomeScreen
// ROUTE: /home (tab)
// FLUTTER WIDGETS: Scaffold, CustomScrollView, SliverToBoxAdapter, Card, BottomNavigationBar
// STATE: hasActiveWorkout(bool)
// ANIMATIONS: none (static page)
// NAVIGATION: "开始今日训练" → PreWorkoutScreen; "继续训练" → WorkoutScreen/RestScreen; settings icon → SettingsScreen

import { useState } from 'react'
import StatusBar from '../components/StatusBar'
import BottomNav from '../components/BottomNav'
import ProgressBar from '../components/ProgressBar'
import ExerciseTile from '../components/ExerciseTile'
import { colors, fontSize, fontWeight, radius } from '../tokens'
import { useNav } from '../navigation'
import { useWorkout } from '../workoutStore'
import { todayExercises } from '../data/mockData'

const TOTAL_SETS = todayExercises.reduce((sum, e) => sum + e.sets.length, 0)

// Mock flags — in real app these derive from plan/date data
// Flutter: computed from PlanRepository + DateService
const IS_REST_DAY = false   // set true to preview rest-day state
const HAS_NO_PLANS = false  // set true to preview empty-plans state

export default function HomeScreen() {
  const { push } = useNav()
  const { phase, exercises, elapsedSeconds } = useWorkout()

  // Flutter: bool — workout in progress banner
  const hasActiveWorkout = phase === 'active' || phase === 'resting' // Flutter: setState

  // Flutter: Scaffold
  return (
    <div style={{
      display: 'flex',        // Flutter: Column
      flexDirection: 'column',
      height: '100%',
      background: colors.fogBg,
    }}>
      <StatusBar />

      {/* Flutter: Expanded → CustomScrollView */}
      <div style={{ flex: 1, overflowY: 'auto' }}>

        {/* Top header row — Flutter: Padding + Row, mainAxis: spaceBetween */}
        <div style={{
          display: 'flex',          // Flutter: Row
          alignItems: 'flex-end',   // crossAxis: end (baseline align)
          justifyContent: 'space-between',
          padding: '4px 16px 0',
        }}>
          <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
            9月14日 · 周日
          </span>
          {/* Flutter: Row — page tag + settings icon */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ fontSize: fontSize.xxs, color: colors.textMuted, fontWeight: fontWeight.semibold }}>
              今日
            </span>
            <button
              onClick={() => push('settings')}
              style={{
                width: 28, height: 28,
                background: colors.iconBtn,
                border: 'none', borderRadius: radius.full,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                cursor: 'pointer', color: colors.textMuted, fontSize: 14,
              }}
            >
              ⚙
            </button>
          </div>
        </div>

        {/* Page title — Flutter: Padding + Text */}
        <div style={{ padding: '4px 16px 12px' }}>
          <h1 style={{
            margin: 0,
            fontSize: fontSize.title,
            fontWeight: fontWeight.heavy,
            color: colors.text,
            lineHeight: 1.2,
          }}>
            {hasActiveWorkout ? '训练进行中' : IS_REST_DAY ? '今日休息' : HAS_NO_PLANS ? '开始你的第一次训练' : '今天，练得漂亮'}
          </h1>
        </div>

        {/* ── NO PLANS EMPTY STATE ── Flutter: Center + Column */}
        {!hasActiveWorkout && HAS_NO_PLANS && (
          <div style={{ padding: '0 16px 16px' }}>
            <div style={{
              background: colors.white, border: `1px solid ${colors.border}`,
              borderRadius: radius.hero, padding: '28px 20px', textAlign: 'center',
            }}>
              <div style={{ fontSize: 40, marginBottom: 12 }}>📋</div>
              <div style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text, marginBottom: 6 }}>
                还没有训练计划
              </div>
              <div style={{ fontSize: fontSize.sm, color: colors.textMuted, lineHeight: 1.6, marginBottom: 20 }}>
                创建你的第一个训练计划，<br />或直接开始自由训练
              </div>
              <button
                onClick={() => push('createPlan')}
                style={{
                  width: '100%', height: 46,
                  background: colors.coral, color: colors.onDeep,
                  border: 'none', borderRadius: radius.btn,
                  fontSize: fontSize.md, fontWeight: fontWeight.bold,
                  cursor: 'pointer', marginBottom: 10,
                }}
              >
                创建训练计划
              </button>
              <button
                onClick={() => push('preWorkout', { freeWorkout: true })}
                style={{
                  width: '100%', height: 40, background: 'transparent',
                  border: `1px solid ${colors.border}`,
                  borderRadius: radius.btn,
                  fontSize: fontSize.base, color: colors.textMuted, cursor: 'pointer',
                }}
              >
                开始自由训练
              </button>
            </div>
          </div>
        )}

        {/* ── REST DAY STATE ── Flutter: Card with 休息 badge */}
        {!hasActiveWorkout && IS_REST_DAY && !HAS_NO_PLANS && (
          <div style={{ padding: '0 16px 12px' }}>
            <div style={{
              background: colors.deepBlue, borderRadius: radius.hero, padding: '20px 20px',
            }}>
              <div style={{
                display: 'inline-block',
                background: 'rgba(255,255,255,0.12)', borderRadius: radius.full,
                padding: '3px 10px', fontSize: fontSize.xxs, color: colors.onDeepMuted, marginBottom: 10,
              }}>
                今日计划 · 休息日
              </div>
              <div style={{ fontSize: fontSize.xl, fontWeight: fontWeight.bold, color: colors.onDeep, marginBottom: 6 }}>
                今天好好休息 💙
              </div>
              <div style={{ fontSize: fontSize.xxs, color: colors.onDeepMuted, marginBottom: 16 }}>
                休息也是训练的一部分。身体在恢复中变强。
              </div>
              <button
                onClick={() => push('preWorkout', { freeWorkout: true })}
                style={{
                  width: '100%', height: 44,
                  background: 'rgba(255,255,255,0.15)',
                  color: colors.onDeep, border: '1.5px solid rgba(255,255,255,0.3)',
                  borderRadius: radius.btn,
                  fontSize: fontSize.base, fontWeight: fontWeight.semibold,
                  cursor: 'pointer',
                }}
              >
                开始自由训练
              </button>
            </div>
          </div>
        )}

        {/* ── ACTIVE WORKOUT RESUME CARD ── */}
        {hasActiveWorkout && (
          <>
            <div style={{ padding: '0 16px 10px' }}>
              {/* Flutter: Card (deep blue surface) */}
              <div style={{
                background: colors.deepBlue,
                borderRadius: radius.hero,
                padding: '16px 18px',
              }}>
                <div style={{ fontSize: fontSize.xxs, color: colors.onDeepMuted, marginBottom: 4 }}>
                  当前场次 · {phase === 'resting' ? '休息中' : '进行中'}
                </div>
                <div style={{ fontSize: fontSize.xl, fontWeight: fontWeight.bold, color: colors.onDeep, marginBottom: 12 }}>
                  推拉基础 · D3
                </div>
                {/* Spacer: 8px → SizedBox(height: 8) */}
                <div style={{ height: 8 }} />
                <button
                  onClick={() => push(phase === 'resting' ? 'rest' : 'workout')}
                  style={{
                    width: '100%', height: 44,
                    background: colors.coral,
                    color: colors.onDeep,
                    border: 'none', borderRadius: radius.btn,
                    fontSize: fontSize.md, fontWeight: fontWeight.bold,
                    cursor: 'pointer',
                  }}
                >
                  继续训练
                </button>
              </div>
            </div>
          </>
        )}

        {/* ── TODAY HERO CARD ── */}
        {!hasActiveWorkout && !IS_REST_DAY && !HAS_NO_PLANS && (
          <div style={{ padding: '0 16px 12px' }}>
            {/* Flutter: Card (deep sea blue) */}
            <div style={{
              background: colors.deepBlue,
              borderRadius: radius.hero,
              padding: '16px 18px',
            }}>
              {/* Plan badge — Flutter: Chip */}
              <div style={{
                display: 'inline-block',
                background: 'rgba(255,255,255,0.12)',
                borderRadius: radius.full,
                padding: '3px 10px',
                fontSize: fontSize.xxs,
                color: colors.onDeepMuted,
                marginBottom: 10,
              }}>
                推拉基础 · D3
              </div>
              {/* Flutter: Text (headline) */}
              <div style={{
                fontSize: fontSize.xl,
                fontWeight: fontWeight.bold,
                color: colors.onDeep,
                marginBottom: 4,
              }}>
                胸背力量
              </div>
              <div style={{ fontSize: fontSize.xxs, color: colors.onDeepMuted, marginBottom: 14 }}>
                5 个动作 · {TOTAL_SETS} 组 · 约 55 分钟
              </div>
              {/* Progress bar on hero card */}
              <ProgressBar
                progress={0.44}
                trackColor="rgba(255,255,255,0.15)"
                barColor={colors.coral}
                height={4}
              />
            </div>
          </div>
        )}

        {/* ── START BUTTON ── */}
        {!hasActiveWorkout && !IS_REST_DAY && !HAS_NO_PLANS && (
          <div style={{ padding: '0 16px 12px' }}>
            {/* Flutter: ElevatedButton (primary) */}
            {/* Animation: scale 0.97 on press, 120ms easeOut */}
            {/* Flutter: GestureDetector + AnimatedScale */}
            <button
              onClick={() => push('preWorkout')}
              style={{
                width: '100%', height: 50,
                background: colors.coral,
                color: colors.onDeep,
                border: 'none',
                borderRadius: radius.btn,
                fontSize: fontSize.md,
                fontWeight: fontWeight.bold,
                cursor: 'pointer',
                letterSpacing: '0.3px',
              }}
            >
              开始今日训练
            </button>
          </div>
        )}

        {/* ── STATS ROW ── */}
        {/* Flutter: Row, mainAxis: spaceAround */}
        <div style={{
          display: 'flex',  // Flutter: Row
          gap: 8,
          padding: '0 16px 16px',
        }}>
          {[
            { value: '28', label: '累计天数' },
            { value: '3', label: '本周训练' },
            { value: '8', label: '本月训练' },
          ].map(({ value, label }) => (
            <div key={label} style={{
              flex: 1,
              background: colors.white,
              border: `1px solid ${colors.border}`,
              borderRadius: radius.md,
              padding: '10px 4px',
              textAlign: 'center',
            }}>
              {/* Flutter: Text (numeral) */}
              <div style={{ fontSize: fontSize.lg, fontWeight: fontWeight.heavy, color: colors.text }}>{value}</div>
              {/* Spacer: 2px → SizedBox(height: 2) */}
              <div style={{ height: 2 }} />
              <div style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>{label}</div>
            </div>
          ))}
        </div>

        {/* ── TODAY EXERCISES LIST ── */}
        {/* Flutter: Column with SectionHeader + ListView */}
        <div style={{ padding: '0 16px 8px' }}>
          {/* Section header — Flutter: Row, mainAxis: spaceBetween */}
          <div style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            marginBottom: 10,
          }}>
            <span style={{ fontSize: fontSize.md, fontWeight: fontWeight.bold, color: colors.text }}>
              今日动作
            </span>
            <span style={{ fontSize: fontSize.xxs, color: colors.textMuted }}>
              {TOTAL_SETS} 组
            </span>
          </div>

          {/* Flutter: ListView.builder */}
          {todayExercises.map((ex, i) => (
            <ExerciseTile
              key={ex.id}
              iconChar={ex.iconChar}
              name={ex.name}
              subtitle={`${ex.sets.length} 组 · ${ex.sets[0].weight === 0 ? '体重' : `${ex.sets[0].weight} kg`}`}
              trailing={String(i + 1).padStart(2, '0')}
              animationDelay={i * 50}
              onTap={() => push('exerciseDetail', { exerciseId: ex.id, exerciseName: ex.name })}
            />
          ))}
        </div>

        {/* Spacer: 16px → SizedBox(height: 16) */}
        <div style={{ height: 16 }} />
      </div>

      <BottomNav />
    </div>
  )
}
