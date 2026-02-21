import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Utility for persisting picked images to the app's temporary directory.
///
/// `getTemporaryDirectory()` returns a persistent-enough cache dir that:
///   • survives across sessions on Android/iOS
///   • is accessible without extra permissions
///   • gets cleared by the OS only when storage is critically low
abstract final class ImageStorage {
  static final _log = Logger('ImageStorage');

  /// Copies [sourcePath] into `<tmpDir>/evidence_images/<fileName>`
  /// and returns the new persistent path.
  ///
  /// Returns [sourcePath] unchanged if copy fails.
  static Future<String> copyToTemp(String sourcePath) async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final destDir = Directory(p.join(tmpDir.path, 'evidence_images'));
      if (!destDir.existsSync()) {
        destDir.createSync(recursive: true);
      }

      final ext = p.extension(sourcePath).isNotEmpty
          ? p.extension(sourcePath)
          : '.jpg';
      final fileName = 'evidence_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = p.join(destDir.path, fileName);

      await File(sourcePath).copy(destPath);
      _log.info('Image saved to temp: $destPath');
      return destPath;
    } catch (e, s) {
      _log.severe('Failed to copy image to temp dir', e, s);
      return sourcePath; // fallback to original path
    }
  }

  /// Returns true if the file at [path] exists and is readable.
  static bool exists(String? path) {
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }
}
