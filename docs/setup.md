# Setup: building the content database

`apps/mobile/assets/content/content.db` (and its web counterpart,
`content.json`) are **compiled build artifacts** and are deliberately
not committed to git (see spec section 3 and THE-14). After cloning this
repo, generate them before running the app:

```
python -m pip install pyyaml   # one-time
python tools/content_compiler/compile.py --out apps/mobile/assets/content/content.db
```

This also writes `apps/mobile/assets/content/content.json` (used only by
the web build — see "Web setup" below). Both defaults land in the right
place automatically; `--json-out` overrides the JSON path if needed.

Then `flutter pub get` and run as usual from `apps/mobile/`.

Re-run the compiler any time `content/source/*.yaml` changes. It is
deterministic — running it twice on unchanged source produces a
byte-identical output file (verified: SHA-256 matches across runs).

To pull the latest CC-BY-licensed Tatoeba sentence data first (optional —
`content/source/sentences_tatoeba.yaml` is already generated and checked
in), see `tools/content_compiler/import_tatoeba.py`.

## Web setup (THE-58)

The web build needs two more one-time-generated files that also aren't
committed (`apps/mobile/web/sqlite3.wasm`, `apps/mobile/web/sqflite_sw.js`
— tied to the installed `sqflite_common_ffi_web` package version, not to
project content):

```
cd apps/mobile
dart run sqflite_common_ffi_web:setup
```

Web has no filesystem, so sqflite_common_ffi_web (real SQLite compiled
to WASM, persisted in IndexedDB) always creates an empty database —
unlike desktop/mobile, which copy `content.db`'s bytes directly.
`WebContentSeeder` (packages/core) populates the empty web database from
`content.json` on first launch instead. Same source of truth, a second
output format purely because of that platform constraint.

## Speech recognition model (THE-37)

`apps/mobile/assets/models/ggml-tiny.bin` is a third-party binary
(~77.7MB, the multilingual Whisper "tiny" GGML model) and is not
committed to git. Download it once:

```
mkdir -p apps/mobile/assets/models
curl -L -o apps/mobile/assets/models/ggml-tiny.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin
```

This is the bundled fallback ASR engine (`WhisperFallbackService`,
packages/voice) used when the OS on-device speech recognizer isn't
available for the requested language/device — see spec 7.1. Without
this file present, that fallback path returns "unavailable" rather than
failing to build; the app still runs, just without the fallback.
