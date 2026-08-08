# Local AI (llama.cpp) desktop setup — THE-51/52

Real, reproducible steps used to validate that llama.cpp can run fully
offline on desktop and load a GGUF model (THE-51's AC), and to select a
concrete first GGUF model (THE-52). This is native-toolchain build work,
not something `flutter pub get` can do for you — follow this once per
development machine.

## 1. Prerequisites

- CMake (installed via `winget install --id Kitware.CMake -e`)
- A C++ toolchain — Visual Studio Build Tools 2022 with the "Desktop
  development with C++" workload (provides `cl.exe`, `vcvars64.bat`, and
  Ninja under `Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/`)

## 2. Build llama.cpp at the exact commit `llama_cpp_dart` targets

`llama_cpp_dart`'s Dart FFI bindings are generated against a specific
llama.cpp C API, so the shared library must be built at the matching
commit — not just "latest llama.cpp" — or symbols can silently
mismatch. To find the pinned commit for whatever `llama_cpp_dart`
version you're using:

```bash
git clone https://github.com/netdur/llama_cpp_dart.git
cd llama_cpp_dart
# find the commit whose pubspec.yaml has your target `version:` line
git log --oneline -- pubspec.yaml
git show <that-commit>:pubspec.yaml   # look for "version: 0.2.2 # <sha>"
```

For `llama_cpp_dart` 0.2.2 the pinned commit is
`4ffc47cb2001e7d523f9ff525335bbe34b1a2858`.

```bash
git clone https://github.com/ggml-org/llama.cpp.git native/llama.cpp
cd native/llama.cpp
git checkout 4ffc47cb2001e7d523f9ff525335bbe34b1a2858
```

Configure and build (run from a shell that has `cmake` on PATH; the
build itself must run inside an MSVC dev environment):

```bat
"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
cmake -S native\llama.cpp -B native\llama.cpp\build -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON ^
  -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF
cmake --build native\llama.cpp\build --config Release --target llama -j
```

This produces `native/llama.cpp/build/bin/llama.dll` plus its
dependencies `ggml.dll`, `ggml-base.dll`, `ggml-cpu.dll` (CPU-only —
no CUDA/Vulkan backend was requested, so nothing GPU-specific is
required on the build or target machine).

## 3. Two real Windows-specific gotchas found and fixed during validation

1. **DLL search path**: loading `llama.dll` by absolute path does *not*
   put its own directory on the search path for its dependencies
   (`ggml.dll`/`ggml-base.dll`) — that's standard Windows `LoadLibrary`
   behavior, not a bug. Either run the consuming process with its
   working directory set to `native/llama.cpp/build/bin`, or call
   `SetDllDirectory`/`AddDllDirectory` before loading, or copy the four
   DLLs next to the app's executable.

2. **`ggml_backend_load_all` symbol**: `llama_cpp_dart`'s Dart bindings
   open a single `DynamicLibrary` (`llama.dll`) and expect every
   function they wrap — including `ggml_backend_load_all` — to be
   resolvable from that one handle. On this Windows build layout,
   `ggml_backend_load_all` is only exported by `ggml.dll`, not
   `llama.dll` (confirmed via `dumpbin /exports`), so the call throws.
   It's safe to skip: with `GGML_BACKEND_DL=OFF` (the default, used
   above), the CPU backend self-registers via static initializers when
   `ggml.dll`/`ggml-base.dll` load, so this call is redundant on this
   build anyway. Fix applied as a small vendored patch — see
   `native/llama_cpp_dart_patched/lib/src/llama.dart` (wrap the call in
   `try { } catch (_) {}`) — reproduce by copying the pub-cache package
   and applying that one change, then depending on it via a `path:`
   override instead of the plain pub.dev version.

3. **`main_gpu` default**: `ModelParams()` defaults to `nGpuLayers: 99,
   mainGpu: 0` (i.e. "offload to GPU device 0"). On a CPU-only build
   with zero GPU devices, device index `0` is invalid and model loading
   fails with `invalid value for main_gpu: 0 (available devices: 0)`.
   Set `ModelParams()..nGpuLayers = 0..mainGpu = -1` for CPU-only.

## 4. Model selection (THE-52)

Selected: **Qwen2.5-0.5B-Instruct**, GGUF `Q4_K_M` quantization, from
`https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF`.

- License: Apache 2.0 (commercially clean, same bar applied to all
  other third-party content in this project).
- Size: ~469 MB — appropriate for bundling/downloading on consumer
  desktop hardware (spec 8.6), unlike 7B+ models.
- Multilingual instruction-tuned base, a reasonable starting point for
  THE-53 (conversation) / THE-54 (grammar correction); prompt-format is
  ChatML (`<|im_start|>...<|im_end|>`).

Download for local validation:

```bash
mkdir -p native/models
curl -L -o native/models/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf
```

## 5. Smoke test

`native/llama_cpp_dart_probe/bin/probe.dart` loads the built DLL and
the downloaded model and runs one real completion. Run it with the
working directory set to the DLL's folder (gotcha #1 above):

```bash
cd native/llama.cpp/build/bin
dart run ../../../llama_cpp_dart_probe/bin/probe.dart
```

Confirmed working output (verbatim from a real run): the model loaded,
built its KV cache and compute graph, and generated a real (if
imperfect — 0.5B is small) completion for a Tamil translation prompt.
This is the concrete evidence behind THE-51's "runs locally, loads a
GGUF model, no network dependency" AC and THE-52's model selection.

## 6. What's NOT done yet

This validates the runtime + model can work together on this platform.
It is **not** wired into the app (no packages/core service, no
Riverpod provider, no UI) — that's THE-53 (Engine B conversation
pipeline) and THE-54 (grammar correction), still open. The native
build artifacts and model file are intentionally gitignored (see
`.gitignore`) — they're large, regenerable, and machine/toolchain
specific; this doc is what makes them reproducible.
