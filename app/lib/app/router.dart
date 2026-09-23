import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/domain/local_date.dart';
import '../features/exercises/presentation/exercise_create_edit_screen.dart';
import '../features/exercises/presentation/exercise_detail_screen.dart';
import '../features/exercises/presentation/exercise_library_screen.dart';
import '../features/history/presentation/calendar_screen.dart';
import '../features/history/presentation/history_detail_screen.dart';
import '../features/plans/presentation/create_edit_plan_screen.dart';
import '../features/plans/presentation/plan_edit_screen.dart';
import '../features/plans/presentation/plan_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/today/presentation/home_screen.dart';
import '../features/workout/domain/workout_session.dart';
import '../features/workout/presentation/pre_workout_screen.dart';
import '../features/workout/presentation/rest_screen.dart';
import '../features/workout/presentation/workout_screen.dart';
import '../features/workout/presentation/workout_summary_screen.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../widgets/app_scaffold.dart';

abstract final class AppRoutes {
  static const home = '/home';
  static const workoutFallback = '/home?workout=unavailable';
  static const plan = '/plan';
  static const calendar = '/calendar';
  static const exercises = '/exercises';
  static const preWorkoutPath = '/pre-workout';
  static const workoutPath = '/workout/:sessionId';
  static const restPath = '/rest/:sessionId';
  static const summaryPath = '/summary/:sessionId';
  static String workout(String sessionId) => '/workout/$sessionId';
  static String rest(String sessionId) => '/rest/$sessionId';
  static String summary(String sessionId) => '/summary/$sessionId';
  static String forWorkoutSession(WorkoutSession session) =>
      switch (session.phase) {
        WorkoutPhase.resting => rest(session.id),
        WorkoutPhase.finishing => summary(session.id),
        _ => workout(session.id),
      };
  static String preWorkout({
    required LocalDate date,
    required bool freeWorkout,
  }) =>
      '$preWorkoutPath?free=$freeWorkout&date=${date.iso8601}';
  static const exerciseCreate = '/exercise-create';
  static const settings = '/settings';
  static const createPlan = '/create-plan';
  static String editPlan(String id) => '/edit-plan/$id';
  static String planEdit(String id) => '/plan-edit/$id';
  static String exerciseDetail(String id) => '/exercise-detail/$id';
  static String exerciseEdit(String id) => '/exercise-edit/$id';

  static const primary = [home, plan, calendar, exercises];
}

GoRouter createRouter() => GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => _DestinationShell(
            selectedTabIndex: 0,
            title: AppStrings.todayTitle,
            body: HomeScreen(
              showWorkoutUnavailable:
                  state.uri.queryParameters['workout'] == 'unavailable',
            ),
            action: _DestinationAction.settings,
          ),
        ),
        GoRoute(
          path: AppRoutes.preWorkoutPath,
          builder: (_, state) => PreWorkoutScreen(
            date: _routeDate(state.uri.queryParameters['date']!),
            freeWorkout: state.uri.queryParameters['free'] == 'true',
          ),
        ),
        GoRoute(
          path: AppRoutes.workoutPath,
          builder: (_, state) => WorkoutScreen(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
        GoRoute(
          path: AppRoutes.restPath,
          builder: (_, state) => RestScreen(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
        GoRoute(
          path: AppRoutes.summaryPath,
          builder: (_, state) => WorkoutSummaryScreen(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
        GoRoute(
          path: AppRoutes.plan,
          builder: (context, state) => const PlanScreen(),
        ),
        GoRoute(
          path: AppRoutes.createPlan,
          builder: (_, __) => const CreateEditPlanScreen(),
        ),
        GoRoute(
          path: '/edit-plan/:planId',
          builder: (_, state) =>
              CreateEditPlanScreen(planId: state.pathParameters['planId']!),
        ),
        GoRoute(
          path: '/plan-edit/:planId',
          builder: (_, state) =>
              PlanEditScreen(planId: state.pathParameters['planId']!),
        ),
        GoRoute(
          path: AppRoutes.calendar,
          builder: (context, state) => const CalendarScreen(),
        ),
        GoRoute(
          path: '/history/:date',
          redirect: (_, state) =>
              _tryRouteDate(state.pathParameters['date']) == null
                  ? AppRoutes.calendar
                  : null,
          builder: (_, state) => HistoryDetailScreen(
            date: _routeDate(state.pathParameters['date']!),
            initialSessionId: state.uri.queryParameters['session'],
          ),
        ),
        GoRoute(
          path: AppRoutes.exercises,
          builder: (context, state) => const ExerciseLibraryScreen(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.exerciseCreate,
          builder: (_, __) => const ExerciseCreateEditScreen(),
        ),
        GoRoute(
          path: '/exercise-edit/:exerciseId',
          builder: (_, state) => ExerciseCreateEditScreen(
            exerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
        GoRoute(
          path: '/exercise-detail/:exerciseId',
          builder: (_, state) => ExerciseDetailScreen(
            exerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ],
    );

final class _DestinationAction {
  const _DestinationAction._(this.tooltip, this.icon);

  static const settings = _DestinationAction._(
    AppStrings.settings,
    Icons.settings_outlined,
  );

  final String tooltip;
  final IconData icon;
}

LocalDate _routeDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) throw FormatException('Invalid route date: $value');
  return LocalDate(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

LocalDate? _tryRouteDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  try {
    return _routeDate(value);
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

final class _DestinationShell extends StatelessWidget {
  const _DestinationShell({
    required this.selectedTabIndex,
    required this.title,
    required this.body,
    this.action,
  });

  final int selectedTabIndex;
  final String title;
  final Widget body;
  final _DestinationAction? action;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppScaffold(
      selectedTabIndex: selectedTabIndex,
      onDestinationSelected: (selectedTabIndex) {
        context.go(AppRoutes.primary[selectedTabIndex]);
      },
      appBar: FitnessAppBar(
        title: title,
        actions: [
          if (action case final action?)
            IconButton(
              onPressed: () => context.push(AppRoutes.settings),
              tooltip: action.tooltip,
              icon: Icon(action.icon, size: theme.typography.xl),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: theme.dimensions.maxContentWidth,
          ),
          child: body,
        ),
      ),
    );
  }
}
