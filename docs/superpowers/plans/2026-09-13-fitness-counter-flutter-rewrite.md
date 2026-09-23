# Fitness Counter Flutter Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Android Flutter 工程中重建可测试的健身计数领域、SQLite 持久化、训练闭环和三套主题 UI，覆盖设计文档定义的 P0，并为 P1 功能保留稳定接口。

**Architecture:** 以 `domain -> data -> application -> presentation` 分层，领域层为纯 Dart；SQLite 仓储只在 data 层实现并写入会话快照；Provider 注入仓储和用例，ChangeNotifier 控制器向页面暴露不可变状态。Material 3 页面通过 `FitnessThemeExtension` 读取语义令牌，根路由承载四项导航，训练/休息/总结使用沉浸式路由。

**Tech Stack:** Flutter/Dart（SDK 约束以 `app/pubspec.yaml` 为准）、Material 3、`provider`、`sqflite`、`path`、Flutter test/widget/Golden/integration test。

**Spec:** `docs/superpowers/specs/2026-09-13-fitness-counter-flutter-rewrite-design.md`

## Global Constraints

- 旧 Flutter 业务代码视为废弃，重新建立可测试的领域层、SQLite 持久化层和共享 UI 组件。
- 所有日期使用本地日历日期，时间戳使用 UTC ISO/epoch；展示按设备时区。
- 训练快照在确认开始时一次性创建，之后计划/动作库变更不影响会话。
- 每次只允许一个 active 会话；至少完成一组才生成有效记录，未完成任何组不得保存有效场次。
- 主题为 `breathRhythm`（默认）、`trainingStickers`、`nightInstrument`；未知/损坏值回退 A，切换不清除当前会话。
- 所有关键点击区至少 48x48；系统字体缩放 1.3 倍不得裁切时长、重量、次数。
- 破坏性操作（放弃、删除历史/计划）必须二次确认；SQLite 写入失败保留内存状态并提供非阻塞重试。
- 后续阶段不得复制主题页面或破坏已保存历史数据；每阶段必须可运行、可迁移、可回归。

## File Map

- `app/lib/domain/`: 实体、值对象、周期/合并规则、训练和会话状态机；无 Flutter/SQLite import。
- `app/lib/data/`: SQLite schema/migrations、DAO、仓储实现、快照映射。
- `app/lib/application/`: Provider、用例和不可变视图状态。
- `app/lib/presentation/`: Material 3 shell、页面和共享组件；只读取语义主题令牌。
- `app/lib/theme/`: `AppThemeId`、`FitnessThemeExtension`、三套 `ThemeData`、字体和设置绑定。
- `app/test/domain/`, `app/test/data/`, `app/test/application/`, `app/test/presentation/`: 分层单元/widget/golden 测试。
- `app/integration_test/`: 开始至保存、恢复和主题持久化闭环。

---

### Task 1: 工程骨架与领域模型

**Files:**
- Modify: `app/pubspec.yaml`, `app/lib/main.dart`
- Create: `app/lib/domain/entities.dart`, `app/lib/domain/value_objects.dart`, `app/lib/domain/rules.dart`, `app/lib/domain/workout_state_machine.dart`, `app/lib/domain/fakes.dart`
- Test: `app/test/domain/value_objects_test.dart`, `app/test/domain/rules_test.dart`, `app/test/domain/workout_state_machine_test.dart`

**Interfaces:**
- Produces immutable `Exercise`, `Plan`, `PlanDay`, `PlanDayExercise`, `PlanSet`, `WorkoutSession`, `SessionExercise`, `SessionSet` and enums for units/statuses.
- Produces `int? cycleNumber({required DateTime localDate, required DateTime startDate, required int cycleDays, DateTime? endDate, required bool enabled})`.
- Produces `List<PlannedExercise> mergePlans(List<PlanSnapshot> plans, DateTime localDate, int defaultPriorityOrder)`.
- Produces `WorkoutStateMachine.transition(WorkoutEvent event)` and rejects invalid transitions without mutating state.

- [ ] **Step 1: Write failing domain tests** covering cycle formula, date bounds, leap/day gaps, plan merge/rest exclusion, every set/session transition, and one-active-session invariant.
- [ ] **Step 2: Run tests to verify failure**

  Run: `cd app; flutter test test/domain -r expanded`

  Expected: FAIL because new domain types and functions do not exist.
