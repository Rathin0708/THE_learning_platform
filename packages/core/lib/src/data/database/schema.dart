/// Content DB (read-only, shipped with the app / updated via content packs)
/// and User DB (read/write, entirely local) schema definitions.
/// Column layouts follow the engineering spec section 4.1 / 4.2 exactly.
library;

const List<String> contentDatabaseDdl = [
  '''
  CREATE TABLE IF NOT EXISTS languages (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    native_name TEXT NOT NULL
  );
  ''',
  '''
  CREATE TABLE IF NOT EXISTS levels (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    rank INTEGER NOT NULL
  );
  ''',
  '''
  CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
  );
  ''',
  '''
  CREATE TABLE IF NOT EXISTS words (
    id INTEGER PRIMARY KEY,
    language_id INTEGER NOT NULL REFERENCES languages(id),
    word TEXT NOT NULL,
    normalized_word TEXT NOT NULL,
    type TEXT,
    level TEXT NOT NULL,
    category TEXT NOT NULL,
    frequency REAL DEFAULT 0,
    difficulty INTEGER DEFAULT 1
  );
  ''',
  'CREATE INDEX IF NOT EXISTS idx_words_normalized ON words(normalized_word);',
  'CREATE INDEX IF NOT EXISTS idx_words_language ON words(language_id);',
  'CREATE INDEX IF NOT EXISTS idx_words_level ON words(level);',
  'CREATE INDEX IF NOT EXISTS idx_words_category ON words(category);',
  'CREATE INDEX IF NOT EXISTS idx_words_frequency ON words(frequency);',
  '''
  CREATE TABLE IF NOT EXISTS translations (
    id INTEGER PRIMARY KEY,
    source_word_id INTEGER NOT NULL REFERENCES words(id),
    target_word_id INTEGER NOT NULL REFERENCES words(id),
    meaning TEXT,
    context TEXT
  );
  ''',
  'CREATE INDEX IF NOT EXISTS idx_translations_source ON translations(source_word_id);',
  'CREATE INDEX IF NOT EXISTS idx_translations_target ON translations(target_word_id);',
  '''
  CREATE TABLE IF NOT EXISTS sentences (
    id INTEGER PRIMARY KEY,
    level TEXT NOT NULL,
    category TEXT NOT NULL,
    source_language TEXT NOT NULL,
    source_text TEXT NOT NULL
  );
  ''',
  'CREATE INDEX IF NOT EXISTS idx_sentences_level ON sentences(level);',
  '''
  CREATE TABLE IF NOT EXISTS sentence_translations (
    id INTEGER PRIMARY KEY,
    sentence_id INTEGER NOT NULL REFERENCES sentences(id),
    language TEXT NOT NULL,
    translated_text TEXT NOT NULL
  );
  ''',
  'CREATE INDEX IF NOT EXISTS idx_sentence_translations_sentence ON sentence_translations(sentence_id);',
  '''
  CREATE TABLE IF NOT EXISTS pronunciations (
    id INTEGER PRIMARY KEY,
    content_id INTEGER NOT NULL,
    language TEXT NOT NULL,
    ipa TEXT,
    tamil_pronunciation TEXT,
    english_pronunciation TEXT,
    audio_asset TEXT
  );
  ''',
  'CREATE INDEX IF NOT EXISTS idx_pronunciations_content ON pronunciations(content_id);',
  '''
  CREATE TABLE IF NOT EXISTS examples (
    id INTEGER PRIMARY KEY,
    word_id INTEGER REFERENCES words(id),
    sentence_id INTEGER REFERENCES sentences(id),
    context TEXT,
    meaning TEXT
  );
  ''',
  '''
  CREATE TABLE IF NOT EXISTS grammar (
    id INTEGER PRIMARY KEY,
    level TEXT NOT NULL,
    topic TEXT NOT NULL,
    explanation TEXT NOT NULL,
    examples TEXT
  );
  ''',
  '''
  CREATE TABLE IF NOT EXISTS conversations (
    id INTEGER PRIMARY KEY,
    level TEXT NOT NULL,
    scenario TEXT NOT NULL,
    title TEXT NOT NULL
  );
  ''',
  '''
  CREATE TABLE IF NOT EXISTS conversation_lines (
    id INTEGER PRIMARY KEY,
    conversation_id INTEGER NOT NULL REFERENCES conversations(id),
    speaker TEXT NOT NULL,
    text TEXT NOT NULL,
    translation TEXT NOT NULL,
    expected_response TEXT
  );
  ''',
  'CREATE INDEX IF NOT EXISTS idx_conversation_lines_conv ON conversation_lines(conversation_id);',
  '''
  CREATE TABLE IF NOT EXISTS quiz_questions (
    id INTEGER PRIMARY KEY,
    level TEXT NOT NULL,
    type TEXT NOT NULL,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    options TEXT
  );
  ''',
  // FTS5 virtual table across English, Tamil, Hindi, Roman Hindi (spec 4.3).
  // Standalone (not content-linked to `words`) because the app never inserts
  // content words directly — the Content Compiler populates both `words`
  // and `words_fts` together at build time, keeping rowids in sync.
  '''
  CREATE VIRTUAL TABLE IF NOT EXISTS words_fts USING fts5(
    word,
    normalized_word,
    romanized
  );
  ''',
];

const List<String> userDatabaseDdl = [
  '''
  CREATE TABLE IF NOT EXISTS user_progress (
    content_id INTEGER PRIMARY KEY,
    ease_factor REAL NOT NULL DEFAULT 2.5,
    interval INTEGER NOT NULL DEFAULT 0,
    repetitions INTEGER NOT NULL DEFAULT 0,
    last_review TEXT,
    next_review TEXT,
    mastery REAL NOT NULL DEFAULT 0
  );
  ''',
  'CREATE INDEX IF NOT EXISTS idx_user_progress_next_review ON user_progress(next_review);',
  '''
  CREATE TABLE IF NOT EXISTS user_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  );
  ''',
  '''
  CREATE TABLE IF NOT EXISTS review_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_id INTEGER NOT NULL,
    quality INTEGER NOT NULL,
    reviewed_at TEXT NOT NULL
  );
  ''',
];
