import 'package:flutter/material.dart';

class AppBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.exposure_plus_1_outlined),
          activeIcon: Icon(Icons.exposure_plus_1),
          label: 'Counter',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.contact_mail_outlined),
          activeIcon: Icon(Icons.contact_mail),
          label: 'Contact',
        ),
      ],
    );
  }
}
