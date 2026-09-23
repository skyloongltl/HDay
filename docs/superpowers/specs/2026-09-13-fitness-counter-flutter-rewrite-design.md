# 健身计数 App Flutter 重写设计

## 1. 目标与边界

本设计指导 Android 首版 Flutter 重写。旧 Flutter 业务代码视为废弃，重新建立可测试的领域层、SQLite 持久化层和共享 UI 组件。首版覆盖 PRD 的 P0，并按阶段交付 P1；云同步、账号、多端、穿戴设备、复杂趋势分析属于后续版本。

设计依据：`docs/fitness-counter-app-prd.md`、`docs/fitness-counter-app-prototype-design.md`、`docs/superpowers/specs/2026-09-12-fitness-counter-ui-design.md`。

## 2. 架构

采用分层结构：

- `domain`：实体、值对象、周期计算、计划合并、训练状态机；纯 Dart，不依赖 Flutter 或 SQLite。
- `data`：SQLite schema、迁移、DAO、仓储实现；所有历史记录保存快照，不依赖当前动作库或计划。
- `application`：用例和状态控制器（今日摘要、计划编辑、开始/恢复/结束训练、主题设置）。
- `presentation`：Material 3 基础骨架、共享页面和组件；页面只读语义主题令牌。

状态管理统一采用 `ChangeNotifier + Provider` 的单向数据流：仓储由 Provider 注入，用例控制器暴露不可变视图状态，页面只调用命令方法。计时器由持久化 UTC 时间戳推导，前台 ticker 只负责刷新显示。导航使用根路由加沉浸式训练路由；训练、休息、总结页隐藏底部导航。

## 3. 数据模型

核心表及关键字段：

| 表 | 关键字段 |
|---|---|
| `exercises` | id、name（不允许完全同名）、defaultUnit、note、createdAt、updatedAt |
| `plans` | id、name、cycleDays(1..365)、startDate、executionMode、cycleCount、endDate、priority、enabled、createdAt、updatedAt |
| `plan_days` | id、planId、dayIndex、name、kind(training/rest)、sortOrder |
| `plan_day_exercises` | id、planDayId、exerciseId、nameSnapshot、sortOrder、note、targetRestSeconds |
| `plan_sets` | id、planDayExerciseId、setIndex、plannedWeight、weightUnit、plannedReps |
| `workout_sessions` | id、workoutDate、startedAt、endedAt、status、totalDurationSeconds、sourceSummary、note |
| `session_exercises` | id、sessionId、exerciseId、nameSnapshot、sourcePlanId/dayId、actualOrder、temporary、targetRestSeconds |
| `session_sets` | id、sessionExerciseId、setIndex、plannedWeight/reps/unit、actualWeight/reps、status、startedAt、completedAt、setDurationSeconds、preSetRestSeconds、temporary |
| `app_settings` | key、value；主题、默认单位、默认休息、提醒、震动、通知权限、一周起始日、常亮 |

所有日期使用本地日历日期，时间戳使用 UTC ISO/epoch；展示按设备时区。`workout_sessions.status` 至少包含 active、saved、discarded。训练快照在确认开始时一次性创建，之后计划/动作库变更不影响会话。

## 4. 核心规则与状态机

周期序号为 `((localDate - startDate).days % cycleDays) + 1`，只在启用且有效日期范围内计算；漏练不暂停、不顺延、不补课。日期范围到期立即停止，周期中途到期不补完。多计划按有效性排除休息日后，按 priority 降序及用户默认顺序合并，保留各计划内部动作/组顺序。

训练组状态：`pending -> inProgress -> completed`，或 `pending/inProgress -> skipped`。完成组后进入 `resting`；开始任一有效下一组、跳转其他未完成组或结束训练时结束休息，并把实际休息秒数写入下一组。达到目标只提醒，不自动开始下一组。

会话状态：`preparing -> active <-> resting -> finishing -> saved/discarded`。启动时若存在 active 会话，首页显示恢复卡片；恢复通过绝对时间戳重算总时长、组时长和休息时长。每次只允许一个 active 会话。

结束规则：结束并保存会将当前和剩余未开始组标为 skipped；至少完成一组才生成有效记录并计入健身日。未完成任何组不得保存有效场次。放弃必须二次确认并删除 active 会话快照。当天多场有效场次只计一个健身日。

## 5. 主题系统

