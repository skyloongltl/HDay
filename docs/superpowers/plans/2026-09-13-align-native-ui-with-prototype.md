# Align Native UI With Fitness Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Flutter app's visible pages and theme behavior back into alignment with the reference UI defined by `prototype/fitness-counter/index.html`, while preserving Android safe-area and navigation behavior.

**Architecture:** Keep the existing Flutter page/controller boundaries. Move visual truth into the shared theme extension and scaffold, then make each page consume those tokens instead of embedding one-off Material defaults. Rebuild the Today page around the prototype's information hierarchy and actions, and use screenshot/widget tests to verify all three themes and the native safe-area shell.

**Tech Stack:** Flutter, Dart, Material 3, `flutter_test`, existing application controllers and theme extension.

**Spec:** `prototype/fitness-counter/index.html` plus the observed reference captures in `app_pages/` (`呼吸节拍.jpg`, `训练贴纸.jpg`, `夜间首页.jpg`).

## Global Constraints

- Preserve the existing controller/domain contracts and callbacks (`onStart`, `onFreeWorkout`, `onResume`, `onSettings`).
- Keep the four-tab navigation and Android safe-area handling; visual alignment must not remove tappable areas.
- Support all three existing theme IDs: `breathRhythm`, `trainingStickers`, and `nightInstrument`.
- Use the prototype as the source of component hierarchy, labels, spacing intent, and theme roles; use screenshots as the source of native status-bar/nav-shell behavior.
- Keep user-visible Chinese text valid UTF-8 and correct any currently mojibake labels encountered in touched files.

---

### Task 1: Establish a visual contract and regression fixtures

**Files:**
- Modify: `app/test/theme/theme_test.dart`
- Modify: `app/test/presentation/shared_widgets_test.dart`
- Create: `app/test/presentation/today_page_visual_test.dart`

**Interfaces:**
- Consumes: `themeFor(AppThemeId)`, `TodayPage`, `AppScaffold`.
- Produces: named expectations for theme roles, Today-page sections, and navigation selected state used by later tasks.

- [ ] **Step 1: Write failing theme-role tests** asserting exact values for each theme's `surfacePrimary`, `surfaceElevated`, `primaryAction`, `outline`, `cardRadius`, and `borderWidth`, using the values from the prototype token table.
- [ ] **Step 2: Write failing Today-page widget tests** asserting the initial planned state exposes the training card, rhythm section, primary start action, disabled free-workout action, stats, and exercise summary rows; assert the empty-plan/rest/recovery branches remain available.
- [ ] **Step 3: Write failing scaffold tests** asserting the selected destination has a visible selected container and that the settings action remains present without changing safe-area behavior.
- [ ] **Step 4: Run focused tests** with `flutter test test/theme/theme_test.dart test/presentation/shared_widgets_test.dart test/presentation/today_page_visual_test.dart`; record the expected failures before implementation.

### Task 2: Correct shared theme tokens and Material surfaces

**Files:**
- Modify: `app/lib/theme/app_theme.dart`
- Modify: `app/test/theme/theme_test.dart`

**Interfaces:**
- Consumes: `AppThemeId`, `FitnessThemeExtension`.
- Produces: theme data that pages can use for background, elevated surfaces, primary actions, outlines, radii, and hard-shadow treatment.

- [ ] **Step 1: Update the theme values** so the three themes map to the prototype roles: A uses light blue-gray background, deep-blue hero, white card surface, coral action; B uses yellow background/hero, near-white card, purple action, dark outline, hard shadow; C uses near-black background, dark elevated surface, blue action, lime active state.
- [ ] **Step 2: Set `ColorScheme.surface`, scaffold background, text colors, and navigation surface from the same roles** so Material 3 defaults cannot introduce a second palette.
- [ ] **Step 3: Add selected-navigation and card decoration helpers** only if needed by existing widgets; avoid duplicating color literals in individual pages.
- [ ] **Step 4: Run `flutter test test/theme/theme_test.dart` and confirm all theme-role tests pass.**

### Task 3: Align scaffold, app bar, and bottom navigation with the native captures

**Files:**
- Modify: `app/lib/presentation/app_scaffold.dart`
- Modify: `app/lib/presentation/widgets/page_header.dart`
- Modify: `app/test/presentation/shared_widgets_test.dart`
- Modify: `app/test/presentation/navigation_test.dart`

**Interfaces:**
- Consumes: shared theme extension and existing navigation callbacks.
- Produces: consistent top spacing/settings affordance and a four-item bottom bar with prototype-compatible selected-state treatment.

- [ ] **Step 1: Make the app bar/header spacing explicit** so the status-bar inset is handled once by the scaffold and page content does not receive a second accidental top offset.
- [ ] **Step 2: Style the bottom navigation** with the prototype's four equal destinations, theme-aware surface, compact icon/label spacing, and a selected pill/background matching the captures; retain 48dp minimum tap targets.
- [ ] **Step 3: Ensure settings is a single, consistently placed icon action** and that title rendering does not duplicate the Today page title.
- [ ] **Step 4: Run `flutter test test/presentation/shared_widgets_test.dart test/presentation/navigation_test.dart`.**

