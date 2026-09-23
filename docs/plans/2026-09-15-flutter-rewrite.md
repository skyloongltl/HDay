# Fitness Counter Android Flutter Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从空 SQLite 库交付 Android 健身计划、动作、训练、恢复、提醒、历史修正和 Figma 14 页的完整可用闭环。

**Architecture:** Riverpod + GoRouter，按 exercises/plans/today/workout/history/settings 分 feature；每个 feature 拥有 pure Dart domain、typed repository、SQLite data implementation、Riverpod application/controller、Flutter presentation。SQLite 是唯一事实源，immutable state 是已提交数据及显式未保存编辑的投影；平台服务通过 Clock、NotificationGateway、VibrationGateway、WakeLockGateway、ThemePackageSource 注入。计划采用稳定 identity + 有效日期 revision；训练采用独立快照与可持久化分段计时。

**Tech Stack:** Flutter/Dart、flutter_riverpod、go_router、sqflite、sqflite_common_ffi（主机测试）、path、flutter_local_notifications、timezone、vibration、wakelock_plus、Flutter test/integration_test；依当前 Flutter SDK 解析兼容版本并提交 pubspec.lock，不为使用新 API 无依据提升平台门槛。

**Spec:** `C:/Code/HDay/docs/fitness-counter-app-prd.md`、`C:/Code/HDay/docs/fitness-counter-app-prototype-design.md`、`C:/Code/HDay/figma app/src/tokens.ts`、`C:/Code/HDay/figma app/src/screens/*.tsx`、`C:/Code/HDay/figma app/src/components/*.tsx`、`C:/Code/HDay/figma app/src/App.tsx`、navigation.tsx、workoutStore.tsx、index.css，以及 `C:/Code/HDay/app_pages/`。本文件 Global Constraints 记录 2026-09-15 用户已确认决策，冲突时这些决策优先。

## Global Constraints

- 首发仅 Android；做完整功能闭环，不是 UI-only；Flutter 可从头重构，旧模型/页面/测试可替换；SQLite 唯一事实源，无需迁移现有数据，初始空库不 seed 动作或计划。
- 范围是 PRD 与 Figma 页面并集。14 个 React 页面都应有对应 Flutter 工作流。动作分类/器械是持久化且可筛选字段。分类：胸部、背部、肩部、腿部、手臂、核心、全身、有氧；器械：自重、杠铃、哑铃、器械、绳索、壶铃、弹力带。
- Riverpod + GoRouter；feature-first：exercises/plans/today/workout/history/settings，每个含 pure Dart domain、typed repository、SQLite implementation、Riverpod application/controllers、Flutter presentation。平台抽象 Clock/NotificationGateway/VibrationGateway/WakeLockGateway/ThemePackageSource。
- 计划是稳定 Plan identity + 按生效日期的 PlanRevision；改变周期长度必须新生效日期，新 revision 从 D1 开始。
- 通知和振动独立，可都关闭；Android 为及时休息通知申请 exact alarm 权限。
- 最后一组完成进入 completedPaused，总训练计时暂停；用户选择结束或添加训练；编辑新增训练不计时；真正开始新增组时恢复计时。计时模型=累计 active seconds + 当前 running segment timestamp。负 elapsed 或单段超过 24h 进入 time-anomaly 状态。保存训练后进入该日期历史详情。
- 视觉：高保真复刻 Figma，Android 响应式。遵守 AGENTS：widget 文件无魔法视觉数值/字符串，集中 token/theme，显式状态/导航，结构便于机械映射。
- 主题：首发仅 breath-rhythm，但未来数量不设上限，严禁 enum 或 A/B/C 分支。主题可改 tokens 与共享组件 skin，不改页面信息架构/业务流程。内置主题随 app；未来支持离线导入，仅数据包无可执行 Dart。本版只预留 ThemeId(string)、ThemeManifest、AppThemeDefinition、ThemeRegistry、semantic ThemeExtension、ThemePackageSource 及 schema/contracts，不做导入安装 UI。
- 最终验收至少：flutter analyze、完整 flutter test、Android integration tests、Android release APK build；并做真实 Android 响应式/关键页面视觉比对。若依赖下载网络失败，在同一终端设置 HTTP_PROXY=http://127.0.0.1:7897、HTTPS_PROXY=http://127.0.0.1:7897（必要时小写变量）重试，并记录证据。
- 必须 TDD：每项行为先写失败测试并保留 red/green 命令输出证据。实现任务后须独立规格+质量审查。
- 周期长度 1～365；三种执行方式为无限循环、完整循环次数、包含首尾日期的日期范围；按本地自然日推进，漏练不顺延。相同优先级按 defaultOrder 合并，再保留计划内动作/组顺序。
- 单一未结束场次包含 active、resting、completedPaused、finishing、timeAnomaly；至少一个 completed 组才可保存，同日多场只算一个健身日。修改/删除源计划或动作不改训练快照。
- UTC 时间戳持久化；训练日期固定为开始时本地日历日期，跨午夜不迁移场次归属。前台用单调时钟平滑刷新，跨进程用 UTC checkpoint 校验；无负时长，无静默大跨度截断。
- Flutter visual 常量、动画参数和中文文案集中；所有 widget 文件通过 AppTheme.of(context)/常量访问。保留 React 的局部交互 state 名称，domain 衍生态不伪造成可独立修改状态。
- 四个底部入口：今日、计划、日历、动作；设置由今日进入；准备/训练/休息/总结隐藏 BottomNav；训练/休息右上角结束始终可见。触控区至少 48 logical px，视觉图形可更小；宽 360/390/430、字体倍率 1.0/1.3 无关键内容裁切；SafeArea 只处理一次。
- 删除计划/动作/历史、放弃训练均需产品内二次确认；数据库写失败保留已输入编辑并给出重试，禁止把失败更新显示为已持久化成功。不得执行清理原用户数据的命令。
- 工作目录 `C:/Code/HDay/.worktrees/flutter-rewrite-20260915`，分支 `codex/flutter-rewrite-20260915`。权威未跟踪 Figma/截图/AGENTS 仅从原工作区只读，禁止提交原工作区用户修改。
- 主代理只派发、审阅与裁决；产品实现、修复、计划与 ledger 写入由受派代理完成。每项实现代理不再派生代理，完成后由主代理派独立 task reviewer（同时给出 spec 与 quality verdict）。

## Authority, prior work, and rulings

起始原仓库 SHA：`94da81d41da015452405cf1907e112010660c552`。隔离基础 SHA：`b2efc36eea89644537ae553e2204c1870bb4321f`（仅新建 `.worktrees/.gitignore`）。旧 `docs/superpowers/plans/2026-09-13-fitness-counter-flutter-rewrite.md`、旧 UI 对齐计划与旧 SDD 报告属于此前 Provider/三主题方案；保留但不恢复其任务完成状态。

| 冲突 | 本次约束 | 执行方式 |
|---|---|---|
| 旧 Provider/ChangeNotifier、分技术层目录、主题 enum | 用户确认 Riverpod、feature-first、ThemeId string | Task 1 建新骨架；旧行为测试有用断言移植，不维持旧类型兼容层 |
| PRD/旧代码总时间一直运行，Figma active store 丢进程 | 用户确认 completedPaused + active segments | Task 3/8 唯一计时算法；UI ticker 不能写业务时间 |
| Figma Summary 保存回首页 | 用户确认保存进日期历史 | Task 9/11 路由 `/history/:date`，传训练日期 |
| Figma HistoryDetail 注释只读 | PRD 要求修正实际重量/次数/备注 | 保持卡片展示，增加明确编辑 sheet；不修改计划快照 |
| Figma 动作详情含个人最佳/趋势，PRD列P2 | 用户确认并集 | Task 11 做简单实际数据趋势、个人最佳、历史，不扩展复杂分析 |
| Figma Settings A/B/C 三主题 | 用户确认仅 breath-rhythm 可扩展 registry | 展示 registry 的实际条目，仅一个可选；无导入安装 UI |
| React 局部硬编码、虚构日期/数据、phone frame、StatusBar | tokens + 真实数据 + Android | 提取缺少的 tokens/copy；移除浏览器手机框和模拟系统栏；空库真实 empty states |
| 某些 React 注释提到 AnimatedContainer/AnimatedScale，但未注明 implicit | AGENTS 不允许未经注明的 implicit animation | 以明确 AnimationController/Tween 实现同一时长曲线；仅明确允许时采用 implicit |
| PRD 数据库须支持版本迁移 | 用户无需迁移现有数据 | 新数据库文件 `fitness_counter_v2.db`，schema version=1 + 可扩展 onUpgrade；不读取/删除旧库，不写旧数据迁移测试 |

## File ownership and stable contracts

`app/lib/main.dart` 只 bootstrap。`app/lib/app/app.dart`、`router.dart`、`providers.dart` 负责组合根；`app/lib/core/domain/` 仅共享值/错误/时间，`core/data/app_database.dart` 仅数据库打开/事务，`core/platform/` 仅 gateways。`app/lib/theme/app_theme.dart` 为全部视觉 API 入口，theme 子文件为 registry、manifest、extension、built-in 数据。`app/lib/l10n/app_strings.dart` 统一中文与格式化。`app/lib/widgets/` 放 AppScaffold、AppBar、BottomNav、AppCard、ListTile、SetRow、RestRing、ProgressBar、确认 sheet 等共享 Flutter 语义组件。

