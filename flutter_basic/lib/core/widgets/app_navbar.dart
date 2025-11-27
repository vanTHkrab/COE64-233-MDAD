import 'package:flutter/material.dart';
import 'package:flutter_basic/core/widgets/app_logo.dart';

class AppNavbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final int selectedIndex;
  final VoidCallback? onBack;

  const AppNavbar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
    this.selectedIndex = 0,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: showBack
          ? CircleIconButton(
              icon: AppLogo(),
              onTap: onBack ??
                  () {
                    Navigator.of(context).maybePop();
                  },
            )
          : null,
      leadingWidth: 80,
      actions: actions,
      actionsPadding: const EdgeInsets.only(right: 16, left: 8),
      title: Text("$title Page"),
      centerTitle: true,
      elevation: 0,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}