import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';

import 'package:final66133505/core/database/database.dart';
import 'package:final66133505/core/di/injection.dart';
import 'package:final66133505/core/theme/app_theme.dart';

class EditPollingStationPage extends StatefulWidget {
  final int stationId;

  const EditPollingStationPage({super.key, required this.stationId});

  @override
  State<EditPollingStationPage> createState() => _EditPollingStationPageState();
}

class _EditPollingStationPageState extends State<EditPollingStationPage> {
  static final _log = Logger('EditPollingStationPage');

  static const _allowedPrefixes = [
    'โรงเรียน',
    'วัด',
    'เต็นท์',
    'ศาลา',
    'หอประชุม',
  ];

  final PollingStationRepository _stationRepo = sl<PollingStationRepository>();

  PollingStationEntity? _original;
  List<PollingStationEntity> _allStations = [];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _zoneController = TextEditingController();
  final _provinceController = TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;
  String? _loadError;

  SyncStatus _syncStatus = const SyncStatus();
  StreamSubscription<SyncStatus>? _syncSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    final syncManager = sl<AutoSyncManager>();
    _syncStatus = syncManager.currentStatus;
    _syncSub = syncManager.statusStream.listen((status) {
      if (mounted) setState(() => _syncStatus = status);
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _nameController.dispose();
    _zoneController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load station and all stations separately to avoid Future.wait cast issues
      final station = await _stationRepo.getById(widget.stationId);
      final allStations = await _stationRepo.getAll();

      if (station == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Polling station not found')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      _nameController.text = station.stationName;
      _zoneController.text = station.zone;
      _provinceController.text = station.province;

      if (mounted) {
        setState(() {
          _original = station;
          _allStations = allStations;
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e, s) {
      _log.severe('Failed to load polling station for edit', e, s);
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String? _validatePrefix(String name) {
    final trimmed = name.trim();
    final ok = _allowedPrefixes.any((p) => trimmed.startsWith(p));
    if (!ok) {
      return 'Name must be start follow: ${_allowedPrefixes.join(', ')}';
    }
    return null;
  }

  String? _validateDuplicate(String name) {
    final trimmed = name.trim();
    final isDuplicate = _allStations.any(
      (s) =>
          s.stationId != _original!.stationId &&
          s.stationName.trim().toLowerCase() == trimmed.toLowerCase(),
    );
    if (isDuplicate) {
      return 'This station name already exists in the system. Please use a different name.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_original == null) return;

    final name = _nameController.text.trim();

    final prefixError = _validatePrefix(name);
    if (prefixError != null) {
      _showErrorDialog('Invalid name format', prefixError);
      return;
    }

    final dupError = _validateDuplicate(name);
    if (dupError != null) {
      _showErrorDialog('Duplicate name', dupError); 
      return;
    }

    setState(() => _isSaving = true);

    try {
      final reportCount =
          await _stationRepo.countReportsByStation(_original!.stationId);

      if (reportCount > 0) {
        final confirmed = await _showConfirmDialog(reportCount);
        if (confirmed != true) {
          setState(() => _isSaving = false);
          return;
        }
      }

      final updated = _original!.copyWith(
        stationName: name,
        zone: _zoneController.text.trim(),
        province: _provinceController.text.trim(),
      );
      await _stationRepo.update(updated);
      sl<AutoSyncManager>().requestSync();

      _log.info('Station id=${_original!.stationId} updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกสำเร็จ', style: GoogleFonts.prompt()),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e, s) {
      _log.severe('Failed to save polling station', e, s);
      if (mounted) _showErrorDialog('Error', 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool?> _showConfirmDialog(int count) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: AppTheme.severityHigh,
          size: 40,
        ),
        title: Text(
          'Existing Reports',
          style: GoogleFonts.prompt(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This station has $count existing reports.\nDo you want to proceed with the update?',
          style: GoogleFonts.prompt(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('ยกเลิก', style: GoogleFonts.prompt()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('ยืนยัน', style: GoogleFonts.prompt()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = _original != null
        ? 'Edit: ${_original!.stationName}'
        : 'Edit Polling Station';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.prompt(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Sync indicator in AppBar
          _buildSyncChip(),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load station data',
                      style: GoogleFonts.prompt(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.prompt(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() { _isLoading = true; _loadError = null; });
                        _loadData();
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text('Retry', style: GoogleFonts.prompt()),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Sync banner below AppBar
                _buildSyncBanner(cs),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                    // Station ID (read-only)
                    _buildSectionLabel(theme, Icons.info_outline, 'Station ID'),
                    TextFormField(
                      initialValue: _original?.stationId.toString(),
                      enabled: false,
                      style: GoogleFonts.prompt(),
                    ),
                    const SizedBox(height: 16),

                    _buildSectionLabel(theme, Icons.location_on_outlined, 'Polling Station Details'),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Start with: โรงเรียน, วัด, เต็นท์, ศาลา, หอประชุม',
                        hintStyle: GoogleFonts.prompt(fontSize: 12),
                      ),
                      style: GoogleFonts.prompt(),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    _buildSectionLabel(theme, Icons.map_outlined, 'Zone / District'),
                    TextFormField(
                      controller: _zoneController,
                      decoration: InputDecoration(
                        hintText: 'Enter zone or district',
                        hintStyle: GoogleFonts.prompt(fontSize: 12),
                      ),
                      style: GoogleFonts.prompt(),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    _buildSectionLabel(theme, Icons.place_outlined, 'Province'),
                    TextFormField(
                      controller: _provinceController,
                      decoration: InputDecoration(
                        hintText: 'Enter province',
                        hintStyle: GoogleFonts.prompt(fontSize: 12),
                      ),
                      style: GoogleFonts.prompt(),
                      textInputAction: TextInputAction.done,
                    ),

                    const Spacer(),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Cancel', style: GoogleFonts.prompt()),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _submit,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            _isSaving ? 'Saving…' : 'Save',
                            style: GoogleFonts.prompt(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      );
    }

    Widget _buildSyncBanner(ColorScheme cs) {
    if (_syncStatus.state == SyncState.idle && !_syncStatus.hasPending) {
      return const SizedBox.shrink();
    }

    final (Color bg, Color fg, IconData icon, String text) =
        switch (_syncStatus.state) {
      SyncState.syncing => (
        const Color(0xFFE3F2FD),
        const Color(0xFF0D47A1),
        Icons.sync_rounded,
        'Syncing with server…',
      ),
      SyncState.synced => (
        AppTheme.syncedColor.withOpacity(0.1),
        AppTheme.syncedColor,
        Icons.cloud_done_rounded,
        'Synced to Firestore ✓',
      ),
      SyncState.offline => (
        AppTheme.offlineColor.withOpacity(0.1),
        AppTheme.offlineColor,
        Icons.cloud_off_rounded,
        'Offline — saved locally',
      ),
      SyncState.error => (
        AppTheme.severityHigh.withOpacity(0.1),
        AppTheme.severityHigh,
        Icons.sync_problem_rounded,
        'Sync failed — tap to retry',
      ),
      SyncState.idle when _syncStatus.hasPending => (
        AppTheme.pendingColor.withOpacity(0.1),
        AppTheme.pendingColor,
        Icons.cloud_upload_outlined,
        'Pending sync — will retry automatically',
      ),
      _ => (Colors.transparent, Colors.transparent, Icons.sync, ''),
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return Material(
      color: bg,
      child: InkWell(
        onTap: () => sl<AutoSyncManager>().requestSync(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              if (_syncStatus.isSyncing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                Icon(icon, size: 16, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.prompt(
                    color: fg,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar sync chip ──────────────────────────────────────────────────────
  Widget _buildSyncChip() {
    if (_syncStatus.isSyncing) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Syncing…',
              style: GoogleFonts.prompt(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      );
    }
    if (_syncStatus.state == SyncState.synced) {
      return Icon(
        Icons.cloud_done_rounded,
        size: 20,
        color: AppTheme.syncedColor,
      );
    }
    if (_syncStatus.hasPending) {
      return Icon(
        Icons.cloud_upload_outlined,
        size: 20,
        color: AppTheme.pendingColor,
      );
    }
    if (_syncStatus.state == SyncState.offline) {
      return Icon(
        Icons.cloud_off_rounded,
        size: 20,
        color: AppTheme.offlineColor,
      );
    }
    if (_syncStatus.state == SyncState.error) {
      return Icon(
        Icons.sync_problem_rounded,
        size: 20,
        color: AppTheme.severityHigh,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSectionLabel(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.prompt(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.error_outline_rounded,
          color: Colors.red,
          size: 40,
        ),
        title: Text(
          title,
          style: GoogleFonts.prompt(fontWeight: FontWeight.w700),
        ),
        content: Text(message, style: GoogleFonts.prompt()),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('ตกลง', style: GoogleFonts.prompt()),
          ),
        ],
      ),
    );
  }
}
