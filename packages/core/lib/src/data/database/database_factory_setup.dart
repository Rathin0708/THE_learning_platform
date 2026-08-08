import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Configures the correct sqflite database factory per platform.
/// Mobile (Android/iOS) uses the default platform-channel factory.
/// Desktop (Windows/macOS/Linux) uses sqflite_common_ffi backed by the
/// native sqlite3 libraries bundled via sqlite3_flutter_libs.
/// Web (THE-58) uses sqflite_common_ffi_web: real SQLite compiled to WASM,
/// persisted in the browser's IndexedDB, via the same tekartik/sqflite
/// family and the same Database API as desktop — no repository code
/// changes needed. Requires `dart run sqflite_common_ffi_web:setup` to
/// have generated sqlite3.wasm + sqflite_sw.js into the web app's web/
/// directory (apps/mobile/web/, apps/web/web/).
void configureSqfliteForPlatform() {
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
    return;
  }
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Android/iOS use the default platform-channel sqflite factory.
}
