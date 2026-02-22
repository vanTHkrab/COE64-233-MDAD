import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';

import 'package:final66133505/core/database/database.dart';
import 'package:final66133505/core/di/injection.dart';
import 'package:final66133505/core/theme/app_theme.dart';
import 'package:final66133505/core/utils/image_storage.dart';
import 'package:final66133505/core/utils/tflite_classifier.dart';

class AddReportPage extends StatefulWidget {
  const AddReportPage({super.key});

  @override
  State<AddReportPage> createState() => _AddReportPageState();
}

class _AddReportPageState extends State<AddReportPage> {
  static final _log = Logger('AddReportPage');

  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _reporterCtrl = TextEditingController();

  List<PollingStationEntity> _stations = [];
  List<ViolationTypeEntity> _types = [];

  int? _selectedStationId;
  int? _selectedTypeId;
  bool _isSaving = false;
  bool _isLoading = true;

  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  bool _isAnalyzing = false;
  String? _aiPrediction;
  double _aiConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _reporterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    try {
      final stations = await sl<PollingStationRepository>().getAll();
      final types = await sl<ViolationTypeRepository>().getAll();

      setState(() {
        _stations = stations;
        _types = types;
        _isLoading = false;
      });
    } catch (e, s) {
      _log.severe('Failed to load dropdown data', e, s);
      setState(() => _isLoading = false);
    }
  }


  Future<void> _addNewStation() async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final zoneCtrl = TextEditingController();
    final provinceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'New Polling Station',
            style: GoogleFonts.prompt(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: idCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Station ID *',
                      hintText: 'e.g. 101',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null) return 'Must be a number';
                      if (parsed <= 0) return 'Must be > 0';
                      if (_stations.any((s) => s.stationId == parsed)) {
                        return 'ID $parsed already exists';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Station name *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: zoneCtrl,
                    decoration: const InputDecoration(labelText: 'Zone *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: provinceCtrl,
                    decoration: const InputDecoration(labelText: 'Province *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        final newStation = await sl<PollingStationRepository>().create(
          stationId: int.tryParse(idCtrl.text.trim()),
          name: nameCtrl.text,
          zone: zoneCtrl.text,
          province: provinceCtrl.text,
        );
        if (mounted) {
          setState(() {
            _stations = [
              ..._stations.where((s) => s.stationId != newStation.stationId),
              newStation,
            ];
            _selectedStationId = newStation.stationId;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to add station', e.toString());
      }
    }
  }

  Future<void> _addNewType() async {
    final nameCtrl = TextEditingController();
    String selectedSeverity = 'Medium';
    final formKey = GlobalKey<FormState>();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setInner) => AlertDialog(
            title: Text(
              'New Violation Type',
              style: GoogleFonts.prompt(fontWeight: FontWeight.w700),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Violation name *',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedSeverity,
                    decoration: const InputDecoration(labelText: 'Severity'),
                    items: const [
                      DropdownMenuItem(value: 'High', child: Text('High')),
                      DropdownMenuItem(
                        value: 'Medium',
                        child: Text('Medium'),
                      ),
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                    ],
                    onChanged: (v) => setInner(() => selectedSeverity = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop(true);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true && mounted) {
        final newType = await sl<ViolationTypeRepository>().create(
          name: nameCtrl.text,
          severity: selectedSeverity,
        );
        if (mounted) {
          setState(() {
            _types = [..._types, newType];
            _selectedTypeId = newType.typeId;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to add violation type', e.toString());
      }
    }
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        final persistentPath = await ImageStorage.copyToTemp(image.path);
        setState(() {
          _pickedImage = XFile(persistentPath);
          _aiPrediction = null;
          _aiConfidence = 0.0;
        });
        _analyzeImage();
      }
    } catch (e) {
      _log.warning('Image pick failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Image Source',
                style: GoogleFonts.prompt(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
                title: const Text('Camera'),
                subtitle: const Text('Take a new photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(ctx).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: Theme.of(ctx).colorScheme.secondary,
                  ),
                ),
                title: const Text('Gallery'),
                subtitle: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _analyzeImage() async {
    if (_pickedImage == null) return;

    setState(() => _isAnalyzing = true);

    try {
      await tfliteClassifier.init();
      final result = await tfliteClassifier.classify(File(_pickedImage!.path));

      if (result != null) {
        setState(() {
          _aiPrediction = result.label;
          _aiConfidence = result.confidence;
        });
      } else {
        if (mounted) {
          _showErrorDialog(
            'Analysis Failed',
            'Could not classify this image.\nPlease try a clearer photo.',
          );
        }
      }
    } catch (e) {
      _log.warning('AI analysis error: $e');
      if (mounted) {
        _showErrorDialog('AI Error', 'Image analysis encountered an error:\n$e');
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStationId == null || _selectedTypeId == null) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final timestamp = now.toIso8601String();

      final report = IncidentReportEntity(
        stationId: _selectedStationId!,
        typeId: _selectedTypeId!,
        reporterName: _reporterCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        timestamp: timestamp,
        evidencePhoto: _pickedImage?.path,
        aiResult: _aiPrediction,
        aiConfidence: _aiConfidence,
      );

      await sl<IncidentReportRepository>().create(report);

      // Trigger background auto-sync immediately.
      sl<AutoSyncManager>().requestSync();

      _log.info('Report created successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report created successfully ✓')),
        );
        context.pop(true);
      }
    } catch (e, s) {
      _log.severe('Failed to create report', e, s);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create report: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'New Report',
          style: GoogleFonts.prompt(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Evidence Photo ──────────────────────────────────
                    _buildImageSection(theme, colorScheme),

                    const SizedBox(height: 16),

                    // ── Polling Station ─────────────────────────────────
                    _buildSectionLabel(
                      theme,
                      Icons.how_to_vote_outlined,
                      'Polling Station',
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedStationId,
                      decoration: const InputDecoration(
                        hintText: 'Select a polling station',
                      ),
                      isExpanded: true,
                      items: [
                        ..._stations.map(
                          (s) => DropdownMenuItem(
                            value: s.stationId,
                            child: Text(
                              '${s.stationName} (${s.zone})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: -1,
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Add new station…',
                                style: GoogleFonts.prompt(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == -1) {
                          _addNewStation();
                        } else {
                          setState(() => _selectedStationId = val);
                        }
                      },
                      validator: (val) => (val == null || val == -1)
                          ? 'Please select a station'
                          : null,
                    ),

                    const SizedBox(height: 20),

                    // ── Violation Type ──────────────────────────────────
                    _buildSectionLabel(
                      theme,
                      Icons.gavel_outlined,
                      'Violation Type',
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedTypeId,
                      decoration: const InputDecoration(
                        hintText: 'Select violation type',
                      ),
                      isExpanded: true,
                      items: [
                        ..._types.map(
                          (t) => DropdownMenuItem(
                            value: t.typeId,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.typeName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _SeverityDot(severity: t.severity),
                              ],
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: -1,
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Add new type…',
                                style: GoogleFonts.prompt(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == -1) {
                          _addNewType();
                        } else {
                          setState(() => _selectedTypeId = val);
                        }
                      },
                      validator: (val) => (val == null || val == -1)
                          ? 'Please select a violation type'
                          : null,
                    ),

                    const SizedBox(height: 20),

                    // ── Reporter Name ──────────────────────────────────
                    _buildSectionLabel(theme, Icons.person_outline, 'Reporter'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reporterCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Enter reporter name',
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Please enter a name'
                          : null,
                    ),

                    const SizedBox(height: 20),

                    // ── Description ─────────────────────────────────────
                    _buildSectionLabel(
                      theme,
                      Icons.notes_outlined,
                      'Description',
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Describe the incident...',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Please enter a description'
                          : null,
                    ),

                    const SizedBox(height: 28),

                    // ── Submit ──────────────────────────────────────────
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Submit Report',
                        style: GoogleFonts.prompt(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
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

  Widget _buildImageSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image preview / placeholder ──────────────────────────────
          if (_pickedImage != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.file(
                    File(_pickedImage!.path),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: () => setState(() {
                        _pickedImage = null;
                        _aiPrediction = null;
                        _aiConfidence = 0.0;
                      }),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            )
          else
            InkWell(
              onTap: _showImageSourceSheet,
              child: Container(
                height: 180,
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add Evidence Photo',
                      style: GoogleFonts.prompt(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Take a photo or choose from gallery',
                      style: GoogleFonts.prompt(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Action bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Change / pick image button
                if (_pickedImage != null)
                  TextButton.icon(
                    onPressed: _showImageSourceSheet,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Change'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else
                  const SizedBox.shrink(),

                // Analyze with AI button
                if (_pickedImage != null)
                  FilledButton.tonalIcon(
                    onPressed: _isAnalyzing ? null : _analyzeImage,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.smart_toy_outlined, size: 18),
                    label: Text(
                      _isAnalyzing ? 'Analyzing…' : 'AI Analyze',
                      style: GoogleFonts.prompt(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),

          // ── AI result ───────────────────────────────────────────────
          if (_aiPrediction != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.smart_toy_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _aiPrediction!,
                          style: GoogleFonts.prompt(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Confidence: ${(_aiConfidence * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.prompt(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _aiConfidence >= 0.8
                        ? AppTheme.severityLow.withOpacity(0.15)
                        : AppTheme.severityMedium.withOpacity(0.15),
                    child: Text(
                      '${(_aiConfidence * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.prompt(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _aiConfidence >= 0.8
                            ? AppTheme.severityLow
                            : AppTheme.severityMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SeverityDot extends StatelessWidget {
  final String severity;

  const _SeverityDot({required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.severityColor(severity);

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
