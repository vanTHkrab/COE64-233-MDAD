import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/dashboard/presentation/page/home.dart';
import '../features/analysis/presentation/page/ai_scanner.dart';
import '../features/report/presentation/page/report_page.dart';
import '../features/report/presentation/page/report_detail_page.dart';
import '../features/report/presentation/page/add_report_page.dart';
import '../features/report/presentation/page/edit_report_page.dart';
import '../shared/layouts/main_layout.dart';

// Keys for each navigation branch — keeps each tab's state alive.
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _analysisNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'analysis');
final _reportsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'reports');

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // ── Stateful shell — preserves each tab's navigation stack ──────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainLayout(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0 — Dashboard
        StatefulShellBranch(
          navigatorKey: _homeNavigatorKey,
          routes: [
            GoRoute(path: '/', builder: (context, state) => const MyHomePage()),
          ],
        ),
        // Tab 1 — AI Scanner
        StatefulShellBranch(
          navigatorKey: _analysisNavigatorKey,
          routes: [
            GoRoute(
              path: '/analysis',
              builder: (context, state) => const AiScanner(),
            ),
          ],
        ),
        // Tab 2 — Reports
        StatefulShellBranch(
          navigatorKey: _reportsNavigatorKey,
          routes: [
            GoRoute(
              path: '/reports',
              builder: (context, state) => const ReportPage(),
            ),
          ],
        ),
      ],
    ),

    // ── Full-screen pages (outside shell — own Scaffold, back button) ───
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/reports/detail/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return ReportDetailPage(reportId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/reports/add',
      builder: (context, state) => const AddReportPage(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/reports/edit/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return EditReportPage(reportId: id);
      },
    ),
  ],
);
