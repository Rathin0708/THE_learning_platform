/// Local-AI GGUF model catalog, download, selection, and deletion
/// (THE-61), with tier recommendations informed by a coarse device-RAM
/// probe (THE-62).
///
/// Kept out of packages/core's own implementation for the same reason as
/// [LocalLlmEngine]: the real work (HTTP downloads, checksum verification,
/// dart:io file management, OS RAM queries) is desktop-only I/O that lives
/// in packages/local_ai — this is just the contract UI code depends on, so
/// packages/core and packages/ui stay web-safe to compile.
library;

enum ModelTier { small, standard }

class LocalAiModelCatalogEntry {
  final String id;
  final String displayName;
  final int sizeBytes;
  final ModelTier tier;

  const LocalAiModelCatalogEntry({
    required this.id,
    required this.displayName,
    required this.sizeBytes,
    required this.tier,
  });
}

enum ModelDownloadStatus { inProgress, complete, downloadFailed, checksumMismatch }

class ModelDownloadEvent {
  final ModelDownloadStatus status;

  /// Fraction downloaded, in [0.0, 1.0]. Meaningful only while
  /// [status] is [ModelDownloadStatus.inProgress] or
  /// [ModelDownloadStatus.complete] (1.0).
  final double fraction;

  const ModelDownloadEvent(this.status, this.fraction);
}

abstract class LocalAiModelManager {
  List<LocalAiModelCatalogEntry> get catalog;

  /// Which tier this device's RAM can comfortably run (THE-62). Null means
  /// detection failed — callers should treat that as "unknown", not
  /// "unsupported", and let the user choose freely.
  Future<ModelTier?> recommendedTier();

  /// The catalog id of the model currently selected for Engine B to load,
  /// or null if none is installed/selected yet.
  Future<String?> selectedModelId();

  Future<bool> isInstalled(String modelId);

  /// Downloads and SHA-256-verifies [modelId], emitting progress until it
  /// completes or fails. Never throws — failures resolve to a terminal
  /// [ModelDownloadStatus.downloadFailed]/[ModelDownloadStatus.checksumMismatch]
  /// event instead, matching this app's "no core feature ever crashes on a
  /// flaky network" convention (see [ContentUpdateChecker]).
  Stream<ModelDownloadEvent> download(String modelId);

  /// Makes [modelId] the one Engine B loads. Requires [isInstalled] to be
  /// true for [modelId] first.
  Future<void> select(String modelId);

  /// Deletes the downloaded file for [modelId]. If it was the selected
  /// model, Engine B falls back to unavailable until another is selected.
  Future<void> delete(String modelId);
}
