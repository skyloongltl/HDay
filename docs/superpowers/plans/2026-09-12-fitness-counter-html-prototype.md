# 健身计数 App 核心闭环 HTML 原型实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个无需构建和网络依赖、可完整演示训练核心闭环及 A/B/C 三套主题的单文件 HTML 原型。

**Architecture:** `prototype/fitness-counter/index.html` 包含语义化 HTML、分层原生 CSS 和原生 JavaScript。六个屏幕共用一个 `appState`、一套渲染函数和同一组组件模板；主题通过 `data-theme` 与 CSS 自定义属性切换，训练流程通过纯状态转换函数驱动。

**Tech Stack:** HTML5、CSS 自定义属性、内联 SVG、原生 JavaScript、Node.js 内置测试运行器、Playwright CLI 浏览器验收

**Spec:** `docs/superpowers/specs/2026-09-12-fitness-counter-html-prototype-design.md`

## Global Constraints

- 原型入口固定为 `prototype/fitness-counter/index.html`，直接打开即可运行。
- 不引入 Tailwind、运行时 CDN、网络字体、第三方 JavaScript 或构建工具。
- A「呼吸节拍」为默认主题，主操作色必须为 `#C76F62`。
- 三个主题共享页面 DOM、组件、状态语义和点击区域，不复制三套屏幕。
- 六个核心屏幕为今日、训练准备、训练执行、休息、结束确认和训练总结。
- 最小点击区域为 48px，底部主按钮高度为 52px，桌面手机画布宽度为 390px。
- 核心字号严格采用 UI 规格：页面标题 23px、主卡标题 21px、训练时长 20px、休息计时 40px、主按钮 14px、动作名 12px、组数据 11px、辅助说明及页面标签 10px、结束按钮 12px。
- 主要适配宽度为 360px、390px 和 430px；字体缩放 130% 时关键数据不得裁切。
- `prefers-reduced-motion: reduce` 时取消位移、缩放、旋转和轨道形变。
- 图标使用内联 SVG，不使用 emoji；状态必须同时通过文字、图标或形状表达。
- 训练与休息页面右上角始终显示“结束”，其可点击区域不得小于 48×48px。
- JavaScript 暴露 `window.FitnessPrototype` 供测试调用；生产交互仍由页面原生按钮驱动。

---

## 文件结构

- Create: `prototype/fitness-counter/index.html` — 唯一可运行原型，包含静态壳层、CSS、纯状态逻辑、内联 SVG 模板和浏览器控制器。
- Create: `prototype/fitness-counter/prototype-core.test.js` — 使用 `node:test` 从 HTML 的 `#prototype-core` 脚本块提取纯逻辑，覆盖主题、训练组状态、结束规则和计时派生逻辑。

交付物严格保持单个 HTML。测试文件仅用于开发验证，不参与浏览器运行；核心逻辑置于带固定 `id="prototype-core"` 的内联脚本中，测试通过 `node:vm` 在隔离沙箱执行该脚本，不需要服务器、模块加载器或构建步骤。

---

### Task 1: 建立状态模型与主题解析

**Files:**
- Create: `prototype/fitness-counter/index.html`（`#prototype-core` 脚本块）
- Create: `prototype/fitness-counter/prototype-core.test.js`

**Interfaces:**
- Produces: `createInitialState(nowMs?: number): AppState`
- Produces: `resolveTheme(value: string | null): 'a' | 'b' | 'c'`
- Produces: `setTheme(state: AppState, theme: string): AppState`
- Produces: `formatDuration(seconds: number): string`
- Produces: `getWorkoutStats(state: AppState): WorkoutStats`
- Produces: 浏览器 `window.FitnessPrototypeCore`；测试通过 `node:vm` 读取同一脚本块

`AppState` 使用以下固定结构：

```js
{
  screen: 'today',
  theme: 'a',
  sessionStatus: 'idle',
  workoutStartedAt: null,
  activeSetStartedAt: null,
  restStartedAt: null,
  restTargetSeconds: 90,
  selectedSetId: 'bench-1',
  completedSummary: null,
  notes: '',
  exercises: [
    {
      id: 'bench',
      name: '杠铃卧推',
      collapsed: false,
      sets: [
        { id: 'bench-1', plannedWeight: 60, actualWeight: 60, plannedReps: 8, actualReps: 8, status: 'pending', durationSeconds: 0, temporary: false }
      ]
    }
  ]
}
```

- [ ] **Step 1: 编写主题、初始状态和时长格式的失败测试**