每个 feature 目录使用 `domain/`、`data/`、`application/`、`presentation/`。domain repository 只返回强类型数据，不暴露 sqflite Map/Database。允许 today/history 的 SQLite implementation 做组合查询，不要求为派生 projection 造冗余持久化表。

所有接口的 ID 暂用非空 `String`；时间 UTC `DateTime`；日历 `LocalDate(year, month, day)`，`iso8601` 返回 `YYYY-MM-DD`。错误 `AppFailure(FailureCode code, {String? detail})`；业务失败使用 typed exception，controller 捕获到 `CommandState(isSaving, failure)`。数据写成功才替换 committed projection；待重试 draft 单独保留。代码步骤中列出的最小测试是起点，同一任务列出的每个验收行为均需独立 red/green。

| Task | Primary owned files | Dependencies |
|---|---|---|
| 1 | bootstrap/theme/strings/shared shell | none |
| 2 | exercises/plans domain、LocalDate、settings domain | 1 |
| 3 | workout domain/timing | 2 |
| 4 | schema + all typed SQLite repositories | 2,3 |
| 5 | exercises controller/library/editor/picker | 4 |
| 6 | plans controller/list/base/day editor | 4,5 |
| 7 | today projections/controller、preparation editor | 4,5,6 |
| 8 | durable workout controller/recovery | 3,4,7 |
| 9 | workout/rest/summary presentation | 1,5,8 |
| 10 | Android gateways + rest effects | 8,9 |
| 11 | history/calendar/exercise detail | 4,6,9 |
| 12 | settings controller/presentation/theme preference | 4,10,11 |
| 13 | complete 14-screen visual/navigation audit | 5–12 |
| 14 | Android integration/release evidence | 13 |

实施串行，每个 Task 一个新 implementer 和独立 reviewer。允许审阅/输入盘点并行，但不同时写实现代码。共享文件修改只允许表中的依赖后任务，所有非接口兼容改动先向主代理报告并录入 ledger。

## TDD and evidence protocol (included in every task)

从 `app/` 运行 Flutter 命令。每个行为按以下顺序：写实际失败断言 → 执行 focused test 确认因目标行为缺失失败（编译失败仅用于新 API 首次建立，随后至少看到行为断言失败）→ 最小实现 → focused test 通过 → 必要重构 → 再测涉及代码。不得先实现后伪造 RED。把命令、exit code、关键输出和对应源码 SHA 写入本计划 workspace 的 task-N-report.md；命令原始输出存 task-N-red.log / green.log，可用测试命令的 `Tee-Object` 采集，这是命令输出记录，不是手写报告替代 apply_patch。

```powershell
flutter test test/theme/theme_registry_test.dart -r expanded 2>&1 |
  Tee-Object -FilePath '../.superpowers/sdd/2026-09-15-flutter-rewrite/task-1-red.log'
$LASTEXITCODE
```

没有网络失败时不要无故改代理。若依赖下载失败，在失败命令同一次 shell invocation 中设置并重试，记录两次结果：

```powershell
$env:HTTP_PROXY='http://127.0.0.1:7897'
$env:HTTPS_PROXY='http://127.0.0.1:7897'
$env:http_proxy=$env:HTTP_PROXY
$env:https_proxy=$env:HTTPS_PROXY
flutter pub get
```

每 task 结束运行其 focused tests、`flutter analyze`；改动影响现有跨 feature 契约时运行对应依赖测试，提交前完整 `flutter test` 一次。提交时只 `git add --` 本任务文件，不使用 `git add .`；报告 BASE/HEAD。reviewer 收 brief、report、BASE..HEAD diff package，不重跑无新疑点的同一测试。最终 Task 14 完整重验。

---

### Task 1: 可运行的 Riverpod/GoRouter 骨架与可扩展主题

**Files:**
- Rewrite: `app/pubspec.yaml`, `app/pubspec.lock`, `app/lib/main.dart`, `app/analysis_options.yaml`。
- Replace legacy tracked `app/lib/` 与 `app/test/` 的旧架构（仅本隔离树）。先在报告列出 `git ls-files app/lib app/test`，保留可复用行为断言到对应新测试；不保留 Provider/theme enum 双实现。
- Create: `app/lib/app/{app,router,providers}.dart`, `app/lib/theme/{app_theme,theme_id,theme_manifest,app_theme_definition,theme_registry,fitness_theme_extension,breath_rhythm}.dart`, `app/lib/core/platform/theme_package_source.dart`, `app/lib/l10n/app_strings.dart`, `app/lib/widgets/{app_scaffold,app_card,app_bar,bottom_nav}.dart`。
- Create: `app/lib/features/{today,plans,history,exercises}/presentation/{home_screen,plan_screen,calendar_screen,exercise_library_screen}.dart`（各目录只创建对应单个文件）。初始为真实无数据状态，后续任务接 repository；禁止虚构样例记录。
- Create: `app/test/theme/theme_registry_test.dart`, `app/test/app/navigation_test.dart`, `app/test/support/pump_app.dart`, `app/assets/themes/breath-rhythm/manifest.json`, `app/assets/themes/theme-package.schema.json`。

**Interfaces:**
- `ThemeId(String value)`：immutable value equality，`const ThemeId('breath-rhythm')` 为唯一 built-in identity；不限定未来 ID 集合。
- `ThemeManifest({required ThemeId id, required String name, required int schemaVersion, required String version})`；`AppThemeDefinition({required ThemeManifest manifest, required Map<String, Object?> tokens, required Map<String, Object?> skins})`。
- `ThemeRegistry(Iterable<AppThemeDefinition> definitions)`；`List<AppThemeDefinition> get available`；`AppThemeDefinition resolve(ThemeId? id)` 未知 ID 回退 breath-rhythm，duplicate ID 或无默认定义明确抛格式错误。
- `abstract interface class ThemePackageSource { Future<List<AppThemeDefinition>> load(); }`；本版 `BundledThemePackageSource` 只解析包内 JSON。schema 指定 manifest/tokens/skins、必需语义 token、拒绝未知 executable/script 字段，不实现安装/解压/UI。
- `AppTheme.of(BuildContext)` 返回 `FitnessThemeExtension`；`AppTheme.build(AppThemeDefinition)` 返回 `ThemeData`。font/colors/spacing/radius/shadow/border/minTap/animation/dimensions/opacity 都集中。`AppStrings` 集中 copy/formatters。
- `FitnessCounterApp({required GoRouter router})`；`createRouter()` 用 `/home` `/plan` `/calendar` `/exercises` 四 tab。后续路由新增到同一 router，无第二 Navigator 状态源。

- [ ] **Step 1: 先读全部权威 React 输入与 AGENTS**，将 token 补全项、PAGE state 与 navigation 对应写到报告；建立失败测试：

```dart
test('arbitrary future theme id resolves by registry without enum', () {
  final registry = ThemeRegistry([breathRhythmDefinition]);
  expect(registry.resolve(const ThemeId('future-pack')).manifest.id,
      const ThemeId('breath-rhythm'));
  expect(registry.available.single.tokens['colors.coral'], '#C76F62');
});
```

再断言 primary/coral `#C76F62`、page `#F4F7FA`、hero `#19344C`、mint `#62E6CA`，四 tab 正确切换、设置入口位置、一次 SafeArea，schema 缺 token/重复 ID/可执行字段拒绝。不要写只断言 `isNotNull` 的 registry 测试。
- [ ] **Step 2: RED**：`flutter test test/theme/theme_registry_test.dart test/app/navigation_test.dart -r expanded`；记录失败。
- [ ] **Step 3: 最小实现**：加入 Riverpod/GoRouter，移除 provider；实现上面类型与 JSON 解析、四 tab 空状态、共享 shell。读取 tokens.ts 的所有值，补全 React 中缺少的语义 dimensions 到 theme；初始主题装载失败要显示可重试错误，不静默构造假的用户数据。

```dart
final class ThemeId {
  final String value;
  const ThemeId(this.value);
  @override bool operator ==(Object other) => other is ThemeId && other.value == value;
  @override int get hashCode => value.hashCode;
}
```

- [ ] **Step 4: GREEN**：同一 focused command + `flutter analyze` + `flutter test`。审阅 360/430 逻辑宽、1.3 字体的 empty shell；保留宽/高 token，不把 390 browser phone frame 套进 Flutter。
- [ ] **Step 5: Commit**：明确 stage 本任务新/替换文件，`git commit -m "feat: establish riverpod shell and extensible breath rhythm theme"`；report 列出被替换的旧测试与对应新行为归属。

**Acceptance:** 可启动的四 tab 空应用；无 seed，无 Provider，无 theme enum/A-B-C；theme contract 可接受任意新 ID；schema/完整 tokens/shared skins 边界可测试；无导入 UI。Task 2–14 完成前不宣称产品已完整。

### Task 2: 动作、PlanRevision、自然日与设置领域契约

**Files:**
- Create: `app/lib/core/domain/{local_date,app_failure,clock}.dart`。
- Create: `app/lib/features/exercises/domain/{exercise,exercise_repository}.dart`。
- Create: `app/lib/features/plans/domain/{plan,plan_revision,plan_day,plan_schedule,plan_repository}.dart`。
- Create: `app/lib/features/settings/domain/{app_settings,settings_repository}.dart`。
- Test: `app/test/features/plans/domain/plan_schedule_test.dart`, `app/test/features/exercises/domain/exercise_test.dart`, `app/test/support/catalog_fixtures.dart`。

