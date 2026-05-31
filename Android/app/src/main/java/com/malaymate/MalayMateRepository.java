package com.malaymate;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

class MalayMateRepository extends SQLiteOpenHelper {
    private static final String DB_NAME = "malaymate.db";
    private static final int DB_VERSION = 1;
    private final Context context;
    private final LeitnerScheduler scheduler = new LeitnerScheduler();

    MalayMateRepository(Context context) {
        super(context, DB_NAME, null, DB_VERSION);
        this.context = context.getApplicationContext();
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE decks (id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL, is_starter INTEGER NOT NULL, word_ids_json TEXT NOT NULL, created_at INTEGER NOT NULL)");
        db.execSQL("CREATE TABLE words (id TEXT PRIMARY KEY, term TEXT NOT NULL, language_code TEXT NOT NULL, chinese_meaning TEXT NOT NULL, part_of_speech TEXT NOT NULL, pronunciation_notes TEXT NOT NULL, syllables_json TEXT NOT NULL, examples_json TEXT NOT NULL, source_refs_json TEXT NOT NULL, review_status TEXT NOT NULL, learning_status TEXT, learned_at INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)");
        db.execSQL("CREATE TABLE cards (id TEXT PRIMARY KEY, word_id TEXT NOT NULL, direction TEXT NOT NULL, prompt TEXT NOT NULL, answer TEXT NOT NULL, hint TEXT NOT NULL, created_at INTEGER NOT NULL)");
        db.execSQL("CREATE TABLE review_states (card_id TEXT PRIMARY KEY, box INTEGER NOT NULL, due_at INTEGER NOT NULL, lapses INTEGER NOT NULL, last_reviewed_at INTEGER, ease_hint REAL NOT NULL)");
        db.execSQL("CREATE TABLE review_logs (id TEXT PRIMARY KEY, card_id TEXT NOT NULL, rating TEXT NOT NULL, reviewed_at INTEGER NOT NULL, previous_box INTEGER NOT NULL, next_box INTEGER NOT NULL, previous_due_at INTEGER NOT NULL, next_due_at INTEGER NOT NULL)");
        db.execSQL("CREATE INDEX idx_cards_word ON cards(word_id)");
        db.execSQL("CREATE INDEX idx_review_states_due ON review_states(due_at)");
        db.execSQL("CREATE INDEX idx_words_term ON words(term)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        db.execSQL("DROP TABLE IF EXISTS review_logs");
        db.execSQL("DROP TABLE IF EXISTS review_states");
        db.execSQL("DROP TABLE IF EXISTS cards");
        db.execSQL("DROP TABLE IF EXISTS words");
        db.execSQL("DROP TABLE IF EXISTS decks");
        onCreate(db);
    }

    void ensureSeedImported() throws Exception {
        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            importDeckFile(db, "starter_deck.json");
            importDeckFile(db, "open_frequency_starter_deck.json");
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    private void importDeckFile(SQLiteDatabase db, String assetName) throws Exception {
        JSONObject root = new JSONObject(readAsset(assetName));
        JSONArray decks = root.getJSONArray("decks");
        long now = System.currentTimeMillis();
        for (int i = 0; i < decks.length(); i++) {
            JSONObject deck = decks.getJSONObject(i);
            JSONArray words = deck.getJSONArray("words");
            JSONArray wordIds = new JSONArray();
            for (int w = 0; w < words.length(); w++) {
                JSONObject seed = words.getJSONObject(w);
                String wordId = SeedImporter.stableUuid(seed.getString("id"));
                wordIds.put(wordId);
                if (!exists(db, "words", wordId)) {
                    insertSeedWord(db, seed, wordId, now);
                }
                for (CardDirection direction : CardDirection.values()) {
                    String cardId = SeedImporter.stableUuid(seed.getString("id") + "-" + direction.raw);
                    ContentValues card = new ContentValues();
                    card.put("id", cardId);
                    card.put("word_id", wordId);
                    card.put("direction", direction.raw);
                    card.put("prompt", direction == CardDirection.MALAY_TO_CHINESE ? seed.getString("term") : seed.getString("chineseMeaning"));
                    card.put("answer", direction == CardDirection.MALAY_TO_CHINESE ? seed.getString("chineseMeaning") : seed.getString("term"));
                    card.put("hint", seed.optString("partOfSpeech", ""));
                    card.put("created_at", now);
                    db.insertWithOnConflict("cards", null, card, SQLiteDatabase.CONFLICT_IGNORE);

                    ContentValues state = new ContentValues();
                    state.put("card_id", cardId);
                    state.put("box", 1);
                    state.put("due_at", Long.MAX_VALUE);
                    state.put("lapses", 0);
                    state.putNull("last_reviewed_at");
                    state.put("ease_hint", LeitnerScheduler.DEFAULT_EASE);
                    db.insertWithOnConflict("review_states", null, state, SQLiteDatabase.CONFLICT_IGNORE);
                }
            }
            ContentValues deckValues = new ContentValues();
            deckValues.put("id", deck.getString("id"));
            deckValues.put("name", deck.getString("name"));
            deckValues.put("description", deck.optString("description", ""));
            deckValues.put("is_starter", deck.optBoolean("isStarter", false) ? 1 : 0);
            deckValues.put("word_ids_json", wordIds.toString());
            deckValues.put("created_at", now);
            db.insertWithOnConflict("decks", null, deckValues, SQLiteDatabase.CONFLICT_REPLACE);
        }
    }

    private void insertSeedWord(SQLiteDatabase db, JSONObject seed, String wordId, long now) throws Exception {
        ContentValues values = new ContentValues();
        values.put("id", wordId);
        values.put("term", seed.getString("term"));
        values.put("language_code", seed.optString("languageCode", "ms"));
        values.put("chinese_meaning", seed.optString("chineseMeaning", ""));
        values.put("part_of_speech", seed.optString("partOfSpeech", ""));
        values.put("pronunciation_notes", seed.optString("pronunciationNotes", ""));
        values.put("syllables_json", seed.optJSONArray("syllables") == null ? "[]" : seed.getJSONArray("syllables").toString());
        values.put("examples_json", seed.optJSONArray("examples") == null ? "[]" : seed.getJSONArray("examples").toString());
        values.put("source_refs_json", seed.optJSONArray("sourceRefs") == null ? "[]" : seed.getJSONArray("sourceRefs").toString());
        values.put("review_status", "reviewed");
        values.put("learning_status", LearningStatus.NEW.raw);
        values.putNull("learned_at");
        values.put("created_at", now);
        values.put("updated_at", now);
        db.insertWithOnConflict("words", null, values, SQLiteDatabase.CONFLICT_IGNORE);
    }

    TodaySummary todaySummary(int dailyLimit, long now) {
        List<WordRecord> words = allWords();
        Map<String, WordRecord> wordsById = byWordId(words);
        Map<String, CardRecord> cardsById = byCardId(allCards());
        List<ReviewState> states = allStates();
        TodaySummary summary = new TodaySummary();
        long start = startOfDay(now);
        long end = start + 24L * 60L * 60L * 1000L;
        int safeDailyLimit = Math.max(0, dailyLimit);
        long nextDue = Long.MAX_VALUE;
        for (WordRecord word : words) {
            if (word.learnedAt != null && word.learnedAt >= start && word.learnedAt < end) summary.learnedTodayCount++;
            if (LearningStatus.fromWord(word) == LearningStatus.NEW) summary.newWordCount++;
        }
        for (ReviewState state : states) {
            CardRecord card = cardsById.get(state.cardId);
            WordRecord word = card == null ? null : wordsById.get(card.wordId);
            if (word == null || LearningStatus.fromWord(word) == LearningStatus.NEW) continue;
            if (state.dueAt <= now) summary.dueReviewCount++;
            if (state.dueAt > now && state.dueAt < nextDue) nextDue = state.dueAt;
        }
        summary.remainingNewWordSlots = Math.max(0, safeDailyLimit - summary.learnedTodayCount);
        summary.nextDueAt = nextDue == Long.MAX_VALUE ? null : nextDue;
        return summary;
    }

    LearnPlan learnPlan(String selectedDeckId, int dailyLimit, long now) {
        LearnPlan plan = new LearnPlan();
        plan.dailyLimit = Math.max(0, dailyLimit);
        TodaySummary summary = todaySummary(plan.dailyLimit, now);
        plan.learnedTodayCount = summary.learnedTodayCount;
        plan.remainingNewWordSlots = summary.remainingNewWordSlots;
        for (LibrarySection section : sections()) {
            if (selectedDeckId != null && !selectedDeckId.equals(section.id)) continue;
            for (WordRecord word : section.words) {
                if (plan.words.size() >= plan.remainingNewWordSlots) return plan;
                if (LearningStatus.fromWord(word) == LearningStatus.NEW) plan.words.add(word);
            }
        }
        return plan;
    }

    void markLearned(String wordId, long now) {
        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            ContentValues word = new ContentValues();
            word.put("learning_status", LearningStatus.IN_REVIEW.raw);
            word.put("learned_at", now);
            word.put("updated_at", now);
            db.update("words", word, "id=?", new String[]{wordId});
            Cursor cursor = db.query("cards", new String[]{"id"}, "word_id=?", new String[]{wordId}, null, null, null);
            try {
                while (cursor.moveToNext()) {
                    ContentValues state = new ContentValues();
                    state.put("box", 1);
                    state.put("due_at", now + LeitnerScheduler.RELEARN_INTERVAL_MS);
                    state.put("lapses", 0);
                    state.putNull("last_reviewed_at");
                    state.put("ease_hint", LeitnerScheduler.DEFAULT_EASE);
                    db.update("review_states", state, "card_id=?", new String[]{cursor.getString(0)});
                }
            } finally {
                cursor.close();
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    List<DueReviewItem> dueCards(long now, int limit) {
        List<DueReviewItem> out = new ArrayList<>();
        if (limit <= 0) return out;
        SQLiteDatabase db = getReadableDatabase();
        String sql = "SELECT w.*, c.id AS card_id, c.word_id, c.direction, c.prompt, c.answer, c.hint, c.created_at AS card_created_at, s.box, s.due_at, s.lapses, s.last_reviewed_at, s.ease_hint " +
                "FROM review_states s JOIN cards c ON c.id=s.card_id JOIN words w ON w.id=c.word_id " +
                "WHERE s.due_at<=? AND (w.learning_status IN ('inReview','mastered') OR (w.learning_status IS NULL AND w.review_status!='reviewed')) ORDER BY s.due_at ASC, c.id ASC LIMIT ?";
        Cursor cursor = db.rawQuery(sql, new String[]{String.valueOf(now), String.valueOf(limit)});
        try {
            while (cursor.moveToNext()) {
                DueReviewItem item = new DueReviewItem();
                item.word = wordFromCursor(cursor);
                item.card = cardFromJoinedCursor(cursor);
                item.state = stateFromJoinedCursor(cursor);
                out.add(item);
            }
        } finally {
            cursor.close();
        }
        return out;
    }

    ReviewUpdate applyRating(String cardId, ReviewRating rating, long now) {
        SQLiteDatabase db = getWritableDatabase();
        ReviewState state = stateForCard(cardId);
        ReviewUpdate update = scheduler.update(state, rating, now);
        db.beginTransaction();
        try {
            ContentValues values = new ContentValues();
            values.put("box", update.nextBox);
            values.put("due_at", update.nextDueAt);
            values.put("lapses", update.lapses);
            values.put("last_reviewed_at", update.reviewedAt);
            values.put("ease_hint", update.easeHint);
            db.update("review_states", values, "card_id=?", new String[]{cardId});
            ContentValues log = new ContentValues();
            log.put("id", java.util.UUID.randomUUID().toString());
            log.put("card_id", cardId);
            log.put("rating", rating.raw);
            log.put("reviewed_at", update.reviewedAt);
            log.put("previous_box", update.previousBox);
            log.put("next_box", update.nextBox);
            log.put("previous_due_at", update.previousDueAt);
            log.put("next_due_at", update.nextDueAt);
            db.insert("review_logs", null, log);
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
        return update;
    }

    LibraryBrowseResult browseLibrary(String selectedDeckId, String searchText, String statusFilter, String sort, int visibleLimit) {
        String normalized = searchText == null ? "" : searchText.trim().toLowerCase(Locale.ROOT);
        List<LibrarySection> matched = new ArrayList<>();
        int total = 0;
        for (LibrarySection section : sections()) {
            if (selectedDeckId != null && !selectedDeckId.equals(section.id)) continue;
            LibrarySection copy = copySectionHeader(section);
            for (WordRecord word : section.words) {
                if (!matchesSearch(word, normalized)) continue;
                if (!matchesStatus(word, statusFilter)) continue;
                copy.words.add(word);
            }
            sortWords(copy.words, sort);
            if (!copy.words.isEmpty()) {
                total += copy.words.size();
                matched.add(copy);
            }
        }
        LibraryBrowseResult result = new LibraryBrowseResult();
        result.totalMatches = total;
        int remaining = Math.max(0, visibleLimit);
        for (LibrarySection section : matched) {
            if (remaining <= 0) break;
            LibrarySection visible = copySectionHeader(section);
            int count = Math.min(remaining, section.words.size());
            visible.words.addAll(section.words.subList(0, count));
            remaining -= count;
            result.visibleCount += count;
            result.sections.add(visible);
        }
        result.hasMore = result.visibleCount < result.totalMatches;
        return result;
    }

    String addWord(String term, String userMeaning, String note, AIEnrichment enrichment, String reviewStatus, long now) throws Exception {
        String trimmedTerm = term == null ? "" : term.trim();
        if (trimmedTerm.isEmpty()) throw new IllegalArgumentException("Malay word is required.");
        if (enrichment == null) enrichment = template(trimmedTerm, userMeaning, note, now);
        String safeReviewStatus = reviewStatus == null || reviewStatus.trim().isEmpty() ? "needsEnrichment" : reviewStatus;
        if (enrichment.chineseMeaning == null || enrichment.chineseMeaning.trim().isEmpty()) enrichment.chineseMeaning = trimmedTerm;
        if (enrichment.partOfSpeech == null) enrichment.partOfSpeech = "unknown";
        if (enrichment.pronunciationNotes == null) enrichment.pronunciationNotes = "";
        if (enrichment.syllables == null || enrichment.syllables.isEmpty()) {
            enrichment.syllables = new ArrayList<>();
            enrichment.syllables.add(trimmedTerm);
        }
        String wordId = java.util.UUID.randomUUID().toString();
        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            ContentValues word = new ContentValues();
            word.put("id", wordId);
            word.put("term", trimmedTerm);
            word.put("language_code", "ms-MY");
            word.put("chinese_meaning", enrichment.chineseMeaning);
            word.put("part_of_speech", enrichment.partOfSpeech);
            word.put("pronunciation_notes", enrichment.pronunciationNotes);
            word.put("syllables_json", new JSONArray(enrichment.syllables).toString());
            word.put("examples_json", enrichment.examplesJson == null ? "[]" : enrichment.examplesJson);
            word.put("source_refs_json", userSourceRef(safeReviewStatus, now).toString());
            word.put("review_status", safeReviewStatus);
            word.put("learning_status", LearningStatus.IN_REVIEW.raw);
            word.putNull("learned_at");
            word.put("created_at", now);
            word.put("updated_at", now);
            db.insertOrThrow("words", null, word);
            insertPersonalCard(db, wordId, CardDirection.MALAY_TO_CHINESE, trimmedTerm, enrichment.chineseMeaning, enrichment.partOfSpeech, now);
            insertPersonalCard(db, wordId, CardDirection.CHINESE_TO_MALAY, enrichment.chineseMeaning, trimmedTerm, enrichment.partOfSpeech, now);
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
        return wordId;
    }

    AIEnrichment template(String term, String userMeaning, String note, long now) throws Exception {
        AIEnrichment enrichment = new AIEnrichment();
        String meaning = userMeaning == null ? "" : userMeaning.trim();
        enrichment.chineseMeaning = meaning.isEmpty() ? term : meaning;
        enrichment.partOfSpeech = "unknown";
        String[] parts = term.contains("-") ? term.split("-") : new String[]{term};
        for (String part : parts) enrichment.syllables.add(part);
        enrichment.pronunciationNotes = String.join("-", enrichment.syllables);
        JSONArray examples = new JSONArray();
        JSONObject example = new JSONObject();
        example.put("id", "template-" + term + "-example-1");
        example.put("malay", "Saya belajar perkataan " + term + ".");
        example.put("chinese", "我学习单词 " + term + "。");
        example.put("sourceRefs", templateSourceRef(now));
        examples.put(example);
        enrichment.examplesJson = examples.toString();
        enrichment.practicePrompts.add("看到 " + term + " 时，先回忆中文意思。");
        return enrichment;
    }

    List<DeckRecord> decks() {
        List<DeckRecord> out = new ArrayList<>();
        Cursor c = getReadableDatabase().query("decks", null, null, null, null, null, "name ASC");
        try {
            while (c.moveToNext()) out.add(deckFromCursor(c));
        } finally {
            c.close();
        }
        return out;
    }

    List<LibrarySection> sections() {
        List<WordRecord> words = allWords();
        Map<String, WordRecord> wordsById = byWordId(words);
        Set<String> assigned = new HashSet<>();
        List<LibrarySection> sections = new ArrayList<>();
        for (DeckRecord deck : decks()) {
            LibrarySection section = new LibrarySection();
            section.id = deck.id;
            section.name = deck.name;
            section.description = deck.description;
            section.starter = deck.starter;
            try {
                JSONArray ids = new JSONArray(deck.wordIdsJson);
                for (int i = 0; i < ids.length(); i++) {
                    String wordId = ids.getString(i);
                    WordRecord word = wordsById.get(wordId);
                    if (word != null) {
                        section.words.add(word);
                        assigned.add(wordId);
                    }
                }
            } catch (Exception ignored) {
            }
            sections.add(section);
        }
        LibrarySection personal = new LibrarySection();
        personal.id = "personal-words";
        personal.name = "Personal Words";
        personal.description = "Words you added yourself.";
        personal.starter = false;
        for (WordRecord word : words) {
            if (!assigned.contains(word.id)) personal.words.add(word);
        }
        personal.words.sort((a, b) -> {
            int created = Long.compare(a.createdAt, b.createdAt);
            if (created != 0) return created;
            return a.term.compareToIgnoreCase(b.term);
        });
        if (!personal.words.isEmpty()) sections.add(personal);
        return sections;
    }

    List<WordRecord> allWords() {
        List<WordRecord> out = new ArrayList<>();
        Cursor c = getReadableDatabase().query("words", null, null, null, null, null, "term ASC");
        try {
            while (c.moveToNext()) out.add(wordFromCursor(c));
        } finally {
            c.close();
        }
        return out;
    }

    private void insertPersonalCard(SQLiteDatabase db, String wordId, CardDirection direction, String prompt, String answer, String hint, long now) {
        String cardId = java.util.UUID.randomUUID().toString();
        ContentValues card = new ContentValues();
        card.put("id", cardId);
        card.put("word_id", wordId);
        card.put("direction", direction.raw);
        card.put("prompt", prompt);
        card.put("answer", answer);
        card.put("hint", hint);
        card.put("created_at", now);
        db.insertOrThrow("cards", null, card);
        ReviewState initial = scheduler.initialState(cardId, now);
        ContentValues state = new ContentValues();
        state.put("card_id", cardId);
        state.put("box", initial.box);
        state.put("due_at", initial.dueAt);
        state.put("lapses", initial.lapses);
        state.putNull("last_reviewed_at");
        state.put("ease_hint", initial.easeHint);
        db.insertOrThrow("review_states", null, state);
    }

    private JSONArray userSourceRef(String reviewStatus, long now) throws Exception {
        JSONArray refs = new JSONArray();
        JSONObject ref = new JSONObject();
        ref.put("field", "term");
        ref.put("sourceName", "User input");
        ref.put("sourceUrl", "local://user-input");
        ref.put("license", "personal-use-local");
        ref.put("attribution", "User-added word");
        ref.put("retrievedAt", java.time.Instant.ofEpochMilli(now).toString());
        ref.put("reviewStatus", reviewStatus);
        refs.put(ref);
        return refs;
    }

    private JSONArray templateSourceRef(long now) throws Exception {
        JSONArray refs = new JSONArray();
        JSONObject ref = new JSONObject();
        ref.put("field", "examples");
        ref.put("sourceName", "MalayMate template fallback");
        ref.put("sourceUrl", "local://template-fallback");
        ref.put("license", "generated-template");
        ref.put("attribution", "MalayMate local template fallback");
        ref.put("retrievedAt", java.time.Instant.ofEpochMilli(now).toString());
        refs.put(ref);
        return refs;
    }

    private boolean matchesSearch(WordRecord word, String query) {
        if (query.isEmpty()) return true;
        return word.term.toLowerCase(Locale.ROOT).contains(query)
                || word.chineseMeaning.toLowerCase(Locale.ROOT).contains(query)
                || word.partOfSpeech.toLowerCase(Locale.ROOT).contains(query)
                || word.pronunciationNotes.toLowerCase(Locale.ROOT).contains(query);
    }

    private boolean matchesStatus(WordRecord word, String filter) {
        if (filter == null || "all".equals(filter)) return true;
        return LearningStatus.fromWord(word).raw.equals(filter);
    }

    private void sortWords(List<WordRecord> words, String sort) {
        if ("term".equals(sort)) {
            words.sort((a, b) -> a.term.compareToIgnoreCase(b.term));
        } else if ("status".equals(sort)) {
            words.sort((a, b) -> {
                int status = Integer.compare(statusRank(LearningStatus.fromWord(a)), statusRank(LearningStatus.fromWord(b)));
                if (status != 0) return status;
                return a.term.compareToIgnoreCase(b.term);
            });
        } else if ("createdNewest".equals(sort)) {
            words.sort((a, b) -> {
                int created = Long.compare(b.createdAt, a.createdAt);
                if (created != 0) return created;
                return a.term.compareToIgnoreCase(b.term);
            });
        }
    }

    private int statusRank(LearningStatus status) {
        if (status == LearningStatus.NEW) return 0;
        if (status == LearningStatus.IN_REVIEW) return 1;
        return 2;
    }

    private LibrarySection copySectionHeader(LibrarySection section) {
        LibrarySection copy = new LibrarySection();
        copy.id = section.id;
        copy.name = section.name;
        copy.description = section.description;
        copy.starter = section.starter;
        return copy;
    }

    private List<CardRecord> allCards() {
        List<CardRecord> out = new ArrayList<>();
        Cursor c = getReadableDatabase().query("cards", null, null, null, null, null, null);
        try {
            while (c.moveToNext()) out.add(cardFromCursor(c));
        } finally {
            c.close();
        }
        return out;
    }

    private List<ReviewState> allStates() {
        List<ReviewState> out = new ArrayList<>();
        Cursor c = getReadableDatabase().query("review_states", null, null, null, null, null, null);
        try {
            while (c.moveToNext()) out.add(stateFromCursor(c));
        } finally {
            c.close();
        }
        return out;
    }

    private ReviewState stateForCard(String cardId) {
        Cursor c = getReadableDatabase().query("review_states", null, "card_id=?", new String[]{cardId}, null, null, null);
        try {
            if (!c.moveToFirst()) throw new IllegalArgumentException("Missing review state: " + cardId);
            return stateFromCursor(c);
        } finally {
            c.close();
        }
    }

    private Map<String, WordRecord> byWordId(List<WordRecord> words) {
        Map<String, WordRecord> map = new LinkedHashMap<>();
        for (WordRecord word : words) map.put(word.id, word);
        return map;
    }

    private Map<String, CardRecord> byCardId(List<CardRecord> cards) {
        Map<String, CardRecord> map = new HashMap<>();
        for (CardRecord card : cards) map.put(card.id, card);
        return map;
    }

    private DeckRecord deckFromCursor(Cursor c) {
        DeckRecord deck = new DeckRecord();
        deck.id = s(c, "id");
        deck.name = s(c, "name");
        deck.description = s(c, "description");
        deck.starter = i(c, "is_starter") == 1;
        deck.wordIdsJson = s(c, "word_ids_json");
        return deck;
    }

    private WordRecord wordFromCursor(Cursor c) {
        WordRecord word = new WordRecord();
        word.id = s(c, "id");
        word.term = s(c, "term");
        word.languageCode = s(c, "language_code");
        word.chineseMeaning = s(c, "chinese_meaning");
        word.partOfSpeech = s(c, "part_of_speech");
        word.pronunciationNotes = s(c, "pronunciation_notes");
        word.syllablesJson = s(c, "syllables_json");
        word.examplesJson = s(c, "examples_json");
        word.sourceRefsJson = s(c, "source_refs_json");
        word.reviewStatus = s(c, "review_status");
        word.learningStatus = nullableString(c, "learning_status");
        word.learnedAt = nullableLong(c, "learned_at");
        word.createdAt = l(c, "created_at");
        word.updatedAt = l(c, "updated_at");
        return word;
    }

    private CardRecord cardFromCursor(Cursor c) {
        CardRecord card = new CardRecord();
        card.id = s(c, "id");
        card.wordId = s(c, "word_id");
        card.direction = s(c, "direction");
        card.prompt = s(c, "prompt");
        card.answer = s(c, "answer");
        card.hint = s(c, "hint");
        card.createdAt = l(c, "created_at");
        return card;
    }

    private CardRecord cardFromJoinedCursor(Cursor c) {
        CardRecord card = new CardRecord();
        card.id = s(c, "card_id");
        card.wordId = s(c, "word_id");
        card.direction = s(c, "direction");
        card.prompt = s(c, "prompt");
        card.answer = s(c, "answer");
        card.hint = s(c, "hint");
        card.createdAt = l(c, "card_created_at");
        return card;
    }

    private ReviewState stateFromCursor(Cursor c) {
        return new ReviewState(s(c, "card_id"), i(c, "box"), l(c, "due_at"), i(c, "lapses"), nullableLong(c, "last_reviewed_at"), d(c, "ease_hint"));
    }

    private ReviewState stateFromJoinedCursor(Cursor c) {
        return new ReviewState(s(c, "card_id"), i(c, "box"), l(c, "due_at"), i(c, "lapses"), nullableLong(c, "last_reviewed_at"), d(c, "ease_hint"));
    }

    private long count(SQLiteDatabase db, String table) {
        Cursor c = db.rawQuery("SELECT COUNT(*) FROM " + table, null);
        try {
            c.moveToFirst();
            return c.getLong(0);
        } finally {
            c.close();
        }
    }

    private boolean exists(SQLiteDatabase db, String table, String id) {
        Cursor c = db.query(table, new String[]{"id"}, "id=?", new String[]{id}, null, null, null);
        try {
            return c.moveToFirst();
        } finally {
            c.close();
        }
    }

    private String readAsset(String assetName) throws Exception {
        InputStream input = context.getAssets().open(assetName);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int read;
        while ((read = input.read(buffer)) != -1) output.write(buffer, 0, read);
        input.close();
        return output.toString(StandardCharsets.UTF_8.name());
    }

    private static long startOfDay(long now) {
        Calendar calendar = Calendar.getInstance();
        calendar.setTimeInMillis(now);
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        return calendar.getTimeInMillis();
    }

    private static String s(Cursor c, String column) { return c.getString(c.getColumnIndexOrThrow(column)); }
    private static int i(Cursor c, String column) { return c.getInt(c.getColumnIndexOrThrow(column)); }
    private static long l(Cursor c, String column) { return c.getLong(c.getColumnIndexOrThrow(column)); }
    private static double d(Cursor c, String column) { return c.getDouble(c.getColumnIndexOrThrow(column)); }
    private static String nullableString(Cursor c, String column) {
        int index = c.getColumnIndexOrThrow(column);
        return c.isNull(index) ? null : c.getString(index);
    }
    private static Long nullableLong(Cursor c, String column) {
        int index = c.getColumnIndexOrThrow(column);
        return c.isNull(index) ? null : c.getLong(index);
    }
}
