import 'dart:io';

import 'package:core/core.dart';

import 'local_ai_model_manager_io.dart';

/// Constructs a real [LocalAiModelManagerIo] on desktop platforms only —
/// same platform rule [LocalAiPlatformGate] applies to Engine B itself
/// (spec 7.3/12: never forced onto mobile hardware). Unlike
/// [tryLoadDesktopLocalLlmEngine], this doesn't check whether a model is
/// already installed — it's the thing that lets you install one.
LocalAiModelManager? tryCreateDesktopModelManager() {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return null;
  return LocalAiModelManagerIo();
}