**Interfaces:**
- `Clock.nowUtc()`、`Clock.monotonicElapsed`（Duration）、`Clock.today()`（LocalDate）；`SystemClock` 实现留 Task 8；domain 不 import Flutter/sqflite。
- `Exercise({id,name,category,equipment,defaultUnit,note,createdAt,updatedAt})`（required 命名参数）；`WeightUnit {kg,lb,bodyweight,none}`。分类/器械 value 采用稳定 code + AppStrings label（上述精确集合）。trim 后名称非空，完全同名拒绝，重量有限且 >=0，次数整数 >=1，目标休息 >=0。
- `Plan({id,name,enabled,priority,defaultOrder,createdAt,updatedAt})` stable identity；`PlanRevision({id,planId,effectiveFrom,cycleAnchorDate,cycleDays,mode,cycleCount,endDate,days})`；`PlanMode {infinite,cycles,dateRange}`；`PlanDay({id,dayNumber,name,isRest,exercises})`；`PlanExercise({id,exerciseId,nameSnapshot,note,targetRestSeconds,order,sets})`；`PlanSet({id,order,plannedWeight,unit,plannedReps})`。集合 defensive-copy + unmodifiable。
- `PlanSchedule.dayFor(Plan plan, List<PlanRevision> revisions, LocalDate date) -> ScheduledPlanDay?`；`ScheduledPlanDay` 包含 plan、revision、day；按 date 取 effectiveFrom 最大且 <= date 的 revision，剩余规则参见下方。
- `PlanRepository.list()`、`find(String id)`、`revisions(String id)`、`save(Plan plan, PlanRevision revision)`、`setEnabled(String id,bool)`、`delete(String id)` 均 Future typed；`duplicate(String id,{required String newId,required LocalDate startsOn}) -> Future<Plan>` 深复制并新 ID。
- `ExerciseRepository.search({String query='',String? category,String? equipment}) -> Future<List<Exercise>>`、`find(String id) -> Future<Exercise?>`、`recent({int limit=10})`、`save(Exercise)`、`delete(String id)`。
- `AppSettings({defaultUnit,defaultRestSeconds,restReminder,vibration,screenAwake,weekStart,themeId})` 与同字段`copyWith`，默认 kg/90/true/true/true/Monday/breath-rhythm（沿 React），不在页面硬编码；`SettingsRepository.read()` / `save(AppSettings)`。
- fixture `catalogExercise({String id='x1',String name='哑铃卧推'})`固定 chest/dumbbell/kg/空note/2026-09-01 UTC；`catalogPlan({String id='p1',int priority=0,int defaultOrder=0,bool enabled=true})` 与 `catalogRevision({String id='r1',String planId='p1',required LocalDate effectiveFrom,LocalDate? anchor,int cycleDays=3,PlanMode mode=PlanMode.infinite,int? cycleCount,LocalDate? endDate})`，显式创建 1..N 天，fixture 默认训练日含 1 动作 pe1（exerciseId x1）1组s1（20kg/8次/90s休息）；生产绝不调用。

- [ ] **Step 1: 写失败日期/revision 行为测试**，再写不可变集合/名称/字段校验测试：

```dart
test('cycle-length revision restarts on its effective date only', () {
  final plan = catalogPlan();
  final revisions = [
    catalogRevision(effectiveFrom: LocalDate(2026,9,1)),
    catalogRevision(id:'r2', effectiveFrom:LocalDate(2026,9,15), cycleDays:5),
  ];
  expect(PlanSchedule.dayFor(plan,revisions,LocalDate(2026,9,14))!.day.dayNumber,2);
  expect(PlanSchedule.dayFor(plan,revisions,LocalDate(2026,9,15))!.day.dayNumber,1);
});
```

覆盖 1/365 合法、0/366 非法；相同长度保留旧 anchor；新长度未指定日期拒绝；指定循环最后一天/次日；日期范围首尾/中途到期；闰日和 DST 不以 Duration.inDays 直接减本地 DateTime；disabled 和开始前无结果；过去 revision 查询不随新 revision 改变。
- [ ] **Step 2: RED**：`flutter test test/features/plans/domain test/features/exercises/domain -r expanded`。
- [ ] **Step 3: 最小实现**：本地日期差转 UTC 年月日标量，revision 的执行终止在该 revision 规则范围内，所有修改写新 revision（同日起尚未用于训练的 revision 可替换；已开始场次靠快照独立）。有效日期重复用唯一约束；周期变化必须 `cycleAnchorDate=effectiveFrom`，不变保留既有 anchor。

```dart
int calendarDayDifference(LocalDate a, LocalDate b) =>
  DateTime.utc(a.year,a.month,a.day)
      .difference(DateTime.utc(b.year,b.month,b.day)).inDays;
// Valid active revision only:
// dayNumber = calendarDayDifference(date, revision.cycleAnchorDate) % cycleDays + 1;
```

- [ ] **Step 4: GREEN**：同 focused tests + `flutter analyze`；检查 domain import 仅 dart 与其它 domain，不能依赖 Riverpod。
- [ ] **Step 5: Commit**：`git commit -m "feat: model exercise catalog and effective dated plan revisions"`，stage 上列 domain/tests。

**Acceptance:** 所有值、typed repository 与计划日期算法可独立纯 Dart 测试；分类/器械持久化接口明确；无类型重复和共享 mutable list。

### Task 3: 训练快照与 completedPaused 分段计时状态机

**Files:**
- Create: `app/lib/features/workout/domain/{workout_draft,workout_session,workout_event,workout_machine,active_timer,workout_repository}.dart`。
- Test: `app/test/features/workout/domain/{workout_machine_test,active_timer_test}.dart`, `app/test/support/workout_fixtures.dart`。

**Interfaces:**
- `WorkoutDraft({LocalDate workoutDate,List<WorkoutExercise> exercises})`；`WorkoutExercise({id,exerciseId,nameSnapshot,categorySnapshot,equipmentSnapshot,unitSnapshot,sourcePlanId,sourcePlanName,sourceRevisionId,sourceDayNumber,sourceDayName,note,targetRestSeconds,order,temporary,sets})`；nullable source* 为自由训练。
- `WorkoutSet({id,order,plannedWeight,plannedReps,unit,actualWeight,actualReps,status,startedAt,completedAt,skippedAt,setDurationSeconds,preSetRestSeconds,temporary})`；`SetStatus {pending,inProgress,completed,skipped}`。
- `WorkoutSession({id,workoutDate,startedAt,endedAt,phase,exercises,timer,activeSetId,selectedSetId,restStartedAt,restTargetSeconds,note,revision,anomaly,finishCheckpoint})`；`WorkoutPhase {active,resting,completedPaused,finishing,saved,timeAnomaly}`；`revision` 为 CAS 乐观锁版本，`anomaly` 保存原因、检测时刻及此前 phase。`WorkoutFinishCheckpoint`为进入总结前的组状态、选中/当前组、phase、有效total/set/rest累计值；可恢复的临时checkpoint须持久化，避免返回继续时丢失被标为skipped的未完成组。
- `ActiveTimer({int accumulatedActiveSeconds=0,DateTime? runningSegmentStartedAt})`；`read(DateTime nowUtc) -> TimerReading`（seconds、isAnomaly）；`pause(nowUtc)` / `resume(nowUtc)` 返回新 timer。最大单段 `Duration(hours:24)`，恰 24h 合法；负或 >24h 异常。
- `WorkoutMachine.start({required String id,required WorkoutDraft draft,required DateTime nowUtc})`；`transition(WorkoutSession,WorkoutEvent,DateTime nowUtc) -> WorkoutSession`。
- events：`SelectSet(String setId)`, `StartSet(String setId)`, `CompleteSet(String setId,{required double? actualWeight,required int actualReps})`, `SkipSet(String setId)`, `SkipExercise(String exerciseId)`, `UpdateActual(String setId,{double? weight,required int reps})`, `AddExercise(WorkoutExercise exercise)`, `AddSet(String exerciseId,WorkoutSet set)`, `DeletePendingSet(String setId)`, `ReorderPendingExercises(List<String> ids)`, `PrepareFinish()`, `ContinueWorkout()`, `ConfirmTime({required DateTime nowUtc})`。
- `WorkoutRepository.create(WorkoutSession)`、`findUnfinished() -> Future<WorkoutSession?>`、`find(String id)`、`save(WorkoutSession,{required int expectedRevision})`、`saveCompleted(String id,{required String note,required int expectedRevision})`、`discard(String id)`；单 unfinished 约束属于数据库，不只 controller。
- fixture `twoSetDraft({LocalDate? date})` 两个 pending 组 s1/s2；`oneSetDraft()` 一个 pending s1；`temporarySet(String id)` 创建 pending 临时组，所有 planned 值明确为 20kg/8 reps/90s rest。

- [ ] **Step 1: 写失败核心状态/计时测试**：

```dart
test('editing after last set remains paused until a new set starts', () {
  final t=DateTime.utc(2026,9,15,10);
  var s=WorkoutMachine.start(id:'w1',draft:oneSetDraft(),nowUtc:t);
  s=WorkoutMachine.transition(s,StartSet('s1'),t);
  s=WorkoutMachine.transition(s,CompleteSet('s1',actualWeight:20,actualReps:8),t.add(const Duration(seconds:30)));
  expect(s.phase,WorkoutPhase.completedPaused);
  s=WorkoutMachine.transition(s,AddSet('e1',temporarySet('s2')),t.add(const Duration(minutes:5)));
  expect(s.timer.read(t.add(const Duration(minutes:6))).seconds,30);
  s=WorkoutMachine.transition(s,StartSet('s2'),t.add(const Duration(minutes:7)));
  expect(s.timer.read(t.add(const Duration(minutes:7,seconds:10))).seconds,40);
});
```