```js
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
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: FAIL，错误包含 `ENOENT`，指向尚未创建的 `index.html`。

- [ ] **Step 3: 实现主题解析、固定演示数据和格式化函数**

先创建最小 `index.html`，在 `<script id="prototype-core">` 中定义 IIFE 并挂到 `window.FitnessPrototypeCore`：

```js
(function (root, factory) {
  root.FitnessPrototypeCore = factory();
})(window, function () {
  const VALID_THEMES = new Set(['a', 'b', 'c']);

  function makeSets(prefix, count, weight, reps) {
    return Array.from({ length: count }, (_, index) => ({
      id: `${prefix}-${index + 1}`,
      plannedWeight: weight,
      actualWeight: weight,
      plannedReps: reps,
      actualReps: reps,
      status: 'pending',
      durationSeconds: 0,
      temporary: false
    }));
  }

  function resolveTheme(value) {
    return VALID_THEMES.has(value) ? value : 'a';
  }

  function createInitialState() {
    return {
      screen: 'today',
      theme: 'a',
      sessionStatus: 'idle',
      workoutStartedAt: null,
      activeSetStartedAt: null,
      restStartedAt: null,
      restTargetSeconds: 90,
      selectedSetId: 'bench-1',
      completedSummary: null,
      notes: '',
      exercises: [
        { id: 'bench', name: '杠铃卧推', collapsed: false, sets: makeSets('bench', 3, 60, 8) },
        { id: 'press', name: '哑铃肩推', collapsed: false, sets: makeSets('press', 3, 16, 10) },
        { id: 'pushdown', name: '绳索下压', collapsed: false, sets: makeSets('pushdown', 3, 25, 12) }
      ]
    };
  }

  function setTheme(state, theme) {
    return { ...state, theme: resolveTheme(theme) };
  }

  function formatDuration(seconds) {
    const safe = Math.max(0, Math.floor(Number(seconds) || 0));
    const hours = Math.floor(safe / 3600);
    const minutes = Math.floor((safe % 3600) / 60);
    const secs = safe % 60;
    const mm = String(minutes).padStart(2, '0');
    const ss = String(secs).padStart(2, '0');
    return hours ? `${hours}:${mm}:${ss}` : `${mm}:${ss}`;
  }

  function getWorkoutStats(state) {
    const sets = state.exercises.flatMap(item => item.sets);
    const count = status => sets.filter(set => set.status === status).length;
    return {
      total: sets.length,
      completed: count('completed'),
      skipped: count('skipped'),
      active: count('active'),
      pending: count('pending'),
      completedExercises: state.exercises.filter(item => item.sets.some(set => set.status === 'completed')).length
    };
  }

  return { createInitialState, resolveTheme, setTheme, formatDuration, getWorkoutStats };
});
```

- [ ] **Step 4: 运行测试并确认通过**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: 3 tests PASS。

- [ ] **Step 5: 提交状态模型基础**

```bash
git add prototype/fitness-counter/index.html prototype/fitness-counter/prototype-core.test.js
git commit -m "feat: add fitness prototype state model"
```

---

### Task 2: 实现训练状态转换与结束规则

**Files:**
- Modify: `prototype/fitness-counter/index.html`（`#prototype-core` 脚本块）
- Modify: `prototype/fitness-counter/prototype-core.test.js`

**Interfaces:**
- Consumes: `AppState`、`getWorkoutStats(state)`
- Produces: `prepareWorkout(state): AppState`
- Produces: `startWorkout(state, nowMs): AppState`
- Produces: `selectSet(state, setId): AppState`
- Produces: `startSelectedSet(state, nowMs): AppState`
- Produces: `completeSelectedSet(state, nowMs): AppState`
- Produces: `startNextSet(state, nowMs): AppState`
- Produces: `skipSelectedSet(state): AppState`
- Produces: `canSaveWorkout(state): boolean`
- Produces: `finishWorkout(state, nowMs): AppState`
- Produces: `discardWorkout(state): AppState`
- Produces: `deriveTimers(state, nowMs): { workoutSeconds, setSeconds, restSeconds, restRemainingSeconds, restOvertimeSeconds }`

- [ ] **Step 1: 编写训练闭环和零完成组结束规则的失败测试**

```js
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

test('计时从绝对时间推导且不产生负数', () => {
  let state = core.startWorkout(core.prepareWorkout(core.createInitialState()), 10_000);
  state = core.startSelectedSet(state, 12_000);
  assert.deepEqual(core.deriveTimers(state, 15_000), {
    workoutSeconds: 5,
    setSeconds: 3,
    restSeconds: 0,
    restRemainingSeconds: 90,
    restOvertimeSeconds: 0
  });
  assert.equal(core.deriveTimers(state, 5_000).workoutSeconds, 0);
});
```

- [ ] **Step 2: 运行测试并确认新测试失败**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: FAIL，错误包含 `core.prepareWorkout is not a function`。

