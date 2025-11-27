import 'package:flutter/material.dart';
import 'package:flutter_basic/core/theme/app_typography.dart';
import 'package:flutter_basic/features/counter/presentation/widgets/counter_stat_card.dart';

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  // Keys for testing purposes
  static const _counterValueKey = ValueKey('counter-value');
  static const _incrementButtonKey = ValueKey('counter-increment');
  static const _decrementButtonKey = ValueKey('counter-decrement');

  // Counter state
  int _counter = 0;

  // Methods to modify counter state
  void _increment() => setState(() => _counter++);
  void _decrement() => setState(() => _counter--);
  void _reset() => setState(() => _counter = 0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available height minus padding
  const paddingOffset = 48.0; // 24 top + 24 bottom
  // Ensure minHeight is not negative
  final availableHeight = constraints.maxHeight.isFinite ? constraints.maxHeight - paddingOffset : 0.0;
  final minHeight = availableHeight < 0 ? 0.0 : availableHeight;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            // Set minimum height to fill available space
            constraints: BoxConstraints(minHeight: minHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text('กดเพื่อเพิ่ม – ลด ตัวเลข', style: AppTypography.subtitle, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  '$_counter',
                  key: _counterValueKey,
                  textAlign: TextAlign.center,
                  style: AppTypography.headline1.copyWith(fontSize: 56),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    CounterStatCard(
                      label: 'ค่าสุดท้าย',
                      value: '$_counter',
                      icon: Icons.numbers,
                    ),
                    CounterStatCard(
                      label: 'เพิ่มทั้งหมด',
                      value: '${_counter >= 0 ? _counter : 0}',
                      icon: Icons.trending_up,
                    ),
                    CounterStatCard(
                      label: 'ลดทั้งหมด',
                      value: '${_counter < 0 ? _counter.abs() : 0}',
                      icon: Icons.trending_down,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: _decrementButtonKey,
                        onPressed: _decrement,
                        icon: const Icon(Icons.remove),
                        label: const Text('ลด'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: _incrementButtonKey,
                        onPressed: _increment,
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่ม'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('รีเซ็ต'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
