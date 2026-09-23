const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function loadCore() {
  const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
  const match = html.match(/<script id="prototype-core">([\s\S]*?)<\/script>/);
  assert.ok(match, '缺少 #prototype-core 脚本块');
  const sandbox = { window: {} };
  vm.runInNewContext(match[1], sandbox);
  return sandbox.window.FitnessPrototypeCore;
}

function readHtml() {
  return fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
}

/** 取出指定选择器单层规则块内的声明文本，避免整份样式表的子串误匹配。 */
function cssRule(html, selector) {
  const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = html.match(new RegExp(`(?:^|\\n)\\s*${escaped}\\s*\\{([^}]*)\\}`));
  assert.ok(match, `缺少 CSS 规则 ${selector}`);
  return match[1];
}

/** 取出控制器内指定函数的函数体文本，用于锁定不能被 CSS 断言覆盖的内部分支。 */
function jsFunctionBody(html, name) {
  const match = html.match(new RegExp(`function\\s+${name}\\s*\\([^)]*\\)\\s*\\{([\\s\\S]*?)\\n  \\}`));
  assert.ok(match, `缺少函数 ${name}`);
  return match[1];
}

const core = loadCore();

test('未知主题回退到默认主题 A', () => {
  assert.equal(core.resolveTheme(null), 'a');
  assert.equal(core.resolveTheme('broken'), 'a');
  assert.equal(core.resolveTheme('b'), 'b');
  assert.equal(core.resolveTheme('c'), 'c');
});

test('初始状态包含 3 个动作和 9 个待训练组', () => {
  const state = core.createInitialState(1_000);
  assert.equal(state.screen, 'today');
  assert.equal(state.sessionStatus, 'idle');
  assert.equal(state.exercises.length, 3);
  assert.equal(state.exercises.flatMap(item => item.sets).length, 9);
  assert.ok(state.exercises.flatMap(item => item.sets).every(set => set.status === 'pending'));
});

test('时长格式稳定且不显示负数', () => {
  assert.equal(core.formatDuration(-1), '00:00');
  assert.equal(core.formatDuration(65), '01:05');
  assert.equal(core.formatDuration(3_661), '1:01:01');
});

test('非有限时长统一格式化为 00:00', () => {
  assert.equal(core.formatDuration(Infinity), '00:00');
  assert.equal(core.formatDuration(-Infinity), '00:00');
  assert.equal(core.formatDuration(NaN), '00:00');
  assert.equal(core.formatDuration('not-a-number'), '00:00');
});

test('setTheme 返回新状态、不修改原状态并回退非法主题', () => {
  const state = core.createInitialState(0);
  const next = core.setTheme(state, 'c');
  assert.notEqual(next, state);
  assert.equal(next.theme, 'c');
  assert.equal(state.theme, 'a');
  assert.equal(core.setTheme(state, 'b').theme, 'b');
  assert.equal(core.setTheme(state, 'broken').theme, 'a');
});

test('混合组状态统计口径正确', () => {
  const state = core.createInitialState(0);
  const setsOf = id => state.exercises.find(item => item.id === id).sets;
  setsOf('bench')[0].status = 'completed';
  setsOf('bench')[1].status = 'completed';
  setsOf('press')[0].status = 'skipped';
  setsOf('pushdown')[0].status = 'active';

  const stats = core.getWorkoutStats(state);
  assert.equal(stats.total, 9);
  assert.equal(stats.completed, 2);
  assert.equal(stats.skipped, 1);
  assert.equal(stats.active, 1);
  assert.equal(stats.pending, 5);
  assert.equal(stats.completedExercises, 1);
});

test('训练完成一组后进入休息并可开始下一组', () => {
  let state = core.createInitialState();
  state = core.prepareWorkout(state);
  state = core.startWorkout(state, 1_000);
  state = core.startSelectedSet(state, 2_000);
  state = core.completeSelectedSet(state, 12_000);

  assert.equal(state.screen, 'rest');
  assert.equal(state.sessionStatus, 'resting');
  assert.equal(state.exercises[0].sets[0].status, 'completed');
  assert.equal(state.exercises[0].sets[0].durationSeconds, 10);
  assert.equal(core.canSaveWorkout(state), true);

  state = core.startNextSet(state, 20_000);
  assert.equal(state.screen, 'workout');
  assert.equal(state.selectedSetId, 'bench-2');
  assert.equal(state.exercises[0].sets[1].status, 'active');
});