- [ ] **Step 3: 实现不可变状态转换**

在 `index.html` 的 `#prototype-core` 脚本块中增加：

```js
function updateSet(state, setId, updater) {
  return {
    ...state,
    exercises: state.exercises.map(exercise => ({
      ...exercise,
      sets: exercise.sets.map(set => set.id === setId ? updater(set) : set)
    }))
  };
}

function findSet(state, setId) {
  return state.exercises.flatMap(item => item.sets).find(set => set.id === setId);
}

function prepareWorkout(state) {
  return { ...state, screen: 'prepare', sessionStatus: 'preparing' };
}

function startWorkout(state, nowMs) {
  return { ...state, screen: 'workout', sessionStatus: 'active', workoutStartedAt: nowMs };
}

function selectSet(state, setId) {
  const set = findSet(state, setId);
  return set && set.status === 'pending' ? { ...state, selectedSetId: setId } : state;
}

function startSelectedSet(state, nowMs) {
  const selected = findSet(state, state.selectedSetId);
  if (!selected || selected.status !== 'pending') return state;
  const cleared = {
    ...state,
    exercises: state.exercises.map(exercise => ({
      ...exercise,
      sets: exercise.sets.map(set => set.status === 'active' ? { ...set, status: 'pending' } : set)
    }))
  };
  const started = updateSet(cleared, state.selectedSetId, set => ({ ...set, status: 'active' }));
  return { ...started, activeSetStartedAt: nowMs, sessionStatus: 'active' };
}

function completeSelectedSet(state, nowMs) {
  const selected = findSet(state, state.selectedSetId);
  if (!selected || selected.status !== 'active') return state;
  const durationSeconds = Math.max(0, Math.floor((nowMs - state.activeSetStartedAt) / 1000));
  const completed = updateSet(state, selected.id, set => ({ ...set, status: 'completed', durationSeconds }));
  return { ...completed, screen: 'rest', sessionStatus: 'resting', activeSetStartedAt: null, restStartedAt: nowMs };
}

function nextPendingSet(state) {
  return state.exercises.flatMap(item => item.sets).find(set => set.status === 'pending');
}

function startNextSet(state, nowMs) {
  const next = nextPendingSet(state);
  if (!next) return state;
  return startSelectedSet({ ...state, screen: 'workout', selectedSetId: next.id, restStartedAt: null }, nowMs);
}

function skipSelectedSet(state) {
  const selected = findSet(state, state.selectedSetId);
  if (!selected || !['pending', 'active'].includes(selected.status)) return state;
  const skipped = updateSet(state, selected.id, set => ({ ...set, status: 'skipped' }));
  const next = nextPendingSet(skipped);
  return { ...skipped, selectedSetId: next ? next.id : state.selectedSetId, activeSetStartedAt: null };
}

function canSaveWorkout(state) {
  return getWorkoutStats(state).completed > 0;
}

function finishWorkout(state, nowMs) {
  if (!canSaveWorkout(state)) return state;
  const exercises = state.exercises.map(exercise => ({
    ...exercise,
    sets: exercise.sets.map(set => ['pending', 'active'].includes(set.status) ? { ...set, status: 'skipped' } : set)
  }));
  const finished = { ...state, exercises, screen: 'summary', sessionStatus: 'summary', activeSetStartedAt: null, restStartedAt: null };
  return {
    ...finished,
    completedSummary: { ...getWorkoutStats(finished), workoutSeconds: deriveTimers(state, nowMs).workoutSeconds }
  };
}

function discardWorkout() {
  return createInitialState();
}

function deriveTimers(state, nowMs) {
  const elapsed = start => start == null ? 0 : Math.max(0, Math.floor((nowMs - start) / 1000));
  const workoutSeconds = elapsed(state.workoutStartedAt);
  const setSeconds = elapsed(state.activeSetStartedAt);
  const restSeconds = elapsed(state.restStartedAt);
  return {
    workoutSeconds,
    setSeconds,
    restSeconds,
    restRemainingSeconds: Math.max(0, state.restTargetSeconds - restSeconds),
    restOvertimeSeconds: Math.max(0, restSeconds - state.restTargetSeconds)
  };
}
```

把所有新函数加入公共 API。`startNextSet` 的查找必须基于完成后的最新状态，保证从 `bench-1` 前进到 `bench-2`。

- [ ] **Step 4: 运行测试并确认通过**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: 7 tests PASS。

- [ ] **Step 5: 提交训练状态机**

```bash
git add prototype/fitness-counter/index.html prototype/fitness-counter/prototype-core.test.js
git commit -m "feat: add prototype workout state transitions"
```

---

### Task 3: 构建手机壳层、三主题令牌与今日首页

