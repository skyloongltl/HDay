import type { WorkoutExercise } from '../workoutStore'

// Today's workout: 推拉基础 · D3 — 胸背力量
export const todayExercises: WorkoutExercise[] = [
  {
    id: 'e1', name: '杠铃卧推', iconChar: '卧', targetRest: 90,
    sets: [
      { id: 'e1s1', weight: 60, reps: 10, status: 'pending' },
      { id: 'e1s2', weight: 60, reps: 10, status: 'pending' },
      { id: 'e1s3', weight: 62.5, reps: 8, status: 'pending' },
      { id: 'e1s4', weight: 60, reps: 8, status: 'pending' },
    ],
  },
  {
    id: 'e2', name: '坐姿划船', iconChar: '划', targetRest: 90,
    sets: [
      { id: 'e2s1', weight: 45, reps: 12, status: 'pending' },
      { id: 'e2s2', weight: 45, reps: 12, status: 'pending' },
      { id: 'e2s3', weight: 45, reps: 10, status: 'pending' },
      { id: 'e2s4', weight: 45, reps: 10, status: 'pending' },
    ],
  },
  {
    id: 'e3', name: '哑铃侧平举', iconChar: '侧', targetRest: 60,
    sets: [
      { id: 'e3s1', weight: 12, reps: 15, status: 'pending' },
      { id: 'e3s2', weight: 12, reps: 15, status: 'pending' },
      { id: 'e3s3', weight: 12, reps: 12, status: 'pending' },
    ],
  },
  {
    id: 'e4', name: '引体向上', iconChar: '引', targetRest: 120,
    sets: [
      { id: 'e4s1', weight: 0, reps: 8, status: 'pending' },
      { id: 'e4s2', weight: 0, reps: 8, status: 'pending' },
      { id: 'e4s3', weight: 0, reps: 6, status: 'pending' },
    ],
  },
  {
    id: 'e5', name: '绳索夹胸', iconChar: '绳', targetRest: 60,
    sets: [
      { id: 'e5s1', weight: 35, reps: 15, status: 'pending' },
      { id: 'e5s2', weight: 35, reps: 15, status: 'pending' },
      { id: 'e5s3', weight: 35, reps: 12, status: 'pending' },
      { id: 'e5s4', weight: 30, reps: 12, status: 'pending' },
    ],
  },
]

export const plans = [
  {
    id: 'p1',
    name: '推拉基础计划',
    cycle: '6 天循环',
    currentDay: 3,
    enabled: true,
    days: [
      { day: 1, label: 'D1 · 胸肩', sets: 18, type: 'workout' as const },
      { day: 2, label: 'D2 · 背部', sets: 14, type: 'workout' as const },
      { day: 3, label: 'D3 · 胸背', sets: 18, type: 'workout' as const },
      { day: 4, label: 'D4 · 休息', sets: 0,  type: 'rest' as const },
      { day: 5, label: 'D5 · 腿部', sets: 16, type: 'workout' as const },
      { day: 6, label: 'D6 · 手臂', sets: 14, type: 'workout' as const },
    ],
    exercises: {
      1: [{ name: '杠铃卧推', sets: 4, weight: '60 kg' }, { name: '哑铃侧平举', sets: 3, weight: '12 kg' }, { name: '绳索夹胸', sets: 4, weight: '35 kg' }, { name: '坐姿肩推', sets: 4, weight: '24 kg' }, { name: '面拉', sets: 3, weight: '20 kg' }],
      2: [{ name: '坐姿划船', sets: 4, weight: '45 kg' }, { name: '引体向上', sets: 3, weight: '体重' }, { name: '直臂下压', sets: 4, weight: '25 kg' }, { name: '单臂哑铃划船', sets: 3, weight: '30 kg' }],
      3: [{ name: '杠铃卧推', sets: 4, weight: '60 kg' }, { name: '坐姿划船', sets: 4, weight: '45 kg' }, { name: '哑铃侧平举', sets: 3, weight: '12 kg' }, { name: '引体向上', sets: 3, weight: '体重' }, { name: '绳索夹胸', sets: 4, weight: '35 kg' }],
      4: [],
      5: [{ name: '深蹲', sets: 5, weight: '80 kg' }, { name: '腿举', sets: 4, weight: '120 kg' }, { name: '腿弯举', sets: 3, weight: '40 kg' }, { name: '腿伸展', sets: 4, weight: '45 kg' }],
      6: [{ name: '哑铃弯举', sets: 3, weight: '16 kg' }, { name: '三头下压', sets: 3, weight: '25 kg' }, { name: '锤式弯举', sets: 3, weight: '16 kg' }, { name: '仰卧臂屈伸', sets: 3, weight: '体重' }, { name: '集中弯举', sets: 2, weight: '14 kg' }],
    } as Record<number, { name: string; sets: number; weight: string }[]>,
  },
  {
    id: 'p2',
    name: '核心力量计划',
    cycle: '3 天循环',
    currentDay: 1,
    enabled: true,
    days: [
      { day: 1, label: 'D1 · 核心 A', sets: 9, type: 'workout' as const },
      { day: 2, label: 'D2 · 核心 B', sets: 9, type: 'workout' as const },
      { day: 3, label: 'D3 · 休息',   sets: 0, type: 'rest' as const },
    ],
    exercises: {
      1: [{ name: '卷腹', sets: 3, weight: '体重' }, { name: '悬挂举腿', sets: 3, weight: '体重' }, { name: '平板支撑', sets: 3, weight: '体重' }],
      2: [{ name: '俄罗斯转体', sets: 3, weight: '10 kg' }, { name: '仰卧举腿', sets: 3, weight: '体重' }, { name: '死虫式', sets: 3, weight: '体重' }],
      3: [],
    } as Record<number, { name: string; sets: number; weight: string }[]>,
  },
]

