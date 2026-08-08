import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Engine B (THE-53/54, spec 7.3): free-text grammar correction backed by
/// the local LLM. Additive on top of the fully working non-AI core — this
/// screen simply doesn't appear (see settings_screen.dart's gating) when
/// [grammarCorrectionServiceProvider] resolves to null (not desktop, or no
/// model installed), so disabling/removing local AI never touches Engine A
/// conversation or any other feature.
class LocalTutorScreen extends ConsumerStatefulWidget {
  const LocalTutorScreen({super.key});

  @override
  ConsumerState<LocalTutorScreen> createState() => _LocalTutorScreenState();
}

class _LocalTutorScreenState extends ConsumerState<LocalTutorScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  GrammarCorrectionResult? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final service = ref.read(grammarCorrectionServiceProvider);
    final input = _controller.text.trim();
    if (service == null || input.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await service.correct(input);
      if (!mounted) return;
      setState(() => _result = result);
    } on LocalLlmResponseFormatException {
      if (!mounted) return;
      setState(() => _error =
          "The local model's response didn't match the expected format this time — try rephrasing or ask again.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not get a correction: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(grammarCorrectionServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Local AI Tutor')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: service == null
              ? const Center(
                  child: Text('The local AI tutor is not available on this device right now.'),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Type a sentence in English — the local tutor will correct it and explain why, '
                        'in Hindi and Tamil too.'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'e.g. I am go market yesterday',
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Correct my sentence'),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    if (_result != null) Expanded(child: _ResultView(result: _result!)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final GrammarCorrectionResult result;
  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _Row(label: 'Corrected', value: result.corrected),
        _Row(label: 'Why', value: result.explanation),
        _Row(label: 'Hindi', value: result.hindiTranslation),
        _Row(label: 'Tamil', value: result.tamilTranslation),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