覆盖当前唯一 inProgress、选择不等于开始、完成非当前组拒绝、普通完成进入 resting、90s 到点无自动 StartSet、休息125s写入真正下一组、跳过/重排不关闭休息、终组跳过且无 pending 也暂停、最后组完成无多余休息提醒、finishing/continue 的暂停与恢复、早结束当前/剩余变 skipped、0完成拒绝 save、time rollback/24h边界/25h。额外验证PrepareFinish后进程重启再Continue恢复原pending/inProgress/rest语义，排除总结编辑间隔，不能把所有组永久跳过导致无从继续。
- [ ] **Step 2: RED**：`flutter test test/features/workout/domain -r expanded`。
- [ ] **Step 3: 实现纯 reducer**：状态转移不可变，终态不能修改训练组；finished 的 completed 原值不变；reorder 只移动尚未完成内容并固定 completed 位置；删除只允许 pending；PrepareFinish先保存finishCheckpoint再将剩余标skipped并暂停，Continue从checkpoint还原并以新segment继续total/set/rest（有效累计不变，原始startedAt保留为历史时间）；save成功清checkpoint。每次 anomaly 返回 timeAnomaly，保留最后有效累计，不写负数。`ConfirmTime` 丢弃异常区间，在用户确认时重开依赖当前时钟的 segment，并保留已累计值与原 phase；不凭空猜修正时长。

```dart
// Normal reading, after anomaly guards:
final seconds = accumulatedActiveSeconds +
  (runningSegmentStartedAt == null ? 0 : nowUtc.difference(runningSegmentStartedAt!).inSeconds);
// Pause commits this valid reading and clears runningSegmentStartedAt.
// Resume keeps accumulatedActiveSeconds and starts a new segment at nowUtc.
```

- [ ] **Step 4: GREEN**：同 focused command + `flutter analyze`；禁止 Stopwatch 作为唯一持久化时间，禁止 now-startedAt 直接当总时长。
- [ ] **Step 5: Commit**：`git commit -m "feat: add resumable workout state machine and paused completion timing"`。

**Acceptance:** 训练及计时由一个纯 Dart 状态机决定；休息归下一组；暂停编辑间隔严格排除；异常不能损坏快照。

### Task 4: 空库 SQLite schema、typed repositories 与事务边界

**Files:**
- Create: `app/lib/core/data/{app_database,schema}.dart`。
- Create: `app/lib/features/exercises/data/sqlite_exercise_repository.dart`, `app/lib/features/plans/data/sqlite_plan_repository.dart`, `app/lib/features/workout/data/{sqlite_workout_repository,workout_mapper}.dart`, `app/lib/features/settings/data/sqlite_settings_repository.dart`。
- Create: `app/lib/features/today/domain/{today_repository,today_overview}.dart`, `app/lib/features/today/data/sqlite_today_repository.dart`, `app/lib/features/history/domain/{history_repository,history_models}.dart`, `app/lib/features/history/data/sqlite_history_repository.dart`。
- Test: `app/test/core/data/schema_test.dart`, `app/test/features/{exercises,plans,workout,settings,today,history}/data/` focused repository tests, `app/test/support/test_database.dart`。

**Interfaces:**
- `AppDatabase.open({String? path,DatabaseFactory? factory}) -> Future<AppDatabase>`；`Database get database`（仅 data/composition）、`close()`；test helper `openTestDatabase()` FFI memory，每个测试隔离。
- schema=1，tables：exercises、plans、plan_revisions、plan_days、plan_exercises、plan_sets、workout_sessions、workout_exercises、workout_sets、app_settings。`plan_revisions UNIQUE(plan_id,effective_from)`；计划内顺序显式列；session 中保存 timer accumulated/running timestamp、phase/current/selected/rest/anomaly/revision。源ID用于溯源，不给 workout snapshot 源外键 ON DELETE CASCADE。
- SQLite 启用 foreign_keys；对未结束 status 的 partial unique index 使用常量表达式，确保 active/resting/completedPaused/finishing/timeAnomaly 合计最多一条。会话写操作事务且 CAS revision 校验；create、save、finalize 全树原子。
- `TodayRepository.load(LocalDate date) -> Future<TodayOverview>`，projection 包含 scheduledDays、mergedExercises、isAllRest、savedCompletedSets、totalPlannedSets、unfinishedSession、FitnessDayStats。
- `HistoryRepository.month(LocalDate monthStart) -> Future<List<CalendarDaySummary>>`、`day(LocalDate date) -> Future<List<WorkoutSession>>`、`stats(LocalDate today,{required int weekStart}) -> Future<FitnessDayStats>`、`exerciseRecords(String exerciseId) -> Future<List<ExerciseRecord>>`、`correctSet(String sessionId,String setId,{required double? weight,required int reps})`、`updateNote(String sessionId,String note)`、`deleteSession(String id)`。
- `CalendarDaySummary(date,hasSavedWorkout,hasUnfinishedWorkout,hasPlan,isAllRest)`、`FitnessDayStats(total,week,month,lastWorkoutAt)`、`ExerciseRecord(sessionId,setId,exerciseId,date,completedAt,unit,weight,reps)` 只读 typed projections；`SqliteTodayRepository` 通过 PlanSchedule + SqliteHistoryRepository 派生，不重复日期公式。

- [ ] **Step 1: repository 真 SQLite 失败测试**：

```dart
test('fresh database is empty and unfinished session is exclusive', () async {
  final db=await openTestDatabase();
  final exercises=SqliteExerciseRepository(db);
  final workouts=SqliteWorkoutRepository(db);
  expect(await exercises.search(),isEmpty);
  final t=DateTime.utc(2026,9,15);
  await workouts.create(WorkoutMachine.start(id:'w1',draft:oneSetDraft(),nowUtc:t));
  await expectLater(workouts.create(WorkoutMachine.start(id:'w2',draft:oneSetDraft(),nowUtc:t)),throwsA(isA<AppFailure>()));
  expect((await workouts.findUnfinished())!.id,'w1');
  await db.close();
});
```

覆盖文件库 close/open 后全字段 roundtrip、snapshot 源重命名/删除不变、计划 revision 查询历史日期、分类/器械筛选、同名竞争约束、完成至少一组、保存两次不重复、同日两场统计一日、CAS 旧 revision 拒绝、事务中途失败后全树不部分更新、所有 unfinished phase 排他、空 settings 默认值不 seed 业务实体。
- [ ] **Step 2: RED**：`flutter test test/core/data test/features/exercises/data test/features/plans/data test/features/workout/data test/features/settings/data test/features/today/data test/features/history/data -r expanded`。
- [ ] **Step 3: 实现 schema/仓储**：正常返回 typed entities，mapper 只放 data；删除历史事务清理子表；动作删除只使源消失，不删计划快照或 history；新建训练复制 draft 所有快照字段。库名 v2，onUpgrade 明确拒绝不支持的降级与未来版本，不写假的迁移脚本。

```sql
CREATE UNIQUE INDEX one_unfinished_workout
ON workout_sessions((1))
WHERE phase IN ('active','resting','completedPaused','finishing','timeAnomaly');
```

- [ ] **Step 4: GREEN**：同 repository command + analyze；重新打开文件库测试不能以同一缓存对象代替；PRD snapshot 每个字段有断言。
- [ ] **Step 5: Commit**：`git commit -m "feat: persist catalog revisions and workout snapshots in sqlite"`。

**Acceptance:** 空库、事务、并发排他、CAS、字段快照、持久化重启均通过真实 SQLite；feature domain 不泄露 Map/DB。

### Task 5: 动作库、动作编辑与共享选择器

**Files:**
- Create: `app/lib/features/exercises/application/{exercise_controller,exercise_providers}.dart`；`app/lib/features/exercises/presentation/{exercise_create_edit_screen,exercise_picker_sheet,exercise_list_tile}.dart`。
- Modify: `exercise_library_screen.dart`, `app/lib/app/{router,providers}.dart`, `app/lib/l10n/app_strings.dart`, theme token files。
- Test: `app/test/features/exercises/application/exercise_controller_test.dart`, `app/test/features/exercises/presentation/exercise_flow_test.dart`。

**Interfaces:**
- `ExerciseController` Riverpod AsyncNotifier；state 包含 searchQuery、selectedCategory、selectedEquipment、items、recentItems、isSaving、failure；`search(String)`、`setCategory(String?)`、`setEquipment(String?)`、`save(Exercise)`、`delete(String)`。
- `ExercisePickerSheet({required ValueChanged<Exercise> onSelected, bool allowMultiple=false})`，共用 repository search，不造另一个 mock list；多选连续添加仍显式反馈已选项。
- `/exercise-create` 与 `/exercise-edit/:exerciseId` 共享 `ExerciseCreateEditScreen(exerciseId:...)`；保存等待数据库成功后 pop；删除从 editor → 确认 → 回 library（避免回到已删详情）。详情路由 Task 11 实现。

- [ ] **Step 1: 失败 controller/widget 测试**：创建胸部/哑铃/20kg 可重启查询；搜索 + 两个筛选叠加；重复名提示且不 pop；所有四单位可选；编辑分类/器械持久化；删除取消/确认；无结果、空库、读失败重试；selector 最近与全部不显示已删源。

