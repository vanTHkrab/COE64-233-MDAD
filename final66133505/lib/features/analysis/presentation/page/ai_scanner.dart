import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';

import 'package:final66133505/core/theme/app_theme.dart';
import 'package:final66133505/core/utils/image_storage.dart';
import 'package:final66133505/core/utils/tflite_classifier.dart';

/// AI-powered election incident scanner page.
class AiScanner extends StatefulWidget {
  const AiScanner({super.key});

  @override
  State<AiScanner> createState() => _AiScannerState();
}

class _AiScannerState extends State<AiScanner>
    with SingleTickerProviderStateMixin {
  static final _log = Logger('AiScanner');

  final ImagePicker _picker = ImagePicker();

  XFile? _pickedImage;
  bool _isAnalyzing = false;
  String? _prediction;
  double _confidence = 0.0;
  String? _severity;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
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
        // Copy to persistent temp dir so the path survives process restarts.
        final persistentPath = await ImageStorage.copyToTemp(image.path);
        setState(() {
          _pickedImage = XFile(persistentPath);
          _prediction = null;
          _confidence = 0.0;
          _severity = null;
        });
      }
    } catch (e) {
      _log.warning('Image pick failed: \$e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: \$e')));
      }
    }
  }

  void _showImageSourceSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
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
              const SizedBox(height: 20),
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
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.camera_alt_rounded, color: cs.primary),
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
                  backgroundColor: cs.secondaryContainer,
                  child: Icon(Icons.photo_library_rounded, color: cs.secondary),
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
      // Ensure the model is loaded (no-op if already initialised)
      await tfliteClassifier.init();

      final result = await tfliteClassifier.classify(File(_pickedImage!.path));

      if (result != null) {
        setState(() {
          _prediction = result.label;
          _confidence = result.confidence;
          _severity = result.severity;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analysis failed — try another image')),
          );
        }
      }
    } catch (e) {
      _log.warning('AI analysis error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _reset() {
    setState(() {
      _pickedImage = null;
      _prediction = null;
      _confidence = 0.0;
      _severity = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(cs),
          const SizedBox(height: 24),
          _buildImageArea(theme, cs),
          const SizedBox(height: 20),
          _buildActions(cs),
          if (_prediction != null) ...[
            const SizedBox(height: 24),
            _buildResult(theme, cs),
          ],
          if (_pickedImage == null && _prediction == null) ...[
            const SizedBox(height: 32),
            _buildHowItWorks(theme, cs),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.document_scanner_rounded,
            size: 26,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Scanner',
                style: GoogleFonts.prompt(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              Text(
                'Analyze election evidence photos',
                style: GoogleFonts.prompt(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageArea(ThemeData theme, ColorScheme cs) {
    if (_pickedImage != null) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(_pickedImage!.path),
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _reset,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
            if (_isAnalyzing)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'Analyzing image…',
                        style: GoogleFonts.prompt(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Transform.scale(
        scale: _pulseAnim.value,
        child: Card(
          child: InkWell(
            onTap: _showImageSourceSheet,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 240,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_a_photo_rounded,
                      size: 40,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Tap to scan evidence',
                    style: GoogleFonts.prompt(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Take a photo or choose from gallery\nfor AI-powered analysis',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.prompt(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(ColorScheme cs) {
    if (_pickedImage == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showImageSourceSheet,
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            label: Text('Change Photo', style: GoogleFonts.prompt()),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _isAnalyzing ? null : _analyzeImage,
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.smart_toy_rounded, size: 20),
            label: Text(
              _isAnalyzing ? 'Analyzing…' : 'Analyze with AI',
              style: GoogleFonts.prompt(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(ThemeData theme, ColorScheme cs) {
    final sevColor = AppTheme.severityColor(_severity ?? 'Low');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.analytics_rounded,
                    color: cs.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Analysis Result',
                  style: GoogleFonts.prompt(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sevColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sevColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: sevColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _prediction!,
                          style: GoogleFonts.prompt(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: sevColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Severity: \${_severity ?? "Unknown"}',
                          style: GoogleFonts.prompt(
                            fontSize: 12,
                            color: sevColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Confidence',
                  style: GoogleFonts.prompt(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '\${(_confidence * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.prompt(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _confidence >= 0.8
                        ? AppTheme.severityLow
                        : _confidence >= 0.5
                        ? AppTheme.severityMedium
                        : AppTheme.severityHigh,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _confidence,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                color: _confidence >= 0.8
                    ? AppTheme.severityLow
                    : _confidence >= 0.5
                    ? AppTheme.severityMedium
                    : AppTheme.severityHigh,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI results are advisory only. Always verify with human review.',
                      style: GoogleFonts.prompt(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks(ThemeData theme, ColorScheme cs) {
    const steps = [
      (Icons.camera_alt_rounded, 'Capture', 'Take or select an evidence photo'),
      (Icons.smart_toy_rounded, 'Analyze', 'AI scans for election violations'),
      (
        Icons.assessment_rounded,
        'Results',
        'Get severity and confidence score',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How It Works',
          style: GoogleFonts.prompt(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map((entry) {
          final i = entry.key;
          final (icon, title, desc) = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.chartColors[i],
                        AppTheme.chartColors[i].withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.prompt(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        desc,
                        style: GoogleFonts.prompt(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
