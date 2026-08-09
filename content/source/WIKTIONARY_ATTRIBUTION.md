# Attribution — Wiktionary

`words_wiktionary.yaml` contains vocabulary concepts derived from
[English Wiktionary](https://en.wiktionary.org)'s translation tables.

- **License:** CC BY-SA 4.0 + GFDL (Wiktionary's dual license) —
  **ShareAlike**, unlike `sentences_tatoeba.yaml`'s plain CC-BY 2.0. Any
  redistribution of this data (or a database substantially built from it)
  must carry compatible attribution and remain under a compatible
  share-alike license. This has a real implication for how this app's
  compiled content database can be licensed/distributed if this file is
  included — worth confirming against the project's overall licensing
  plan before shipping a build that bundles it.
- **Source:** [kaikki.org](https://kaikki.org/dictionary/English/) — a
  third-party project (not affiliated with Wikimedia) that parses
  Wiktionary's raw wikitext into machine-readable JSON Lines, republishing
  the same underlying Wiktionary content and license. Downloaded to
  `build/wiktionary/kaikki-english.jsonl` (not committed — a ~3.2GB build
  artifact).
- **Imported:** via `tools/content_compiler/import_wiktionary.py`, which
  keeps English headwords that have both a Tamil (`ta`) and a Hindi
  (`hi`) translation with romanization listed in the entry's
  community-contributed translation table, plus IPA pronunciation where
  Wiktionary has it. No translation is generated or modified — only
  part-of-speech -> `type` mapping, frequency ranking, and category
  classification are added by the importer.
- **Frequency ranking:** cross-referenced against
  [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords)
  (MIT license, OpenSubtitles-2018-derived English word frequency list) —
  a separate dataset, included here only to rank which Wiktionary matches
  to keep, not to source any translation content.

This satisfies the CC BY-SA attribution requirement for including this
data in the Language Learning OS content database — see the ShareAlike
note above for the follow-up licensing question it raises.