```dart
testWidgets('duplicate exercise stays editable with an error', (tester) async {
  await pumpApp(tester, initialLocation:'/exercise-create', database:db);
  await tester.enterText(find.byKey(const Key('exercise-name')), '哑铃卧推');
  await tester.tap(find.byKey(const Key('exercise-save')));
  await tester.pumpAndSettle();
  expect(find.text(AppStrings.duplicateExerciseName),findsOneWidget);
  expect(find.byKey(const Key('exercise-name')),findsOneWidget);
});
```

测试 setup 使用 SqliteExerciseRepository 在测试库预建相同名，不在生产 seed。`pumpApp(tester,{required String initialLocation,required AppDatabase database})` 在 Task 1 helper 扩展，用 ProviderScope overrides 注入同一 SQLite。
- [ ] **Step 2: RED**：`flutter test test/features/exercises/application test/features/exercises/presentation -r expanded`。
- [ ] **Step 3: 实现真实 forms/filter/picker**：保持 React name/category/equipment/unit/notes/isEditing/showDeleteConfirm；验证类别 code 集合，复制视觉 tokens，界面 state 与异步保存 state 分开。

```dart
// Controller command contract:
Future<void> save(Exercise exercise) async {
  // Set isSaving; await repository.save; reload query on success.
  // On AppFailure retain the form values and expose failure; never pop here.
}
```

- [ ] **Step 4: GREEN**：同 focused command；主机 widget 360/430 + 1.3 text，软键盘时保存可见/可滚到；analyze + 完整 test。
- [ ] **Step 5: Commit**：`git commit -m "feat: implement persisted exercise library editor and picker"`。

**Acceptance:** 动作相关 CRUD/search/filter 从用户操作经 Riverpod 到 SQLite；空库可创建第一个动作，计划/训练可复用 picker。

### Task 6: 计划列表、基础信息和周期日完整编辑

**Files:**
- Create: `app/lib/features/plans/application/{plan_controller,plan_editor_controller,plan_providers}.dart`；`app/lib/features/plans/presentation/{create_edit_plan_screen,plan_edit_screen,plan_day_expansion_tile,plan_set_editor_sheet}.dart`。
- Modify: `plan_screen.dart`, app router/strings；`app/test/features/plans/{application/plan_editor_test.dart,presentation/plan_flow_test.dart}`。

**Interfaces:**
- `PlanController.load/search/setEnabled/duplicate/delete`；`PlanEditorController.open(String? planId)`、`save({required LocalDate effectiveFrom})`；state `name,cycleLength,execMode,loopCount,startDate,endDate,priority,enabled,selectedDayIndex,days,isSaving,failure`。
- typed local draft commands：`setDayRest(int dayIndex,bool)`、`renameDay(int,String)`、`copyDay(int source,int target)`、`addExercise(int dayIndex,Exercise)`、`deleteExercise(int,String)`、`copyExercise(int,String)`、`reorderExercises(int,List<String>)`、`batchAddSets(int dayIndex,String exerciseId,{required int count,required double? weight,required WeightUnit unit,required int reps})`、`updateSet/deleteSet/copySet/reorderSets`（参数为 dayIndex/exerciseId/setId 或 ordered IDs）。调用顺序仅改 draft，`save` 写 Plan+Revision 一个事务。
- routes `/create-plan`、`/edit-plan/:planId`（基础信息）、`/plan-edit/:planId`（周期日）；list expandedPlanId/searchQuery/enabledPlanIds 语义保留，enabledPlanIds 来自已持久化 Plan。

- [ ] **Step 1: 失败测试三执行方式与 revision 编辑**：分别创建 1/3/365 天、范围中途结束、复制所有层级后 ID 不共享、开关持久化、优先级/defaultOrder 排序；无变化长度不重置 Dn；改变长度必须填写新日期；训练日至少一组有效内容后才产生训练清单，休息日无动作；N=365 可滚动/按序号跳转和名称搜索。

```dart
test('batch sets expand into independently editable rows', () async {
  await editor.open(null);
  editor.addExercise(0,catalogExercise());
  final exerciseId=editor.state.days.first.exercises.single.id;
  // The editor adds an exercise with zero sets; batch creation supplies its sets.
  editor.batchAddSets(0,exerciseId,count:5,weight:32,unit:WeightUnit.kg,reps:8);
  final sets=editor.state.days.first.exercises.first.sets;
  expect(sets,hasLength(5));
  expect(sets.map((s)=>s.id).toSet(),hasLength(5));
  expect(sets.map((s)=>s.plannedReps),everyElement(8));
});
```

- [ ] **Step 2: RED**：`flutter test test/features/plans/application test/features/plans/presentation -r expanded`。
- [ ] **Step 3: 实现 controller/三页与组编辑 sheet**：list 纵向展开，day editor 横向 D1..DN；触发 range/cycle-count 时显示计算结束日期、完整周期/剩余天数；删除/转休息日影响已有 draft 内容时确认，取消保留。计划 copy 新 ID、默认名字由 AppStrings 格式化。

```dart
// Saving chooses anchor from previous revision only when length is unchanged.
final anchor = previous != null && previous.cycleDays == draft.cycleLength
    ? previous.cycleAnchorDate : effectiveFrom;
```

- [ ] **Step 4: GREEN**：同 focused command + Task 2 schedule tests + 完整 test/analyze；输入键盘/横向标签无 overflow。
- [ ] **Step 5: Commit**：`git commit -m "feat: implement revision aware plan editing and cycle day workflows"`。

**Acceptance:** 任意 1..365 周期、三模式、CRUD/复制/启停/所有排序/批量组可操作；revision 生效规则用户可见且数据库执行一致。

### Task 7: 今日合并、真实统计与训练准备

**Files:**
- Create: `app/lib/features/today/application/{today_controller,today_providers}.dart`；`app/lib/features/workout/application/pre_workout_controller.dart`；`app/lib/features/workout/presentation/{pre_workout_screen,workout_draft_card}.dart`。
- Modify: `home_screen.dart`、`sqlite_today_repository.dart`、router/strings。
- Test: `app/test/features/today/application/today_controller_test.dart`, `app/test/features/workout/application/pre_workout_test.dart`, `app/test/features/today/presentation/home_screen_test.dart`。

**Interfaces:**
- `TodayController` expose `AsyncValue<TodayOverview>`，`refresh()`；`PreWorkoutController.prepare({required LocalDate date,required bool freeWorkout}) -> Future<void>`，`WorkoutDraft get draft`；`addExercise`、`removeExercise`、`reorderExercises`、`addSet/deleteSet/updateSet/reorderSets` 仅修改本次 draft；`takeDraft() -> WorkoutDraft` 返回不可变副本，正式开始 Task 8 消费。
- route `/pre-workout?free=true|false&date=YYYY-MM-DD`；home `hasActiveWorkout` 来自所有 unfinished phase；恢复去 phase route；开始前不创建计时场次。跨日期刷新使用 Clock.today，不以页面硬编码日期。

- [ ] **Step 1: 失败合并/准备测试**：两个不同长度计划、同 priority defaultOrder、rest+training、all-rest、无计划、disabled、到期；首页恢复优先；统计来自已保存组；自由训练空 draft 可添加；准备删除重排/修改组不改变 PlanRevision，未确认无 unfinished。

```dart
test('preparation edits never rewrite plan templates', () async {
  await prepare.prepare(date:LocalDate(2026,9,15),freeWorkout:false);
  prepare.updateSet('s1',weight:25,reps:10);
  expect(prepare.takeDraft().exercises.first.sets.first.plannedReps,10);
  expect((await plans.revisions('p1')).first.days.first.exercises.first.sets.first.plannedReps,8);
  expect(await workouts.findUnfinished(),isNull);
});
```

- [ ] **Step 2: RED**：`flutter test test/features/today test/features/workout/application/pre_workout_test.dart -r expanded`。
- [ ] **Step 3: 实现 action-first Home + preparation**：每个数字/日期/来源真实；无计划与休息日均允许自由训练；常规日也可自由训练，不照抄旧计划禁用按钮；训练来源 plan/revision/day 完整显示；预计时间用说明清楚的估算或无数据不显示，禁止固定55分钟。

```dart
// Merge comparator shared by projection:
final byPriority = b.plan.priority.compareTo(a.plan.priority);
return byPriority != 0 ? byPriority : a.plan.defaultOrder.compareTo(b.plan.defaultOrder);
```

- [ ] **Step 4: GREEN**：focused + analyze + 完整 tests；验证 loading/read error/retry、空库首次流程与恢复卡内容。
- [ ] **Step 5: Commit**：`git commit -m "feat: connect today plan merge and editable workout preparation"`。

**Acceptance:** 所有首页状态都由 SQLite+date 衍生；准备只改快照 draft，无多计划混序，无启动前计时。

### Task 8: 持久化训练控制器、恢复与失败重试

**Files:**
- Create: `app/lib/features/workout/application/{workout_controller,workout_providers,workout_view_state}.dart`；`app/lib/core/platform/system_clock.dart`；`app/test/support/fake_clock.dart`。
- Modify: app providers/router、pre_workout_screen 开始按钮。
- Test: `app/test/features/workout/application/{workout_flow_test,workout_recovery_test,workout_failure_test}.dart`。

