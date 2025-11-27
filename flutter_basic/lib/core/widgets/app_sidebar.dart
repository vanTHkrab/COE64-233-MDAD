import 'package:flutter/material.dart';

class AppSidebar extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppSidebar({
    super.key,
    required this.child,
    required this.onDestinationSelected,
    this.selectedIndex = 0,
  });

  static const _destinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Home'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.favorite_border),
      selectedIcon: Icon(Icons.favorite),
      label: Text('Favorites'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.exposure_plus_1_outlined),
      selectedIcon: Icon(Icons.exposure_plus_1),
      label: Text('Counter'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.contact_mail_outlined),
      selectedIcon: Icon(Icons.contact_mail),
      label: Text('Contact'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          labelType: NavigationRailLabelType.all,
          destinations: _destinations,
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(child: child),
      ],
    );
  }
}