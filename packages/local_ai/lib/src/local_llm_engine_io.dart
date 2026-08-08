import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:core/core.dart';
import 'package:ffi/ffi.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path/path.dart' as p;

/// On Windows, loading llama.dll by absolute path does NOT put its own
/// directory on the search path used to resolve ITS dependencies
/// (ggml.dll etc.) — that's standard `LoadLibrary` behavior, confirmed
/// during THE-51's validation (see docs/local_ai_setup.md). Calling
/// `SetDllDirectory` ourselves before loading fixes it regardless of the
/// process's current working directory, which matters here because a
/// real app is never launched with its CWD set to the DLL folder.
void _ensureWindowsDllSearchPath(String libraryPath) {
  if (!Platform.isWindows) return;
  final dir = p.dirname(libraryPath);
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final setDllDirectory = kernel32
      .lookupFunction<Int32 Function(Pointer<Utf16>), int Function(Pointer<Utf16>)>('SetDllDirectoryW');
  final dirPtr = dir.toNativeUtf16();
  try {
    setDllDirectory(dirPtr);
  } finally {
    malloc.free(dirPtr);
  }
}

class _GenerationRequest {
  final String libraryPath;
  final String modelPath;
  final String prompt;
  final int maxTokens;
  const _GenerationRequest(this.libraryPath, this.modelPath, this.prompt, this.maxTokens);
}

/// Runs entirely inside a throwaway isolate (see [LlamaCppLocalLlmEngine.generate]
/// doc comment for why): loads the model, runs one completion, disposes.
String _runGeneration(_GenerationRequest req) {
  _ensureWindowsDllSearchPath(req.libraryPath);
  Llama.libraryPath = req.libraryPath;
  final llama = Llama(
    req.modelPath,
    modelParams: ModelParams()
      ..nGpuLayers = 0
      ..mainGpu = -1,
    contextParams: ContextParams(),
    samplerParams: SamplerParams(),
  );
  try {
    llama.setPrompt(req.prompt);
    final buffer = StringBuffer();
    var tokenCount = 0;
    while (true) {
      final (token, done) = llama.getNext();
      if (done) break;
      buffer.write(token);
      tokenCount++;
      if (tokenCount >= req.maxTokens) break;
    }
    return buffer.toString();
  } finally {
    llama.dispose();
  }
}

/// Real llama.cpp-backed [LocalLlmEngine] (THE-51/52/53), desktop-only.
///
/// Deliberately reloads the model fresh inside a throwaway [Isolate.run]
/// for every [generate] call rather than keeping a long-lived background
/// isolate warm: llama_cpp_dart's synchronous [Llama] API is the one
/// actually verified end-to-end during THE-51's validation (see
/// docs/local_ai_setup.md); its isolate-managed [LlamaParent] API is
/// untested here and adds real isolate-lifecycle/protocol risk for a
/// first working version. The cost is a few hundred ms of extra model-load
/// latency per call (small model, local NVMe) in exchange for each call
/// being self-contained and unable to leave the engine in a corrupted
/// state after a crash. Documented as a known follow-up, not silently
/// accepted as final.
class LlamaCppLocalLlmEngine implements LocalLlmEngine {
  final String libraryPath;
  final String modelPath;
  final int maxTokens;
  bool _ready = false;

  LlamaCppLocalLlmEngine({
    required this.libraryPath,
    required this.modelPath,
    this.maxTokens = 200,
  });

  @override
  bool get isReady => _ready;

  @override
  Future<void> initialize() async {
    _ready = true;
  }

  @override
  Future<String> generate(String prompt) async {
    if (!_ready) {
      throw StateError('LlamaCppLocalLlmEngine.initialize() must be called before generate().');
    }
    return Isolate.run(() => _runGeneration(_GenerationRequest(libraryPath, modelPath, prompt, maxTokens)));
  }

  @override
  Future<void> dispose() async {
    _ready = false;
  }
}
