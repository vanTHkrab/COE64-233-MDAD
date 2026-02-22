import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'package:final66133505/core/database/app_database.dart';
import 'package:final66133505/core/database/database.dart';
import 'package:final66133505/core/di/injection.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static final _log = Logger('MainLayout');

  static const _titles = ['Election Monitor', 'Reports', 'Polling Stations'];

  static const _navItems = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.assignment_outlined),
      selectedIcon: Icon(Icons.assignment_rounded),
      label: 'Reports',
    ),
    NavigationDestination(
      icon: Icon(Icons.location_on_outlined),
      selectedIcon: Icon(Icons.location_on_rounded),
      label: 'Polling Stations',
    ),
  ];

  late final AutoSyncManager _syncManager;
  StreamSubscription<SyncStatus>? _syncSub;
  SyncStatus _syncStatus = const SyncStatus();

  @override
  void initState() {
    super.initState();
    _syncManager = sl<AutoSyncManager>();
    _syncStatus = _syncManager.currentStatus;
    _syncSub = _syncManager.statusStream.listen((status) {
      if (mounted) setState(() => _syncStatus = status);
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  // ── reset database ─────────────────────────────────────────────────────

  Future<void> _confirmAndReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 40,
        ),
        title: const Text('Reset Database'),
        content: const Text(
          'This will delete ALL local data and restore the original seed data.\n\n'
          'Synced data in Firestore will NOT be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final scaffoldMsg = ScaffoldMessenger.of(context);
    scaffoldMsg.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 14),
            Text('Resetting database…'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      await sl<AppDatabase>().resetDatabase();
      _log.info('Database reset complete');

      scaffoldMsg.hideCurrentSnackBar();
      scaffoldMsg.showSnackBar(
        const SnackBar(
          content: Text('✅ Database reset — seed data restored'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Trigger a sync after reset.
      _syncManager.requestSync();

      if (mounted) widget.navigationShell.goBranch(0);
    } catch (e, s) {
      _log.severe('Database reset failed', e, s);
      scaffoldMsg.hideCurrentSnackBar();
      scaffoldMsg.showSnackBar(
        SnackBar(
          content: Text('❌ Reset failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[currentIndex],
          style: GoogleFonts.prompt(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: false,
        surfaceTintColor: colorScheme.surfaceTint,
        actions: [
          // ── Live sync status chip ──────────────────────────────────
          _SyncStatusChip(
            status: _syncStatus,
            onTap: () => _syncManager.requestSync(),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _confirmAndReset,
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset Database',
          ),
        ],
      ),
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _navItems,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sync status chip — shown in AppBar
// ═════════════════════════════════════════════════════════════════════════════

class _SyncStatusChip extends StatelessWidget {
  final SyncStatus status;
  final VoidCallback onTap;

  const _SyncStatusChip({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (IconData icon, Color color, String label) = switch (status.state) {
      SyncState.syncing => (Icons.sync_rounded, colorScheme.primary, 'Syncing'),
      SyncState.synced => (
        Icons.cloud_done_rounded,
        Colors.green.shade600,
        'Synced',
      ),
      SyncState.offline => (
        Icons.cloud_off_rounded,
        Colors.grey.shade600,
        'Offline',
      ),
      SyncState.error => (
        Icons.sync_problem_rounded,
        Colors.red.shade600,
        'Error',
      ),
      SyncState.idle when status.hasPending => (
        Icons.cloud_upload_rounded,
        Colors.orange.shade600,
        '${status.pendingCount}',
      ),
      SyncState.idle => (Icons.cloud_done_outlined, Colors.green.shade600, ''),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Tooltip(
          message: _tooltipMessage,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status.isSyncing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  Icon(icon, size: 18, color: color),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _tooltipMessage {
    return switch (status.state) {
      SyncState.syncing => 'Syncing with server…',
      SyncState.synced => 'All data synced',
      SyncState.offline => 'Offline — data saved locally',
      SyncState.error =>
        'Sync error: ${status.errorMessage ?? "unknown"}. Tap to retry.',
      SyncState.idle when status.hasPending =>
        '${status.pendingCount} report${status.pendingCount > 1 ? "s" : ""} pending sync. Tap to sync.',
      SyncState.idle => 'All data synced',
    };
  }
}