- [ ] **Step 3: Implement pure Dart entities, value objects, rules, and state machine** with UTC/local conversion helpers and exhaustive transition validation.
- [ ] **Step 4: Run tests to verify pass**

  Run: `cd app; flutter test test/domain -r expanded`

  Expected: PASS with no Flutter or SQLite dependency in `app/lib/domain`.
- [ ] **Step 5: Commit**

  ```bash
  git add app/pubspec.yaml app/lib/main.dart app/lib/domain app/test/domain
  git commit -m "feat: add fitness domain model and workout state machine"
  ```

### Task 2: SQLite schema、迁移与快照仓储

**Files:**
- Create: `app/lib/data/schema.dart`, `app/lib/data/migrations.dart`, `app/lib/data/daos.dart`, `app/lib/data/repositories.dart`, `app/lib/data/database.dart`
- Test: `app/test/data/database_migration_test.dart`, `app/test/data/repository_snapshot_test.dart`, `app/test/data/repository_failure_test.dart`

**Interfaces:**
- `AppDatabase.open()` / `AppDatabase.close()` and `MigrationRunner.migrate(Database db, int oldVersion, int newVersion)`.
- `ExerciseRepository`, `PlanRepository`, `WorkoutRepository`, `SettingsRepository` interfaces; `WorkoutRepository.createSnapshot`, `saveSession`, `findActive`, `deleteActive`.
- `WorkoutRepository` maps every session field to a durable snapshot, including name/source/target-rest/temporary flags.

- [ ] **Step 1: Write failing migration and repository tests** for all tables/indices, idempotent migration, snapshot isolation after source edits, auto-save/update/delete, and injected SQLite write failure retaining caller state.
- [ ] **Step 2: Run tests to verify failure**

  Run: `cd app; flutter test test/data -r expanded`

  Expected: FAIL because schema and repositories are absent.
- [ ] **Step 3: Implement schema version 1 and migration runner** for `exercises`, `plans`, `plan_days`, `plan_day_exercises`, `plan_sets`, `workout_sessions`, `session_exercises`, `session_sets`, and `app_settings`; add foreign keys and ordering indices.
- [ ] **Step 4: Implement DAOs/repositories and transactional snapshot creation**; expose typed failures and do not overwrite in-memory state on write exceptions.
- [ ] **Step 5: Run data tests**

  Run: `cd app; flutter test test/data -r expanded`

  Expected: PASS, including reopen/reload assertions.
- [ ] **Step 6: Commit**

  ```bash
  git add app/lib/data app/test/data
  git commit -m "feat: add sqlite schema migrations and snapshot repositories"
  ```

### Task 3: 主题令牌、设置仓储与应用控制器

**Files:**
- Modify: `app/lib/theme/app_theme.dart`
- Create: `app/lib/theme/theme_ids.dart`, `app/lib/theme/fitness_theme_extension.dart`, `app/lib/application/providers.dart`, `app/lib/application/today_controller.dart`, `app/lib/application/plan_controller.dart`, `app/lib/application/workout_controller.dart`, `app/lib/application/settings_controller.dart`
- Test: `app/test/application/controller_test.dart`, `app/test/theme/theme_test.dart`

**Interfaces:**
- `AppThemeId.parse(String)` and `AppThemeId.storageValue`; `buildAppTheme(AppThemeId)` returns `ThemeData` containing `FitnessThemeExtension`.
- `TodayController.state`, `PlanController.state`, `WorkoutController.state`, `SettingsController.state` are immutable view states; commands return `Future<Result<void>>`.
- `WorkoutController.startFromPlan`, `startFreeWorkout`, `resume`, `completeSet`, `skipSet`, `startRest`, `endRest`, `finish`, `discard`.

- [ ] **Step 1: Write failing tests** for semantic token completeness/three theme differences, corrupted preference fallback, live theme switch without active-session loss, controller command/state emissions, and notification/vibration permission non-blocking behavior.
- [ ] **Step 2: Run tests to verify failure**

  Run: `cd app; flutter test test/application test/theme -r expanded`

  Expected: FAIL because controllers and token extension are missing.
