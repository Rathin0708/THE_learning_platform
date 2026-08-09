# Attribution — Tatoeba Project

`sentences_tatoeba.yaml` contains sentence pairs derived from the
[Tatoeba Project](https://tatoeba.org).

- **License:** CC-BY 2.0 (France)
- **Source:** [downloads.tatoeba.org/exports/per_language/](https://downloads.tatoeba.org/exports/per_language/)
  — the project's own per-language sentence and translation-link exports
  (`hin_sentences.tsv`, `tam_sentences.tsv`, `eng_sentences.tsv`,
  `hin-eng_links.tsv`, `tam-eng_links.tsv`), downloaded to
  `build/tatoeba/raw/` (not committed — build artifacts, and the full
  English export in particular is ~2 million rows / 25MB compressed).
  Tatoeba sentence IDs are preserved in those raw TSV files and must be
  retained if this data is redistributed, per CC-BY's attribution
  requirement.
- **Imported:** via `tools/content_compiler/import_tatoeba.py`, which
  joins the per-language link files against the sentence text, then
  deduplicates against hand-authored content. No translation or
  modification of the sentence pairs themselves happens — only
  level/category classification is added.
- **Previously** (through THE-20's first pass) this used the smaller,
  pre-joined curated snapshot at manythings.org/anki (`hin-eng.zip`,
  `tam-eng.zip`, ~3,100 and ~216 pairs respectively). Switching to
  Tatoeba's own direct exports found substantially more real,
  community-verified pairs (~10,600 Hindi-English, ~560 Tamil-English)
  from the same underlying project and license.

This satisfies the CC-BY attribution requirement for including this data
in the Language Learning OS content database.