**Files:**
- Modify: `prototype/fitness-counter/index.html`（将最小核心文件扩展为完整壳层）
- Modify: `prototype/fitness-counter/prototype-core.test.js`

**Interfaces:**
- Consumes: `window.FitnessPrototypeCore.createInitialState()`、`resolveTheme()`、`setTheme()`（均来自同一 HTML 的 `#prototype-core`）
- Produces: `window.FitnessPrototype = { getState, dispatch, render }`
- Produces: DOM 锚点 `#app-shell`、`#screen-root`、`#theme-switcher`、`#live-status`
- Produces: actions `OPEN_PREPARE`、`SET_THEME`、`RESET_DEMO`

- [ ] **Step 1: 编写 HTML 结构契约失败测试**

向 `prototype-core.test.js` 增加静态文件测试：

```js
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
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: FAIL，错误包含 `ENOENT`，指向 `index.html`。

- [ ] **Step 3: 创建语义化壳层和分层 CSS**

`index.html` 必须按以下顺序组织：

```html
<!doctype html>
<html lang="zh-CN" data-theme="a">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>健身计数 · 核心训练原型</title>
  <style>
    /* reset */
    /* tokens */
    /* themes */
    /* layout */
    /* components */
    /* screens */
    /* utilities */
    /* motion */
  </style>
</head>
<body>
  <aside class="demo-panel" aria-label="原型控制">
    <h1>训练核心闭环</h1>
    <div id="theme-switcher" role="group" aria-label="界面风格"></div>
    <button type="button" data-action="RESET_DEMO">重置演示</button>
  </aside>
  <main id="app-shell" class="device-shell" data-theme="a">
    <div id="live-status" class="sr-only" aria-live="polite"></div>
    <div id="screen-root"></div>
  </main>
  <script id="prototype-core">/* pure state core */</script>
  <script id="prototype-controller">/* browser controller */</script>
</body>
</html>
```

CSS 主题必须定义相同语义令牌：

```css
[data-theme="a"] {
  --app-bg: #F4F7FA;
  --surface-hero: #19344C;
  --primary-action: #C76F62;
  --active-state: #62E6CA;
  --text-main: #142A3A;
  --text-muted: #60717E;
  --outline: #DFE7EC;
  --surface-card: #FFFFFF;
  --radius-hero: 24px;
  --radius-card: 14px;
  --radius-button: 14px;
}
[data-theme="b"] {
  --app-bg: #FFF7D8;
  --surface-hero: #FFDF3D;
  --primary-action: #6956DF;
  --active-state: #FF655F;
  --secondary-state: #8CE6CF;
  --text-main: #25231E;
  --surface-card: #FFFDF0;
  --outline: #25231E;
  --radius-hero: 10px;
  --radius-card: 8px;
  --radius-button: 10px;
}
[data-theme="c"] {
  --app-bg: #131720;
  --surface-hero: #1D222C;
  --primary-action: #5D85FF;
  --active-state: #C8FF5A;
  --text-main: #EDF2F7;
  --text-muted: #98A4B3;
  --outline: #303845;
  --surface-card: #1D222C;
  --radius-hero: 20px;
  --radius-card: 12px;
  --radius-button: 12px;
}
```

共同尺寸用 `--space-*`、`--font-*` 和 `--tap-size: 48px` 表达。所有按钮使用 `min-inline-size` 或 `min-block-size: var(--tap-size)`；`.device-shell` 桌面宽 390px，520px 以下铺满视口；处理 `env(safe-area-inset-*)`。

- [ ] **Step 4: 实现今日首页渲染和主题控制器**

控制器维护唯一可变引用：

```js
const Core = window.FitnessPrototypeCore;
let state = Core.createInitialState(Date.now());
state = Core.setTheme(state, Core.resolveTheme(localStorage.getItem('fitness-theme')));

function dispatch(action) {
  if (action.type === 'SET_THEME') {
    state = Core.setTheme(state, action.theme);
    localStorage.setItem('fitness-theme', state.theme);
  }
  if (action.type === 'OPEN_PREPARE') state = Core.prepareWorkout(state);
  if (action.type === 'RESET_DEMO') state = { ...Core.createInitialState(Date.now()), theme: state.theme };
  render();
}

window.FitnessPrototype = {
  getState: () => state,
  dispatch,
  render
};
```

`renderToday()` 生成：日期与“今日”同基线顶栏、页面标题、Hero、阶段轨道、开始按钮、自由训练展示入口、三项统计、动作摘要和四项底部导航。主题按钮的 `aria-pressed` 与当前主题同步；点击主题按钮不得替换 `state.exercises`。

- [ ] **Step 5: 运行静态和核心测试**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: 8 tests PASS。

- [ ] **Step 6: 浏览器检查今日首页和主题切换**

Run: 使用 Playwright CLI 打开 `file:///C:/Code/HDay/prototype/fitness-counter/index.html`。