**Interfaces:**
- `WorkoutController.start(WorkoutDraft) -> Future<String>`、`restore() -> Future<void>`、`dispatch(WorkoutEvent) -> Future<void>`、`save({required String note}) -> Future<LocalDate>`、`discard() -> Future<void>`、`retry() -> Future<void>`。
- `WorkoutViewState({WorkoutSession? session,bool isSaving,AppFailure? failure,WorkoutSession? pendingSession})`；Riverpod 保存单个活动 controller。命令串行，CAS expectedRevision，UI 双击不能创建第二次；成功 commit 后刷新 Today/history providers，失败保留 committed 与 pending 编辑。
- `FakeClock(DateTime now)` 实现 Clock，`advance(Duration)`、`setUtc(DateTime)`，单调值单独前进；system DateTime 不在 controller 直接调用。

- [ ] **Step 1: 失败持久化闭环/重启测试**：创建/每个 event 后新建 repository/controller 从数据库恢复，确认 timer/actual/rest/order/temporary/selected/current；completedPaused重启仍冻结，添加组编辑不会恢复；CAS/磁盘失败不丢草稿、不重复完成；one unfinished；回退与25h异常提示保留最近有效状态。

```dart
test('restart restores the actual rest duration onto next started set', () async {
  await controller.start(twoSetDraft());
  await controller.dispatch(StartSet('s1'));
  clock.advance(const Duration(seconds:30));
  await controller.dispatch(CompleteSet('s1',actualWeight:20,actualReps:8));
  clock.advance(const Duration(seconds:125));
  final restored = makeWorkoutController(database:db,clock:clock);
  await restored.restore();
  await restored.dispatch(StartSet('s2'));
  expect(restored.state.session!.exercises.first.sets.last.preSetRestSeconds,125);
});
```

`makeWorkoutController({required AppDatabase database,required Clock clock})` 在 support helper 建真实 SQLite repositories 与 ProviderContainer，测试结束 dispose。
- [ ] **Step 2: RED**：`flutter test test/features/workout/application -r expanded`。
- [ ] **Step 3: 实现 persistence-first commands 与 recovery**：reducer 产 candidate，await transaction，成功才发布 committed；retry 重试同一 candidate/command，revision 冲突读取最新并显式告知；所有计时刷新只投影不逐秒 DB 写；pause/complete/start/finish 写完整 timer checkpoint。

```dart
final candidate = WorkoutMachine.transition(current,event,clock.nowUtc());
await repository.save(candidate,expectedRevision:current.revision);
// Read committed revision and publish only after transaction success.
```

- [ ] **Step 4: GREEN**：focused + Task 3/4 tests + 完整 tests/analyze；恢复测试必须 dispose 旧 controller，文件库 reopen 至少一个 case。
- [ ] **Step 5: Commit**：`git commit -m "feat: persist workout commands and recover timing across restarts"`。

**Acceptance:** app/background/进程重建后用户看到同一 session；各关键操作原子保存；保存失败可重试；时钟异常明确可确认而不是负数/假连续计时。

### Task 9: 训练、休息、提前结束、总结页面与导航

**Files:**
- Create: `app/lib/features/workout/presentation/{workout_screen,rest_screen,workout_summary_screen,early_end_sheet,in_workout_adjustment_sheet}.dart`。
- Create: `app/lib/widgets/{set_row,rest_ring,progress_bar}.dart`。
- Modify: router、strings、shared theme tokens；Test `app/test/features/workout/presentation/workout_pages_test.dart`。

**Interfaces:**
- `/workout/:sessionId`、`/rest/:sessionId`、`/summary/:sessionId`；route 仅 ID，持久化 controller 决定 phase；deep link 缺/已删 session 回安全页并提示；system back保留未结束训练，返回首页恢复入口，放弃必须独立确认。
- `EarlyEndSheet` 只显示/发出动作，统计来自 session：继续、结束保存已完成、放弃后二次确认；`InWorkoutAdjustmentSheet` 使用 Task 8 dispatch；view locals 保留 `isEndSheetOpen`,`activeTab`,`showPicker`,`editWeight`,`editReps`,`noteText`。

- [ ] **Step 1: 失败 widget 流程测试**：完整可选组清单；select pending不自动开始；完成非终组到rest；rest达目标不跳页；选择其他组真正 start 时记rest；固定结束按钮；0完成禁止保存；提前结束 current和remaining skipped；完成终组显示结束/添加且总时长冻结；添加sheet期间不计时；保存导航到日期历史。

```dart
testWidgets('last set completion pauses and offers adding training', (tester) async {
  await pumpWorkout(tester,session:oneSetSessionInProgress);
  await tester.tap(find.byKey(const Key('complete-set')));
  await tester.pumpAndSettle();
  expect(find.text(AppStrings.workoutCompletedPaused),findsOneWidget);
  expect(find.byKey(const Key('add-training')),findsOneWidget);
  expect(find.byKey(const Key('finish-workout')),findsOneWidget);
});
```

Task 9 定义 `pumpWorkout(tester,{required WorkoutSession session})` 与 `oneSetSessionInProgress`（Task3 fixture 在固定时刻经 StartSet 获得），真实 controller repository setup，不用回调 noop 假装业务。
- [ ] **Step 2: RED**：`flutter test test/features/workout/presentation -r expanded`。
- [ ] **Step 3: 实现 Figma 四流程与 shared components**：显式 AnimationController 实现 progress300ms、set dots200ms、RestRing 1s linear/overtime300ms、sheet280ms，对照 index.css 补充其曲线与 overlay；结束入口 minTap48，但视觉依Figma。disabled/loading/pressed 有明确 state，保存失败 sheet/form 不退出。

```dart
final savedDate = await ref.read(workoutControllerProvider.notifier).save(note:noteText);
if (context.mounted) context.go('/history/${savedDate.iso8601}');
```

- [ ] **Step 4: GREEN**：focused + navigation + analyze/完整 tests；对照 React read各页面，键盘/1.3字体下固定 controls 可操作；history route Task11接正式页，当前 route contract测试检查路径而不增加临时生产虚构历史。
- [ ] **Step 5: Commit**：`git commit -m "feat: implement immersive workout rest and completion workflows"`。

**Acceptance:** 所有操作连真实controller；没有 UI-only 增删/跳过按钮；休息/总结计时语义精确；返回/放弃/保存三个动作不混淆。

### Task 10: Android 通知、独立振动、exact alarm 与屏幕常亮

**Files:**
- Create: `app/lib/core/platform/{notification_gateway,vibration_gateway,wake_lock_gateway,android_notification_gateway,android_vibration_gateway,android_wake_lock_gateway}.dart`；`app/android/app/src/main/kotlin/com/example/fitness_counter/RestVibrationReceiver.kt`（包名以Task1实际applicationId为准）；Modify同目录`MainActivity.kt`注册类型明确的method channel。
- Create: `app/lib/features/workout/application/rest_effects_controller.dart`。
- Modify: pubspec/lock、Android manifests/Gradle（仅插件明确需要项）、providers、workout_controller、`app/lib/features/settings/domain/app_settings.dart`（只补必要permission projection，权限不是用户偏好）。
- Test: `app/test/core/platform/android_gateway_test.dart`, `app/test/features/workout/application/rest_effects_test.dart`, `app/integration_test/android_reminders_test.dart`。

**Interfaces:**
- `NotificationPermissionState({bool notificationsGranted,bool exactAlarmsGranted})`；`NotificationGateway.permissionState()`、`requestNotificationPermission()`、`requestExactAlarmPermission()`、`scheduleRest({required String sessionId,required String restId,required DateTime dueAtUtc})`、`cancelRest(String restId)`，仅发有声通知且通知channel禁用振动，避免与独立振动重复。
- `VibrationGateway.hasVibrator()`、`pulse()`、`scheduleRest({required String sessionId,required String restId,required DateTime dueAtUtc})`、`cancelRest(String restId)`；`WakeLockGateway.setEnabled(bool enabled)`。`RestEffectsController.reconcile(WorkoutSession? session,AppSettings settings)` 与 `dispose()`；稳定 restId=sessionId+restStartedAt；notification channel/IDs/method channel参数集中常量。
- truth table `(restReminder,vibration)`：00 无通知无振动；10 有声通知无振动；01 仅振动、无通知；11 通知+振动各一次。后台振动由 Android AlarmManager + BroadcastReceiver + Vibrator/VibratorManager 执行，不依赖 POST_NOTIFICATIONS，应用进程被回收后仍由系统触发；VIBRATE权限、exact alarm授权各自处理。通知权限拒绝只影响通知。exact被拒采用非精准闹钟降级并显示实际状态，不声称仍准时。

- [ ] **Step 1: 失败 effect测试**：四组合、权限拒绝/授予/撤销、exact granted/denied、前后台与重复reconcile、rest开始一次schedule、离开rest/结束/放弃cancel、恢复已过due不重发多次、达到目标不StartSet、wakelock按设置且仅可见训练/休息页启用、离页/保存释放。

```dart
test('both reminders disabled never schedule or vibrate', () async {
  await effects.reconcile(restingSession, settings.copyWith(restReminder:false,vibration:false));
  clock.advance(const Duration(seconds:90));
  await effects.reconcile(restingSession, settings.copyWith(restReminder:false,vibration:false));
  expect(notificationFake.scheduled,isEmpty);
  expect(vibrationFake.pulseCount,0);
});
```

