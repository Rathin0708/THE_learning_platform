# Attribution — WikiMatrix / wikimedia (Wikipedia-derived parallel sentences)

`sentences_wikimatrix.yaml` contains sentence pairs derived from two
Wikipedia-based parallel corpora, both distributed via
[OPUS](https://opus.nlpl.eu):

- **WikiMatrix** (Schwenk et al., Facebook AI Research — [paper](https://arxiv.org/abs/1907.05791)):
  mined from Wikipedia article translations across 1620 language pairs.
  License confirmed directly in the download's own bundled `LICENSE`
  file: **CC BY-SA 4.0**.
- **wikimedia** (OPUS corpus, sourced from the Wikimedia Foundation's
  [ContentTranslation](https://dumps.wikimedia.org/other/contenttranslation)
  tool exports): the download's own bundled `README` states **License:
  CC-BY-SA 4.0** directly.

Both are the same license family as `words_wiktionary.yaml`
(Wiktionary) — see `WIKTIONARY_ATTRIBUTION.md` for what ShareAlike means
for this app's content licensing.

- **Downloaded to:** `build/wikimatrix/` (not committed — build
  artifacts, ~124MB compressed across the four corpus files).
- **Imported via:** `tools/content_compiler/import_wikimatrix.py`, which
  reuses `import_tatoeba.py`'s mature-content and grammar-sanity filters
  directly (not duplicated), adds a translation-identity check (mined
  Wikipedia alignment occasionally leaves an untranslated English row
  copied into the target-language column), and caps sentence length at
  25 words (this is encyclopedic Wikipedia text, not conversational
  speech — long sentences don't serve a beginner course well even when
  every other check passes).
- **Register note:** unlike Tatoeba's casual/conversational sentences,
  this is Wikipedia article content — more formal and encyclopedic. Real
  and appropriately licensed, but a different register; worth knowing
  when reviewing what a "sentence" in this catalogue actually looks like
  at this scale.
- **Web-specific cap:** `compile.py`'s `WEB_SENTENCE_CAP` limits how much
  of this (and the Tatoeba) sentence data reaches `content.json` (the
  web platform's seed file) — see that constant's comment. Desktop/mobile
  get the full set via `content.db`.

This satisfies the CC BY-SA attribution requirement for including this
data in the Language Learning OS content database.