验证：

1. 390px 画布中出现今日页，无控制台错误。
2. 依次点击 A/B/C，布局位置不变，颜色、圆角、描边和阴影语言改变。
3. 刷新后保留最后选择主题。
4. 删除 `localStorage.fitness-theme` 后刷新回到 A。
5. 截取 A/B/C 今日页截图供视觉复查。

- [ ] **Step 7: 提交壳层与今日页**

```bash
git add prototype/fitness-counter/index.html prototype/fitness-counter/prototype-core.test.js
git commit -m "feat: add themed fitness prototype home"
```

---

### Task 4: 实现训练准备页和本次训练编辑

**Files:**
- Modify: `prototype/fitness-counter/index.html`（页面渲染与 `#prototype-core` 脚本块）
- Modify: `prototype/fitness-counter/prototype-core.test.js`

**Interfaces:**
- Consumes: `prepareWorkout(state)`、`startWorkout(state, nowMs)`
- Produces: `toggleExercise(state, exerciseId): AppState`
- Produces: `editSet(state, setId, patch: { actualWeight?: number, actualReps?: number }): AppState`
- Produces: actions `TOGGLE_EXERCISE`、`EDIT_SET`、`START_WORKOUT`、`BACK_TODAY`

- [ ] **Step 1: 编写折叠和仅本次编辑失败测试**

```js
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
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: FAIL，错误包含 `core.toggleExercise is not a function`。

- [ ] **Step 3: 实现准备状态编辑函数**

```js
function toggleExercise(state, exerciseId) {
  return {
    ...state,
    exercises: state.exercises.map(item => item.id === exerciseId ? { ...item, collapsed: !item.collapsed } : item)
  };
}

function editSet(state, setId, patch) {
  return updateSet(state, setId, set => ({
    ...set,
    actualWeight: patch.actualWeight == null ? set.actualWeight : Number(patch.actualWeight),
    actualReps: patch.actualReps == null ? set.actualReps : Number(patch.actualReps),
    temporary: true
  }));
}
```

将两个函数加入公共 API。

- [ ] **Step 4: 渲染训练准备页**

`renderPrepare()` 包含：

- 顶栏返回按钮、页面标签“准备”和标题“确认本次训练”
- 来源“上肢三日循环 · D2”
- 明确提示“本次调整不会修改原计划”
- 三个可折叠动作块和 9 个组行
- 每组两个带 label 的数字输入框：实际重量、实际次数
- 数据变化后显示“仅本次”文本标记
- 动作拖动手柄使用按钮但设置 `aria-disabled="true"`，标题说明“拖动排序将在正式版提供”
- 固定底部“开始训练”

输入事件派发 `EDIT_SET`；折叠按钮派发 `TOGGLE_EXERCISE`；开始按钮派发 `START_WORKOUT`，传入 `Date.now()`。

- [ ] **Step 5: 运行测试并确认通过**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: 9 tests PASS。

- [ ] **Step 6: 浏览器检查准备页**

Run: 使用 Playwright CLI 打开原型并点击“开始今日训练”。

验证：

1. 底部导航隐藏，底部开始按钮固定。
2. 折叠杠铃卧推后，其他动作位置自然补位。
3. 将第一组改为 62.5kg × 7，计划值仍为 60kg × 8，并出现“仅本次”。
4. 按 Tab 可依次进入返回、折叠、输入和开始按钮。
5. 在 A/B/C 下内容顺序完全一致。

- [ ] **Step 7: 提交训练准备页**

```bash
git add prototype/fitness-counter/index.html prototype/fitness-counter/prototype-core.test.js
git commit -m "feat: add workout preparation flow"
```

---

### Task 5: 实现训练执行页、节拍轨道和组操作

**Files:**
- Modify: `prototype/fitness-counter/index.html`（页面渲染与 `#prototype-core` 脚本块）
- Modify: `prototype/fitness-counter/prototype-core.test.js`

**Interfaces:**
- Consumes: `startSelectedSet()`、`completeSelectedSet()`、`skipSelectedSet()`、`getWorkoutStats()`、`deriveTimers()`
- Produces: `addTemporarySet(state, exerciseId): AppState`
- Produces: actions `SELECT_SET`、`START_SET`、`COMPLETE_SET`、`SKIP_SET`、`ADD_SET`、`OPEN_END_SHEET`
- Produces: `renderRhythmTrack(stats, mode): string`

- [ ] **Step 1: 编写添加临时组及选择约束失败测试**

```js
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
```

