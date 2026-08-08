import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureSqfliteForPlatform();

  // Splash-equivalent: only tiny metadata is touched before Home renders;
  // AppDatabase.open() is the one heavy I/O call, done once, up front
  // (spec 9.6: splash -> tiny metadata only -> home -> lazy-load DB modules).
  // On web this is real SQLite via sqflite_common_ffi_web (WASM +
  // IndexedDB, THE-58) — the same AppDatabase API as desktop/mobile.
  final database = AppDatabase();
  await database.open();

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const LanguageLearningApp(),
    ),
  );
}

class LanguageLearningApp extends StatelessWidget {
  const LanguageLearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildAppRouter(onboardingComplete: false);
    return MaterialApp.router(
      title: 'Language Learning OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
