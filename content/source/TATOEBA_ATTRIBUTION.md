# Attribution — Tatoeba Project

`sentences_tatoeba.yaml` contains sentence pairs derived from the
[Tatoeba Project](https://tatoeba.org), obtained via the pre-packaged
tab-delimited exports at [manythings.org/anki](https://www.manythings.org/anki/)
(`hin-eng.zip`, `tam-eng.zip`).

- **License:** CC-BY 2.0 (France)
- **Source:** tatoeba.org — individual sentence/translation contributor
  attributions (Tatoeba sentence IDs and contributor usernames) are
  preserved in the original downloaded TSV files at
  `build/tatoeba/hin.txt` and `build/tatoeba/tam.txt` (not committed —
  build artifacts) and must be retained if this data is redistributed.
- **Imported:** via `tools/content_compiler/import_tatoeba.py`, which
  deduplicates against hand-authored content and performs no translation
  or modification of the sentence pairs themselves — only level/category
  classification is added.

This satisfies the CC-BY attribution requirement for including this data
in the Language Learning OS content database.
