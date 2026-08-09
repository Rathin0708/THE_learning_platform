import 'package:core/core.dart';

/// Web (and any platform without dart:io) fallback — see local_ai.dart's
/// conditional export. Model management is desktop-only (THE-61/62 are
/// gated the same way as Engine B itself), so this only exists to keep
/// the package importable and web builds compiling;
/// [tryCreateDesktopModelManager] never actually constructs this on web.
class LocalAiModelManagerIo implements LocalAiModelManager {
  @override
  List<LocalAiModelCatalogEntry> get catalog => const [];

  @override
  Future<ModelTier?> recommendedTier() async => null;

  @override
  Future<String?> selectedModelId() async => null;

  @override
  Future<bool> isInstalled(String modelId) async => false;

  @override
  Stream<ModelDownloadEvent> download(String modelId) {
    throw UnsupportedError('Local AI model management is not available on this platform.');
  }

  @override
  Future<void> select(String modelId) async {
    throw UnsupportedError('Local AI model management is not available on this platform.');
  }

  @override
  Future<void> delete(String modelId) async {
    throw UnsupportedError('Local AI model management is not available on this platform.');
  }
}
