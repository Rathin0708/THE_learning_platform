import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local-AI GGUF model catalog: download, select, delete (THE-61), with a
/// recommended-tier hint from a coarse device-RAM probe (THE-62). Simply
/// doesn't appear reachable (see settings_screen.dart's gating) when
/// [localAiModelManagerProvider] resolves to null (not desktop) — same
/// pattern [LocalTutorScreen] uses for [grammarCorrectionServiceProvider].
class ModelManagementScreen extends ConsumerStatefulWidget {
  const ModelManagementScreen({super.key});

  @override
  ConsumerState<ModelManagementScreen> createState() => _ModelManagementScreenState();
}

class _ModelManagementScreenState extends ConsumerState<ModelManagementScreen> {
  ModelTier? _recommendedTier;
  String? _selectedId;
  final Set<String> _installedIds = {};
  final Map<String, double> _downloadProgress = {};
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final manager = ref.read(localAiModelManagerProvider);
    if (manager == null) return;

    final tier = await manager.recommendedTier();
    final selected = await manager.selectedModelId();
    final installed = <String>{};
    for (final entry in manager.catalog) {
      if (await manager.isInstalled(entry.id)) installed.add(entry.id);
    }
    if (!mounted) return;
    setState(() {
      _recommendedTier = tier;
      _selectedId = selected;
      _installedIds
        ..clear()
        ..addAll(installed);
    });
  }

  Future<void> _download(String modelId) async {
    final manager = ref.read(localAiModelManagerProvider);
    if (manager == null) return;

    setState(() {
      _busyIds.add(modelId);
      _downloadProgress[modelId] = 0;
    });

    await for (final event in manager.download(modelId)) {
      if (!mounted) return;
      setState(() => _downloadProgress[modelId] = event.fraction);
      if (event.status != ModelDownloadStatus.inProgress) {
        setState(() {
          _busyIds.remove(modelId);
          _downloadProgress.remove(modelId);
        });
        if (event.status == ModelDownloadStatus.complete) {
          await _refresh();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                event.status == ModelDownloadStatus.checksumMismatch
                    ? 'Download failed a checksum check — try again.'
                    : 'Download failed — check your connection and try again.',
              ),
            ),
          );
        }
        return;
      }
    }
  }

  Future<void> _select(String modelId) async {
    final manager = ref.read(localAiModelManagerProvider);
    if (manager == null) return;
    setState(() => _busyIds.add(modelId));
    await manager.select(modelId);
    setState(() => _busyIds.remove(modelId));
    await _refresh();
  }

  Future<void> _delete(String modelId) async {
    final manager = ref.read(localAiModelManagerProvider);
    if (manager == null) return;
    setState(() => _busyIds.add(modelId));
    await manager.delete(modelId);
    setState(() => _busyIds.remove(modelId));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(localAiModelManagerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Local AI models')),
      body: SafeArea(
        child: manager == null
            ? const Center(child: Text('Model management is not available on this device.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_recommendedTier != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Recommended for this device: ${_tierLabel(_recommendedTier!)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  for (final entry in manager.catalog) _ModelTile(
                    entry: entry,
                    isInstalled: _installedIds.contains(entry.id),
                    isSelected: _selectedId == entry.id,
                    isRecommended: _recommendedTier == entry.tier,
                    isBusy: _busyIds.contains(entry.id),
                    downloadProgress: _downloadProgress[entry.id],
                    onDownload: () => _download(entry.id),
                    onSelect: () => _select(entry.id),
                    onDelete: () => _delete(entry.id),
                  ),
                ],
              ),
      ),
    );
  }
}

String _tierLabel(ModelTier tier) => switch (tier) {
      ModelTier.small => 'smaller model (lower RAM devices)',
      ModelTier.standard => 'standard model',
    };

class _ModelTile extends StatelessWidget {
  final LocalAiModelCatalogEntry entry;
  final bool isInstalled;
  final bool isSelected;
  final bool isRecommended;
  final bool isBusy;
  final double? downloadProgress;
  final VoidCallback onDownload;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const _ModelTile({
    required this.entry,
    required this.isInstalled,
    required this.isSelected,
    required this.isRecommended,
    required this.isBusy,
    required this.downloadProgress,
    required this.onDownload,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(entry.displayName, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (isSelected) const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            Text('${_formatSize(entry.sizeBytes)}${isRecommended ? ' · recommended' : ''}'),
            const SizedBox(height: 8),
            if (downloadProgress != null)
              LinearProgressIndicator(value: downloadProgress! > 0 ? downloadProgress : null)
            else
              Row(
                children: [
                  if (!isInstalled)
                    FilledButton(onPressed: isBusy ? null : onDownload, child: const Text('Download'))
                  else ...[
                    if (!isSelected)
                      FilledButton(onPressed: isBusy ? null : onSelect, child: const Text('Select')),
                    const SizedBox(width: 8),
                    TextButton(onPressed: isBusy ? null : onDelete, child: const Text('Delete')),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _formatSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb < 1024) return '${mb.toStringAsFixed(0)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }
}
