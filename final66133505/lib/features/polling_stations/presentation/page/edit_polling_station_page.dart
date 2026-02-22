import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';

import 'package:final66133505/core/database/database.dart';
import 'package:final66133505/core/di/injection.dart';
import 'package:final66133505/core/theme/app_theme.dart';
import '../../domain/entities/polling_station.dart';

class EditPollingStationPage extends StatefulWidget {
  final int stationId;

  const EditPollingStationPage({super.key, required this.stationId});

  @override
  State<EditPollingStationPage> createState() => _EditPollingStationPageState();
}

class _EditPollingStationPageState extends State<EditPollingStationPage> {
  static final _log = Logger('EditPollingStationPage');

  final PollingStationRepository _stationRepo = sl<PollingStationRepository>();

  PollingStationEntity? _original;


  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _zoneController = TextEditingController();
  final _provinceController = TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

    @override
  void dispose() {
    _nameController.dispose();
    _zoneController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final station = await sl<PollingStationRepository>().getById(
        widget.stationId,
      );
      _nameController.text = station?.stationName ?? '';
      _zoneController.text = station?.zone ?? '';
      _provinceController.text = station?.province ?? '';

      if (station == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Polling station not found')));
          Navigator.of(context).pop();
        }
        return;
      }

      setState(() {
        _original = station;
        _isLoading = false;
      });
    } catch (e, s) {
      _log.severe('Failed to load polling station for edit', e, s);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _log.warning('Form validation failed');
      return;
    }
    if (_original == null) return;

    _log.info('Submitting edit for station ID ${_original!.stationId}');

    setState(() => _isSaving = true);

    try {
      final updated = _original!.copyWith(
        stationId: _original!.stationId,
        stationName: _nameController.text.trim(),
        zone: _zoneController.text.trim(),
        province: _provinceController.text.trim(),
      );

      await sl<PollingStationRepository>().update(updated);
      sl<AutoSyncManager>().requestSync();

    } catch (e, s) {
      _log.severe('Failed to save polling station', e, s);
      if (mounted) _showErrorDialog('Error', 'Failed to save polling station');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = (_original != null ? 'Edit ${_original!.zone} - ${_original!.stationName}' : 'Edit Polling Station');

    final _idController = TextEditingController(text: _original?.stationId.toString());
    final _nameController = TextEditingController(text: _original?.stationName);
    final _zoneController = TextEditingController(text: _original?.zone);
    final _provinceController = TextEditingController(text: _original?.province);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
        toolbarTextStyle: GoogleFonts.prompt(fontWeight: FontWeight.w600).copyWith(color: cs.onPrimary),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _idController,
                      decoration: InputDecoration(labelText: 'Station ID'),
                    enabled: false,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: 'Station Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _zoneController,
                    decoration: InputDecoration(labelText: 'Zone'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _provinceController,
                    decoration: InputDecoration(labelText: 'Province'),
                  ),
                  const SizedBox(height: 12),
                  Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        child: _isSaving
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            )

        ),  
      ); 
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
        title: Text(title, style: GoogleFonts.prompt(fontWeight: FontWeight.w700)),
        content: Text(message, style: GoogleFonts.prompt()),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
} 

