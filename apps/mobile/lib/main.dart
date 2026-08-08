import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureSqfliteForPlatform();

  // sqflite has no web implementation (spec Phase 7 — Web/Desktop
  // Optimization — covers real web storage later). Rather than let that
  // surface as an unhandled exception and a blank white screen, show an
  // honest "not yet supported" screen on web and open the DB everywhere
  // else.
  if (kIsWeb) {
    runApp(const _WebNotYetSupportedApp());
    return;
  }

  // Splash-equivalent: only tiny metadata is touched before Home renders;
  // AppDatabase.open() is the one heavy I/O call, done once, up front
  // (spec 9.6: splash -> tiny metadata only -> home -> lazy-load DB modules).
  final database = AppDatabase();
  await database.open();

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const LanguageLearningApp(),
    ),
  );
}

class _WebNotYetSupportedApp extends StatelessWidget {
  const _WebNotYetSupportedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Language Learning OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Web support (offline storage) lands in the Web/Desktop '
              'Optimization phase. Try the Windows or Android build for now.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
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