- [ ] **Step 3: Implement theme IDs, extension, three Material 3 themes, and settings persistence**; pages will consume only extension fields.
- [ ] **Step 4: Implement Provider composition and controllers** around repository interfaces; derive timer values from persisted UTC timestamps and guard time rollback/large-span anomalies.
- [ ] **Step 5: Run tests to verify pass**

  Run: `cd app; flutter test test/application test/theme -r expanded`

  Expected: PASS.
- [ ] **Step 6: Commit**

  ```bash
  git add app/lib/theme app/lib/application app/test/theme app/test/application
  git commit -m "feat: add semantic themes settings and provider controllers"
  ```

### Task 4: 共享组件与四项导航页面

**Files:**
- Create: `app/lib/presentation/app_scaffold.dart`, `app/lib/presentation/widgets/page_header.dart`, `workout_summary_card.dart`, `plan_day_list.dart`, `exercise_set_list.dart`, `workout_set_tile.dart`, `rest_timer.dart`, `end_workout_sheet.dart`, `theme_preview_tile.dart`
- Create: `app/lib/presentation/pages/today_page.dart`, `plans_page.dart`, `calendar_page.dart`, `catalog_page.dart`, `settings_page.dart`
- Modify: `app/lib/shell/app_shell.dart`, `app/lib/main.dart`
- Test: `app/test/presentation/shared_widgets_test.dart`, `app/test/presentation/navigation_test.dart`, `app/test/presentation/goldens/*.dart`

**Interfaces:**
- Widgets accept domain/view-state data and callbacks; no direct repository access or hex colors.
- `AppScaffold(selectedIndex, onDestinationSelected, body)` supplies fixed 今日/计划/日历/动作 navigation and a settings action.
- `WorkoutSetTile` exposes compact end-button hit target >=48x48; `RestTimer` accepts target/elapsed/remaining and pause anomaly state.

- [ ] **Step 1: Write failing widget tests** for navigation, five Today states (no plan/rest/record/recovery/mixed), four set states, 48x48 hit regions, and text scale 1.3 at widths 360/430.
- [ ] **Step 2: Run widget tests to verify failure**

  Run: `cd app; flutter test test/presentation/shared_widgets_test.dart test/presentation/navigation_test.dart -r expanded`

  Expected: FAIL because the new widgets/pages are absent.
- [ ] **Step 3: Implement shared components and shell** using only semantic theme extension fields, stable dimensions, baseline-aligned top labels, and accessible labels/tooltips.
- [ ] **Step 4: Implement Today/Plans/Calendar/Catalog/Settings page shells** wired to controllers, including empty/loading/error/retry states.
- [ ] **Step 5: Run widget tests and generate Goldens**

  Run: `cd app; flutter test test/presentation -r expanded --update-goldens`

  Expected: PASS; review generated images for all three themes and both widths, then rerun without `--update-goldens`.
- [ ] **Step 6: Commit**

  ```bash
  git add app/lib/presentation app/lib/shell/app_shell.dart app/lib/main.dart app/test/presentation
  git commit -m "feat: add shared material shell and primary navigation pages"
  ```

### Task 5: 训练准备、执行、休息、总结与恢复闭环

**Files:**
- Create: `app/lib/presentation/pages/workout_prepare_page.dart`, `workout_active_page.dart`, `workout_rest_page.dart`, `workout_summary_page.dart`
- Modify: `app/lib/application/workout_controller.dart`, `app/lib/presentation/app_scaffold.dart`
- Test: `app/test/application/workout_flow_test.dart`, `app/test/presentation/workout_pages_test.dart`, `app/integration_test/workout_flow_test.dart`

**Interfaces:**
- Route arguments carry only `sessionId`; pages read immutable `WorkoutViewState` from `WorkoutController`.
- `WorkoutController` persists after every set/rest transition, restores one active session, and computes duration from timestamps.

- [ ] **Step 1: Write failing state/widget/integration tests** for plan/free start, snapshot isolation, complete/skip/rest/jump/reorder, auto-save, finish-save/discard rules, recovery after process restart, and no-negative-duration clock rollback.
- [ ] **Step 2: Run focused tests to verify failure**

  Run: `cd app; flutter test test/application/workout_flow_test.dart test/presentation/workout_pages_test.dart -r expanded`

  Expected: FAIL until flow pages and controller persistence are implemented.
