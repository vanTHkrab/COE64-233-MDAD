import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';

import 'package:final66133505/core/database/database.dart';
import 'package:final66133505/core/di/injection.dart';
import 'package:final66133505/core/theme/app_theme.dart';
import '../../domain/entities/polling_station.dart';
import 'edit_polling_station_page.dart';


class PollingStationDetailPage extends StatefulWidget {
  final int stationId;

  const PollingStationDetailPage({super.key, required this.stationId});

  @override
  State<PollingStationDetailPage> createState() => _PollingStationDetailPageState();
}

class _PollingStationDetailPageState extends State<PollingStationDetailPage> {
  static final _log = Logger('PollingStationDetailPage');

  final PollingStationRepository _stationRepo = sl<PollingStationRepository>();

  PollingStationEntity? _station;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final station = await _stationRepo.getById(widget.stationId);
      if (mounted) setState(() => _station = station);
    } catch (e, st) {
      _log.severe('Failed to load polling station', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load polling station')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = (_station != null ? '${_station!.zone} - ${_station!.stationName}' : '');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.prompt(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final updated = await Navigator.of(context).push<bool>(
                // to route edit page with stationId param
                MaterialPageRoute(
                  builder: (context) => EditPollingStationPage(stationId: widget.stationId),
                ),
              );
              if (updated == true && mounted) _load();
            },
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit polling station',
          ),
        ],
      ),
      
       body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _station == null
          ? _buildNotFound(theme)
          : _buildDetail(theme, cs),
    );
  }

  Widget _buildNotFound(ThemeData theme) {
    return Center(
      child: Text(
        'Polling station not found',
        style: GoogleFonts.prompt(fontSize: 16, color: theme.colorScheme.error),
      ),
    );
  }

  Widget _buildDetail(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Station ID: ${_station!.stationId}', style: GoogleFonts.prompt(fontSize: 14)),
          const SizedBox(height: 8),
          Text('Station Name: ${_station!.stationName}', style: GoogleFonts.prompt(fontSize: 14)),
          const SizedBox(height: 8),
          Text('Zone: ${_station!.zone}', style: GoogleFonts.prompt(fontSize: 14)),
          const SizedBox(height: 8),
          Text('Province: ${_station!.province}', style: GoogleFonts.prompt(fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            'Last Updated: ${DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(_station!.updatedAt))}',
            style: GoogleFonts.prompt(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text('Synced: ${_station!.isSynced ? 'Yes' : 'No'}', style: GoogleFonts.prompt(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}