这里明确：存在进行中组时，不能直接选择其他组；先完成或跳过当前组。

- [ ] **Step 2: 运行测试并确认失败**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: FAIL，因为当前 `selectSet` 会允许切换，且 `addTemporarySet` 尚未定义。

- [ ] **Step 3: 收紧选组规则并实现添加组**

```js
function selectSet(state, setId) {
  const hasActive = state.exercises.flatMap(item => item.sets).some(set => set.status === 'active');
  const set = findSet(state, setId);
  return !hasActive && set && set.status === 'pending' ? { ...state, selectedSetId: setId } : state;
}

function addTemporarySet(state, exerciseId) {
  return {
    ...state,
    exercises: state.exercises.map(exercise => {
      if (exercise.id !== exerciseId) return exercise;
      const source = exercise.sets.at(-1);
      const suffix = Math.max(...exercise.sets.map(set => Number(set.id.split('-').at(-1)))) + 1;
      return {
        ...exercise,
        sets: [...exercise.sets, {
          ...source,
          id: `${exercise.id}-${suffix}`,
          status: 'pending',
          durationSeconds: 0,
          temporary: true
        }]
      };
    })
  };
}
```

- [ ] **Step 4: 渲染训练执行页和线性节拍轨道**

`renderWorkout()` 包含：

- 顶栏左侧“训练时长”与动态时间，右侧同基线“训练”标签和 48×48 点击区内的紧凑结束按钮
- `完成 x / y 组` 和 SVG/CSS 节拍轨道
- 三个动作分组、所有训练组、计划值与实际值
- pending/active/completed/skipped 的复合状态表达
- 当前组显示单组计时
- 次操作“修改数据”“跳过本组”“添加组”
- 主按钮按当前组状态显示“开始本组”或“完成本组”

`renderRhythmTrack(stats, 'linear')` 输出有 `role="img"` 和动态 `aria-label="已完成 1 组，共 9 组，当前第 2 组"` 的 SVG；节点用 `data-state` 表达状态，不能只有填充色差异。

浏览器控制器启动一个 250ms 的界面刷新定时器，仅在 `sessionStatus` 为 `active` 或 `resting` 时更新计时文本和轨道，不重建输入焦点所在页面。

- [ ] **Step 5: 运行测试并确认通过**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: 10 tests PASS。

- [ ] **Step 6: 浏览器检查训练组状态与计时**

验证：

1. 点击开始训练后总时长开始增长。
2. 未开始组显示空心节点和“未开始”。
3. 点击“开始本组”后显示“进行中”和单组计时。
4. 进行中时点击其他组不会切换。
5. 添加组后总组数从 9 变 10，新组显示“临时”。
6. 跳过当前组后显示弱化和“已跳过”，并选择下一组。
7. 结束按钮始终可见，视觉紧凑但点击区至少 48×48。

- [ ] **Step 7: 提交训练执行页**

```bash
git add prototype/fitness-counter/index.html prototype/fitness-counter/prototype-core.test.js
git commit -m "feat: add interactive workout execution"
```

---

### Task 6: 实现独立休息页和环形节拍轨道

**Files:**
- Modify: `prototype/fitness-counter/index.html`（页面渲染与 `#prototype-core` 脚本块）
- Modify: `prototype/fitness-counter/prototype-core.test.js`

**Interfaces:**
- Consumes: `completeSelectedSet()`、`deriveTimers()`、`startNextSet()`
- Produces: `chooseNextSet(state, setId, nowMs): AppState`
- Produces: actions `START_NEXT_SET`、`CHOOSE_NEXT_SET`、`JUMP_REST_TIMER`
- Produces: `renderRestRing(timers): string`

- [ ] **Step 1: 编写休息选组和超时显示逻辑失败测试**

```js
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
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: FAIL，缺少 `chooseNextSet` 和 `restOvertimeSeconds`。

- [ ] **Step 3: 实现休息选组和超时派生**

```js
function chooseNextSet(state, setId, nowMs) {
  const chosen = findSet(state, setId);
  if (!chosen || chosen.status !== 'pending') return state;
  return startSelectedSet({ ...state, screen: 'workout', selectedSetId: setId, restStartedAt: null }, nowMs);
}
```

在 `deriveTimers` 返回值中增加：

```js
restOvertimeSeconds: Math.max(0, restSeconds - state.restTargetSeconds)
```

该字段已在 Task 2 的接口和基础测试中定义；本任务验证其超时分支。

- [ ] **Step 4: 渲染休息页与演示控制**

`renderRest()` 包含：

- 复用训练顶栏，页面标签为“休息”
- 目标“01:30”
- 40px 大号实际休息计时
- SVG 环形轨道：未到目标显示进度，达到后固定满环并切换完成形态
- 剩余时间；超时后显示“已超过 mm:ss”
- 下一组完整卡和再下一组简要预览
- “选择其他未完成组”打开同页内选择面板
- 固定主按钮“结束休息并开始下一组”

桌面 `.demo-panel` 在休息状态显示“跳至目标前 3 秒”，其 action 将 `state.restStartedAt` 改为 `Date.now() - 87_000`；该按钮在 520px 以下隐藏。

到达目标的视觉反馈只触发一次：控制器维护 `restTargetAnnounced` 布尔值，首次满足时更新 `#live-status` 为“已达到目标休息时间”，同时为环形轨道添加一次性主题反馈 class。

