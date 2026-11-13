import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/presentation/analytics_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/workouts/presentation/screens/history_screen.dart';
import '../features/workouts/presentation/screens/home_shell.dart';
import '../features/workouts/presentation/screens/workout_session_screen.dart';
import '../features/workouts/presentation/screens/weekly_schedule_screen.dart';
import 'app_settings.dart';
import 'theme.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const WeeklyScheduleScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/workout/:templateId',
      builder: (context, state) => WorkoutSessionScreen(
        templateId: state.pathParameters['templateId']!,
        date: DateTime.tryParse(state.uri.queryParameters['date'] ?? ''),
      ),
    ),
  ],
);

class WeightLogApp extends ConsumerWidget {
  const WeightLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appSettingsProvider).themeMode;
    return MaterialApp.router(
      title: 'WeightLog',
      debugShowCheckedModeBanner: false,
      theme: WeightLogTheme.light,
      darkTheme: WeightLogTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