定义 `AppThemeId`：`breathRhythm`（A，默认）、`trainingStickers`（B）、`nightInstrument`（C）。每套提供 `ThemeData` 和 `FitnessThemeExtension`，至少暴露 `workoutActive/completed/skipped/pending`、`restProgress`、`primaryAction`、`destructiveAction`、`surfacePrimary/elevated`、`outline`、`timerTextStyle`、`compactEndButtonStyle`。

页面和组件不得读取主题十六进制颜色；三套主题共享布局、文案、导航、触控区和状态语义。A 使用 `#C76F62` 主操作色，B 使用黄/紫/盖章红硬边语言，C 使用夜幕/蓝/荧光绿仪表语言。字体随包提供并按规格回退；系统字体缩放 1.3 倍不得裁切时长、重量、次数等关键数据。主题偏好本地保存，未知/损坏值回退 A，切换不重建或清除当前会话。

## 6. 页面与组件

底部导航固定为今日、计划、日历、动作；设置由今日右上角进入。共享组件包括 `AppScaffold`、`PageHeader`、`WorkoutSummaryCard`、`PlanDayList`、`ExerciseSetList`、`WorkoutSetTile`、`RestTimer`、`EndWorkoutSheet`、`ThemePreviewTile`。

- 今日：日期/设置、今日合并主卡、开始今日训练、自由训练、累计/周/月健身日、动作摘要；支持无计划、全休息、已有记录、未结束恢复等状态。
- 计划：列表及新建/编辑/复制/启停/删除；查询用纵向折叠周期日，编辑用横向 D1..DN 标签，支持动作和训练组增删排序及批量建组。
- 训练准备：显示来源计划/周期日、完整动作组清单，所有调整仅作用本次快照。
- 训练执行：顶部时长与“训练”标签、固定紧凑结束按钮、完成进度、完整组清单、底部组操作。
- 休息：目标/实际/倒计时、下一组和后续预览、选择其他组、结束休息并开始下一组；顶部标签改为“休息”。
- 总结/历史：完成/跳过统计、备注、保存/继续/放弃；月历区分训练结果和计划状态，日期详情及按动作折叠的快照详情支持修正和删除确认。
- 动作：搜索、最近使用、全部动作、新建/编辑、动作选择器；单位支持 kg、lb、自重、无重量。
- 设置：界面风格实时预览，以及默认单位、默认休息、提醒、震动、通知权限、一周起始日、屏幕常亮。

训练/休息顶栏“结束”可视约 38x20，透明命中区至少 48x48；“今日/训练/休息”与左侧辅助文字同字号同基线，不能重叠。

## 7. 错误处理与恢复

SQLite 写入失败时保留内存状态、显示可重试的非阻塞错误；关键动作成功只显示轻量保存状态。检测到系统时间倒退或异常跨度时暂停异常推导、不显示负时长，提示校准系统时间并保留最近有效快照。通知/震动权限缺失不阻断训练。主题资源失败回退 A。所有破坏性操作（放弃、删除历史/计划）二次确认。

## 8. 测试与验收

- 单元测试：周期序号、日期范围、漏练推进、多计划合并/休息排除、健身日计算、结束规则、时间异常。
- 状态机测试：每个组状态转移、休息结束触发、跳转/重排、恢复重算及单 active 会话约束。
- 仓储测试：SQLite 迁移、快照隔离、自动保存、删除与历史不变性。
- Widget/Golden：三主题今日/训练/休息关键页、五种首页态、四种组态、结束面板、字体 1.3 倍、360/430 宽度。
- 集成测试：开始至保存闭环、自由训练、锁屏/进程恢复模拟、主题切换重启持久化。

验收必须确认：可建 1..365 日计划和三种执行方式；自然日与日期范围规则正确；多计划合并正确；逐组计时/休息提醒/结束保存正确；历史快照独立；所有关键点击区>=48；减少动画设置生效。

## 9. 分阶段交付

1. 工程骨架、SQLite 迁移、领域模型、主题令牌和设置仓储。
2. 共享组件、四项导航、三主题预览与无障碍基础。
3. 今日首页及计划计算/合并、自由训练入口。
4. 准备、执行、休息、总结、自动保存和恢复闭环。
5. 计划完整编辑、动作库、日历和历史修正。
6. P1 打磨：统计、备注、训练中增删重排、常亮；完成回归、Golden、性能和发布验收。

每阶段均须保持可运行、可迁移、可回归；后续阶段不得复制主题页面或破坏已保存历史数据。
