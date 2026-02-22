import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:final66133505/core/database/database.dart';
import 'package:final66133505/core/di/injection.dart';
import 'package:final66133505/core/theme/app_theme.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  int _totalReports = 0;
  int _unsyncedCount = 0;
  int _totalStations = 0;
  
  List<PollingStationEntity> _topStations = [];
  List<IncidentReportEntity> _allReports = [];
  List<IncidentReportEntity> _recentReports = [];
  List<ViolationTypeEntity> _violationTypes = [];
  List<PollingStationEntity> _stations = [];
  bool _isLoading = true;
  SyncStatus _syncStatus = const SyncStatus();

  StreamSubscription<SyncStatus>? _syncSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboard();

    final syncManager = sl<AutoSyncManager>();
    _syncStatus = syncManager.currentStatus;
    _syncSub = syncManager.statusStream.listen((status) {
      // Reload on every sync completion so a delete on the Reports tab
      // is reflected here as soon as sync fires.
      if ((status.state == SyncState.synced ||
              status.state == SyncState.syncing) &&
          mounted) {
        _loadDashboard();
      }
      if (mounted) setState(() => _syncStatus = status);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload when app comes back to foreground.
    if (state == AppLifecycleState.resumed && mounted) {
      _loadDashboard();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final report = await sl<IncidentReportRepository>().getAll();
      final topstation = await sl<PollingStationRepository>().getTopStationByReportCount(3);
      final unsynced = await sl<IncidentReportRepository>().getUnsyncedCount();
      final stations = await sl<PollingStationRepository>().getAll();
      final types = await sl<ViolationTypeRepository>().getAll();

      setState(() {
        _topStations = topstation;
        _allReports = report;
        _totalReports = report.length;
        _unsyncedCount = unsynced;
        _totalStations = stations.length;
        _stations = stations;
        _violationTypes = types;
        _recentReports = report.take(5).toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // ── Computed data for charts ──────────────────────────────────────────

  /// Severity distribution: { "High": n, "Medium": n, "Low": n }
  Map<String, int> get _severityCounts {
    final counts = <String, int>{'High': 0, 'Medium': 0, 'Low': 0};
    for (final r in _allReports) {
      final type = _violationTypes.where((t) => t.typeId == r.typeId);
      if (type.isNotEmpty) {
        final sev = type.first.severity;
        counts[sev] = (counts[sev] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Reports per station: { stationName: count }
  Map<String, int> get _stationCounts {
    final counts = <String, int>{};
    for (final r in _allReports) {
      final station = _stations.where((s) => s.stationId == r.stationId);
      if (station.isNotEmpty) {
        final name = station.first.stationName;
        final shortName = name.length > 12 ? '${name.substring(0, 12)}…' : name;
        counts[shortName] = (counts[shortName] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Reports per violation type
  Map<String, int> get _typeCounts {
    final counts = <String, int>{};
    for (final r in _allReports) {
      final type = _violationTypes.where((t) => t.typeId == r.typeId);
      if (type.isNotEmpty) {
        final name = type.first.typeName;
        final shortName = name.contains('(')
            ? name.substring(0, name.indexOf('(')).trim()
            : (name.length > 15 ? '${name.substring(0, 15)}…' : name);
        counts[shortName] = (counts[shortName] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 16),
            Text(
              'Loading dashboard…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // ── Header ─────────────────────────────────────────────────
          _buildHeader(theme, cs),
          const SizedBox(height: 20),

          // ── KPI Stats Row ──────────────────────────────────────────
          _buildStatsRow(cs),
          const SizedBox(height: 24),

          // ── Quick Actions ──────────────────────────────────────────
          _buildQuickActions(theme, cs),
          const SizedBox(height: 24),

          // ── Charts ─────────────────────────────────────────────────
          if (_allReports.isNotEmpty) ...[
            _buildSectionTitle(theme, 'Severity Distribution'),
            const SizedBox(height: 12),
            _SeverityPieChart(severityCounts: _severityCounts),
            const SizedBox(height: 24),

            _buildSectionTitle(theme, 'Reports by Station'),
            const SizedBox(height: 12),
            _StationBarChart(
              stationCounts: _stationCounts,
              chartColors: AppTheme.chartColors,
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(theme, 'Reports by Type'),
            const SizedBox(height: 12),
            _TypeBarChart(typeCounts: _typeCounts),
            const SizedBox(height: 24),
          ],

          // ── Recent Reports ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle(theme, 'The top 3 polling stations\nwith the most complaints.'),
              TextButton.icon(
                onPressed: () => context.go('/reports'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // _buildRecentReports(theme, cs),
          _buildTopStations(theme, cs),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.how_to_vote_rounded, size: 28, color: cs.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Election Monitor',
                style: GoogleFonts.prompt(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE, d MMMM y').format(DateTime.now()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stats Row ───────────────────────────────────────────────────────────

  Widget _buildStatsRow(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _KPICard(
            icon: Icons.assignment_rounded,
            label: 'Reports',
            value: '$_totalReports',
            gradient: const [Color(0xFF0D47A1), Color(0xFF1976D2)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KPICard(
            icon: Icons.cloud_upload_rounded,
            label: 'Unsynced',
            value: '$_unsyncedCount',
            gradient: _unsyncedCount > 0
                ? const [Color(0xFFE65100), Color(0xFFEF6C00)]
                : const [Color(0xFF2E7D32), Color(0xFF43A047)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KPICard(
            icon: Icons.location_on_rounded,
            label: 'Stations',
            value: '$_totalStations',
            gradient: const [Color(0xFF00796B), Color(0xFF26A69A)],
          ),
        ),
      ],
    );
  }

  // ── Quick Actions ───────────────────────────────────────────────────────

  Widget _buildQuickActions(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(theme, 'Quick Actions'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionChip(
                icon: Icons.add_circle_outline_rounded,
                label: 'New Report',
                color: cs.primary,
                onTap: () => context.push('/reports/add'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionChip(
                icon: _syncStatus.isSyncing
                    ? Icons.hourglass_top_rounded
                    : Icons.sync_rounded,
                label: _syncStatus.isSyncing ? 'Syncing…' : 'Sync Now',
                color: const Color(0xFFD4A017),
                onTap: () async {
                  if (!_syncStatus.isSyncing) {
                    await sl<AutoSyncManager>().requestSync();
                    _loadDashboard();
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionChip(
                icon: Icons.list_alt_rounded,
                label: 'All Reports',
                color: const Color(0xFF00796B),
                onTap: () => context.go('/reports'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopStations(ThemeData theme, ColorScheme cs) {
    if (_topStations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: cs.onSurfaceVariant.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No data yet',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reports will be analyzed here',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _TopStationTile(
      stations: _topStations,
      // onTap: (stationId) => context.push('/stations/detail/$stationId'),
    );  
  }

  // ── Recent Reports ──────────────────────────────────────────────────────

  Widget _buildRecentReports(ThemeData theme, ColorScheme cs) {
    if (_recentReports.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: cs.onSurfaceVariant.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No reports yet',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap "New Report" to add one',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _recentReports.map((r) {
        final type = _violationTypes.where((t) => t.typeId == r.typeId);
        final severity = type.isNotEmpty ? type.first.severity : 'Low';

        return _RecentReportTile(
          report: r,
          severityColor: AppTheme.severityColor(severity),
          onTap: () => context.push('/reports/detail/${r.reportId}'),
        );
      }).toList(),
    );
  }

  // ── Section Title ───────────────────────────────────────────────────────

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: GoogleFonts.prompt(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// KPI Card — gradient background stat card
// ═════════════════════════════════════════════════════════════════════════════

class _KPICard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;

  const _KPICard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.prompt(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.prompt(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Action Chip — quick action button
// ═════════════════════════════════════════════════════════════════════════════

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.prompt(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Severity Pie Chart
// ═════════════════════════════════════════════════════════════════════════════

class _SeverityPieChart extends StatelessWidget {
  final Map<String, int> severityCounts;

  const _SeverityPieChart({required this.severityCounts});

  @override
  Widget build(BuildContext context) {
    final total = severityCounts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final entries = severityCounts.entries.where((e) => e.value > 0).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // ── Pie ───────────────────────────────────────────────────
            SizedBox(
              width: 130,
              height: 130,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 28,
                  sections: entries.map((e) {
                    final pct = (e.value / total * 100).round();
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      color: AppTheme.severityColor(e.key),
                      radius: 38,
                      title: '$pct%',
                      titleStyle: GoogleFonts.prompt(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 24),

            // ── Legend ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppTheme.severityColor(e.key),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          e.key,
                          style: GoogleFonts.prompt(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${e.value}',
                          style: GoogleFonts.prompt(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Station Bar Chart
// ═════════════════════════════════════════════════════════════════════════════

class _StationBarChart extends StatelessWidget {
  final Map<String, int> stationCounts;
  final List<Color> chartColors;

  const _StationBarChart({
    required this.stationCounts,
    required this.chartColors,
  });

  @override
  Widget build(BuildContext context) {
    final entries = stationCounts.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    final maxVal = entries
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
        child: SizedBox(
          height: (entries.length * 50).toDouble().clamp(100, 250),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal + 1,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${entries[group.x.toInt()].key}\n',
                      GoogleFonts.prompt(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(
                          text: '${rod.toY.toInt()} reports',
                          style: GoogleFonts.prompt(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      if (value == value.roundToDouble() && value >= 0) {
                        return Text(
                          '${value.toInt()}',
                          style: GoogleFonts.prompt(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < entries.length) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            entries[idx].key,
                            style: GoogleFonts.prompt(fontSize: 8),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
                },
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(entries.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: entries[i].value.toDouble(),
                      color: chartColors[i % chartColors.length],
                      width: 22,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Violation Type Bar Chart
// ═════════════════════════════════════════════════════════════════════════════

class _TypeBarChart extends StatelessWidget {
  final Map<String, int> typeCounts;

  const _TypeBarChart({required this.typeCounts});

  @override
  Widget build(BuildContext context) {
    final entries = typeCounts.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    final maxVal = entries
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
        child: SizedBox(
          height: (entries.length * 50).toDouble().clamp(100, 250),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal + 1,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${entries[group.x.toInt()].key}\n',
                      GoogleFonts.prompt(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(
                          text: '${rod.toY.toInt()} reports',
                          style: GoogleFonts.prompt(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      if (value == value.roundToDouble() && value >= 0) {
                        return Text(
                          '${value.toInt()}',
                          style: GoogleFonts.prompt(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < entries.length) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            entries[idx].key,
                            style: GoogleFonts.prompt(fontSize: 8),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
                },
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(entries.length, (i) {
                const colors = [
                  Color(0xFF6A1B9A),
                  Color(0xFFD4A017),
                  Color(0xFFC62828),
                  Color(0xFF0D47A1),
                  Color(0xFF00796B),
                ];
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: entries[i].value.toDouble(),
                      color: colors[i % colors.length],
                      width: 22,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Recent Report Tile
// ═════════════════════════════════════════════════════════════════════════════

class _TopStationTile extends StatelessWidget {
  final List<PollingStationEntity> stations;
  // final Function(int stationId) onTap;

  const _TopStationTile({
    required this.stations,
    // required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: stations.map((s) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            // onTap: () => onTap(s.stationId),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s.stationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.prompt(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RecentReportTile extends StatelessWidget {
  final IncidentReportEntity report;
  final Color severityColor;
  final VoidCallback onTap;

  const _RecentReportTile({
    required this.report,
    required this.severityColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(report.timestamp) ?? DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Severity indicator bar ────────────────────────────
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),

              // ── Sync status icon ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: report.isSynced
                      ? AppTheme.syncedColor.withOpacity(0.1)
                      : AppTheme.pendingColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  report.isSynced
                      ? Icons.cloud_done_rounded
                      : Icons.schedule_rounded,
                  color: report.isSynced
                      ? AppTheme.syncedColor
                      : AppTheme.pendingColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),

              // ── Text ──────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.prompt(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$formattedDate  •  ${report.reporterName}',
                      style: GoogleFonts.prompt(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
