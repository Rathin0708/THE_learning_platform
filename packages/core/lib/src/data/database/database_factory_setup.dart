import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Configures the correct sqflite database factory per platform.
/// Mobile (Android/iOS) uses the default platform-channel factory.
/// Desktop (Windows/macOS/Linux) uses sqflite_common_ffi backed by the
/// native sqlite3 libraries bundled via sqlite3_flutter_libs.
void configureSqfliteForPlatform() {
  if (kIsWeb) {
    // Web SQLite support is explicitly out of scope for this phase
    // (spec Phase 7 — Web/Desktop Optimization handles this later).
    return;
  }
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Android/iOS use the default platform-channel sqflite factory.
}
