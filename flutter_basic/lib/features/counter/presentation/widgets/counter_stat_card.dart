import 'package:flutter/material.dart';
import 'package:flutter_basic/core/theme/app_spacing.dart';
import 'package:flutter_basic/core/theme/app_typography.dart';

class CounterStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const CounterStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            child: Icon(icon),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.subtitle),
              Text(value, style: AppTypography.headline1),
            ],
          ),
        ],
      ),
    );
  }
}
