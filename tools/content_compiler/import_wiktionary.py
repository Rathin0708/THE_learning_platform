#!/usr/bin/env python3
"""
Importer: extracts trilingual (English/Tamil/Hindi) vocabulary concepts
from English Wiktionary's translation tables (via kaikki.org's
machine-readable Wiktionary extract) into content/source/words_wiktionary.yaml.

Real, community-sourced dictionary data, not generated: for each English
headword that has BOTH a Tamil and a Hindi translation listed on English
Wiktionary (with a romanization), emits one concept with IPA (from
Wiktionary's pronunciation data), romanization, and part-of-speech.
Frequency is derived by cross-referencing the hermitdave/FrequencyWords
English rank list (MIT licensed, OpenSubtitles-derived) since Wiktionary
itself doesn't carry frequency data.

Licensing: Wiktionary text is CC BY-SA 4.0 (+ GFDL) — ShareAlike, unlike
Tatoeba's plain CC-BY. See content/source/WIKTIONARY_ATTRIBUTION.md.
"""
import json
import re
import unicodedata
from pathlib import Path

import yaml

ROOT = Path(__file__).parent.parent.parent
WIKT_DIR = ROOT / "build" / "wiktionary"
SOURCE_DIR = ROOT / "content" / "source"


# Deliberately excludes closed-class function words (pronoun/preposition/
# conjunction/determiner): spot-checking the first pass found these are
# where Wiktionary's translation tables most often produce mismatched-
# sense or template-artifact "translations" ("to"/"of"/"and" don't have
# a single 1:1 target-language word the way content words do), and
# isolated function-word flashcards aren't a meaningful vocabulary unit
# for a learner anyway. Content-word classes only.
VALID_POS = {"noun", "verb", "adj", "adv", "intj", "num", "phrase"}
POS_TO_TYPE = {
    "noun": "noun", "verb": "verb", "adj": "adjective", "adv": "adverb",
    "intj": "interjection", "num": "numeral", "phrase": "phrase",
}

# Wiktionary translation entries occasionally carry editorial/template
# text instead of (or alongside) an actual translation — e.g. "N/A.
# Alternatives: ..." when a sense has no single agreed translation, or
# "... का" for a grammatical particle template. Reject any candidate
# whose word/romanization contains one of these tells.
SUSPICIOUS_MARKERS = ("N/A", "Alternatives", "...", "(", ")", "[", "]", "see ", "e.g")


def has_suspicious_marker(text: str) -> bool:
    return any(marker in text for marker in SUSPICIOUS_MARKERS)

# How many of the highest-frequency matches to keep — stays close to
# spec's 2,000-word MVP target combined with the existing hand-authored
# set, rather than dumping every match Wiktionary happens to have (which
# trails off into obscure/rare vocabulary not useful for a beginner
# course).
TARGET_NEW_CONCEPTS = 1800


def normalize(text: str) -> str:
    return unicodedata.normalize("NFC", text.strip()).lower()


def load_frequency_ranks(path: Path) -> dict:
    """Returns {normalized_word: rank} (0-indexed, most frequent first)."""
    ranks = {}
    with open(path, "r", encoding="utf-8") as f:
        for idx, line in enumerate(f):
            parts = line.rstrip("\n").split(" ")
            if not parts or not parts[0]:
                continue
            word = normalize(parts[0])
            if word not in ranks:  # keep first (highest) occurrence
                ranks[word] = idx
    return ranks


def rank_to_frequency(rank, top_n=3000) -> float:
    if rank is None:
        return 0.4
    return round(max(0.3, 1.0 - rank / top_n), 3)


def first_ipa(sounds):
    if not sounds:
        return None
    for s in sounds:
        ipa = s.get("ipa")
        if ipa:
            return ipa
    return None


CATEGORY_KEYWORDS = {
    "family": ["mother", "father", "brother", "sister", "son", "daughter", "wife", "husband",
               "child", "parent", "family", "baby", "grandmother", "grandfather", "uncle", "aunt"],
    "food": ["eat", "food", "rice", "water", "drink", "tea", "coffee", "bread", "fruit",
             "vegetable", "meat", "fish", "milk", "sugar", "salt", "cook", "kitchen", "hungry", "thirsty"],
    "numbers": ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                "hundred", "thousand", "number", "first", "second", "third"],
    "colors": ["red", "blue", "green", "yellow", "black", "white", "colour", "color",
               "orange", "purple", "pink", "brown"],
    "time": ["today", "tomorrow", "yesterday", "morning", "evening", "night", "hour",
             "minute", "week", "month", "year", "day", "time", "clock", "now", "later"],
    "body": ["head", "hand", "leg", "eye", "ear", "nose", "mouth", "hair", "face",
             "body", "finger", "foot", "heart", "arm", "shoulder", "back"],
    "animals": ["dog", "cat", "cow", "bird", "fish", "horse", "animal", "elephant",
                "tiger", "lion", "goat", "sheep", "rat", "snake", "monkey"],
    "weather": ["rain", "sun", "cloud", "wind", "hot", "cold", "weather", "storm", "snow", "sky"],
    "travel": ["go", "come", "station", "airport", "road", "car", "bus", "train",
               "walk", "travel", "journey", "ticket", "arrive", "leave"],
    "greetings": ["hello", "thank", "sorry", "please", "goodbye", "welcome", "yes", "no"],
    "work": ["work", "job", "office", "study", "school", "book", "read",
             "write", "teacher", "student", "learn"],
    "home": ["house", "home", "room", "door", "window", "table", "chair", "bed", "roof", "wall"],
    "emotions": ["happy", "sad", "angry", "love", "fear", "afraid", "worry", "joy", "glad", "tired"],
}


