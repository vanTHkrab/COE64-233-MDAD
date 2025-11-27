import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';

Future<bool> assetExists(String path) async {
  try {
    await rootBundle.load(path);
    return true;
  } catch (e) {
    return false;
  }
}