test('零完成组不能保存训练', () => {
  let state = core.startWorkout(core.prepareWorkout(core.createInitialState()), 1_000);
  assert.equal(core.canSaveWorkout(state), false);
  assert.equal(core.finishWorkout(state, 5_000), state);
});

test('提前结束保留完成组并把其余组标为跳过', () => {
  let state = core.startWorkout(core.prepareWorkout(core.createInitialState()), 1_000);
  state = core.startSelectedSet(state, 2_000);
  state = core.completeSelectedSet(state, 7_000);
  state = core.finishWorkout(state, 10_000);

  const statuses = state.exercises.flatMap(item => item.sets).map(set => set.status);
  assert.equal(state.screen, 'summary');
  assert.equal(statuses.filter(value => value === 'completed').length, 1);
  assert.equal(statuses.filter(value => value === 'skipped').length, 8);
  assert.equal(state.completedSummary.completed, 1);
});

test('HTML 壳层包含离线脚本、主题和无障碍锚点', () => {
  const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
  assert.match(html, /<script id="prototype-core">/);
  assert.match(html, /id="app-shell"/);
  assert.match(html, /id="screen-root"/);
  assert.match(html, /id="theme-switcher"/);
  assert.match(html, /id="live-status"[^>]*aria-live="polite"/);
  assert.match(html, /data-theme="a"/);
  assert.match(html, /--primary-action:\s*#C76F62/i);
});

test('主题菜单触发按钮语义与弹层角色一致', () => {
  const html = readHtml();
  const trigger = html.match(/<button[^>]*data-ui="toggle-theme-menu"[\s\S]*?>/);
  assert.ok(trigger, '缺少移动端主题菜单触发按钮');
  assert.match(trigger[0], /aria-controls="theme-menu"/);
  assert.match(trigger[0], /aria-expanded=/);
  assert.doesNotMatch(html, /aria-haspopup/);
  assert.match(html, /id="theme-menu"[^>]*role="group"/);
});

test('排版层级声明与 UI 规格一致', () => {
  const html = readHtml();

  const nameRule = cssRule(html, '.exercise__name');
  assert.match(nameRule, /font-size:\s*var\(--text-exercise\)/);
  assert.match(nameRule, /font-weight:\s*var\(--weight-semibold\)/);
  assert.match(nameRule, /line-height:\s*1\.35/);

  const metaRule = cssRule(html, '.exercise__meta');
  assert.match(metaRule, /font-size:\s*var\(--text-set\)/);
  assert.match(metaRule, /font-weight:\s*var\(--weight-medium\)/);
  assert.match(metaRule, /line-height:\s*1\.35/);

  for (const selector of ['.today-top__date', '.page-tag', '.hero__meta', '.stat__label']) {
    assert.match(cssRule(html, selector), /line-height:\s*1\.40/, `${selector} 应为 1.40 行高`);
  }
});

test('准备页可以折叠动作并只修改本次训练数据', () => {
  let state = core.prepareWorkout(core.createInitialState());
  state = core.toggleExercise(state, 'bench');
  assert.equal(state.exercises[0].collapsed, true);

  state = core.editSet(state, 'bench-1', { actualWeight: 62.5, actualReps: 7 });
  const set = state.exercises[0].sets[0];
  assert.equal(set.plannedWeight, 60);
  assert.equal(set.plannedReps, 8);
  assert.equal(set.actualWeight, 62.5);
  assert.equal(set.actualReps, 7);
  assert.equal(set.temporary, true);
});

test('训练中只能选择待训练组且可以添加临时组', () => {
  let state = core.startWorkout(core.prepareWorkout(core.createInitialState()), 1_000);
  state = core.startSelectedSet(state, 2_000);
  assert.equal(core.selectSet(state, 'press-1'), state);

  state = core.addTemporarySet(state, 'bench');
  const added = state.exercises[0].sets.at(-1);
  assert.equal(added.temporary, true);
  assert.equal(added.status, 'pending');
  assert.equal(state.exercises.flatMap(item => item.sets).length, 10);
});

test('跳过进行中组后仍处于执行阶段并选中下一组', () => {
  let state = core.startWorkout(core.prepareWorkout(core.createInitialState()), 1_000);
  state = core.startSelectedSet(state, 2_000);
  state = core.skipSelectedSet(state);

  // sessionStatus='active' 表示会话执行阶段，不保证当前必有 active set。
  assert.equal(state.screen, 'workout');
  assert.equal(state.sessionStatus, 'active');
  assert.equal(state.selectedSetId, 'bench-2');
  assert.equal(state.exercises[0].sets[0].status, 'skipped');
});

test('计时从绝对时间推导且不产生负数', () => {
  let state = core.startWorkout(core.prepareWorkout(core.createInitialState()), 10_000);
  state = core.startSelectedSet(state, 12_000);
  // deriveTimers 的返回值由 vm 上下文创建，其原型与测试 realm 不同，
  // 这里先用展开语法复制到测试 realm 再比较，避免 deepStrictEqual 误报原型不一致。
  assert.deepEqual({ ...core.deriveTimers(state, 15_000) }, {
    workoutSeconds: 5,
    setSeconds: 3,
    restSeconds: 0,
    restRemainingSeconds: 90,
    restOvertimeSeconds: 0
  });
  assert.equal(core.deriveTimers(state, 5_000).workoutSeconds, 0);
});

test('训练顶栏在滚动容器内固定且不透底', () => {
  const html = readHtml();
  const rule = cssRule(html, '.workout-top');
  assert.match(rule, /position:\s*sticky/);
  assert.match(rule, /inset-block-start:\s*0/);
  assert.match(rule, /z-index:\s*2/);
  assert.match(rule, /background:\s*var\(--app-bg\)/);
  // 顶栏位于滚动容器的水平内边距内，必须用负外边距让背景铺满，否则滚动内容会从两侧透出。
  assert.match(rule, /margin-inline:\s*calc\(-1\s*\*\s*var\(--gutter\)\)/);
  assert.match(rule, /padding-inline:\s*var\(--gutter\)/);
  // 工作页把滚动容器顶部内边距移到顶栏内部，顶栏才能贴住滚动区上沿，上方不留出透出内容的一条缝。
  assert.match(rule, /padding-block-start:\s*var\(--screen-pad-top\)/);
  assert.match(cssRule(html, '.screen[data-screen="workout"] .screen__scroll'), /padding-block-start:\s*0/);
  assert.match(cssRule(html, '.screen__scroll'), /padding:\s*var\(--screen-pad-top\)/);
});

test('进行中行与轨道节点使用同一进行中令牌，选中态保留主操作令牌', () => {
  const html = readHtml();
  const activeRow = cssRule(html, '.workout-set__row[data-state="active"]');
  assert.match(activeRow, /border-color:\s*var\(--active-state\)/);
  assert.match(activeRow, /box-shadow:\s*inset 0 0 0 2px var\(--active-state\)/);
  assert.doesNotMatch(activeRow, /primary-action/);
  assert.match(cssRule(html, '.workout-set__row[data-state="active"] .workout-set__status'), /color:\s*var\(--active-state\)/);
  assert.match(cssRule(html, '.workout-set__row[aria-pressed="true"]'), /var\(--primary-action\)/);
});

test('结束按钮显示文字且保持 12px / 1 / 700 与 48px 点击区', () => {
  const html = readHtml();
  const rule = cssRule(html, '.workout-end');
  assert.match(rule, /inline-size:\s*var\(--tap-size\)/);
  assert.match(rule, /block-size:\s*var\(--tap-size\)/);
  assert.match(rule, /font-size:\s*var\(--text-exercise\)/);
  assert.match(rule, /font-weight:\s*var\(--weight-bold\)/);
  assert.match(rule, /line-height:\s*1;/);
  assert.doesNotMatch(html, /workout-end__glyph/);

  const button = html.match(/<button[^>]*class="workout-end"[^>]*>([\s\S]*?)<\/button>/);
  assert.ok(button, '缺少训练页结束按钮');
  assert.match(button[0], /aria-label="结束训练"/);
  assert.equal(button[1].replace(/<[^>]*>/g, '').trim(), '结束');
});

test('禁用主按钮与可用主按钮外观不同且不依赖透明度', () => {
  const html = readHtml();
  const disabled = cssRule(html, '.button--primary[disabled]');
  assert.match(disabled, /background:\s*var\(--surface-card\)/);
  assert.match(disabled, /color:\s*var\(--text-muted\)/);
  assert.match(disabled, /border-style:\s*dashed/);
  assert.doesNotMatch(disabled, /opacity/);
  assert.match(cssRule(html, '.button--primary'), /background:\s*var\(--primary-action\)/);
});

test('轨道在无 active 且无 pending 时不谎报当前组序号', () => {
  const html = readHtml();
  const position = jsFunctionBody(html, 'trackPosition');
  assert.match(position, /return null/);
  assert.doesNotMatch(position, /stats\.completed\s*\+\s*stats\.skipped/);
  assert.match(jsFunctionBody(html, 'buildTrackLabel'), /当前无待训练组/);
  assert.match(jsFunctionBody(html, 'renderRhythmTrack'), /当前无待训练组/);
});

test('进行中行只声明 aria-current，不与 aria-pressed 并存', () => {
  const html = readHtml();
  // 旧模板把 aria-pressed 与 aria-disabled 同时写在选中且进行中的行上，语义矛盾。
  assert.doesNotMatch(html, /aria-pressed="\$\{selected\}" \$\{selectable/);
  const body = jsFunctionBody(html, 'renderWorkoutSet');
  assert.match(body, /const pressed = selectable/);
  assert.match(body, /aria-current="step"/);
});

test('添加组后聚焦新增组行而不是列表末尾的添加按钮', () => {
  const html = readHtml();
  assert.doesNotMatch(html, /pendingFocus = '\[data-action="ADD_SET"\]'/);
  const body = jsFunctionBody(html, 'dispatch');
  assert.match(body, /\[data-set-row="\$\{added\.id\}"\]/);
});

test('训练页三个次按钮使用按钮字号且保留 48px 触控区', () => {
  const html = readHtml();
  assert.match(cssRule(html, '.workout-secondary .button--ghost'), /font-size:\s*var\(--text-button\)/);
  assert.match(cssRule(html, '.button--ghost'), /block-size:\s*var\(--tap-size\)/);
});

test('休息中可选择其他待训练组并立即开始', () => {
  let state = core.startWorkout(core.prepareWorkout(core.createInitialState()), 1_000);
  state = core.startSelectedSet(state, 2_000);
  state = core.completeSelectedSet(state, 5_000);
  state = core.chooseNextSet(state, 'press-1', 8_000);

  assert.equal(state.screen, 'workout');
  assert.equal(state.selectedSetId, 'press-1');
  assert.equal(state.exercises[1].sets[0].status, 'active');
  assert.equal(state.restStartedAt, null);
});

test('休息计时到达目标后继续累计', () => {
  let state = core.startWorkout(core.prepareWorkout(core.createInitialState()), 1_000);
  state = core.startSelectedSet(state, 2_000);
  state = core.completeSelectedSet(state, 3_000);
  const timers = core.deriveTimers(state, 98_000);
  assert.equal(timers.restSeconds, 95);
  assert.equal(timers.restRemainingSeconds, 0);
  assert.equal(timers.restOvertimeSeconds, 5);
});

test('总结备注保留且完成后回到今日已完成状态', () => {
  let state = core.startWorkout(core.prepareWorkout(core.createInitialState()), 1_000);
  state = core.startSelectedSet(state, 2_000);
  state = core.completeSelectedSet(state, 8_000);
  state = core.finishWorkout(state, 10_000);
  state = core.setNotes(state, '肩部状态稳定');
  state = core.completeSession(state);

  assert.equal(state.screen, 'today');
  assert.equal(state.sessionStatus, 'completed');
  assert.equal(state.notes, '肩部状态稳定');
  assert.equal(state.completedSummary.completed, 1);
});

test('放弃训练恢复默认空闲状态但保留当前主题', () => {
  let state = core.setTheme(core.createInitialState(), 'c');
  state = core.startWorkout(core.prepareWorkout(state), 1_000);
  state = core.discardWorkout(state);
  assert.equal(state.screen, 'today');
  assert.equal(state.sessionStatus, 'idle');
  assert.equal(state.theme, 'c');
});

test('备注超过 300 字符被截断', () => {
  const long = 'a'.repeat(320);
  const state = core.setNotes(core.createInitialState(), long);
  assert.equal(state.notes.length, 300);
  assert.equal(state.notes, long.slice(0, 300));
  assert.equal(core.setNotes(core.createInitialState(), null).notes, '');
});

test('completeSession 仅在总结阶段生效', () => {
  const idle = core.createInitialState();
  assert.equal(core.completeSession(idle), idle);
});

test('重复保存训练幂等且不重算时长', () => {
  let state = core.startWorkout(core.prepareWorkout(core.createInitialState()), 1_000);
  state = core.startSelectedSet(state, 2_000);
  state = core.completeSelectedSet(state, 7_000);
  const saved = core.finishWorkout(state, 10_000);
  assert.equal(saved.completedSummary.workoutSeconds, 9);
  const again = core.finishWorkout(saved, 99_000);
  assert.equal(again, saved);
  assert.equal(again.completedSummary.workoutSeconds, 9);
});

test('重复开始训练不覆盖既有开始时间', () => {
  const started = core.startWorkout(core.prepareWorkout(core.createInitialState()), 1_000);
  assert.equal(core.startWorkout(started, 5_000).workoutStartedAt, 1_000);
});

test('计时推导对非有限起点与当前时间加 0 保护', () => {
  const state = {
    ...core.createInitialState(),
    workoutStartedAt: Infinity,
    activeSetStartedAt: NaN,
    restStartedAt: undefined
  };
  const timers = { ...core.deriveTimers(state, 5_000) };
  assert.equal(timers.workoutSeconds, 0);
  assert.equal(timers.setSeconds, 0);
  assert.equal(timers.restSeconds, 0);
  assert.equal(timers.restRemainingSeconds, 90);
  assert.equal({ ...core.deriveTimers(state, NaN) }.workoutSeconds, 0);
});

test('结束 Bottom Sheet 与放弃二次确认具备覆盖层语义', () => {
  const html = readHtml();
  assert.match(html, /id="end-sheet"/);
  assert.match(html, /id="end-sheet-title"/);
  assert.match(html, /role="dialog"/);
  assert.match(html, /id="discard-dialog"/);
  assert.match(html, /role="alertdialog"/);
  assert.match(html, /aria-modal="true"/);
  assert.match(html, /data-action="SAVE_PARTIAL"/);
  assert.match(html, /data-action="OPEN_DISCARD_CONFIRM"/);
  assert.match(html, /data-action="CONFIRM_DISCARD"/);
  assert.match(html, /data-action="CLOSE_DISCARD_CONFIRM"/);
});

test('结束入口在训练与休息共用且带关闭后恢复焦点的角色', () => {
  const html = readHtml();
  assert.match(html, /data-role="end-trigger"/);
  const entries = html.match(/data-action="OPEN_END_SHEET"/g) || [];
  assert.ok(entries.length >= 2, '训练页与休息页都应提供结束入口');
});

test('总结备注与 core 一致限制 300 字并走局部更新', () => {
  const html = readHtml();
  assert.match(html, /data-role="notes"/);
  assert.match(html, /maxlength="300"/);
  assert.match(jsFunctionBody(html, 'dispatch'), /SET_NOTES/);
  assert.match(html, /addEventListener\('input'/);
});

test('总结页保留收束轨道与固定底栏声明', () => {
  const html = readHtml();
  assert.match(cssRule(html, '.rhythm--closing'), /gap:/);
  assert.match(cssRule(html, '.summary-footer'), /border-block-start/);
});

test('Task 5 的结束提示临时路径已彻底移除', () => {
  const html = readHtml();
  assert.doesNotMatch(html, /endSheetNotice/);
  assert.doesNotMatch(html, /workout-end-notice/);
});

test('覆盖层打开时背景禁用且 Escape 顶层优先级为 dialog 优先', () => {
  const html = readHtml();
  assert.match(html, /\.inert\s*=\s*true/);
  assert.match(html, /discardDialogOpen[\s\S]{0,400}?endSheetOpen[\s\S]{0,400}?themeMenuOpen/);
});

// —— Task 7 修复轮次 1：模态层叠 / 阻断 / XSS / 焦点陷阱 / aria-controls ——

test('二次确认对话框与结束 Sheet 共用同一网格单元，避免堆叠挤压', () => {
  const html = readHtml();
  const match = html.match(/\.overlay-layer\s*>\s*\.end-sheet\s*,[\s\S]{0,200}?\.overlay-layer\s*>\s*\.discard-dialog\s*\{([^}]*)\}/);
  assert.ok(match, '缺少覆盖层共用网格单元声明');
  assert.match(match[1], /grid-area:\s*1\s*\/\s*1/);
  // 二次确认时遮罩必须抬到 Sheet 之上：点 Sheet 区域只会落到遮罩，不会误触保存。
  assert.match(html, /\.overlay-layer--dialog\s+\.overlay-mask\s*\{[^}]*z-index/);
  assert.match(html, /overlay-layer\$\{[^}]*overlay-layer--dialog/);
});

test('二次确认打开时底层结束 Sheet 被 inert 阻断', () => {
  const html = readHtml();
  const body = jsFunctionBody(html, 'render');
  assert.match(body, /discardDialogOpen[\s\S]{0,240}#end-sheet[\s\S]{0,240}inert\s*=\s*true/);
});

test('二次确认期间脚本派发 SAVE_PARTIAL 也不能把放弃偷换成保存', () => {
  const html = readHtml();
  const body = jsFunctionBody(html, 'dispatch');
  assert.match(body, /SAVE_PARTIAL'\)\s*\{[\s\S]{0,200}?discardDialogOpen\)\s*return/);
});

test('escapeHtml 转义全部五个危险字符', () => {
  const html = readHtml();
  const body = jsFunctionBody(html, 'escapeHtml');
  assert.match(body, /&amp;/);
  assert.match(body, /&lt;/);
  assert.match(body, /&gt;/);
  assert.match(body, /&quot;/);
  assert.match(body, /&#39;/);
});

test('备注与动态文本全部走 escapeHtml，核心状态保留原文', () => {
  const html = readHtml();
  // 备注：不允许任何裸插；只读视图与 textarea 两个 sink 都必须转义。
  assert.doesNotMatch(html, /\$\{state\.notes\}/);
  assert.match(jsFunctionBody(html, 'renderCompletedCard'), /escapeHtml\(note\)/);
  assert.match(jsFunctionBody(html, 'renderSummaryBody'), /escapeHtml\(noteText\)/);
  assert.match(jsFunctionBody(html, 'renderSummaryBody'), /escapeHtml\(state\.notes\)/);

  // 动作名：所有插入 innerHTML 的渲染函数都转义。
  for (const name of ['renderExerciseSummary', 'renderPrepareExercise', 'renderWorkoutExercise', 'renderRestChooser', 'renderSummaryBody']) {
    assert.match(jsFunctionBody(html, name), /escapeHtml\(exercise\.name\)/, `${name} 未转义 exercise.name`);
  }
  const restBody = jsFunctionBody(html, 'renderRest');
  assert.match(restBody, /escapeHtml\(next\.exercise\.name\)/);
  assert.match(restBody, /escapeHtml\(after\.exercise\.name\)/);

  // 计划名 / 来源：today、完成卡、准备页、总结页都转义。
  for (const name of ['renderToday', 'renderCompletedCard', 'renderPrepare', 'renderSummaryBody']) {
    assert.match(jsFunctionBody(html, name), /escapeHtml\(WORKOUT_PLAN\.(?:name|source)\)/, `${name} 未转义计划名/来源`);
  }

  // 兜底：任何裸插若紧跟 HTML 标签或分隔点都应消失（announce 走 textContent，不计入）。
  assert.doesNotMatch(html, /\$\{(?:next\.|after\.)?exercise\.name\}(?=\s*[<·])/);
  assert.doesNotMatch(html, /\$\{WORKOUT_PLAN\.(?:name|source)\}(?=\s*<)/);

  // core 层不转义：状态里保留用户原文，转义只发生在渲染边界。
  const payload = '<img src=x onerror="window.__xss=1">';
  assert.equal(core.setNotes(core.createInitialState(), payload).notes, payload);
});

test('Tab 焦点陷阱通用化并优先困在最上层覆盖层', () => {
  const html = readHtml();
  const body = jsFunctionBody(html, 'trapTabWithin');
  assert.match(body, /if\s*\(!focusables\.length\)\s*return/);
  assert.match(body, /focusables\.indexOf\(document\.activeElement\)/);
  assert.match(body, /event\.shiftKey/);
  // 调用点：二次确认优先于结束 Sheet
  assert.match(html, /discardDialogOpen\s*\)\s*\{\s*trapTabWithin\('#discard-dialog'[\s\S]{0,200}?endSheetOpen\s*\)\s*\{\s*trapTabWithin\('#end-sheet'/);
});

test('完成卡查看总结按钮用 aria-controls 指向始终存在的只读容器', () => {
  const html = readHtml();
  const body = jsFunctionBody(html, 'renderCompletedCard');
  assert.match(body, /aria-controls="completed-review"/);
  assert.match(body, /id="completed-review"[^>]*\$\{[^}]*completedSummaryOpen[^}]*'hidden'/);
  // 收起/展开后焦点仍回到切换按钮，不因容器常驻而退化。
  assert.match(jsFunctionBody(html, 'dispatch'), /pendingFocus = '\[data-action="TOGGLE_SUMMARY_VIEW"\]'/);
});

// —— Task 8 最终响应式 / 无障碍 / 减弱动画 / 视觉契约 ——

test('HTML 包含响应式、减弱动画和关键对话框语义', () => {
  const html = readHtml();
  assert.match(html, /@media\s*\(max-width:\s*520px\)/);
  assert.match(html, /@media\s*\(prefers-reduced-motion:\s*reduce\)/);
  assert.match(html, /env\(safe-area-inset-bottom\)/);
  assert.match(html, /role="alertdialog"/);
  assert.match(html, /aria-label="结束训练"/);
  assert.doesNotMatch(html, /https?:\/\//);
});

test('初始状态锁定完整结构与演示计划', () => {
  const state = core.createInitialState(1_000);
  assert.equal(state.screen, 'today');
  assert.equal(state.theme, 'a');
  assert.equal(state.sessionStatus, 'idle');
  assert.equal(state.workoutStartedAt, null);
  assert.equal(state.activeSetStartedAt, null);
  assert.equal(state.restStartedAt, null);
  assert.equal(state.restTargetSeconds, 90);
  assert.equal(state.selectedSetId, 'bench-1');
  assert.equal(state.completedSummary, null);
  assert.equal(state.notes, '');

  // 用 JSON 归一化到测试 realm，避免 vm 原型导致的 deepStrictEqual 误报。
  const structure = JSON.parse(JSON.stringify(state.exercises.map(exercise => ({
    id: exercise.id,
    name: exercise.name,
    collapsed: exercise.collapsed,
    ids: exercise.sets.map(set => set.id),
    plannedWeight: exercise.sets[0].plannedWeight,
    plannedReps: exercise.sets[0].plannedReps
  }))));
  assert.deepEqual(structure, [
    { id: 'bench', name: '杠铃卧推', collapsed: false, ids: ['bench-1', 'bench-2', 'bench-3'], plannedWeight: 60, plannedReps: 8 },
    { id: 'press', name: '哑铃肩推', collapsed: false, ids: ['press-1', 'press-2', 'press-3'], plannedWeight: 16, plannedReps: 10 },
    { id: 'pushdown', name: '绳索下压', collapsed: false, ids: ['pushdown-1', 'pushdown-2', 'pushdown-3'], plannedWeight: 25, plannedReps: 12 }
  ]);
  assert.ok(state.exercises.flatMap(item => item.sets).every(set =>
    set.status === 'pending'
    && set.durationSeconds === 0
    && set.temporary === false
    && set.actualWeight === set.plannedWeight
    && set.actualReps === set.plannedReps
  ));
});

test('hidden 属性靠层叠顺序生效而不依赖 !important', () => {
  const html = readHtml();
  const rule = cssRule(html, '[hidden]');
  assert.match(rule, /display:\s*none/);
  assert.doesNotMatch(rule, /!important/);
  // 组件层用单层 class 声明 display，[hidden] 必须排在这些规则之后才能在同等优先级下胜出。
  const hiddenAt = html.search(/\n\s*\[hidden\]\s*\{/);
  assert.ok(hiddenAt > -1, '缺少 [hidden] 规则');
  for (const selector of ['.prep-sets', '.theme-menu', '.completed-review', '.rest-chooser']) {
    const at = html.search(new RegExp(`\\n\\s*\\${selector}\\s*\\{`));
    assert.ok(at > -1, `缺少 ${selector}`);
    assert.ok(hiddenAt > at, `[hidden] 必须位于 ${selector} 之后`);
  }
});

test('窄桌面视口下演示栏与手机画布可换行避免横向滚动', () => {
  const html = readHtml();
  const layoutBody = html.match(/\n\s*body\s*\{[^}]*display:\s*flex[^}]*\}/);
  assert.ok(layoutBody, '缺少 body 弹性布局规则');
  assert.match(layoutBody[0], /flex-wrap:\s*wrap/);
  assert.match(html, /@media\s*\(max-width:\s*520px\)/);
});

test('首帧前按本地存储同步主题避免闪烁', () => {
  const html = readHtml();
  const head = html.match(/<head>([\s\S]*?)<\/head>/);
  assert.ok(head, '缺少 head');
  assert.match(head[1], /localStorage\.getItem\('fitness-theme'\)/);
  assert.match(head[1], /documentElement\.setAttribute\('data-theme'/);
});

test('减弱动画模式取消动画与位移动效', () => {
  const html = readHtml();
  const block = html.match(/@media\s*\(prefers-reduced-motion:\s*reduce\)\s*\{([\s\S]*?)\n    \}/);
  assert.ok(block, '缺少减弱动画媒体查询');
  assert.match(block[1], /animation-duration:\s*\.01ms\s*!important/);
  assert.match(block[1], /animation:\s*none\s*!important/);
  assert.match(block[1], /\.rest-ring__badge\s*\{\s*transform:\s*none\s*!important/);
});

test('准备页拖动手柄不作为空 Tab 停靠点', () => {
  const html = readHtml();
  const handle = html.match(/<button[^>]*class="prep-exercise__handle"[^>]*>/);
  assert.ok(handle, '缺少拖动手柄');
  assert.match(handle[0], /aria-disabled="true"/);
  assert.match(handle[0], /tabindex="-1"/);
});

test('训练/休息/准备页在移动端保留主题入口', () => {
  const html = readHtml();
  for (const name of ['renderPrepare', 'renderWorkout', 'renderRest']) {
    assert.match(jsFunctionBody(html, name), /themeTriggerButton\(\)/, `${name} 缺少主题入口`);
  }
  const helper = jsFunctionBody(html, 'themeTriggerButton');
  assert.match(helper, /data-ui="toggle-theme-menu"/);
  assert.match(helper, /aria-controls="theme-menu"/);
  assert.match(helper, /aria-expanded=/);
});

test('主题菜单由全局渲染且不在单屏内重复', () => {
  const html = readHtml();
  assert.match(jsFunctionBody(html, 'screenMarkup'), /renderThemeMenu\(\)/);
  assert.doesNotMatch(jsFunctionBody(html, 'renderToday'), /renderThemeMenu\(\)/);
});

test('桌面主题按钮切换后焦点回到对应按钮', () => {
  const html = readHtml();
  assert.match(html, /fromMenu:\s*!!choice\.closest\('#theme-menu'\)/);
  assert.match(jsFunctionBody(html, 'dispatch'), /fromMenu[\s\S]{0,240}?#theme-switcher \[data-theme-choice=/);
});

test('节拍轨道计划阶段与计划名来源一致转义', () => {
  const html = readHtml();
  const body = jsFunctionBody(html, 'renderRhythm');
  assert.match(body, /escapeHtml\(WORKOUT_PLAN\.phases\.join\('、'\)\)/);
  assert.match(body, /escapeHtml\(phase\)/);
});

test('休息页选组面板收起时其 aria-controls 目标仍存在', () => {
  const html = readHtml();
  const rest = jsFunctionBody(html, 'renderRest');
  assert.match(rest, /aria-controls="rest-chooser"/);
  // 常驻调用：不再按 choosingNext 条件渲染，避免收起时 aria-controls 指向不存在的节点。
  assert.match(rest, /\$\{renderRestChooser\(entries\)\}/);
  assert.doesNotMatch(rest, /choosingNext \? renderRestChooser/);
  const chooser = jsFunctionBody(html, 'renderRestChooser');
  assert.match(chooser, /id="rest-chooser"[\s\S]{0,200}?\$\{choosingNext \? '' : 'hidden'\}/);
});

test('addTemporarySet 对空组与未知动作安全返回', () => {
  const base = core.createInitialState(0);
  const emptyState = { ...base, exercises: base.exercises.map(item => item.id === 'bench' ? { ...item, sets: [] } : item) };
  assert.equal(core.addTemporarySet(emptyState, 'bench'), emptyState);
  assert.equal(core.addTemporarySet(base, 'missing'), base);
});

test('selectSet 对已选中的待训练组幂等且不重渲染', () => {
  const state = core.startWorkout(core.prepareWorkout(core.createInitialState()), 1_000);
  assert.equal(core.selectSet(state, state.selectedSetId), state);
  const changed = core.selectSet(state, 'press-1');
  assert.notEqual(changed, state);
  assert.equal(changed.selectedSetId, 'press-1');
});

test('chooseNextSet 仅在休息阶段生效', () => {
  const workout = core.startWorkout(core.prepareWorkout(core.createInitialState()), 1_000);
  assert.equal(core.chooseNextSet(workout, 'press-1', 9_000), workout);
  assert.equal(core.chooseNextSet(core.createInitialState(), 'press-1', 9_000).sessionStatus, 'idle');

  let resting = core.startSelectedSet(workout, 2_000);
  resting = core.completeSelectedSet(resting, 5_000);
  const chosen = core.chooseNextSet(resting, 'press-1', 8_000);
  assert.notEqual(chosen, resting);
  assert.equal(chosen.screen, 'workout');
  assert.equal(chosen.selectedSetId, 'press-1');
});
