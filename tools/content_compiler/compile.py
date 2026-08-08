#!/usr/bin/env python3
"""
Content Compiler (spec section 3.2 / THE-14).

Raw source content -> Normalize -> Duplicate Detection -> (validation) ->
Difficulty Classification -> SQLite database, matching the schema in
packages/core/lib/src/data/database/schema.dart exactly.

Usage:
    python compile.py [--source ../../content/source] [--out ../../build/content.db]

The compiled .db is a build artifact — never hand-edited, never committed
as source (spec section 3: "Git holds the source content. The compiled
runtime artifacts ... are generated, not hand-edited.").
"""
import argparse
import re
import sqlite3
import sys
import unicodedata
from pathlib import Path

import yaml

LANGUAGES = [
    (1, "en", "English", "English"),
    (2, "ta", "Tamil", "தமிழ்"),
    (3, "hi", "Hindi", "हिन्दी"),
]
LANG_ID_BY_CODE = {code: id_ for id_, code, *_ in LANGUAGES}

LEVELS = [
    (1, "level_1", 1),
    (2, "level_2", 2),
    (3, "level_3", 3),
]

DDL_STATEMENTS = [
    """CREATE TABLE languages (
        id INTEGER PRIMARY KEY, code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL, native_name TEXT NOT NULL)""",
    """CREATE TABLE levels (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL, rank INTEGER NOT NULL)""",
    """CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE)""",
    """CREATE TABLE words (
        id INTEGER PRIMARY KEY, language_id INTEGER NOT NULL REFERENCES languages(id),
        word TEXT NOT NULL, normalized_word TEXT NOT NULL, type TEXT,
        level TEXT NOT NULL, category TEXT NOT NULL,
        frequency REAL DEFAULT 0, difficulty INTEGER DEFAULT 1)""",
    "CREATE INDEX idx_words_normalized ON words(normalized_word)",
    "CREATE INDEX idx_words_language ON words(language_id)",
    "CREATE INDEX idx_words_level ON words(level)",
    "CREATE INDEX idx_words_category ON words(category)",
    "CREATE INDEX idx_words_frequency ON words(frequency)",
    """CREATE TABLE translations (
        id INTEGER PRIMARY KEY, source_word_id INTEGER NOT NULL REFERENCES words(id),
        target_word_id INTEGER NOT NULL REFERENCES words(id), meaning TEXT, context TEXT)""",
    "CREATE INDEX idx_translations_source ON translations(source_word_id)",
    "CREATE INDEX idx_translations_target ON translations(target_word_id)",
    """CREATE TABLE sentences (
        id INTEGER PRIMARY KEY, level TEXT NOT NULL, category TEXT NOT NULL,
        source_language TEXT NOT NULL, source_text TEXT NOT NULL)""",
    "CREATE INDEX idx_sentences_level ON sentences(level)",
    """CREATE TABLE sentence_translations (
        id INTEGER PRIMARY KEY, sentence_id INTEGER NOT NULL REFERENCES sentences(id),
        language TEXT NOT NULL, translated_text TEXT NOT NULL)""",
    "CREATE INDEX idx_sentence_translations_sentence ON sentence_translations(sentence_id)",
    """CREATE TABLE pronunciations (
        id INTEGER PRIMARY KEY, content_id INTEGER NOT NULL, language TEXT NOT NULL,
        ipa TEXT, tamil_pronunciation TEXT, english_pronunciation TEXT, audio_asset TEXT)""",
    "CREATE INDEX idx_pronunciations_content ON pronunciations(content_id)",
    """CREATE TABLE examples (
        id INTEGER PRIMARY KEY, word_id INTEGER REFERENCES words(id),
        sentence_id INTEGER REFERENCES sentences(id), context TEXT, meaning TEXT)""",
    """CREATE TABLE grammar (
        id INTEGER PRIMARY KEY, level TEXT NOT NULL, topic TEXT NOT NULL,
        explanation TEXT NOT NULL, examples TEXT)""",
    """CREATE TABLE conversations (
        id INTEGER PRIMARY KEY, level TEXT NOT NULL, scenario TEXT NOT NULL, title TEXT NOT NULL)""",
    """CREATE TABLE conversation_lines (
        id INTEGER PRIMARY KEY, conversation_id INTEGER NOT NULL REFERENCES conversations(id),
        speaker TEXT NOT NULL, text TEXT NOT NULL, translation TEXT NOT NULL,
        expected_response TEXT)""",
    "CREATE INDEX idx_conversation_lines_conv ON conversation_lines(conversation_id)",
    """CREATE TABLE quiz_questions (
        id INTEGER PRIMARY KEY, level TEXT NOT NULL, type TEXT NOT NULL,
        question TEXT NOT NULL, answer TEXT NOT NULL, options TEXT,
        content_id INTEGER REFERENCES words(id))""",
    """CREATE VIRTUAL TABLE words_fts USING fts5(word, normalized_word, romanized)""",
]


def normalize(text: str) -> str:
    """NFC-normalize and lowercase (Latin only — Tamil/Hindi have no case)."""
    text = unicodedata.normalize("NFC", text.strip())
    return text.lower()