使用自有 recording fake 验证边界；Android integration 使用真实平台插件，fake不能代替权限/后台验证。
- [ ] **Step 2: RED**：`flutter test test/core/platform test/features/workout/application/rest_effects_test.dart -r expanded`；设备 test 初始缺真实网关也应失败并记录。
- [ ] **Step 3: 实现 Android adapters**：Android 13 POST_NOTIFICATIONS；SCHEDULE_EXACT_ALARM 用户授权（非未经依据 USE_EXACT_ALARM）；exact denied 使用明确的非精准降级并显示状态；按 plugin 文档注册通知接收器；为独立振动实现显式Intent、非exported RestVibrationReceiver、按restId稳定PendingIntent的schedule/cancel，接收器读取应用内部最新有效reminder记录防止已取消rest触发。foreground vibration 与 receiver 使用同一delivery identity防重；通知channel无振动。不要以Dart Timer承诺被杀进程提醒。系统设置强制停止与普通进程回收不同，强制停止后的系统限制需如实记录。

```dart
// Side effects follow a successful session transaction only.
final permissions = await notifications.permissionState();
// Select exactAllowWhileIdle only with exactAlarmsGranted; otherwise a supported fallback.
// Persist reminder identity/delivery state before repeating a recovered effect.
```

- [ ] **Step 4: GREEN**：focused tests，`flutter test integration_test/android_reminders_test.dart -d <adb-device-id>`；真 Android 测锁屏/后台到目标提醒、独立振动、拒绝权限、取消提醒；报告 OS/API与权限状态；网络失败按Global约定同终端代理重试。
- [ ] **Step 5: Commit**：`git commit -m "feat: add android rest reminders permissions and wake lock gateways"`。

**Acceptance:** 平台代码可替换、settings可独立控制通知与振动；无“按了开关实际无效”占位；exact请求与降级真实可见；通知不自动开组；所有失败不阻断训练。

### Task 11: 日历、日期历史修正、动作详情真实记录

**Files:**
- Create: `app/lib/features/history/application/{history_controller,history_providers}.dart`；`app/lib/features/history/presentation/{history_detail_screen,history_set_editor_sheet,session_expansion_tile}.dart`；`app/lib/features/exercises/presentation/exercise_detail_screen.dart`。
- Modify: calendar_screen、sqlite_history_repository、today stats projections、router/strings。
- Test: `app/test/features/history/{application/history_controller_test.dart,presentation/history_flow_test.dart}`、`app/test/features/exercises/presentation/exercise_detail_test.dart`。

**Interfaces:**
- `HistoryController.loadMonth(LocalDate)` / `loadDay(LocalDate)` / `correctSet` / `updateNote` / `deleteSession` 委派 Task4 repository，成功 invalidate today/exercise detail/calendar；state `selectedDate,currentMonth,expandedSessionIdx,showDeleteConfirm` 保留 React语义。
- routes `/history/:date`（多个场次按 startedAt 升序，最新保存可初始展开）；`/exercise-detail/:exerciseId` 编辑→既有 editor。
- `ExerciseHistorySummary.fromRecords(List<ExerciseRecord>)`（定义于 `features/history/domain/history_models.dart`）按 unit 分组；最高实际重量为 best，同重量次数最大、再按最新完成时间；bodyweight/none 用次数最大，不跨kg/lb换算。趋势取所选单位按时间序列最近记录，无历史呈空态。

- [ ] **Step 1: 失败历史测试**：月份跨年/闰日/周起始；saved主标记+planned次标记可共存；unfinished/all-rest；同日两场只一天；删除最后有效场后统计减一；编辑actual不动planned/unit快照；修改备注重启保留；源删除历史不变；动作详情 best/trend/log 来自完成已保存组，不含active/skipped，不混合单位。

```dart
test('unit-specific personal best never compares kg with lb', () {
  final summary=ExerciseHistorySummary.fromRecords([
    exerciseRecord(unit:WeightUnit.kg,weight:40,reps:8),
    exerciseRecord(unit:WeightUnit.lb,weight:80,reps:10),
  ]);
  expect(summary.bestByUnit[WeightUnit.kg]!.weight,40);
  expect(summary.bestByUnit[WeightUnit.lb]!.weight,80);
});
```

fixture `exerciseRecord({required WeightUnit unit,required double? weight,required int reps})` 在 history test 文件固定日期/IDs，避免生产样例。
- [ ] **Step 2: RED**：`flutter test test/features/history test/features/exercises/presentation/exercise_detail_test.dart -r expanded`。
- [ ] **Step 3: 实现月历/日期详情/编辑sheet/动作详情**：Figma卡片布局保留，PRD actual corrections在明确sheet进行；每组计划/actual/unit/status/start/end/duration/preRest/temporary完整；source plan/revision/day 快照显示；删除二次确认，数据库成功再消失。

```dart
await history.correctSet(sessionId,setId,weight:editedWeight,reps:editedReps);
// Refresh day, month, statistics, and per-exercise summaries after success.
// Snapshot plannedWeight/plannedReps/unit never change here.
```

- [ ] **Step 4: GREEN**：focused + Task4 snapshot/data tests + navigation/analyze/完整 test；从 Task9保存实际进入选定训练日期；无历史及已删exercise深链接安全。
- [ ] **Step 5: Commit**：`git commit -m "feat: add calendar history corrections and exercise performance detail"`。

**Acceptance:** Figma14页面中的历史/动作详情真实闭环；结果和计划状态视觉区分；不因当前模板修改污染历史；统计精确。

### Task 12: 持久化设置与主题 registry 展示

**Files:**
- Create: `app/lib/features/settings/application/{settings_controller,settings_providers}.dart`；`app/lib/features/settings/presentation/settings_screen.dart`。
- Modify: app composition/theme loading、calendar week start、rest effects、strings。
- Test: `app/test/features/settings/{application/settings_controller_test.dart,presentation/settings_screen_test.dart}`。

**Interfaces:**
- `SettingsController.load()` / `update(AppSettings)`；state中保留 `weightUnit,defaultRest,restReminder,vibration,screenAwake,weekStart,selectedTheme`，selectedTheme类型 ThemeId，permissionState另为系统投影。
- `/settings` 返回 caller home；theme列表来自 ThemeRegistry.available，本版只有 breath-rhythm；无导入/安装、无占位不可用 A/B/C；未知持久化ID resolve默认并保持当前workout。

- [ ] **Step 1: 失败设置重启测试**：每个开关/默认单位/休息/周起始持久化；独立通知与振动包括都关闭；权限真实状态refresh；默认值仅用于未来新增组/动作，不改已有snapshot；切换 registry definition不重建丢session；损坏/未知ThemeId fallback；一个实际主题仍正确显示已选状态。

```dart
test('settings update does not mutate active workout snapshots', () async {
  final before=await workouts.findUnfinished();
  await settings.save((await settings.read()).copyWith(defaultRestSeconds:120,defaultUnit:WeightUnit.lb));
  expect((await workouts.findUnfinished())!.exercises.first.targetRestSeconds,
      before!.exercises.first.targetRestSeconds);
});
```

- [ ] **Step 2: RED**：`flutter test test/features/settings -r expanded`。
- [ ] **Step 3: 实现 settings 与实时 platform状态**：沿Figma分组；通知/exact状态和按钮真实调用gateway；保存失败回退committed switch并保留待重试值；AppStrings和theme tokens全覆盖；周起始只改日历展示不改计划自然日推进。

```dart
final definitions=ref.watch(themeRegistryProvider).available;
// Render exactly these definitions. Business routes never branch on their IDs.
```

- [ ] **Step 4: GREEN**：focused + rest effect tests + calendar tests + analyze/完整 test；关闭页面重新打开/应用重启偏好相同。
- [ ] **Step 5: Commit**：`git commit -m "feat: persist settings and expose extensible theme selection"`。

**Acceptance:** 首版所有设置实际生效；theme仅registry改变tokens/skin，不复制页面；无mock权限状态/主题枚举。

### Task 13: 14 页高保真与 Android 响应式整合

**Files:**
- Modify: `app/lib/theme/`、`app/lib/widgets/`、上列14 screen文件、router/strings，仅有视觉或已验证导航差异。
- Create: `app/test/presentation/{screen_coverage_test,responsive_screens_test,visual_goldens_test}.dart`、`app/test/presentation/goldens/`、`docs/verification/2026-09-15-flutter-visual-matrix.md`。
- Test fixtures stay `app/test/support/`，所有14页面使用真实类型的确定性fixture，不进入生产bootstrap。

**Interfaces:**
- 下表是最终 PAGE SPEC 覆盖合同；逐行记录 React source → Flutter path → reachable route → empty/data/error states → screenshot证据。新增平台提示可用现有sheet不另造业务路线。

| React screen | Flutter feature/presentation file | Route | Important preserved state |
|---|---|---|---|
| HomeScreen | today/home_screen.dart | /home | hasActiveWorkout derived |
| PlanScreen | plans/plan_screen.dart | /plan | expandedPlanId, searchQuery, enabledPlanIds |
| CreateEditPlanScreen | plans/create_edit_plan_screen.dart | /create-plan, /edit-plan/:planId | name, cycleLength, execMode, loopCount, endDate, priority, enabled |
| PlanEditScreen | plans/plan_edit_screen.dart | /plan-edit/:planId | selectedDayIndex, showPicker |
| ExerciseLibraryScreen | exercises/exercise_library_screen.dart | /exercises | searchQuery + explicit filters |
| ExerciseCreateEditScreen | exercises/exercise_create_edit_screen.dart | /exercise-create, /exercise-edit/:exerciseId | name, category, equipment, unit, notes, isEditing, showDeleteConfirm |
| ExerciseDetailScreen | exercises/exercise_detail_screen.dart | /exercise-detail/:exerciseId | repository-derived records |
| PreWorkoutScreen | workout/pre_workout_screen.dart | /pre-workout | exercises, reordering, showPicker |
| WorkoutScreen | workout/workout_screen.dart | /workout/:sessionId | isEndSheetOpen + explicit selection |
| RestScreen | workout/rest_screen.dart | /rest/:sessionId | isEndSheetOpen |
| WorkoutSummaryScreen | workout/workout_summary_screen.dart | /summary/:sessionId | noteText |
| CalendarScreen | history/calendar_screen.dart | /calendar | selectedDate, currentMonth |
| HistoryDetailScreen | history/history_detail_screen.dart | /history/:date | expandedSessionIdx, showDeleteConfirm |
| SettingsScreen | settings/settings_screen.dart | /settings | weightUnit, defaultRest, restReminder, vibration, screenAwake, weekStart, selectedTheme |

