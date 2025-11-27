import 'package:flutter/material.dart';
import 'package:flutter_basic/features/home/presentation/pages/home_page.dart';
import 'package:flutter_basic/features/counter/presentation/pages/counter_page.dart';
import 'package:flutter_basic/features/contact/presentation/pages/contact_page.dart';
import 'package:flutter_basic/features/favorites/presentation/page/favorites_page.dart';
import 'package:flutter_basic/core/widgets/app_bottom_navbar.dart';
import 'package:flutter_basic/core/widgets/app_navbar.dart';
import 'package:flutter_basic/core/widgets/app_sidebar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _breakpoint = 900.0;

  int _currentIndex = 0;

  static const _titles = [
    'Home',
    'Favorites'
    'Counter',
    'Contact',
  ];

  final _pages = [
    const HomePage(),
    const FavoritesPage(),
    const CounterPage(),
    const ContactPage(),
  ];

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  Widget _buildContent() {
    return IndexedStack(
      index: _currentIndex,
      children: _pages,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSidebar = constraints.maxWidth >= _breakpoint;
        final body = useSidebar
            ? AppSidebar(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onTabSelected,
                child: _buildContent(),
              )
            : _buildContent();

        return Scaffold(
          appBar: AppNavbar(title: _titles[_currentIndex], showBack: true, onBack: () {
            setState(() => _currentIndex = 0);
            }),
          body: body,
          bottomNavigationBar: useSidebar
              ? null
              : AppBottomNavbar(
                  currentIndex: _currentIndex,
                  onTap: _onTabSelected,
                ),
        );
      },
    );
  }
}
