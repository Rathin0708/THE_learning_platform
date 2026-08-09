#!/usr/bin/env python3
"""
Importer: converts CC-BY-licensed Tatoeba sentence pairs into
content/source/sentences_tatoeba.yaml, in the same shape as the
hand-authored sentences.yaml.

Sourced directly from tatoeba.org's own per-language export files
(downloads.tatoeba.org/exports/per_language/), not the smaller curated
snapshot at manythings.org/anki — the direct source has ~6,900 real
Hindi-English pairs and ~300 real Tamil-English pairs (vs. manythings'
~3,100 and ~216), all still real, community-verified Tatoeba sentences
and links; nothing here is generated or guessed. Deduplicates against
the existing hand-authored sentences.yaml by normalized English text.
"""
import re
import unicodedata
from pathlib import Path

import yaml

ROOT = Path(__file__).parent.parent.parent
TATOEBA_DIR = ROOT / "build" / "tatoeba" / "raw"
SOURCE_DIR = ROOT / "content" / "source"


def normalize(text: str) -> str:
    return unicodedata.normalize("NFC", text.strip()).lower()


def load_sentences(path: Path) -> dict:
    """Returns {tatoeba_id: text}."""
    result = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            sid, _lang, text = parts[0], parts[1], parts[2]
            result[sid] = text
    return result


def load_needed_english_ids(*link_paths: Path) -> set:
    needed = set()
    for path in link_paths:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                parts = line.rstrip("\n").split("\t")
                if len(parts) < 2:
                    continue
                needed.add(parts[0])
                needed.add(parts[1])
    return needed


def load_english_sentences_filtered(path: Path, needed_ids: set) -> dict:
    """Streams the ~2M-row full English export, keeping only rows whose id
    is in [needed_ids] — avoids holding the entire corpus in memory."""
    result = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            sid = parts[0]
            if sid in needed_ids:
                result[sid] = parts[2]
    return result


def load_pairs(links_path: Path, other_sentences: dict, eng_sentences: dict) -> dict:
    """Returns {normalized_english: (original_english, other_language_text)},
    reading a hin-eng/tam-eng links file where each row links a sentence id
    in [other_sentences] to one in [eng_sentences] (direction not assumed —
    links files contain both directions, so either column may be the
    English id)."""
    result = {}
    with open(links_path, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 2:
                continue
            a, b = parts[0], parts[1]
            if a in eng_sentences and b in other_sentences:
                eng_id, other_id = a, b
            elif b in eng_sentences and a in other_sentences:
                eng_id, other_id = b, a
            else:
                continue
            english = eng_sentences[eng_id]
            key = normalize(english)
            if key not in result:
                result[key] = (english, other_sentences[other_id])
    return result


def classify_level(english: str) -> str:
    word_count = len(english.split())
    if word_count <= 5:
        return "level_1"
    if word_count <= 10:
        return "level_2"
    return "level_3"


CATEGORY_KEYWORDS = {
    "food": ["eat", "food", "rice", "hungry", "drink", "water", "tea", "coffee", "cook"],
    "travel": ["go", "come", "station", "airport", "road", "car", "bus", "train", "walk"],
    "family": ["mother", "father", "brother", "sister", "family", "friend", "child"],
    "time": ["today", "tomorrow", "yesterday", "time", "morning", "night", "hour"],
    "greetings": ["hello", "thank", "sorry", "please", "goodbye", "welcome"],
    "work": ["work", "job", "office", "study", "school", "book", "read", "write"],
}


def classify_category(english: str) -> str:
    lowered = english.lower()
    for category, keywords in CATEGORY_KEYWORDS.items():
        if any(kw in lowered for kw in keywords):
            return category
    return "general"


def main():
    hin_sentences = load_sentences(TATOEBA_DIR / "hin_sentences.tsv")
    tam_sentences = load_sentences(TATOEBA_DIR / "tam_sentences.tsv")

    needed_eng_ids = load_needed_english_ids(
        TATOEBA_DIR / "hin-eng_links.tsv", TATOEBA_DIR / "tam-eng_links.tsv"
    )
    eng_sentences = load_english_sentences_filtered(TATOEBA_DIR / "eng_sentences.tsv", needed_eng_ids)

    hin_pairs = load_pairs(TATOEBA_DIR / "hin-eng_links.tsv", hin_sentences, eng_sentences)
    tam_pairs = load_pairs(TATOEBA_DIR / "tam-eng_links.tsv", tam_sentences, eng_sentences)

    existing = yaml.safe_load((SOURCE_DIR / "sentences.yaml").read_text(encoding="utf-8"))
    existing_keys = {normalize(s["english"]) for s in existing.get("sentences", [])}

    all_keys = set(hin_pairs) | set(tam_pairs)
    new_keys = sorted(all_keys - existing_keys)

    entries = []
    for idx, key in enumerate(new_keys):
        hin = hin_pairs.get(key)
        tam = tam_pairs.get(key)
        english = (hin or tam)[0]
        # Skip bare punctuation/interjection-only lines with no letters.
        if not re.search(r"[a-zA-Z]", english):
            continue

        entry = {
            "id": f"tatoeba_{idx}",
            "level": classify_level(english),
            "category": classify_category(english),
            "english": english,
        }
        if tam:
            entry["tamil"] = tam[1]
        if hin:
            entry["hindi"] = hin[1]
        entries.append(entry)

    output = {"sentences": entries}
    out_path = SOURCE_DIR / "sentences_tatoeba.yaml"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(
            "# Sourced directly from the Tatoeba Project (tatoeba.org)'s own\n"
            "# per-language export files, licensed CC-BY 2.0 (France).\n"
            "# Community-verified translations, not machine-generated. See\n"
            "# content/source/TATOEBA_ATTRIBUTION.md.\n"
            "# Auto-generated by tools/content_compiler/import_tatoeba.py — do not hand-edit.\n\n"
        )
        yaml.dump(output, f, allow_unicode=True, sort_keys=False, width=1000)

    both = sum(1 for k in new_keys if k in hin_pairs and k in tam_pairs)
    only_hin = sum(1 for k in new_keys if k in hin_pairs and k not in tam_pairs)
    only_tam = sum(1 for k in new_keys if k in tam_pairs and k not in hin_pairs)

    print(f"hin-eng pairs available: {len(hin_pairs)}")
    print(f"tam-eng pairs available: {len(tam_pairs)}")
    print(f"Already in hand-authored sentences.yaml (skipped): {len(all_keys & existing_keys)}")
    print(f"New sentences written: {len(entries)}")
    print(f"  trilingual (en+ta+hi): {both}")
    print(f"  english+hindi only: {only_hin}")
    print(f"  english+tamil only: {only_tam}")
    print(f"-> {out_path}")


if __name__ == "__main__":
    main()
