# 缺失页面清单 & 补全计划

## Context

当前已实现 12 个屏幕，覆盖了核心训练流程。但对照 `fitness-counter-app-prd.md`，仍有若干完整页面、弹层和关键 inline 状态尚未实现。本计划列出所有缺口并给出优先级与实现路径。

---

## 缺口分析

### A. 缺失的完整页面（Full Screens）

| 缺失页面 | PRD 章节 | 说明 |
|---|---|---|
| `CreateEditPlanScreen` | §8.2 §8.3 §8.5 | 新建/编辑计划的表单页：名称、周期天数 N、起始日期、执行模式（无限循环 / 固定次数 / 日期范围）、优先级、启用开关。当前 `PlanEditScreen` 只做了周期日动作配置，缺计划元信息表单。 |
| `DayDetailScreen` | §13.2 §13.3 §13.4 | 日历点击某天后的独立详情页：多场次展示、每组实际数据、可编辑备注/实际重量次数、删除场次（含末场次特殊警告）。当前 `CalendarScreen` 只嵌入了摘要卡，未做完整详情页。 |
| `FreeWorkoutScreen`（或 PreWorkoutScreen 自由训练模式） | §7.2 §8.8 §10 | PRD 明确将"自由训练"列为 P1 功能：休息日或无计划时，从首页进入一个空白训练前清单，用户手动添加动作后开始训练。当前 `PreWorkoutScreen` 固定读取 `todayExercises`，无法进入空白模式。 |

---

### B. 缺失的模态/弹层（Modals & Bottom Sheets）

| 缺失组件 | PRD 章节 | 说明 |
|---|---|---|
| `ExercisePickerSheet` | §8.5 §10 | 在计划周期日编辑和训练前清单中点击"添加动作"时弹出，包含搜索 + 全库列表 + 新建动作入口。当前两处"添加动作"按钮均为无操作。 |
| `InWorkoutAdjustmentSheet` | §11.7 | 训练中"修改数据 / 跳过本组 / 添加组"底部弹层：修改实际重量次数、添加/删除未开始组、跳过整个动作、添加临时动作。当前三个 tiny-action 按钮均为 no-op。 |
| `BatchCreateSetsDialog` | §8.7 | 计划周期日编辑中批量创建训练组的对话框（组数 + 计划重量 + 次数）。 |
| `NewEffectiveDateDialog` | §8.10 | 修改已有计划的周期天数 N 时，要求用户指定新的生效日期（新的第 1 天）。 |
| `DeletePlanConfirmDialog` | §8.1 | 删除计划时的二次确认（明确告知不删除历史记录）。 |

---

### C. 现有页面缺失的关键 Inline 状态

| 页面 | 缺失状态 | PRD 章节 |
|---|---|---|
| `HomeScreen` | **全部计划均为休息日**：隐藏训练卡，改为"今日休息"提示 + "开始自由训练"入口 | §7.2 §8.8 |
| `HomeScreen` | **无有效计划**：空状态引导用户创建第一个计划 | §7.1 |
| `WorkoutScreen` | **组状态细化**：当前只有 pending/current/done/skipped，缺"进行中"（组计时运行中，Start→Complete 两步）完整实现 | §11.2 |
| `WorkoutSummaryScreen` | **零完成组状态**：不允许保存为有效健身日，仅展示"放弃"操作 | §12 |
| `CalendarScreen` | **5 种日期格状态**：当前只区分完成/计划/普通，缺"未结束场次"和"有计划但未打卡"两种样式 | §13.1 |
| `ExerciseLibraryScreen` | **空库状态** + **搜索无结果状态** | §9.1 |
| `PlanScreen` | **空计划列表状态** | §8.1 |

---

## 实现计划

### 优先级 P1 — 核心流程缺口

**1. `CreateEditPlanScreen.tsx`**（新文件）
- 路由：push `createPlan` / push `editPlan`
- 字段：计划名称（TextField）、周期天数 N（数字输入）、执行模式（SegmentedControl：无限/固定次数/日期范围）、条件字段（循环次数 or 结束日期）、优先级（可选）、启用开关
- 保存后回到 `PlanScreen`，触发列表刷新
- 复用：`SettingsScreen` 的 `Toggle` 组件模式；`PlanEditScreen` 的 AppBar 模式