def classify_category(word: str) -> str:
    lowered = word.lower()
    for category, keywords in CATEGORY_KEYWORDS.items():
        if lowered in keywords:
            return category
    return "general"


def main():
    freq_ranks = load_frequency_ranks(WIKT_DIR / "en_50k_freq.txt")

    existing = yaml.safe_load((SOURCE_DIR / "words.yaml").read_text(encoding="utf-8"))
    existing_english = {normalize(c["english"]["word"]) for c in existing.get("concepts", []) if c.get("english")}

    # compile.py's dedup key for non-English words is (language, normalized
    # word, category) — two different English synonyms (e.g. "ask"/"hear")
    # can share one Tamil/Hindi realization, which would otherwise collide.
    # Seed with existing words.yaml's words so new entries can't collide
    # with hand-authored content either.
    seen_target_words = set()
    for c in existing.get("concepts", []):
        category = c.get("category", "")
        for code, lang in (("ta", "tamil"), ("hi", "hindi")):
            entry = c.get(lang)
            if entry and entry.get("word"):
                seen_target_words.add((code, normalize(entry["word"]), category))

    entries = []
    seen_english = set()

    with open(WIKT_DIR / "kaikki-english.jsonl", "r", encoding="utf-8") as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue

            word = d.get("word")
            pos = d.get("pos")
            translations = d.get("translations")
            if not word or not pos or not translations or pos not in VALID_POS:
                continue

            key = normalize(word)
            if key in existing_english or key in seen_english:
                continue
            if not re.fullmatch(r"[a-zA-Z][a-zA-Z '-]*", word):
                continue  # skip multi-word/punctuated headwords for a clean starter vocab

            ta = next(
                (t for t in translations if t.get("code") == "ta" and t.get("word") and t.get("roman")
                 and not has_suspicious_marker(t["word"]) and not has_suspicious_marker(t["roman"])),
                None,
            )
            hi = next(
                (t for t in translations if t.get("code") == "hi" and t.get("word") and t.get("roman")
                 and not has_suspicious_marker(t["word"]) and not has_suspicious_marker(t["roman"])),
                None,
            )
            if not ta or not hi:
                continue

            ipa = first_ipa(d.get("sounds"))
            if ipa and not (ipa.startswith("/") or ipa.startswith("[")):
                ipa = None

            seen_english.add(key)
            rank = freq_ranks.get(key)
            category = classify_category(word)
            entries.append({
                "id": re.sub(r"[^a-z0-9]+", "_", key).strip("_"),
                "category": category,
                "type": POS_TO_TYPE[pos],
                "frequency": rank_to_frequency(rank),
                "_rank": rank if rank is not None else 999999,
                "english": {"word": word, **({"ipa": ipa} if ipa else {})},
                "tamil": {"word": ta["word"], "roman": ta["roman"]},
                "hindi": {"word": hi["word"], "roman": hi["roman"]},
            })

    # Resolve target-word collisions in frequency order (the more common
    # English word keeps the shared Tamil/Hindi realization; the rarer
    # synonym is dropped rather than emitted as an unusable duplicate).
    entries.sort(key=lambda e: e["_rank"])
    deduped = []
    for e in entries:
        ta_key = ("ta", normalize(e["tamil"]["word"]), e["category"])
        hi_key = ("hi", normalize(e["hindi"]["word"]), e["category"])
        if ta_key in seen_target_words or hi_key in seen_target_words:
            continue
        seen_target_words.add(ta_key)
        seen_target_words.add(hi_key)
        deduped.append(e)
        if len(deduped) >= TARGET_NEW_CONCEPTS:
            break
    entries = deduped
    for e in entries:
        del e["_rank"]

    output = {"concepts": entries}
    out_path = SOURCE_DIR / "words_wiktionary.yaml"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(
            "# Trilingual vocabulary sourced from English Wiktionary's translation\n"
            "# tables (via kaikki.org's machine-readable extract), CC BY-SA 4.0 +\n"
            "# GFDL (Wiktionary's dual license — ShareAlike, unlike Tatoeba's plain\n"
            "# CC-BY). Community-sourced, not machine-translated. See\n"
            "# content/source/WIKTIONARY_ATTRIBUTION.md. Frequency ranking\n"
            "# cross-referenced against hermitdave/FrequencyWords (MIT,\n"
            "# OpenSubtitles-derived).\n"
            "# Auto-generated by tools/content_compiler/import_wiktionary.py — do not hand-edit.\n\n"
        )
        yaml.dump(output, f, allow_unicode=True, sort_keys=False, width=1000)

    print(f"Existing hand-authored concepts (skipped): {len(existing_english)}")
    print(f"New concepts written: {len(entries)}")
    print(f"-> {out_path}")


if __name__ == "__main__":
    main()
