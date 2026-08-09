import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_ai/local_ai.dart';
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

  // Engine B (THE-51..54): resolves to a real engine only on desktop with
  // a model actually installed at the documented path (see
  // docs/local_ai_setup.md); a plain `null` everywhere else (mobile, web,
  // desktop with no model installed yet — THE-61's install flow doesn't
  // exist). tryLoadDesktopLocalLlmEngine() is web-safe to call
  // unconditionally (see packages/local_ai's conditional export).
  final localLlmEngine = await tryLoadDesktopLocalLlmEngine();

  // Model catalog/download/select/delete (THE-61/62) — same desktop-only,
  // web-safe factory pattern as tryLoadDesktopLocalLlmEngine above.
  final localAiModelManager = tryCreateDesktopModelManager();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        if (localLlmEngine != null) localLlmEngineProvider.overrideWithValue(localLlmEngine),
        if (localAiModelManager != null) localAiModelManagerProvider.overrideWithValue(localAiModelManager),
      ],
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
