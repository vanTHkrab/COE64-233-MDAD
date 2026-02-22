import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Result from a TFLite classification.
class ClassificationResult {
  final String label;
  final double confidence;
  final String severity;

  const ClassificationResult({
    required this.label,
    required this.confidence,
    required this.severity,
  });
}

/// Wraps a TFLite image-classification model.
///
/// **Model contract**
/// - File  : `assets/models/incident_classifier.tflite`
/// - Labels: `assets/models/incident_labels.txt`  (one label per line)
/// - Input : `[1, 224, 224, 3]` FLOAT32, normalised to [0, 1]
/// - Output: `[1, N]` FLOAT32  (one probability per class)
///
/// The label file maps each index → human-readable class name.
/// A `severity_map.txt` (optional) maps each class name → High / Medium / Low.
/// If the severity map is absent every class defaults to 'Medium'.
class TFLiteClassifier {
  static final _log = Logger('TFLiteClassifier');

  static const _modelPath = 'assets/models/model_unquant.tflite';
  static const _labelsPath = 'assets/models/labels.txt';
  static const _severityMapPath = 'assets/models/severity_map.txt';

  static const int _inputSize = 224; // expected width & height

  Interpreter? _interpreter;
  List<String> _labels = [];
  Map<String, String> _severityMap = {};

  bool get isReady => _interpreter != null && _labels.isNotEmpty;

  // ── Initialise ────────────────────────────────────────────────────────────

  /// Load model + labels from assets.  Safe to call multiple times (no-op if
  /// already loaded).
  Future<void> init() async {
    if (isReady) return;
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _labels = await _loadLines(_labelsPath);
      _severityMap = await _loadSeverityMap();
      _log.info(
        'TFLiteClassifier ready — ${_labels.length} classes, '
        'input ${_interpreter!.getInputTensor(0).shape}',
      );
    } catch (e, s) {
      _log.severe('Failed to load TFLite model', e, s);
      _interpreter = null;
      rethrow;
    }
  }

  /// Release interpreter resources.
  void close() {
    _interpreter?.close();
    _interpreter = null;
  }

  // ── Classify ──────────────────────────────────────────────────────────────

  /// Run inference on [imageFile].
  ///
  /// Returns `null` if the model is not loaded or preprocessing fails.
  Future<ClassificationResult?> classify(File imageFile) async {
    if (!isReady) {
      _log.warning('classify() called before init()');
      return null;
    }

    try {
      final input = await _preprocess(imageFile);
      if (input == null) return null;

      final outputShape =
          _interpreter!.getOutputTensor(0).shape; // [1, numClasses]
      final numClasses = outputShape.last;
      final outputBuffer =
          List.generate(1, (_) => List<double>.filled(numClasses, 0.0));

      _interpreter!.run(input, outputBuffer);

      final probs = outputBuffer[0];
      final maxIdx = _argMax(probs);
      final confidence = probs[maxIdx];
      final label =
          maxIdx < _labels.length ? _labels[maxIdx] : 'Unknown ($maxIdx)';
      final severity = _severityMap[label] ?? _defaultSeverity(confidence);

      _log.fine('Result: $label  conf=${confidence.toStringAsFixed(3)}');

      return ClassificationResult(
        label: label,
        confidence: confidence,
        severity: severity,
      );
    } catch (e, s) {
      _log.severe('Inference failed', e, s);
      return null;
    }
  }

  // ── Preprocessing ─────────────────────────────────────────────────────────

  /// Decode → resize to [_inputSize]² → normalise → return [1,H,W,3] Float32.
  Future<List<List<List<List<double>>>>?> _preprocess(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) {
        _log.warning('Could not decode image: ${imageFile.path}');
        return null;
      }

      // Resize
      final resized = img.copyResize(
        decoded,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear,
      );

      // Build [1, H, W, 3] Float32 normalised to [0, 1]
      return List.generate(1, (_) {
        return List.generate(_inputSize, (y) {
          return List.generate(_inputSize, (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          });
        });
      });
    } catch (e, s) {
      _log.severe('Preprocessing failed', e, s);
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<String>> _loadLines(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      return raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } catch (e) {
      _log.warning('Could not load $assetPath: $e');
      return [];
    }
  }

  /// Parses `severity_map.txt` — lines like `Ballot Stuffing:High`.
  Future<Map<String, String>> _loadSeverityMap() async {
    final map = <String, String>{};
    try {
      final lines = await _loadLines(_severityMapPath);
      for (final line in lines) {
        final parts = line.split(':');
        if (parts.length == 2) {
          map[parts[0].trim()] = parts[1].trim();
        }
      }
    } catch (_) {
      // Optional file — silently ignore
    }
    return map;
  }

  int _argMax(List<double> values) {
    int maxIdx = 0;
    double maxVal = values[0];
    for (int i = 1; i < values.length; i++) {
      if (values[i] > maxVal) {
        maxVal = values[i];
        maxIdx = i;
      }
    }
    return maxIdx;
  }

  /// Fallback severity when no `severity_map.txt` entry is found.
  String _defaultSeverity(double confidence) {
    if (confidence >= 0.75) return 'High';
    if (confidence >= 0.45) return 'Medium';
    return 'Low';
  }
}

/// Global singleton — shared across all pages so the model is loaded once.
final tfliteClassifier = TFLiteClassifier();