class DuplicateError(Exception):
    pass


class ContentCompiler:
    def __init__(self, source_dir: Path, out_path: Path):
        self.source_dir = source_dir
        self.out_path = out_path
        self.seen_words = set()  # (language_id, normalized_word, category) dedup key
        self.word_id_by_concept_lang = {}  # (concept_id, lang_code) -> word row id
        self.stats = {"words": 0, "translations": 0, "sentences": 0,
                      "sentence_translations": 0, "conversations": 0,
                      "conversation_lines": 0, "quiz_questions": 0, "pronunciations": 0}

    def load_yaml(self, filename: str) -> dict:
        path = self.source_dir / filename
        if not path.exists():
            return {}
        with open(path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f) or {}

    def compile(self):
        self.out_path.parent.mkdir(parents=True, exist_ok=True)
        if self.out_path.exists():
            self.out_path.unlink()

        conn = sqlite3.connect(self.out_path)
        cur = conn.cursor()
        for statement in DDL_STATEMENTS:
            cur.execute(statement)

        for id_, code, name, native in LANGUAGES:
            cur.execute("INSERT INTO languages (id, code, name, native_name) VALUES (?,?,?,?)",
                        (id_, code, name, native))
        for id_, name, rank in LEVELS:
            cur.execute("INSERT INTO levels (id, name, rank) VALUES (?,?,?)", (id_, name, rank))

        words_data = self.load_yaml("words.yaml").get("concepts", [])
        self._compile_words(cur, words_data)

        sentences_data = self.load_yaml("sentences.yaml").get("sentences", [])
        sentences_data += self.load_yaml("sentences_tatoeba.yaml").get("sentences", [])
        self._compile_sentences(cur, sentences_data)

        conversations_data = self.load_yaml("conversations.yaml").get("conversations", [])
        conversations_data += self.load_yaml("conversations_extra.yaml").get("conversations", [])
        self._compile_conversations(cur, conversations_data)

        self._generate_quiz_questions(cur)

        conn.commit()
        conn.close()

        return self.stats

    def _compile_words(self, cur, concepts: list):
        categories_seen = set()
        for concept in concepts:
            concept_id = concept["id"]
            category = concept["category"]
            word_type = concept.get("type", "")
            level = concept.get("level", "level_1")
            frequency = float(concept.get("frequency", 0.5))
            difficulty = self._classify_difficulty(frequency)

            if category not in categories_seen:
                categories_seen.add(category)
                cur.execute("INSERT OR IGNORE INTO categories (name) VALUES (?)", (category,))

            lang_ids_this_concept = {}
            for lang_code in ("english", "tamil", "hindi"):
                entry = concept.get(lang_code)
                if not entry:
                    continue
                code = {"english": "en", "tamil": "ta", "hindi": "hi"}[lang_code]
                word_text = entry["word"]
                normalized = normalize(word_text)
                dedup_key = (code, normalized, category)
                if dedup_key in self.seen_words:
                    raise DuplicateError(f"Duplicate word detected: {dedup_key} (concept {concept_id})")
                self.seen_words.add(dedup_key)

                cur.execute(
                    "INSERT INTO words (language_id, word, normalized_word, type, level, "
                    "category, frequency, difficulty) VALUES (?,?,?,?,?,?,?,?)",
                    (LANG_ID_BY_CODE[code], word_text, normalized, word_type, level,
                     category, frequency, difficulty),
                )
                word_id = cur.lastrowid
                self.word_id_by_concept_lang[(concept_id, code)] = word_id
                lang_ids_this_concept[code] = word_id
                self.stats["words"] += 1

                roman = entry.get("roman")
                cur.execute(
                    "INSERT INTO words_fts (rowid, word, normalized_word, romanized) VALUES (?,?,?,?)",
                    (word_id, word_text, normalized, normalize(roman) if roman else normalized),
                )

                # Pronunciation row: IPA for English, romanization for ta/hi.
                ipa = entry.get("ipa")
                roman = entry.get("roman")
                if ipa or roman:
                    cur.execute(
                        "INSERT INTO pronunciations (content_id, language, ipa, "
                        "tamil_pronunciation, english_pronunciation, audio_asset) "
                        "VALUES (?,?,?,?,?,?)",
                        (word_id, code, ipa, roman if code != "en" else None,
                         roman if code != "en" else None, None),
                    )
                    self.stats["pronunciations"] += 1

            # Pairwise translations between every language pair present.
            codes = list(lang_ids_this_concept.keys())
            for i, source_code in enumerate(codes):
                for target_code in codes:
                    if source_code == target_code:
                        continue
                    cur.execute(
                        "INSERT INTO translations (source_word_id, target_word_id, "
                        "meaning, context) VALUES (?,?,?,?)",
                        (lang_ids_this_concept[source_code], lang_ids_this_concept[target_code],
                         concept_id, category),
                    )
                    self.stats["translations"] += 1

    @staticmethod
    def _classify_difficulty(frequency: float) -> int:
        # Higher frequency -> lower difficulty (spec 5.3 difficulty classification).
        if frequency >= 0.85:
            return 1
        if frequency >= 0.65:
            return 2
        return 3

    def _compile_sentences(self, cur, sentences: list):
        seen_texts = set()
        for s in sentences:
            english = s["english"].strip()
            dedup_key = (s.get("level", "level_1"), s.get("category", ""), normalize(english))
            if dedup_key in seen_texts:
                raise DuplicateError(f"Duplicate sentence detected: {s['id']}")
            seen_texts.add(dedup_key)

            cur.execute(
                "INSERT INTO sentences (level, category, source_language, source_text) "
                "VALUES (?,?,?,?)",
                (s.get("level", "level_1"), s.get("category", ""), "en", english),
            )
            sentence_id = cur.lastrowid
            self.stats["sentences"] += 1

            for lang_code, key in (("en", "english"), ("ta", "tamil"), ("hi", "hindi")):
                text = s.get(key)
                if not text:
                    continue
                cur.execute(
                    "INSERT INTO sentence_translations (sentence_id, language, translated_text) "
                    "VALUES (?,?,?)",
                    (sentence_id, lang_code, text),
                )
                self.stats["sentence_translations"] += 1

    def _compile_conversations(self, cur, conversations: list):
        for c in conversations:
            cur.execute(
                "INSERT INTO conversations (level, scenario, title) VALUES (?,?,?)",
                (c.get("level", "level_1"), c["scenario"], c["title"]),
            )
            conversation_id = cur.lastrowid
            self.stats["conversations"] += 1
            for line in c.get("lines", []):
                cur.execute(
                    "INSERT INTO conversation_lines (conversation_id, speaker, text, "
                    "translation, expected_response) VALUES (?,?,?,?,?)",
                    (conversation_id, line["speaker"], line["text"],
                     line["translation"], line.get("expected_response")),
                )
                self.stats["conversation_lines"] += 1

    def _generate_quiz_questions(self, cur):
        """
        Auto-generate multiple-choice translation quizzes from the compiled
        words+translations, so quiz content can never drift out of sync with
        the vocabulary data (a hand-written quizzes.yaml would need constant
        re-syncing as words.yaml grows).
        """
        cur.execute(
            """
            SELECT sw.word AS source_word, sw.level AS level, tw.word AS answer, sw.id AS source_word_id
            FROM translations t
            JOIN words sw ON sw.id = t.source_word_id
            JOIN words tw ON tw.id = t.target_word_id
            JOIN languages sl ON sl.id = sw.language_id
            JOIN languages tl ON tl.id = tw.language_id
            WHERE sl.code = 'en' AND tl.code = 'ta'
            """
        )
        rows = cur.fetchall()
        all_answers = [r[2] for r in rows]

        import random
        rng = random.Random(42)  # deterministic output across compiler runs

        for source_word, level, answer, source_word_id in rows:
            distractors = rng.sample([a for a in all_answers if a != answer], k=min(3, len(all_answers) - 1))
            options = distractors + [answer]
            rng.shuffle(options)
            cur.execute(
                "INSERT INTO quiz_questions (level, type, question, answer, options, content_id) VALUES (?,?,?,?,?,?)",
                (level, "translate_en_to_ta", f"Translate to Tamil: '{source_word}'", answer, "|".join(options), source_word_id),
            )
            self.stats["quiz_questions"] += 1


