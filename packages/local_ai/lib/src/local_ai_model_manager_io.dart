import 'dart:io';

import 'package:core/core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'device_capability.dart';
import 'model_downloader.dart';

/// The two GGUF models validated for this app so far (THE-52's original
/// pick plus a larger sibling from the same family/license/prompt-format
/// for [ModelTier.standard] devices) — same Apache-2.0/HuggingFace bar
/// documented in docs/local_ai_setup.md. Checksums and sizes are the real
/// values reported by HuggingFace's API for these exact files, not
/// estimates.
const _catalogSource = <String, ({String url, String sha256, int sizeBytes, ModelTier tier})>{
  'qwen2.5-0.5b-instruct-q4_k_m': (
    url: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
    sha256: '74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db',
    sizeBytes: 491400032,
    tier: ModelTier.small,
  ),
  'qwen2.5-1.5b-instruct-q4_k_m': (
    url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
    sha256: '6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e',
    sizeBytes: 1117320736,
    tier: ModelTier.standard,
  ),
};

/// Real implementation of [LocalAiModelManager] (THE-61/62). Manages a
/// small models directory alongside the fixed `model.gguf` path
/// [tryLoadDesktopLocalLlmEngine] already reads:
///
/// - `<app support dir>/local_ai/models/<id>.gguf` — every downloaded model
/// - `<app support dir>/local_ai/model.gguf` — a copy of whichever one is
///   selected (kept as a plain file copy, not a symlink, since Windows
///   symlinks need elevated permissions by default)
/// - `<app support dir>/local_ai/selected_model_id.txt` — which catalog id
///   that copy corresponds to, purely for the UI to show a checkmark
///
/// [engine_factory_io.dart] itself is untouched — it still just looks for
/// `model.gguf`, so selecting a model here doesn't require any change to
/// the already-verified THE-51..54 loading path.
class LocalAiModelManagerIo implements LocalAiModelManager {
  final ModelDownloader _downloader;

  /// Resolves the `local_ai` directory. Defaults to the real
  /// `<app support dir>/local_ai` (matching [tryLoadDesktopLocalLlmEngine]);
  /// overridable so tests can point this at a temp directory without
  /// needing path_provider's platform channel — same optional-injection
  /// pattern as [AudioPlayerService]/[ModelDownloader]'s `client` param.
  final Future<Directory> Function() _localAiDir;

  LocalAiModelManagerIo({ModelDownloader? downloader, Future<Directory> Function()? localAiDirOverride})
      : _downloader = downloader ?? ModelDownloader(),
        _localAiDir = localAiDirOverride ?? _defaultLocalAiDir;

  static Future<Directory> _defaultLocalAiDir() async {
    final supportDir = await getApplicationSupportDirectory();
    return Directory(p.join(supportDir.path, 'local_ai'));
  }

  @override
  List<LocalAiModelCatalogEntry> get catalog => _catalogSource.entries
      .map((e) => LocalAiModelCatalogEntry(id: e.key, displayName: e.key, sizeBytes: e.value.sizeBytes, tier: e.value.tier))
      .toList(growable: false);

  Future<File> _modelFile(String modelId) async {
    final dir = await _localAiDir();
    return File(p.join(dir.path, 'models', '$modelId.gguf'));
  }

  Future<File> _selectedModelPath() async => File(p.join((await _localAiDir()).path, 'model.gguf'));
  Future<File> _selectedModelIdMarker() async => File(p.join((await _localAiDir()).path, 'selected_model_id.txt'));

  @override
  Future<ModelTier?> recommendedTier() => detectDeviceRamTier();

  @override
  Future<String?> selectedModelId() async {
    final marker = await _selectedModelIdMarker();
    if (!marker.existsSync()) return null;
    final id = (await marker.readAsString()).trim();
    return id.isEmpty ? null : id;
  }

  @override
  Future<bool> isInstalled(String modelId) async => (await _modelFile(modelId)).exists();

  @override
  Stream<ModelDownloadEvent> download(String modelId) async* {
    final source = _catalogSource[modelId];
    if (source == null) {
      yield const ModelDownloadEvent(ModelDownloadStatus.downloadFailed, 0);
      return;
    }
    final target = await _modelFile(modelId);
    yield* _downloader.download(
      url: source.url,
      sha256Hex: source.sha256,
      expectedSizeBytes: source.sizeBytes,
      installPath: target.path,
    );
  }

  @override
  Future<void> select(String modelId) async {
    final source = await _modelFile(modelId);
    if (!source.existsSync()) return;
    final dest = await _selectedModelPath();
    await dest.parent.create(recursive: true);
    await source.copy(dest.path);
    await (await _selectedModelIdMarker()).writeAsString(modelId, flush: true);
  }

  @override
  Future<void> delete(String modelId) async {
    final file = await _modelFile(modelId);
    if (await file.exists()) await file.delete();

    if (await selectedModelId() == modelId) {
      final marker = await _selectedModelIdMarker();
      if (await marker.exists()) await marker.delete();
      final active = await _selectedModelPath();
      if (await active.exists()) await active.delete();
    }
  }
}