// Calendar: completed days in Sep 2026
// Sept 2026 starts on Tuesday (day-of-week index 1)
export const completedDays = [2, 5, 8, 10, 12] // 已完成
export const plannedDays = [14, 17]              // 计划中 (today = 14)

export const historyRecords = [
  {
    id: 'h1', date: '2026-09-12', label: '9月12日 · 周六',
    plan: '推拉基础 · D2', duration: 3156, // seconds
    completedSets: 16, totalSets: 18, skippedSets: 2,
    exercises: [
      { name: '杠铃卧推', sets: [{ reps: 10, weight: 60 }, { reps: 10, weight: 60 }, { reps: 8, weight: 62.5 }, { reps: 8, weight: 60 }] },
      { name: '坐姿划船', sets: [{ reps: 12, weight: 45 }, { reps: 12, weight: 45 }, { reps: 10, weight: 45 }, { reps: 10, weight: 45 }] },
      { name: '哑铃侧平举', sets: [{ reps: 15, weight: 12 }, { reps: 15, weight: 12 }, { reps: 0, weight: 0 }] }, // last skipped
      { name: '引体向上', sets: [{ reps: 8, weight: 0 }, { reps: 8, weight: 0 }, { reps: 6, weight: 0 }] },
      { name: '绳索夹胸', sets: [{ reps: 15, weight: 35 }, { reps: 15, weight: 35 }, { reps: 12, weight: 35 }, { reps: 0, weight: 0 }] }, // last skipped
    ],
  },
  {
    id: 'h2', date: '2026-09-10', label: '9月10日 · 周四',
    plan: '推拉基础 · D1', duration: 2652,
    completedSets: 14, totalSets: 14, skippedSets: 0,
    exercises: [
      { name: '杠铃卧推', sets: [{ reps: 10, weight: 60 }, { reps: 10, weight: 60 }, { reps: 8, weight: 60 }, { reps: 8, weight: 57.5 }] },
      { name: '哑铃侧平举', sets: [{ reps: 15, weight: 12 }, { reps: 15, weight: 12 }, { reps: 12, weight: 12 }] },
      { name: '绳索夹胸', sets: [{ reps: 15, weight: 35 }, { reps: 15, weight: 35 }, { reps: 12, weight: 35 }, { reps: 12, weight: 30 }] },
      { name: '坐姿肩推', sets: [{ reps: 10, weight: 24 }, { reps: 10, weight: 24 }, { reps: 8, weight: 24 }] },
    ],
  },
  {
    id: 'h3', date: '2026-09-08', label: '9月8日 · 周三',
    plan: '核心力量 · D1', duration: 2335,
    completedSets: 9, totalSets: 9, skippedSets: 0,
    exercises: [
      { name: '卷腹', sets: [{ reps: 20, weight: 0 }, { reps: 20, weight: 0 }, { reps: 18, weight: 0 }] },
      { name: '悬挂举腿', sets: [{ reps: 12, weight: 0 }, { reps: 12, weight: 0 }, { reps: 10, weight: 0 }] },
      { name: '平板支撑', sets: [{ reps: 60, weight: 0 }, { reps: 60, weight: 0 }, { reps: 45, weight: 0 }] },
    ],
  },
]

export const exerciseLibrary = [
  { id: 'ex1', name: '杠铃卧推', category: '胸部', equipment: '杠铃', recentWeight: '60 kg', recent: true },
  { id: 'ex2', name: '坐姿划船', category: '背部', equipment: '器械', recentWeight: '45 kg', recent: true },
  { id: 'ex3', name: '哑铃侧平举', category: '肩部', equipment: '哑铃', recentWeight: '12 kg', recent: true },
  { id: 'ex4', name: '引体向上', category: '背部', equipment: '自重', recentWeight: '体重', recent: false },
  { id: 'ex5', name: '绳索夹胸', category: '胸部', equipment: '绳索', recentWeight: '35 kg', recent: false },
  { id: 'ex6', name: '深蹲', category: '腿部', equipment: '杠铃', recentWeight: '80 kg', recent: false },
  { id: 'ex7', name: '硬拉', category: '背部', equipment: '杠铃', recentWeight: '100 kg', recent: false },
  { id: 'ex8', name: '哑铃弯举', category: '手臂', equipment: '哑铃', recentWeight: '16 kg', recent: false },
  { id: 'ex9', name: '三头下压', category: '手臂', equipment: '绳索', recentWeight: '25 kg', recent: false },
  { id: 'ex10', name: '腿举', category: '腿部', equipment: '器械', recentWeight: '120 kg', recent: false },
  { id: 'ex11', name: '坐姿肩推', category: '肩部', equipment: '哑铃', recentWeight: '24 kg', recent: false },
  { id: 'ex12', name: '平板支撑', category: '核心', equipment: '自重', recentWeight: '体重', recent: false },
]
