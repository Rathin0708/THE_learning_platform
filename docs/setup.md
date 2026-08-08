# Setup: building the content database

`apps/mobile/assets/content/content.db` is a **compiled build artifact**
and is deliberately not committed to git (see spec section 3 and THE-14).
After cloning this repo, generate it before running the app:

```
python -m pip install pyyaml   # one-time
python tools/content_compiler/compile.py --out apps/mobile/assets/content/content.db
```

Then `flutter pub get` and run as usual from `apps/mobile/`.

Re-run the compiler any time `content/source/*.yaml` changes. It is
deterministic — running it twice on unchanged source produces a
byte-identical output file (verified: SHA-256 matches across runs).

To pull the latest CC-BY-licensed Tatoeba sentence data first (optional —
`content/source/sentences_tatoeba.yaml` is already generated and checked
in), see `tools/content_compiler/import_tatoeba.py`.