- [ ] **Step 1: 写失败screen coverage/响应式测试**：每条route至少一次可从真实入口到达；每页不存在overflow；360/390/430宽、1.0/1.3 scale；所有关键hit>=48；keyboard表单保存可达；12月/长中文名称/365周期/多动作训练长列表；训练四phase+timeAnomaly；text/source state名字无丢失。

```dart
testWidgets('workout actions stay reachable at narrow width and large text', (tester) async {
  tester.view.physicalSize=const Size(360,800);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await pumpScreenFixture(tester,screen:'workout',textScale:1.3);
  expect(tester.takeException(),isNull);
  expect(tester.getSize(find.byKey(const Key('finish-workout'))).shortestSide,greaterThanOrEqualTo(48));
});
```

`pumpScreenFixture(tester,{required String screen,double textScale=1})` 创建test-only真实controllers/db，所有keys在对应widget由常量统一，golden采用同source fixture，不与生产seed混合。
- [ ] **Step 2: RED**：`flutter test test/presentation/screen_coverage_test.dart test/presentation/responsive_screens_test.dart -r expanded`；视觉缺陷以具体bounds/token差异记录，不只截图“看起来不对”。
- [ ] **Step 3: 复刻与修差**：逐页阅读 React 完整 JSX/注释/组件/CSS；用Figma fog背景、deepBlue英雄卡、coral主按钮、mint休息、精确字号间距/边框/圆角/高度；先修shared组件再修单页；去browser frame与模拟statusbar，用真实Android系统栏；每screen顶部PAGE/ROUTE/WIDGETS/STATE/ANIMATIONS/NAVIGATION注释完整。所有视觉数值/copy迁至theme/strings。

```dart
// PAGE: RestScreen
// ROUTE: /rest/:sessionId
// FLUTTER WIDGETS: Scaffold, AppBar, ListView, CustomPaint, FilledButton
// STATE: isEndSheetOpen(bool); persisted phase/rest timing from WorkoutController
// ANIMATIONS: ring 1000ms linear; overtime color 300ms easeOut
// NAVIGATION: begin next -> workout; finish -> EarlyEndSheet
```

- [ ] **Step 4: GREEN + 可视审阅**：focused tests通过；`flutter test test/presentation/visual_goldens_test.dart --update-goldens`生成→逐张查看→修差→不带update运行通过；matrix列出14页覆盖、key bounds、颜色和OS差异。用真实Android再捕获Home/计划编辑/训练/休息/总结/历史，360/430逻辑宽；浏览器/UI snapshot只作Figma参考，不称为Android验证。
- [ ] **Step 5: Commit**：`git commit -m "feat: align all fourteen flutter workflows with figma visuals"`，仅提交审核后的goldens；完整test/analyze无ignored failures。

**Acceptance:** 14个独立screen workflow全部可达；无残留Provider/legacy页/mock记录/魔法widget视觉值；所有局部交互与导航显式；参考截图说明来源（app_pages其它两主题不为本版要求）。

### Task 14: Android 完整闭环、进程恢复、发布 APK 与最终证据

**Files:**
- Create: `app/integration_test/{full_workout_flow_test,process_recovery_test,plan_revision_flow_test,history_settings_test}.dart`、`app/test_driver/integration_test.dart`（仅需flutter drive截图时）、`docs/verification/2026-09-15-flutter-acceptance.md`。
- Modify: `app/README.md`（启动/测试/构建/数据库/权限说明）；修复只允许针对实际失败并补失败测试，按影响回归。
- Artifacts: 本计划ignored workspace中保存设备截图/日志，正式验收文档链接稳定review路径或发布APK相对路径。不要提交临时设备日志/安装包进Git。

**Interfaces:**
- 使用实际Android SQLite与真实平台网关；测试每次临时数据库或独立integration flavor/suffix，不通过清除用户应用数据重置；恢复测试进程重启不只是widget重建。
- 最终release APK `app/build/app/outputs/flutter-apk/app-release.apk`；现有 debug signing 可作为本地侧载验证，报告签名事实，不将其宣称商店生产签名。

- [ ] **Step 1: 写失败集成验收用例**：空库→新建动作/分类器械→新建两计划(训练/休息混合)→设置cycle模式与revision→准备修改→开始/完成/休息/选其他组→临时增删/重排→末组paused→等待编辑→新增开始恢复→提前结束→备注保存→训练日期历史；同日再训练→统计仍一天；actual修正与源计划修改→snapshot不变；删最后记录→标记消失；设置重启保留。

```dart
IntegrationTestWidgetsFlutterBinding.ensureInitialized();
testWidgets('empty database supports a complete saved workout', (tester) async {
  await launchIntegrationApp(tester,databaseName:'acceptance-flow.sqlite');
  await createExerciseThroughUi(tester,name:'哑铃卧推');
  await startFreeWorkoutThroughUi(tester);
  await completeOneSetThroughUi(tester);
  await saveWorkoutThroughUi(tester,note:'验收训练');
  expect(find.byKey(const Key('history-day-detail')),findsOneWidget);
  expect(find.text('验收训练'),findsOneWidget);
});
```

在integration helper中实现这5个函数，全部通过tester UI进入正式代码，launch override仅数据库文件名与测试clock（专用时钟边界测试），不跳过保存/权限路径。测试fixture仅此scope。
- [ ] **Step 2: RED**：`flutter devices`确认 Android device ID；运行新文件 `flutter test integration_test/full_workout_flow_test.dart -d <device-id>`，保留首次失败。无行为失败的纯验证用例不得伪造red；若已有实现已满足，记录“verification-only，未修改行为”，将新增缺陷用回归red驱动修复。
- [ ] **Step 3: 实机恢复/提醒证据**：训练中、rest中、completedPaused分别使用adb杀后台进程/重启app（记录命令与app id，勿清数据）；恢复实际组/累计时长/剩余提醒；锁屏/返回前台休息继续，exact开/拒绝、通知与振动四组合、保存/放弃取消；negative/25h用可注入clock专用集成用例，不改设备系统时间影响用户。
- [ ] **Step 4: 完整GREEN**，每项分别记录命令exit、总测试数、device/API/分辨率/字体倍率、源码SHA：

```powershell
flutter analyze
flutter test -r expanded
flutter test integration_test -d <device-id> -r expanded
flutter build apk --release
```

`<device-id>` 只能替换为本次 `flutter devices`/adb实际观察到ID；无设备先 `flutter emulators`启动可用Android emulator，仍须记录是真实Android runtime（模拟器或物理机）与限制，不用web替代。网络失败在同终端按Global代理重试。若硬件/权限不可测，应报精确阻碍，不能宣称验收通过。
- [ ] **Step 5: Android视觉矩阵复核**：运行 release APK到Android；实际Home、完整编辑、训练、rest、paused、summary、history、settings截图与Figma同state比较；360/390/430宽与1.3文字无overflow；文档包含像素色/卡片边界/顶部inset/底nav/按钮文本差异与结论。计算APK SHA256、记录绝对路径/大小/签名类型。
- [ ] **Step 6: Commit docs/test/fixes**：`git commit -m "test: verify android workout lifecycle and release build"`；主代理派最终 whole-branch reviewer，输入 initialBase..HEAD diff、Global Constraints、全部TDD报告/视觉证据、ledger所有deferred/parked事项；重要问题按SDD一次fix-wave和scoped re-review处理；最终有风险明确报告，不未经授权merge/push。

**Acceptance:** analyze、全部test、Androidintegration、releasebuild四类实际通过且证据可检索；至少真实Androidruntime高保真截图；无未完成UI操作/假平台实现；APK可安装打开，产品空库自主建立完整训练闭环。

## Coverage self-review

- PRD 7/统计/首页恢复 → Tasks 4/7/8/11；8/三模式/revision/复制/长周期 → Tasks 2/4/6；9/分类器械/动作详情并集 → Tasks 2/5/11。
- PRD 10/11/准备/临时变更/逐组/休息 → Tasks 3/7/8/9；12/提前结束/放弃/paused扩展 → Tasks 3/8/9；13/日历/历史快照/修正/多场统计 → Tasks 4/11。
- PRD 14/15/持久化/时间异常/恢复 → Tasks 3/4/8/14；16/提醒/默认值/常亮/周起始 → Tasks 10/12。
- Figma14页/所有组件/PAGE状态/动画/完整四tab → Tasks 1/5/6/7/9/11/12/13；future themes 无枚举/data-only合同 → Task1/12。
- 每task有明确files/interfaces/真实失败示例/RED和GREEN命令/提交门；真SQLite、Androidintegration、release和视觉 → Tasks4/10/13/14。
- 保留原工作区所有dirty文件；旧计划/ledger不复用；新计划身份/冲突矩阵/每task进展位于本计划自己的 `.superpowers/sdd/2026-09-15-flutter-rewrite/progress.md`。