- [ ] **Step 5: 运行测试并确认通过**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: 12 tests PASS。

- [ ] **Step 6: 浏览器检查休息流程**

验证：

1. 完成一组自动进入休息页。
2. 休息时间持续累计，剩余时间递减。
3. 使用演示控制后 3 秒达到目标，只反馈一次且不自动开始下一组。
4. 超过目标后继续累计并显示超时。
5. 选择“哑铃肩推第 1 组”后回到训练页，该组直接进入进行中。
6. A 为呼吸确认、B 为一次盖章、C 为刻度点亮；背景均不持续运动。

- [ ] **Step 7: 提交休息页**

```bash
git add prototype/fitness-counter/index.html prototype/fitness-counter/prototype-core.test.js
git commit -m "feat: add workout rest experience"
```

---

### Task 7: 实现结束确认、二次放弃与训练总结

**Files:**
- Modify: `prototype/fitness-counter/index.html`（页面渲染与 `#prototype-core` 脚本块）
- Modify: `prototype/fitness-counter/prototype-core.test.js`

**Interfaces:**
- Consumes: `canSaveWorkout()`、`finishWorkout()`、`discardWorkout()`、`getWorkoutStats()`
- Produces: `completeSession(state): AppState`
- Produces: `setNotes(state, notes): AppState`
- Produces: actions `CLOSE_END_SHEET`、`SAVE_PARTIAL`、`OPEN_DISCARD_CONFIRM`、`CONFIRM_DISCARD`、`SET_NOTES`、`COMPLETE_SESSION`
- Produces: overlays `#end-sheet`、`#discard-dialog`

- [ ] **Step 1: 编写总结完成与备注失败测试**

```js
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
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: FAIL，缺少 `setNotes` 与 `completeSession`，且当前 `discardWorkout` 不保留主题。

- [ ] **Step 3: 实现总结状态转换**

```js
function setNotes(state, notes) {
  return { ...state, notes: String(notes).slice(0, 300) };
}

function completeSession(state) {
  if (state.sessionStatus !== 'summary' || !state.completedSummary) return state;
  return { ...state, screen: 'today', sessionStatus: 'completed' };
}

