import 'package:flutter/material.dart';
import 'package:flutter_basic/features/shell/presentation/pages/app_shell.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => const AppShell(),
      settings: settings,
    );
  }
}
