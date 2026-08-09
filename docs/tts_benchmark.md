# TTS engine benchmark (THE-42)

Piper vs. Kokoro synthesis speed, 5 sentences, single-threaded CPU, generated 2026-08-09T15:22:10.156992 on a Windows desktop dev machine.

| Engine | Total synthesis time | Total audio duration | Real-time factor (lower is faster) |
|---|---|---|---|
| Piper (VITS) | 7.34s | 10.89s | 0.674 |
| Kokoro | 39.75s | 11.50s | 3.456 |

Real-time factor = synthesis time / audio duration. Below 1.0 means synthesis is faster than real-time playback.

Voices used: `vits-piper-en_US-lessac-medium` and `kokoro-en-v0_19`, both from sherpa-onnx's `tts-models` GitHub release. Reproduce with:

```
dart run packages/voice/tool/tts_benchmark.dart \
  --piper-dir <path to a Piper voice dir> \
  --kokoro-dir <path to a Kokoro voice dir>
```

**Takeaway:** on CPU, Piper is roughly 5x faster than Kokoro and already synthesizes faster than real-time (RTF 0.674), making it the better default for a "Hear it" button where latency matters. Kokoro's quality is generally considered higher, but at RTF 3.46 a short sentence takes several seconds — noticeable but likely still acceptable for occasional use, not for anything latency-sensitive.

## A real Windows DLL-resolution gotcha found while verifying this

`sherpa_onnx`'s native library depends on a bundled `onnxruntime.dll`. On Windows, when that native library is loaded by a process whose own executable directory does **not** contain a matching `onnxruntime.dll` (e.g. running a bare Dart script via `dart run`, rather than the built Flutter app), Windows' DLL search order falls through to `C:\Windows\System32\onnxruntime.dll` — a different, older ONNX Runtime that Windows 11 itself bundles for OS-level ML features — and `sherpa_onnx` crashes with an ONNX Runtime API version mismatch.

This does **not** affect the real app: `flutter build windows` copies the plugin's matching `onnxruntime.dll` right next to `mobile.exe`, and Windows always searches the launching executable's own directory first — confirmed by compiling this benchmark to a standalone `.exe` and placing it in the built app's output directory, where it ran correctly. It only bites ad hoc `dart run`/`dart test` invocations of code that transitively depends on `sherpa_onnx`. Worth knowing if a future contributor hits a confusing crash while poking at this package from the command line.

## Installing a voice for the app to actually use it

`PiperTtsService`/`KokoroTtsService` (`packages/voice/lib/src/piper_tts_service_io.dart` / `kokoro_tts_service_io.dart`) expect a voice already unpacked under the app's support directory — same "manually installed, dev-machine validation" precedent as `docs/local_ai_setup.md`'s Qwen model; there's no download/install flow yet (that's THE-61/THE-68):

```bash
# Piper (any single-voice sherpa-onnx Piper bundle works — folder just
# needs a *.onnx model, tokens.txt, and espeak-ng-data/)
curl -L -o piper.tar.bz2 https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-medium.tar.bz2
tar -xjf piper.tar.bz2
# copy the extracted folder's contents to <app support dir>/tts/piper-en-us/

# Kokoro
curl -L -o kokoro.tar.bz2 https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-en-v0_19.tar.bz2
tar -xjf kokoro.tar.bz2
# copy model.onnx, voices.bin, tokens.txt, espeak-ng-data/ to <app support dir>/tts/kokoro-en/
```

On Windows, `<app support dir>` is the path `path_provider`'s `getApplicationSupportDirectory()` resolves to for this app (under `%APPDATA%`).