**2. `DayDetailScreen.tsx`**（替换/扩展现有占位）
- 当前 `CalendarScreen` 中的"查看完整记录"卡片已经有 push `historyDetail` 的跳转，需将 `HistoryDetailScreen` 扩展为真正的 Day Detail：支持多场次、备注编辑、实际数据修改、删除场次
- 路由保持 `historyDetail`（已有），扩展现有 `HistoryDetailScreen.tsx`

**3. 自由训练入口**（修改现有文件）
- `HomeScreen.tsx`：在休息日/无计划状态下显示"开始自由训练"按钮，push `preWorkout` 并传 `{ freeWorkout: true }`
- `PreWorkoutScreen.tsx`：读取 `params.freeWorkout`，若为 true 则以空动作列表启动，顶部提示改为"自由训练"
- 同步补全 HomeScreen 的"全部休息日"和"无计划"两个 inline 状态

### 优先级 P2 — 高频弹层

**4. `ExercisePickerSheet.tsx`**（新组件）
- 复用 `ExerciseLibraryScreen` 的搜索 + 列表结构，以 bottom sheet 形式呈现
- 接受 `onSelect(exercise)` 回调，选中后关闭 sheet 并将动作插入调用方列表
- 被 `PreWorkoutScreen` 和 `PlanEditScreen` 共用

**5. `InWorkoutAdjustmentSheet.tsx`**（新组件）
- 替换 `WorkoutScreen` 中三个 no-op tiny-action 按钮的目标
- 内容：修改当前组实际重量/次数（数字输入）、跳过本组、添加一组、跳过本动作剩余组、添加临时动作（调用 ExercisePickerSheet）

### 优先级 P3 — 状态补全（修改现有文件）

**6. 现有页面 inline 状态补全**
- `HomeScreen.tsx`：添加休息日状态 + 无计划空状态
- `WorkoutSummaryScreen.tsx`：添加零完成组状态（隐藏"保存"，只留"放弃"）
- `CalendarScreen.tsx`：补充 5 种日期格样式
- `ExerciseLibraryScreen.tsx`：空库 + 搜索无结果状态
- `PlanScreen.tsx`：空列表状态

---

## 关键文件

| 文件 | 操作 |
|---|---|
| `src/screens/CreateEditPlanScreen.tsx` | 新建 |
| `src/screens/HistoryDetailScreen.tsx` | 扩展（多场次、编辑、删除） |
| `src/screens/HomeScreen.tsx` | 修改（休息日/无计划状态） |
| `src/screens/PreWorkoutScreen.tsx` | 修改（freeWorkout 模式） |
| `src/screens/WorkoutSummaryScreen.tsx` | 修改（零完成组状态） |
| `src/screens/CalendarScreen.tsx` | 修改（5 种日期格） |
| `src/screens/ExerciseLibraryScreen.tsx` | 修改（空/无结果状态） |
| `src/screens/PlanScreen.tsx` | 修改（空列表状态） |
| `src/components/ExercisePickerSheet.tsx` | 新建 |
| `src/components/InWorkoutAdjustmentSheet.tsx` | 新建 |
| `src/navigation.tsx` | 新增 `createPlan` / `editPlan` ScreenKey |

---

## 验证

1. `npx tsc --noEmit` — 零错误
2. 浏览器预览 → 首页切换到"无计划"状态 → 显示引导空状态
3. 首页"开始自由训练" → PreWorkoutScreen 为空列表 → 手动添加动作 → 进入训练流程
4. 计划页"＋" → CreateEditPlanScreen 三种执行模式均可切换 → 保存回计划列表
5. 日历点击有记录的日期 → DayDetailScreen 展示完整组数据 + 备注可编辑
6. WorkoutScreen "修改数据" → InWorkoutAdjustmentSheet 弹出 → 修改后数据更新
7. 训练前清单"＋ 临时添加动作" → ExercisePickerSheet 弹出 → 选中动作加入列表
