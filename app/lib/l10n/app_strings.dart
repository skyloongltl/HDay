abstract final class AppStrings {
  static const historySnapshot = '训练快照';
  static const historyTitle = '训练记录';
  static const historyLoadFailed = '记录加载失败，请重试。';
  static const historyWriteFailed = '修改未保存，输入内容已保留，请重试。';
  static const historyDeleteFailed = '删除未成功，原记录仍然保留，请重试。';
  static const noDateHistory = '该日无训练记录';
  static const noExerciseHistory = '此动作还没有已保存的完成记录';
  static const personalBest = '个人最佳';
  static const weightTrend = '重量趋势';
  static const repsTrend = '次数趋势';
  static const recentTraining = '近期训练';
  static const recentRecord = '最近';
  static const plannedDay = '计划训练';
  static const plannedNotStarted = '有计划 · 尚未开始';
  static const savedWorkout = '已保存训练';
  static const savedWorkoutComplete = '已完成';
  static String remainingExercises(int count) => '+$count';
  static String historyWeekday(int weekday) =>
      '周${weekLabelsMonday[weekday - 1]}';
  static const unfinishedWorkout = '未结束训练';
  static const calendarToday = '今天';
  static const previousMonth = '上个月';
  static const nextMonth = '下个月';
  static const viewFullHistory = '查看完整训练记录';
  static const expandHistory = '展开详情';
  static const collapseHistory = '收起详情';
  static const correctHistorySet = '修正实际数据';
  static const correctionHint = '仅修正实际重量和次数，计划数据与单位快照保持不变。';
  static const plannedValues = '计划';
  static const actualValues = '实际';
  static const deleteHistory = '删除训练场次';
  static const deleteHistoryTitle = '删除此训练场次？';
  static const deleteHistoryHint = '此操作无法撤销。其他场次和计划不受影响。';
  static const deleteLastHistoryHint =
      '这是当天最后一个有效训练场次。删除后，该日期将从健身日统计中移除。此操作无法撤销。';
  static const originalSet = '计划内训练组';
  static const temporarySet = '临时训练组';
  static const noValue = '—';
  static const weekLabelsMonday = ['一', '二', '三', '四', '五', '六', '日'];
  static const weekLabelsSunday = ['日', '一', '二', '三', '四', '五', '六'];
  static String sessionCount(int count) => '$count 个训练场次';
  static String historySessionLabel(int index) => '第 $index 场训练';
  static String historyDate(int month, int day) => '$month 月 $day 日';
  static String historyValue(num? weight, int? reps, String unit) {
    final weightLabel = unit == 'bodyweight' || unit == 'none'
        ? weightUnitLabels[unit]!
        : '${weight == null ? noValue : compactNumber(weight)} ${weightUnitLabels[unit]}';
    return '$weightLabel × ${reps ?? noValue} 次';
  }

  static String recentWeightValue(num? weight, String unit) {
    if (unit == 'bodyweight' || unit == 'none') {
      return weightUnitLabels[unit]!;
    }
    return '${weight == null ? noValue : compactNumber(weight)} ${weightUnitLabels[unit]}';
  }

  static String historyDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600 ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$remainder' : '$minutes:$remainder';
  }

  static String historyTime(DateTime? value) {
    if (value == null) return noValue;
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }

  static String historyTimeSpan(DateTime? start, DateTime? end) =>
      '${historyTime(start)} → ${historyTime(end)}';
  static String historySetTiming(int duration, int preRest) =>
      '单组 ${historyDuration(duration)} · 组前休息 ${historyDuration(preRest)}';
  static String historySetState(String state) => const {
        'completed': '已完成',
        'skipped': '已跳过',
        'inProgress': '进行中',
        'pending': '待练',
      }[state]!;
  static String dayLabel(int day) => 'D$day';
  static const newPlan = '新建计划';
  static const editPlan = '编辑计划';
  static const searchPlan = '搜索计划名称';
  static const noMatchingPlans = '没有找到匹配的计划';
  static const tryOtherQuery = '试试其他关键词';
  static const planLoadFailed = '计划加载失败，请重试。';
  static const planMissing = '此计划已不存在';
  static const basicInfo = '基本信息';
  static const planName = '计划名称';
  static const planNameHint = '例如：推拉腿计划';
  static const planNameRequired = '请输入计划名称';
  static const cycleLength = '周期天数 N（1–365）';
  static const cycleLengthError = '请输入 1–365 之间的周期天数';
  static const positiveCount = '请输入大于 0 的整数';
  static const invalidNumber = '请输入有效的非负数值';
  static const enablePlan = '启用此计划';
  static const enablePlanHint = '启用后纳入今日首页计算';
  static const executionMode = '执行模式';
  static const infiniteMode = '无限循环';
  static const cyclesMode = '固定次数';
  static const rangeMode = '日期范围';
  static const infiniteHint = '计划将无限循环，直到手动停用。每轮结束后自动从 D1 重新开始。';
  static const loopCount = '循环次数';
  static const computedEnd = '预计结束日期';
  static const completeCycles = '完整轮次';
  static const remainingDays = '剩余天数';
  static const startDate = '开始日期';
  static const effectiveDate = '本次修改生效日期';
  static const endDate = '结束日期（当天有效）';
  static const invalidDateRange = '结束日期不能早于生效日期';
  static const priority = '优先级';
  static const priorityHint = '数字越大越优先；相同优先级按创建顺序';
  static const cycleConfig = '周期日配置';
  static const createPlanShort = '创建计划';
  static const deletePlan = '删除此计划';
  static const deletePlanHint = '计划及周期配置将被删除，已有训练记录不受影响。';
  static const duplicate = '复制';
  static const duplicatePlan = '复制此计划';
  static const duplicateSavedPlanSuccess = '已复制已保存的计划版本';
  static const moreActions = '更多操作';
  static const inProgress = '进行中';
  static const inactive = '当前未生效';
  static const restDay = '休息日';
  static const trainingDay = '训练日';
  static const restHint = '休息日 — 好好休息';
  static const toTrainingDay = '改为训练日';
  static const toRestDay = '设为休息日';
  static const restClearHint = '设为休息日会清除此日的动作和训练组。';
  static const confirmChange = '确认更改';
  static const contentsClearTitle = '确认清除内容？';
  static const cycleShrinkHint = '缩短周期会移除超出范围的周期日及其动作和组。';
  static const cycleResetHint = '周期长度已改变。请选择生效日期，该日将作为新周期 D1。';
  static const cycleKeepHint = '周期长度不变，沿用原开始日期计算，周期位置不会重置。';
  static const revisionConflict = '此日期的计划已被训练使用，请选择更晚的生效日期再保存。';
  static const invalidEffectiveDate = '生效日期不能早于上一版本';
  static const chooseEffectiveDate = '请选择本次修改的生效日期';
  static const done = '完成';
  static const dayName = '周期日名称';
  static const jumpDay = '跳转 / 搜索周期日';
  static const daySearchHint = '输入周期日序号或名称';
  static const copyDay = '复制到其他周期日';
  static const copyDayHint = '目标周期日的内容将被当前日覆盖。';
  static const noDayExercises = '点击“添加动作”开始安排今日训练';
  static const editSets = '编辑训练组';
  static const batchAddSets = '批量添加组';
  static const setCount = '组数';
  static const weight = '计划重量';
  static const reps = '每组次数';
  static const targetRest = '目标休息时长（秒）';
  static const exerciseNote = '动作备注';
  static const noSetsHint = '尚无训练组，添加至少一组后才会纳入训练清单。';
  static const removeExercise = '删除动作';
  static const removeSet = '删除训练组';
  static const removeItemHint = '该项将从当前草稿移除，保存后生效。';
  static const moveUp = '上移';
  static const moveDown = '下移';
  static const discardDraft = '放弃未保存修改？';
  static const discardDraftHint = '未保存的编辑将丢失。';
  static const discard = '放弃修改';
  static String generatedDays(int n) => '系统将生成 $n 个周期日（D1–D$n），可单独配置训练或休息';
  static String viewDays(int n) => '查看 $n 个周期日';
  static String daySummary(int exercises, int sets) =>
      '$exercises 个动作 · $sets 组';
  static String cycleSummary(int length, int? current) =>
      '$length 天 / 轮 · ${current == null ? inactive : '当前 D$current'}';
  static String rangeSummary(int cycles, int days) =>
      '完整轮次 $cycles 轮 · 剩余天数 $days 天';
  static String planPriority(int value) => '优先级 $value';
  static String modifiedOn(String date) => '修改于 $date';
  static String dateSpan(String start, String? end) =>
      '$start 至 ${end ?? '不限期'}';
  static String fixedCycles(int count) => '$count 个完整周期';
  static String cycleCountValue(int count) => '$count 轮';
  static String dayCountValue(int count) => '$count 天';
  static String upcomingRevision(String date) => '新版本将于 $date 生效';
  static String setSummary(int count) => '$count 组';

  static String planExerciseWeightSummary(int count, num weight, String unit) {
    final unitLabel = weightUnitLabels[unit]!;
    final weightLabel = unit == 'bodyweight' || unit == 'none'
        ? unitLabel
        : '${compactNumber(weight)}$unitLabel';
    return '$count组 · $weightLabel';
  }

  static String planExerciseSummary(
    int count,
    num weight,
    String unit,
    int reps,
  ) =>
      '$count组 · ${compactNumber(weight)}${weightUnitLabels[unit]} · $reps次';
  static String variedPlanExerciseSummary(int count, String details) =>
      '$count组 · $details';
  static String setRow(int index, num weight, String unit, int reps) =>
      '第 $index 组 · $weight ${weightUnitLabels[unit]} × $reps 次';
  static String ordinal(int index) => index.toString().padLeft(2, '0');
  static String deletePlanTitle(String name) => '删除「$name」？';
  static const primaryTabLabels = [
    todayTab,
    plansTab,
    calendarTab,
    exercisesTab,
  ];
  static const duplicateExerciseName = '已有同名动作，请修改名称后重试。';
  static const cancel = '取消';
  static const confirmDelete = '确认删除';
  static const exerciseWriteFailed = '保存失败，输入内容已保留，请重试。';
  static const pickExercise = '选择动作';
  static const alreadyAdded = '已添加';
  static const close = '关闭';
  static const newExercise = '新建动作';
  static const editExercise = '编辑动作';
  static const exerciseDetail = '动作详情';
  static const edit = '编辑';
  static const back = '返回';
  static const add = '添加';
  static const save = '保存';
  static const saveChanges = '保存修改';
  static const saving = '正在保存…';
  static const searchExercise = '搜索动作名称';
  static const clearSearch = '清除搜索';
  static const allCategories = '全部';
  static const allEquipment = '全部器械';
  static const recentExercises = '最近使用';
  static const noRecentExercises = '开始训练后，使用过的动作会显示在这里。';
  static const allExercises = '全部动作';
  static const noMatchingExercises = '没有找到匹配的动作';
  static const exerciseLoadFailed = '动作加载失败，请重试。';
  static const exerciseDeleted = '此动作已不存在';
  static const exerciseNameLabel = '动作名称 *';
  static const exerciseNameHint = '例如：杠铃卧推';
  static const exerciseNameRequired = '动作名称不能为空';
  static const categoryLabel = '部位分类';
  static const equipmentLabel = '器械类型';
  static const unitLabel = '计重单位';
  static const notesLabel = '动作说明（可选）';
  static const notesHint = '描述动作要点、注意事项或个人笔记…';
  static const exercisePreview = '动作名称预览';
  static const previewInitial = '…';
  static const deleteExercise = '删除此动作';
  static const deleteExerciseExplanation =
      '该动作将从动作库中移除。历史训练记录中已有的数据不受影响。此操作无法撤销。';
  static const exerciseDeleteFailed = '删除失败，动作仍保留，请重试。';
  static const createExerciseHint = '创建自定义动作并添加到库';
  static const weightUnitLabels = {
    'kg': 'kg',
    'lb': 'lb',
    'bodyweight': '自重',
    'none': '无重量',
  };
  static String exerciseCount(int count) => '$count 个动作';
  static String deleteExerciseTitle(String name) => '删除「$name」？';
  static String exerciseSubtitle(
    String category,
    String equipment,
    String unit,
  ) =>
      '${exerciseCategoryLabels[category]} · ${exerciseEquipmentLabels[equipment]} · ${weightUnitLabels[unit]}';
  static const appName = '健身计数';
  static const todayTab = '今日';
  static const plansTab = '计划';
  static const calendarTab = '日历';
  static const exercisesTab = '动作';
  static const todayTitle = '今日';
  static const plansTitle = '训练计划';
  static const calendarTitle = '训练日历';
  static const exercisesTitle = '动作库';
  static const settings = '设置';
  static const trainingPreferences = '训练偏好';
  static const trainingExperience = '训练体验';
  static const calendarSettings = '日历';
  static const appearance = '界面风格';
  static const about = '关于';
  static const developerTools = '开发工具';
  static const seedTestData = '填充测试数据';
  static const seedTestDataHint = '添加测试动作、训练计划和历史记录';
  static const seedTestDataTitle = '填充测试数据？';
  static const seedTestDataConfirmation =
      '只会补充带“[测试]”标记的数据，不会覆盖你现有的动作、计划或训练记录。';
  static const seedTestDataConfirm = '开始填充';
  static const seedTestDataRunning = '正在填充测试数据…';
  static const seedTestDataComplete = '测试数据已就绪';
  static const seedTestDataNoChanges = '测试数据已存在，无需重复填充';
  static const seedTestDataFailed = '填充失败，已保留成功写入的数据，可重试。';
  static const seedTestDataActiveWorkout = '当前有未结束训练，已跳过测试历史记录。';
  static const defaultWeightUnit = '默认重量单位';
  static const defaultRestDuration = '默认休息时长';
  static const restReminder = '休息提醒';
  static const vibrationFeedback = '震动反馈';
  static const screenAwake = '保持屏幕常亮';
  static const weekStart = '一周起始日';
  static const chooseTheme = '选择主题';
  static const version = '版本';
  static const versionValue = '1.0.0 (1)';
  static const privacyPolicy = '隐私政策';
  static const userAgreement = '用户协议';
  static const monday = '周一';
  static const sunday = '周日';
  static const seconds = '秒';
  static const builtInTheme = '内置主题';
  static String themeVersion(String version) => 'v$version';
  static const notificationPermissionDenied = '通知权限未开启';
  static const notificationPermissionGranted = '通知权限已开启';
  static const exactAlarmDenied = '精确提醒不可用';
  static const exactAlarmGranted = '精确提醒可用';
  static const permissionUnavailable = '权限状态暂不可用';
  static const permissionRefreshing = '正在检查权限状态';
  static const permissionActionFailed = '权限请求失败，请重试';
  static const permissionTimingDegraded = '定时提醒状态降级';
  static const retryPermission = '重新检查';
  static const requestNotificationPermission = '开启通知权限';
  static const requestExactAlarmPermission = '允许精确提醒';
  static const settingsSaveFailed = '设置未保存，已恢复上次值，请重试。';
  static const settingsRetry = '重试保存';
  static String defaultRestValue(int seconds) => '$seconds 秒';
  static const createPlan = '创建训练计划';
  static const createExercise = '添加动作';
  static const todaysTraining = '今日训练';
  static const noExercisesToday = '暂无安排的动作';
  static const noExercisesTodayHint = '创建计划，或从自由训练开始。';
  static const todayLoadFailed = '今日训练加载失败，请重试。';
  static const todayLoading = '正在加载今日训练';
  static const todayRestTitle = '今日休息';
  static const todayRestHint = '休息也是训练的一部分。';
  static const todayTraining = '今天，练得漂亮';
  static const currentWorkout = '当前场次';
  static const resumeWorkout = '继续训练';
  static const resumeWorkoutUnavailable = '训练恢复将在后续版本提供';
  static const trainingDuration = '训练时长';
  static const workoutMode = '训练';
  static const restMode = '休息';
  static const restTitle = '组间休息';
  static const restTargetReached = '已超目标';
  static const startNextSet = '结束休息，开始下一组';
  static const chooseAnotherSet = '选择其他组';
  static const nextSetLabel = '下一组';
  static const laterSetLabel = '随后';
  static const addTraining = '添加训练';
  static const finishWorkout = '完成训练';
  static const earlyEndTitle = '结束本次训练？';
  static const continueTraining = '继续训练';
  static const endAndSave = '结束并保存已完成内容';
  static const cannotSaveEmptyWorkout = '至少完成一组后才能保存训练。';
  static const emptyWorkoutCompletionHint = '尚未完成任何训练组，不能保存本次训练。';
  static const discardWorkout = '放弃本次训练';
  static const discardWorkoutTitle = '确认放弃本次训练？';
  static const discardWorkoutHint = '本次训练的所有进度将被删除，此操作无法撤销。';
  static const confirmDiscardWorkout = '确认放弃';
  static const workoutSummary = '训练完成';
  static const workoutSummaryTitle = '训练总结';
  static const summaryHint = '整理本次训练，然后保存记录。';
  static const workoutNote = '训练备注';
  static const workoutNoteHint = '记录感受、状态或下次调整…';
  static const saveWorkout = '保存训练';
  static const workoutSaveFailed = '保存失败，备注和训练进度已保留。';
  static const editWorkoutData = '修改数据';
  static const skipActions = '跳过操作';
  static const addDeleteActions = '添加/删除';
  static const actualWeight = '实际重量';
  static const actualReps = '实际次数';
  static const repsUnit = '次';
  static String currentSetContext(String exercise, int setNumber) =>
      '$exercise · 第 $setNumber 组';
  static const confirmEdit = '确认修改';
  static const skipSelectedSet = '跳过本组';
  static const skipSelectedSetHint = '标记当前选中组为已跳过，进入下一组';
  static const skipSelectedExercise = '跳过此动作剩余组';
  static const skipSelectedExerciseHint = '将该动作所有未完成的组标记为跳过';
  static const addTemporaryWorkoutExercise = '临时添加动作';
  static const addTemporaryWorkoutExerciseHint = '从动作库选择，仅影响本次训练';
  static const addWorkoutSetHint = '复制当前处方，仅影响本次训练';
  static const deleteSelectedSet = '删除选中组';
  static const moveExerciseEarlier = '动作前移';
  static const moveExerciseLater = '动作后移';
  static const noSelectedSet = '请先选择一个训练组';
  static const invalidActualValues = '请输入有效的重量和次数。';
  static const timeAnomalyTitle = '训练计时需要确认';
  static const timeAnomalyHint = '系统时间发生了较大变化。确认后将舍弃异常时间段，并保留已完成训练。';
  static const confirmTime = '确认并继续训练';
  static const totalTrainingDuration = '总训练时长';
  static const completedExercises = '完成动作';
  static const skippedSets = '跳过组数';
  static const unfinishedSets = '未完成';
  static const workoutDetails = '本次训练详情';
  static const returnToWorkout = '返回继续训练';
  static const restoringWorkout = '正在恢复训练…';
  static const endWorkout = '结束';
  static const startSelectedSet = '开始本组';
  static const completeCurrentSet = '完成本组';
  static const allSetsCompleted = '全部组已完成';
  static const pendingSet = '待练';
  static const activeSet = '进行';
  static const doneSet = '完成';
  static const skippedSet = '跳过';
  static const bodyweight = '体重';
  static const workoutUnavailable = '未找到可恢复的训练，已返回今日。';
  static const workoutCommandFailed = '操作未保存，请重试。';
  static const startTodayWorkout = '开始今日训练';
  static const startFreeWorkout = '开始自由训练';
  static const plannedExercises = '今日动作';
  static const completedSets = '已完成组';
  static const allSetsDone = '全部完成';
  static String exerciseCompletion(int completed, int total) =>
      '$completed/$total 组完成';
  static const totalWorkouts = '累计训练';
  static const weeklyWorkouts = '本周训练';
  static const monthlyWorkouts = '本月训练';
  static const noPlanActionHint = '添加计划，或直接开始自由训练。';
  static const trainingPreparation = '训练前准备';
  static const freeWorkout = '自由训练';
  static const preparationHint = '调整仅影响本次，不修改原计划。';
  static const freeWorkoutHint = '添加你想练的动作，自由安排训练。';
  static const noPreparedExercises = '还没有添加动作';
  static const noPreparedExercisesHint = '从动作库选择后，可在这里编辑本次训练。';
  static const addExercise = '添加动作';
  static const addTemporaryExercise = '临时添加动作';
  static const addSet = '添加一组';
  static const removeSetAction = '删除训练组';
  static const removeExerciseAction = '删除动作';
  static const plannedRest = '目标休息';
  static const startTimer = '确认并开始计时';
  static const startingWorkout = '正在开始训练…';
  static const workoutStartFailed = '训练未能开始，准备内容已保留。';
  static const retryWorkoutStart = '重试开始';
  static const workoutStarted = '训练已安全开始';
  static const workoutStartedPendingScreen = '训练数据已保存，可以安全返回今日页。';
  static const backToToday = '返回今日';
  static const startTimerUnavailable = '训练开始将在后续版本提供';
  static const preparationStartPending = '已完成训练准备，开始训练功能即将提供。';
  static const preparationLoadFailed = '训练准备加载失败，已保留当前页面。';
  static const secondsSuffix = '秒';
  static const multiplicationSign = '×';
  static const moveExerciseUp = '上移动作';
  static const moveExerciseDown = '下移动作';
  static const moveSetUp = '上移训练组';
  static const moveSetDown = '下移训练组';
  static const setNumber = '组';
  static const sourceTemporary = '本次临时添加';
  static const invalidWeight = '请输入不小于 0 的重量';
  static const invalidReps = '次数必须是大于 0 的整数';
  static String preparationSource(
    String plan,
    String revision,
    int day,
    String name,
  ) =>
      '计划：$plan · 版本 $revision · D$day $name';
  static String plannedSource(String plan, int day) => '$plan · D$day';
  static String mergedPlanSources(int count) => '$count 个计划合并';
  static const mergedTrainingTitle = '今日合并训练';
  static String plannedSummary(int exercises, int sets) =>
      '$exercises 个动作 · $sets 组';
  static String plannedExerciseSummary(int sets, num weight, String unit) =>
      '$sets 组 · ${compactNumber(weight)} ${weightUnitLabels[unit]}';
  static String compactNumber(num value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();
  static const workoutPhaseLabels = {
    'active': '训练进行中',
    'resting': '组间休息中',
    'completedPaused': '训练已暂停，等待结束或继续',
    'finishing': '训练正在等待保存',
    'timeAnomaly': '训练计时需要确认',
  };
  static String workoutPhaseLabel(String phase) =>
      workoutPhaseLabels[phase] ?? currentWorkout;
  static String workoutProgress(int completed, int total) =>
      '已完成 $completed / $total 组';
  static String targetRestSummary(int seconds) => '目标休息 $seconds 秒';
  static String setReps(int reps) => '$reps 次';
  static String restRemaining(String value) => '还剩 $value';
  static String nextSet(String exercise, int setNumber) =>
      '接下来：$exercise · 第 $setNumber 组';
  static String completedSetCount(int count) => '完成 $count 组';
  static String earlyEndConsequence(int count) => '其余 $count 组将标记为跳过';
  static const sourcePlan = '计划';
  static const noPlans = '还没有训练计划';
  static const noPlansHint = '创建第一个周期计划，安排训练与休息。';
  static const noWorkoutHistory = '还没有训练记录';
  static const noWorkoutHistoryHint = '完成并保存训练后，记录会显示在这里。';
  static const noExercises = '动作库是空的';
  static const noExercisesHint = '添加第一个动作，开始建立你的动作库。';
  static const themeLoading = '正在加载界面主题';
  static const themeLoadFailed = '界面主题加载失败';
  static const themeLoadFailedHint = '请检查内置主题数据后重试。';
  static const retry = '重试';
  static const exerciseCategoryLabels = <String, String>{
    'chest': '胸部',
    'back': '背部',
    'shoulders': '肩部',
    'legs': '腿部',
    'arms': '手臂',
    'core': '核心',
    'full_body': '全身',
    'cardio': '有氧',
  };
  static const exerciseEquipmentLabels = <String, String>{
    'bodyweight': '自重',
    'barbell': '杠铃',
    'dumbbell': '哑铃',
    'machine': '器械',
    'cable': '绳索',
    'kettlebell': '壶铃',
    'resistance_band': '弹力带',
  };

  static String formatMonth(DateTime date) => '${date.year} 年 ${date.month} 月';
}