- [ ] **Step 3: Implement controller persistence and immersive routes** for preparing -> active/resting -> finishing -> saved/discarded; mark remaining groups skipped on save and require second confirmation on discard.
- [ ] **Step 4: Implement four flow pages** with fixed compact 38x20 visible end affordance/48x48 hit area, progress, next-set preview, rest countdown, notes, and save/continue/discard actions.
- [ ] **Step 5: Run all automated flow tests**

  Run: `cd app; flutter test test/application test/presentation -r expanded`

  Expected: PASS.
- [ ] **Step 6: Run Android integration test**

  Run: `cd app; flutter test integration_test/workout_flow_test.dart -d emulator-5554`

  Expected: PASS from start through saved history and simulated restart recovery.
- [ ] **Step 7: Commit**

  ```bash
  git add app/lib/application/workout_controller.dart app/lib/presentation app/test app/integration_test
  git commit -m "feat: implement workout execution rest and recovery flow"
  ```

### Task 6: 完整计划编辑、动作库、日历历史与 P1 打磨

**Files:**
- Modify: `app/lib/application/plan_controller.dart`, `app/lib/application/today_controller.dart`
- Create: `app/lib/presentation/pages/plan_editor_page.dart`, `plan_detail_page.dart`, `exercise_editor_page.dart`, `history_detail_page.dart`
- Modify: `app/lib/presentation/pages/plans_page.dart`, `calendar_page.dart`, `catalog_page.dart`, `settings_page.dart`
- Test: `app/test/application/plan_editor_test.dart`, `app/test/presentation/history_calendar_test.dart`, `app/test/presentation/accessibility_golden_test.dart`, `app/integration_test/theme_persistence_test.dart`

**Interfaces:**
- Plan commands support `create(cycleDays: 1..365)`, `copy`, `enable`, `disable`, `delete`, `addDay`, `reorderDay`, `addExercise`, `batchAddSets`, `reorderSet` and three execution modes.
- Catalog commands support search/recent/all, unit selection (`kg`, `lb`, bodyweight, none), create/edit, and selector results.
- History detail exposes immutable session snapshot, correction/delete commands with confirmation; calendar distinguishes workout result and plan status.

- [ ] **Step 1: Write failing tests** for 1..365 validation, execution modes, CRUD/reordering/batch sets, catalog units/search/recent, calendar markers, snapshot correction/delete confirmation, reduced-motion/always-on settings, and theme persistence after restart.
- [ ] **Step 2: Run focused tests to verify failure**

  Run: `cd app; flutter test test/application/plan_editor_test.dart test/presentation/history_calendar_test.dart -r expanded`

  Expected: FAIL before editor/catalog/history implementations exist.
- [ ] **Step 3: Implement plan editor/detail and controller commands** with vertical query folding and horizontal D1..DN editing while preserving internal order.
- [ ] **Step 4: Implement catalog/editor/selector and history/calendar correction flows** backed by repositories and immutable snapshots.
- [ ] **Step 5: Implement settings for default unit/rest, reminders, vibration, notification permission, week start, reduced motion, and screen always-on** without blocking training when permissions are absent.
- [ ] **Step 6: Run complete verification suite**

  Run: `cd app; flutter analyze; flutter test; flutter test integration_test -d emulator-5554`

  Expected: analyzer clean, unit/widget/golden/integration tests PASS; inspect Goldens at text scale 1.3 and 360/430 widths.
- [ ] **Step 7: Commit**

  ```bash
  git add app/lib app/test app/integration_test
  git commit -m "feat: complete plan catalog history and accessibility polish"
  ```

## Self-Review Checklist

- [ ] Cycle/date-range/leak-through rules map to Task 1 tests.
- [ ] All schema tables, migrations, snapshot isolation and failure recovery map to Task 2 tests.
- [ ] Three themes, semantic tokens, persistence and fallback map to Task 3 and Task 6 tests.
- [ ] Shared components, navigation, five home states, four set states, hit areas and font scaling map to Task 4 tests.
- [ ] Start/free/resume, set/rest state machine, auto-save, finish/discard and clock anomalies map to Task 5 tests.
- [ ] Plan CRUD, catalog, calendar/history correction, settings and P1 polish map to Task 6 tests.
- [ ] Every step names concrete files, interfaces, validation/error behavior, and executable verification.