### Task 4: Rebuild Today page hierarchy and states

**Files:**
- Modify: `app/lib/presentation/pages/today_page.dart`
- Modify: `app/lib/presentation/widgets/workout_summary_card.dart`
- Modify: `app/test/presentation/today_page_visual_test.dart`
- Modify: `app/test/application/today_controller_test.dart` only if callback/state expectations need coverage

**Interfaces:**
- Consumes: `PlanDayExercise`, Today controller state, existing page callbacks.
- Produces: a Today screen with the prototype order: header/date, hero summary, rhythm, actions, stats, and exercise summary.

- [ ] **Step 1: Replace the current generic `Card`/Material defaults** with explicit sections matching the prototype order and spacing.
- [ ] **Step 2: Expand the planned hero** to show plan/source text, training title, exercise count, set count, estimated duration, and the three-node rhythm graphic or equivalent widget.
- [ ] **Step 3: Restore the primary “start today” action and disabled free-workout action**, wiring them to the existing callbacks and preserving loading/error/recovery behavior.
- [ ] **Step 4: Render stats as the prototype intends** and render each planned exercise with its name, set count, and target rest; keep a deliberate empty-state message only when the data really is empty.
- [ ] **Step 5: Keep rest-day, no-plan, resumable, completed, loading, and error branches visually consistent with the same theme roles.**
- [ ] **Step 6: Run `flutter test test/presentation/today_page_visual_test.dart test/application/today_controller_test.dart test/presentation/workout_pages_test.dart`.**

### Task 5: Audit remaining pages after collecting evidence

**Files:**
- Modify: relevant files identified by the page-style audit, expected candidates `app/lib/presentation/pages/workout_prepare_page.dart`, `app/lib/presentation/pages/workout_active_page.dart`, `app/lib/presentation/pages/workout_rest_page.dart`, `app/lib/presentation/pages/workout_summary_page.dart`, `app/lib/presentation/pages/plans_page.dart`, `app/lib/presentation/pages/calendar_page.dart`, `app/lib/presentation/pages/catalog_page.dart`, and shared widgets under `app/lib/presentation/widgets/`.
- Modify: corresponding tests under `app/test/presentation/`.

**Interfaces:**
- Consumes: audit findings from `app_pages/呼吸节拍.jpg`, `app_pages/训练贴纸.jpg`, `app_pages/夜间首页.jpg` and the prototype theme/page definitions. The three available captures are all Today-page theme variants; they are not evidence for plans, calendar, catalog, or workout sub-pages.
- Produces: a cross-page style matrix and targeted fixes without changing unrelated domain behavior.

- [ ] **Step 1: Capture the remaining pages from the installed APK** by navigating to plans, calendar, catalog/actions, prepare, active/rest, and summary states at the same 1080x2400 device size; store captures under a clearly named review directory without overwriting the existing Today references.
- [ ] **Step 2: Record each newly captured page's shell, background, surface, typography, spacing, and selected-navigation treatment in a cross-page matrix; mark unknowns instead of inferring them from the Today screenshots.**
- [ ] **Step 3: Fix shared-component discrepancies first** (cards, page headers, buttons, list rows, timers) so individual pages inherit the correction.
- [ ] **Step 4: Fix page-specific discrepancies only where the new capture or prototype definition shows a structural/content mismatch.**
- [ ] **Step 5: Add or update focused widget tests for every changed shared component/page, then run the full presentation and theme test set.**

### Task 6: Verify on device-sized renders and finish

**Files:**
- Modify: no source files unless verification exposes a defect.
- Inspect: `app_pages/*.jpg`, rendered Flutter screenshots at the same 1080x2400 capture size.

**Interfaces:**
- Consumes: completed Tasks 1-5.
- Produces: evidence that all three themes and the native shell match the reference captures closely enough for handoff.

- [ ] **Step 1: Run `flutter analyze`.**
- [ ] **Step 2: Run `flutter test` for the entire app.**
- [ ] **Step 3: Build/install a debug APK and capture Today, prepare, active/rest, and summary states for all three themes at the reference device size.**
- [ ] **Step 4: Compare screenshots for top inset, content start, card bounds, nav height, colors, typography scale, and selected-state treatment; fix only verified discrepancies.**
- [ ] **Step 5: Re-run `flutter analyze` and `flutter test`, then document residual differences caused by OS status/navigation bars.**

---

## Review Checklist

- [ ] No page relies on a Material default color that conflicts with the active fitness theme.
- [ ] Today planned state contains an actionable start path and planned exercises.
- [ ] Empty, rest-day, recovery, loading, error, and completed states remain reachable and tested.
- [ ] Bottom navigation labels/icons and selected state are consistent across all themes.
- [ ] Safe-area padding is applied exactly once at the shell boundary.
- [ ] All touched Chinese strings render as intended UTF-8 text.