function discardWorkout(state) {
  return { ...createInitialState(), theme: state.theme };
}
```

- [ ] **Step 4: 渲染结束 Bottom Sheet 与放弃确认**

结束按钮设置 `uiState.endSheetOpen = true`，不提前改变训练业务状态。`renderEndSheet()` 必须显示：

- 当前总训练时长
- 完成动作数
- 已完成组数
- 剩余组数
- 零完成组时：“至少完成一组后才能保存训练”
- 保存按钮在零完成组时使用原生 `disabled`
- 返回继续训练
- 放弃本次训练

点击遮罩和返回按钮只关闭 Sheet。点击放弃打开 `role="alertdialog"` 的二次确认，默认焦点落在“返回训练”，确认按钮文案为“确认放弃”。确认后调用 `discardWorkout`。

- [ ] **Step 5: 渲染训练总结和今日完成卡**

`renderSummary()` 显示动态总时长、完成动作数、完成/跳过/未完成组数、动作摘要、备注 textarea、收束轨道和固定“完成”按钮。

保存部分训练时调用 `finishWorkout(state, Date.now())`。总结页输入派发 `SET_NOTES`；完成派发 `COMPLETE_SESSION`。今日页在 `sessionStatus === 'completed'` 时用完成卡替换训练 Hero，显示用时、完成组数和备注摘要。

- [ ] **Step 6: 运行测试并确认通过**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: 14 tests PASS。

- [ ] **Step 7: 浏览器检查三个结束分支**

验证：

1. 未完成任何组时打开 Sheet，保存按钮禁用并解释原因。
2. 返回继续训练后计时和组选中状态不变。
3. 放弃先出现二次确认；取消不丢数据，确认后回到今日空闲状态且主题不变。
4. 完成一组后可保存，剩余 8 组变为跳过并进入总结。
5. 总结填写备注后点击完成，今日页显示完成卡。
6. 在休息页打开结束 Sheet 时，背景仍能识别为休息上下文。

- [ ] **Step 8: 提交结束与总结流程**

```bash
git add prototype/fitness-counter/index.html prototype/fitness-counter/prototype-core.test.js
git commit -m "feat: complete workout ending flow"
```

---

### Task 8: 完成响应式、无障碍、减弱动画与视觉验收

**Files:**
- Modify: `prototype/fitness-counter/index.html`
- Modify: `prototype/fitness-counter/prototype-core.test.js`

**Interfaces:**
- Consumes: 全部原型界面与 actions
- Produces: 最终无障碍语义、响应式规则、减少动画规则和可验收截图

- [ ] **Step 1: 增加关键 CSS 与语义契约失败测试**

```js
test('HTML 包含响应式、减少动画和关键对话框语义', () => {
  const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
  assert.match(html, /@media\s*\(max-width:\s*520px\)/);
  assert.match(html, /@media\s*\(prefers-reduced-motion:\s*reduce\)/);
  assert.match(html, /env\(safe-area-inset-bottom\)/);
  assert.match(html, /role="alertdialog"/);
  assert.match(html, /aria-label="结束训练"/);
  assert.doesNotMatch(html, /https?:\/\//);
});
```

- [ ] **Step 2: 运行测试并确认任何缺口会失败**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: FAIL，至少缺少最终 `role="alertdialog"` 静态模板或完整 reduced-motion 覆盖规则；若契约已由前序任务完整实现，则记录该测试直接 PASS，并继续执行人工无障碍验收，不删除正确代码制造失败。

- [ ] **Step 3: 补齐最终 CSS 和焦点管理**

确保：

```css
:focus-visible {
  outline: 3px solid var(--focus-ring);
  outline-offset: 3px;
}

@media (max-width: 520px) {
  body { display: block; background: var(--app-bg); }
  .demo-panel { display: none; }
  .device-shell { inline-size: 100%; block-size: 100dvh; border: 0; border-radius: 0; }
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    scroll-behavior: auto !important;
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

打开 Sheet 或 Dialog 时保存触发元素；关闭后恢复焦点。Dialog 打开时将焦点限制在其按钮和输入内，按 Escape 只关闭当前最上层覆盖物。页面切换后将焦点移到页面 `<h2 tabindex="-1">`。

- [ ] **Step 4: 运行全部自动化测试**

Run: `node --test prototype/fitness-counter/prototype-core.test.js`

Expected: 15 tests PASS，0 FAIL。

Run: `git diff --check`

Expected: 无输出，退出码 0。

- [ ] **Step 5: 在三个宽度执行完整闭环验收**

使用 Playwright CLI 分别设置 360×800、390×844、430×932，执行：

```text
打开今日页
→ 切换主题 B
→ 开始今日训练
→ 修改 bench-1 为 62.5kg × 7
→ 开始训练
→ 开始并完成 bench-1
→ 休息页跳至目标前 3 秒
→ 达到目标后开始 bench-2
→ 打开结束 Sheet
→ 保存已完成内容
→ 输入备注
→ 完成并回到今日
```

每个宽度验证：无横向滚动、底部按钮未被安全区遮挡、关键计时不裁切、控制台无 error。

- [ ] **Step 6: 三主题视觉截图与设计自评**

在 390×844 下截取：

```text
A：今日、训练、休息
B：今日、训练、休息
C：今日、训练、休息
```

逐张检查：

- A 无高饱和橙色，珊瑚只用于行动，薄荷只用于状态。
- B 只有 Hero 和主按钮使用硬阴影，没有贴纸堆叠。
- C 没有大面积霓虹光晕，荧光只用于状态和刻度。
- 三主题按钮位置、信息顺序、触控区完全一致。
- 节拍轨道承担阶段、组进度或休息进度，不是纯装饰。
- 页面没有通用渐变 Hero、漂浮装饰或指标卡墙。

发现问题时只修复与规格不符之处，不追加新功能。

- [ ] **Step 7: 验证键盘与减少动画**

1. 只用键盘完成“今日 → 准备 → 训练 → 结束 Sheet → 返回”。
2. 确认焦点环清晰，Sheet 关闭后焦点回到“结束”。
3. 模拟 `prefers-reduced-motion: reduce`，完成组和切换页面时无位移、缩放、旋转或轨道形变。
4. 将浏览器文字缩放至 130%，确认训练时长、休息时间、重量、次数和结束按钮不裁切。

- [ ] **Step 8: 最终提交**

```bash
git add prototype/fitness-counter/index.html prototype/fitness-counter/prototype-core.test.js
git commit -m "test: verify fitness prototype experience"
```
