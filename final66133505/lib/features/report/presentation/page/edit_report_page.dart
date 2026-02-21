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

class EditReportPage extends StatefulWidget {
  final int reportId;

  const EditReportPage({super.key, required this.reportId});

  @override
  State<EditReportPage> createState() => _EditReportPageState();
}

class _EditReportPageState extends State<EditReportPage> {
  static final _log = Logger('EditReportPage');

  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _reporterCtrl = TextEditingController();

  List<PollingStationEntity> _stations = [];
  List<ViolationTypeEntity> _types = [];

  int? _selectedStationId;
  int? _selectedTypeId;

  bool _isSaving = false;
  bool _isLoading = true;

  // Image
  final ImagePicker _picker = ImagePicker();
  String? _existingPhotoPath; // path already saved in DB
  XFile? _newPickedImage; // newly picked image (replaces existing)
  bool _isAnalyzing = false;
  String? _aiPrediction;
  double _aiConfidence = 0.0;

  // Original entity — used for copyWith on save
  IncidentReportEntity? _original;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _reporterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final report = await sl<IncidentReportRepository>().getById(
        widget.reportId,
      );
      final stations = await sl<PollingStationRepository>().getAll();
      final types = await sl<ViolationTypeRepository>().getAll();

      if (report == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Report not found')));
          context.pop();
        }
        return;
      }

      _descriptionCtrl.text = report.description;
      _reporterCtrl.text = report.reporterName;

      setState(() {
        _original = report;
        _stations = stations;
        _types = types;
        _selectedStationId = report.stationId;
        _selectedTypeId = report.typeId;
        _existingPhotoPath = report.evidencePhoto;
        _aiPrediction = report.aiResult;
        _aiConfidence = report.aiConfidence;
        _isLoading = false;
      });
    } catch (e, s) {
      _log.severe('Failed to load report for edit', e, s);
      if (mounted) setState(() => _isLoading = false);
    }
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
          _newPickedImage = XFile(persistentPath);
          _aiPrediction = null;
          _aiConfidence = 0.0;
        });
        // Auto-predict immediately after picking
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
                title: Text('Camera', style: GoogleFonts.prompt()),
                subtitle: Text(
                  'Take a new photo',
                  style: GoogleFonts.prompt(fontSize: 12),
                ),
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
                title: Text('Gallery', style: GoogleFonts.prompt()),
                subtitle: Text(
                  'Choose from gallery',
                  style: GoogleFonts.prompt(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_existingPhotoPath != null || _newPickedImage != null)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.severityHigh.withOpacity(0.1),
                    child: Icon(
                      Icons.delete_outline,
                      color: AppTheme.severityHigh,
                    ),
                  ),
                  title: Text(
                    'Remove photo',
                    style: GoogleFonts.prompt(color: AppTheme.severityHigh),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _newPickedImage = null;
                      _existingPhotoPath = null;
                      _aiPrediction = null;
                      _aiConfidence = 0.0;
                    });
                  },
                ),
            ],
          ),
        ),
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

  Future<void> _analyzeImage() async {
    final hasImage =
        _newPickedImage != null || ImageStorage.exists(_existingPhotoPath);
    if (!hasImage) return;

    setState(() => _isAnalyzing = true);

    try {
      final path = _newPickedImage?.path ?? _existingPhotoPath!;
      await tfliteClassifier.init();
      final result = await tfliteClassifier.classify(File(path));

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

  // ── Add-new dialogs ─────────────────────────────────────────────────

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
                    decoration:
                        const InputDecoration(labelText: 'Station name *'),
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
            // Remove any stale entry with the same ID before appending
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
    // Do NOT dispose — dialog close animation runs on the next frame and
    // the TextFormField widgets still hold references to these controllers.
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
    // Do NOT dispose — same reason as _addNewStation above.
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStationId == null || _selectedTypeId == null) return;
    if (_original == null) return;

    setState(() => _isSaving = true);

    try {
      // Use new image path if picked, else keep existing
      final photoPath = _newPickedImage?.path ?? _existingPhotoPath;

      final updated = _original!.copyWith(
        stationId: _selectedStationId,
        typeId: _selectedTypeId,
        reporterName: _reporterCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        evidencePhoto: photoPath,
        aiResult: _aiPrediction,
        aiConfidence: _aiConfidence,
      );

      await sl<IncidentReportRepository>().update(updated);
      sl<AutoSyncManager>().requestSync();

      _log.info('Report ${widget.reportId} updated');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Report updated ✓')));
        context.pop(true);
      }
    } catch (e, s) {
      _log.severe('Failed to update report', e, s);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Active photo path ────────────────────────────────────────────────────

  String? get _activePhotoPath => _newPickedImage?.path ?? _existingPhotoPath;

  bool get _hasPhoto => ImageStorage.exists(_activePhotoPath);

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Report #${widget.reportId}',
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
                    _buildImageSection(theme, cs),

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

                    // ── Reporter Name ───────────────────────────────────
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

                    // ── Save ────────────────────────────────────────────
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
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Changes',
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

  Widget _buildImageSection(ThemeData theme, ColorScheme cs) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image preview / placeholder ──────────────────────────────
          if (_hasPhoto)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.file(
                    File(_activePhotoPath!),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(cs),
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
                        _newPickedImage = null;
                        _existingPhotoPath = null;
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
            InkWell(onTap: _showImageSourceSheet, child: _imagePlaceholder(cs)),

          // ── Action bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_hasPhoto)
                  TextButton.icon(
                    onPressed: _showImageSourceSheet,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text('Change', style: GoogleFonts.prompt()),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (_hasPhoto)
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
                color: cs.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_rounded, color: cs.primary, size: 22),
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
                            color: cs.onSurfaceVariant,
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

  Widget _imagePlaceholder(ColorScheme cs) {
    return Container(
      height: 180,
      color: cs.surfaceContainerHighest.withOpacity(0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 48,
            color: cs.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Add Evidence Photo',
            style: GoogleFonts.prompt(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Take a photo or choose from gallery',
            style: GoogleFonts.prompt(
              fontSize: 12,
              color: cs.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Severity Dot ─────────────────────────────────────────────────────────────

class _SeverityDot extends StatelessWidget {
  final String severity;
  const _SeverityDot({required this.severity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.severityColor(severity),
      ),
    );
  }
}
