import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';

class AddPollingStationPage extends StatefulWidget {
  const AddPollingStationPage({super.key});

  @override
  State<AddPollingStationPage> createState() => _AddPollingStationPageState();
}

class _AddPollingStationPageState extends State<AddPollingStationPage> {
  static final _log = Logger('AddPollingStationPage');

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _zoneController = TextEditingController();
  final _provinceController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _zoneController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Polling Station', style: GoogleFonts.poppins()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Station Name'),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _zoneController,
                decoration: InputDecoration(labelText: 'Zone'),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _provinceController,
                decoration: InputDecoration(labelText: 'Province'),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _savePollingStation,
                child: Text(_isSaving ? 'Saving...' : 'Save', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePollingStation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Simulate saving to database
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pop(); // Go back after saving
    } catch (e, st) {
      _log.severe('Failed to save polling station', e, st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save polling station: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}