EXPORT_TABLES = [
    "languages", "levels", "categories", "words", "translations", "sentences",
    "sentence_translations", "pronunciations", "examples", "grammar",
    "conversations", "conversation_lines", "quiz_questions",
]


def export_json(db_path: Path, json_path: Path):
    """
    Web (THE-58) has no API to import an existing SQLite file into
    IndexedDB-backed storage (sqflite_common_ffi_web creates only empty
    databases). This JSON export lets the Dart-side web seeder recreate
    the same rows via plain INSERTs against an empty web database on
    first launch — same source of truth, a second output format solely
    because of that platform constraint.
    """
    import json

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    export = {}
    for table in EXPORT_TABLES:
        cur.execute(f"SELECT * FROM {table}")
        export[table] = [dict(row) for row in cur.fetchall()]
    conn.close()

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(export, f, ensure_ascii=False)

    return {table: len(rows) for table, rows in export.items()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=str(Path(__file__).parent.parent.parent / "content" / "source"))
    parser.add_argument("--out", default=str(Path(__file__).parent.parent.parent / "build" / "content.db"))
    parser.add_argument("--json-out", default=None,
                         help="Also export a JSON dump for the web seeder (THE-58). Defaults to <out>.json")
    args = parser.parse_args()

    compiler = ContentCompiler(Path(args.source), Path(args.out))
    try:
        stats = compiler.compile()
    except DuplicateError as e:
        print(f"CONTENT QUALITY GATE FAILED: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Compiled content database -> {args.out}")
    for key, value in stats.items():
        print(f"  {key}: {value}")

    json_out = Path(args.json_out) if args.json_out else Path(args.out).with_suffix(".json")
    export_stats = export_json(Path(args.out), json_out)
    print(f"Exported JSON for web seeder -> {json_out}")
    for key, value in export_stats.items():
        print(f"  {key}: {value}")


if __name__ == "__main__":
    main()
