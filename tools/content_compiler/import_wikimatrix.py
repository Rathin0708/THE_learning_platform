#!/usr/bin/env python3
"""
Importer: converts CC BY-SA 4.0-licensed Wikipedia-derived parallel
sentences (WikiMatrix + the "wikimedia" OPUS corpus, both mined from
Wikipedia article translations) into content/source/sentences_wikimatrix.yaml.

THE-64/65/66 (content scale-up to 25K/50K/100K+ items): the large
Tamil/Hindi-English corpora at real scale (Samanantar, NLLB, CCMatrix)
turned out to be CC-BY-NC or ambiguously licensed — see the ticket
comments. WikiMatrix and "wikimedia" are the same license family already
used for words_wiktionary.yaml (CC BY-SA, ShareAlike, both official
sources bundle a LICENSE file confirming this directly), so this reuses
an already-accepted license tier rather than introducing a new one.

Same filters as import_tatoeba.py (mature content, grammar sanity),
reused directly rather than duplicated, plus a translation-identity
check at import time: mined Wikipedia alignment occasionally leaves an
untranslated English row in the target-language column (found by
inspection — e.g. an English sentence copied verbatim into the Tamil
file), which compile.py's Translation Validation gate would otherwise
have to reject one row at a time.
"""
import re
import unicodedata
from pathlib import Path

import yaml

from import_tatoeba import (
    classify_category,
    classify_level,
    fails_grammar_sanity,
    is_mature_content,
    normalize,
)

ROOT = Path(__file__).parent.parent.parent
CORPUS_DIR = ROOT / "build" / "wikimatrix"
SOURCE_DIR = ROOT / "content" / "source"

# Each source is a pair of line-aligned plain-text files (Moses format).
SOURCES = [
    ("WikiMatrix", "hi", CORPUS_DIR / "WikiMatrix.en-hi.en", CORPUS_DIR / "WikiMatrix.en-hi.hi"),
    ("WikiMatrix", "ta", CORPUS_DIR / "WikiMatrix.en-ta.en", CORPUS_DIR / "WikiMatrix.en-ta.ta"),
    ("wikimedia", "hi", CORPUS_DIR / "wikimedia.en-hi.en", CORPUS_DIR / "wikimedia.en-hi.hi"),
    ("wikimedia", "ta", CORPUS_DIR / "wikimedia.en-ta.en", CORPUS_DIR / "wikimedia.en-ta.ta"),
]

# Comfortably clears the 100K-item milestone (THE-66) alongside the
# ~11,500 items already in the catalogue, with headroom for whatever
# gets dropped by quality filtering.
TARGET_NEW_SENTENCES = 92000

# Long encyclopedic sentences (this is Wikipedia-mined content, not
# conversational text) don't serve a beginner course well even when
# they pass every other quality check.
MAX_WORDS = 25


def read_pairs(en_path: Path, other_path: Path):
    with open(en_path, "r", encoding="utf-8") as ef, open(other_path, "r", encoding="utf-8") as of:
        for en_line, other_line in zip(ef, of):
            yield en_line.strip(), other_line.strip()


def main():
    existing_sources = ["sentences.yaml", "sentences_tatoeba.yaml"]
    existing_keys = set()
    for filename in existing_sources:
        data = yaml.safe_load((SOURCE_DIR / filename).read_text(encoding="utf-8")) or {}
        existing_keys |= {normalize(s["english"]) for s in data.get("sentences", [])}

    by_key = {}  # normalized english -> entry dict (merges hi/ta from different sources)
    stats = {"raw_pairs": 0, "duplicate_or_untranslated": 0, "mature_filtered": 0, "grammar_filtered": 0, "too_long": 0}

    for corpus_name, lang_code, en_path, other_path in SOURCES:
        if not en_path.exists() or not other_path.exists():
            print(f"Skipping {corpus_name} ({lang_code}) — files not found at {en_path}")
            continue
        for english, other in read_pairs(en_path, other_path):
            stats["raw_pairs"] += 1
            if not english or not other:
                continue
            key = normalize(english)
            if key in existing_keys:
                continue
            if normalize(other) == key:
                # Untranslated row — the "translation" is a copy of the source.
                stats["duplicate_or_untranslated"] += 1
                continue
            if not re.search(r"[a-zA-Z]", english):
                continue
            if len(english.split()) > MAX_WORDS:
                stats["too_long"] += 1
                continue
            if is_mature_content(english):
                stats["mature_filtered"] += 1
                continue
            if fails_grammar_sanity(english):
                stats["grammar_filtered"] += 1
                continue

            entry = by_key.get(key)
            if entry is None:
                entry = {
                    "id": f"wikimatrix_{len(by_key)}",
                    "level": classify_level(english),
                    "category": classify_category(english),
                    "english": english,
                }
                by_key[key] = entry
            entry[{"hi": "hindi", "ta": "tamil"}[lang_code]] = other

    entries = list(by_key.values())[:TARGET_NEW_SENTENCES]

    output = {"sentences": entries}
    out_path = SOURCE_DIR / "sentences_wikimatrix.yaml"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(
            "# Sourced from WikiMatrix and the \"wikimedia\" OPUS corpus — both\n"
            "# mined from Wikipedia article translations, CC BY-SA 4.0 (confirmed\n"
            "# directly in each source's own bundled LICENSE/README). See\n"
            "# content/source/WIKIMATRIX_ATTRIBUTION.md.\n"
            "# Auto-generated by tools/content_compiler/import_wikimatrix.py — do not hand-edit.\n\n"
        )
        yaml.dump(output, f, allow_unicode=True, sort_keys=False, width=1000)

    print(f"Raw pairs scanned across all 4 files: {stats['raw_pairs']}")
    print(f"Duplicate/untranslated rows skipped: {stats['duplicate_or_untranslated']}")
    print(f"Too long (>{MAX_WORDS} words): {stats['too_long']}")
    print(f"Filtered for mature content: {stats['mature_filtered']}")
    print(f"Filtered for grammar sanity: {stats['grammar_filtered']}")
    print(f"New sentences written: {len(entries)}")
    print(f"-> {out_path}")


if __name__ == "__main__":
    main()
