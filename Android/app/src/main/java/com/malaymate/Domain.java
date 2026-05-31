package com.malaymate;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

enum ReviewRating {
    AGAIN("again"),
    GOOD("good"),
    EASY("easy");

    final String raw;

    ReviewRating(String raw) {
        this.raw = raw;
    }

    static ReviewRating fromRaw(String raw) {
        for (ReviewRating rating : values()) {
            if (rating.raw.equals(raw)) return rating;
        }
        return GOOD;
    }
}

enum CardDirection {
    MALAY_TO_CHINESE("malayToChinese"),
    CHINESE_TO_MALAY("chineseToMalay");

    final String raw;

    CardDirection(String raw) {
        this.raw = raw;
    }

    static CardDirection fromRaw(String raw) {
        if (CHINESE_TO_MALAY.raw.equals(raw)) return CHINESE_TO_MALAY;
        return MALAY_TO_CHINESE;
    }
}

enum LearningStatus {
    NEW("new"),
    IN_REVIEW("inReview"),
    MASTERED("mastered");

    final String raw;

    LearningStatus(String raw) {
        this.raw = raw;
    }

    static LearningStatus fromWord(WordRecord word) {
        if (word.learningStatus != null && !word.learningStatus.isEmpty()) {
            for (LearningStatus status : values()) {
                if (status.raw.equals(word.learningStatus)) return status;
            }
        }
        if ("reviewed".equals(word.reviewStatus)) return NEW;
        return IN_REVIEW;
    }
}

enum AppScreen {
    TODAY("Today"),
    LEARN("Learn"),
    REVIEW("Review"),
    LIBRARY("Library"),
    ADD_WORD("Add Word"),
    SETTINGS("Settings");

    final String title;

    AppScreen(String title) {
        this.title = title;
    }
}

class MobileNavItem {
    final AppScreen screen;
    final String label;
    final boolean selected;

    MobileNavItem(AppScreen screen, String label, boolean selected) {
        this.screen = screen;
        this.label = label;
        this.selected = selected;
    }
}

class MobileNavigation {
    static List<MobileNavItem> bottomItems(AppScreen current) {
        List<MobileNavItem> items = new ArrayList<>();
        items.add(new MobileNavItem(AppScreen.TODAY, "Today", current == AppScreen.TODAY));
        items.add(new MobileNavItem(AppScreen.LEARN, "Learn", current == AppScreen.LEARN));
        items.add(new MobileNavItem(AppScreen.REVIEW, "Review", current == AppScreen.REVIEW));
        items.add(new MobileNavItem(AppScreen.LIBRARY, "Library", current == AppScreen.LIBRARY));
        items.add(new MobileNavItem(null, "More", current == AppScreen.ADD_WORD || current == AppScreen.SETTINGS));
        return items;
    }

    static List<MobileNavItem> moreItems() {
        List<MobileNavItem> items = new ArrayList<>();
        items.add(new MobileNavItem(AppScreen.ADD_WORD, "Add Word", false));
        items.add(new MobileNavItem(AppScreen.SETTINGS, "Settings", false));
        return items;
    }
}

class LibraryUiOption {
    final String value;
    final String label;

    LibraryUiOption(String value, String label) {
        this.value = value;
        this.label = label;
    }
}

class LibraryUiOptions {
    static List<LibraryUiOption> statusFilters() {
        List<LibraryUiOption> options = new ArrayList<>();
        options.add(new LibraryUiOption("all", "全部"));
        options.add(new LibraryUiOption("new", "新词"));
        options.add(new LibraryUiOption("inReview", "复习中"));
        options.add(new LibraryUiOption("mastered", "已掌握"));
        return options;
    }

    static List<LibraryUiOption> sorts() {
        List<LibraryUiOption> options = new ArrayList<>();
        options.add(new LibraryUiOption("deckOrder", "词库顺序"));
        options.add(new LibraryUiOption("term", "字母"));
        options.add(new LibraryUiOption("status", "状态"));
        options.add(new LibraryUiOption("createdNewest", "新添加"));
        return options;
    }

    static String labelForValue(List<LibraryUiOption> options, String value) {
        for (LibraryUiOption option : options) {
            if (option.value.equals(value)) return option.label;
        }
        return options.isEmpty() ? "" : options.get(0).label;
    }
}

class ReviewState {
    final String cardId;
    final int box;
    final long dueAt;
    final int lapses;
    final Long lastReviewedAt;
    final double easeHint;

    ReviewState(String cardId, int box, long dueAt, int lapses, Long lastReviewedAt, double easeHint) {
        this.cardId = cardId;
        this.box = box;
        this.dueAt = dueAt;
        this.lapses = lapses;
        this.lastReviewedAt = lastReviewedAt;
        this.easeHint = easeHint;
    }
}

class ReviewUpdate {
    final ReviewRating rating;
    final long reviewedAt;
    final int previousBox;
    final int nextBox;
    final long previousDueAt;
    final long nextDueAt;
    final int lapses;
    final double easeHint;

    ReviewUpdate(ReviewRating rating, long reviewedAt, int previousBox, int nextBox, long previousDueAt, long nextDueAt, int lapses, double easeHint) {
        this.rating = rating;
        this.reviewedAt = reviewedAt;
        this.previousBox = previousBox;
        this.nextBox = nextBox;
        this.previousDueAt = previousDueAt;
        this.nextDueAt = nextDueAt;
        this.lapses = lapses;
        this.easeHint = easeHint;
    }
}

class LeitnerScheduler {
    static final int MAXIMUM_BOX = 10;
    static final double DEFAULT_EASE = 2.5;
    static final double MINIMUM_EASE = 1.3;
    static final long RELEARN_INTERVAL_MS = 10 * 60 * 1000L;
    static final long MAXIMUM_INTERVAL_MS = 365L * 24L * 60L * 60L * 1000L;

    ReviewState initialState(String cardId, long now) {
        return new ReviewState(cardId, 1, now, 0, null, DEFAULT_EASE);
    }

    ReviewUpdate update(ReviewState snapshot, ReviewRating rating, long now) {
        int currentBox = Math.min(MAXIMUM_BOX, Math.max(1, snapshot.box));
        double currentEase = Math.max(MINIMUM_EASE, snapshot.easeHint > 0 ? snapshot.easeHint : DEFAULT_EASE);
        int nextBox;
        int lapses;
        double easeHint;
        long interval;

        switch (rating) {
            case AGAIN:
                nextBox = 1;
                lapses = snapshot.lapses + 1;
                easeHint = Math.max(MINIMUM_EASE, currentEase - 0.20);
                interval = RELEARN_INTERVAL_MS;
                break;
            case EASY:
                nextBox = Math.min(MAXIMUM_BOX, currentBox + 2);
                lapses = snapshot.lapses;
                easeHint = Math.min(3.0, currentEase + 0.15);
                interval = intervalForStage(nextBox, easeHint, rating);
                break;
            case GOOD:
            default:
                nextBox = Math.min(MAXIMUM_BOX, currentBox + 1);
                lapses = snapshot.lapses;
                easeHint = currentEase;
                interval = intervalForStage(nextBox, easeHint, rating);
                break;
        }

        return new ReviewUpdate(rating, now, snapshot.box, nextBox, snapshot.dueAt, now + interval, lapses, easeHint);
    }

    private long intervalForStage(int stage, double ease, ReviewRating rating) {
        double days;
        if (stage <= 1) return RELEARN_INTERVAL_MS;
        if (stage == 2) {
            days = 1;
        } else if (stage == 3) {
            days = 6;
        } else {
            days = 6 * Math.pow(ease, stage - 3);
        }
        double multiplier = rating == ReviewRating.EASY ? 1.3 : 1.0;
        return Math.min(MAXIMUM_INTERVAL_MS, Math.round(days * multiplier * 24d * 60d * 60d * 1000d));
    }
}

enum SpellingResult {
    CORRECT,
    CLOSE,
    INCORRECT
}

class SpellingEvaluation {
    final SpellingResult result;
    final String normalizedAnswer;
    final String normalizedExpected;
    final int distance;

    SpellingEvaluation(SpellingResult result, String normalizedAnswer, String normalizedExpected, int distance) {
        this.result = result;
        this.normalizedAnswer = normalizedAnswer;
        this.normalizedExpected = normalizedExpected;
        this.distance = distance;
    }
}

class SpellingEvaluator {
    static SpellingEvaluation evaluate(String answer, String expected) {
        String normalizedAnswer = normalize(answer);
        String normalizedExpected = normalize(expected);
        int distance = editDistance(normalizedAnswer, normalizedExpected);
        SpellingResult result;
        if (normalizedAnswer.equals(normalizedExpected)) {
            result = SpellingResult.CORRECT;
        } else if (!normalizedAnswer.isEmpty() && distance <= closeMatchThreshold(normalizedExpected)) {
            result = SpellingResult.CLOSE;
        } else {
            result = SpellingResult.INCORRECT;
        }
        return new SpellingEvaluation(result, normalizedAnswer, normalizedExpected, distance);
    }

    static String normalize(String value) {
        String folded = Normalizer.normalize(value == null ? "" : value, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .toLowerCase(Locale.forLanguageTag("ms-MY"));
        StringBuilder builder = new StringBuilder();
        boolean lastWasSpace = true;
        for (int i = 0; i < folded.length(); i++) {
            char ch = folded.charAt(i);
            if (Character.isLetterOrDigit(ch)) {
                builder.append(ch);
                lastWasSpace = false;
            } else if (Character.isWhitespace(ch) && !lastWasSpace) {
                builder.append(' ');
                lastWasSpace = true;
            }
        }
        int length = builder.length();
        while (length > 0 && builder.charAt(length - 1) == ' ') {
            builder.deleteCharAt(length - 1);
            length--;
        }
        return builder.toString();
    }

    private static int closeMatchThreshold(String expected) {
        return expected.length() <= 5 ? 1 : 2;
    }

    private static int editDistance(String left, String right) {
        if (left.isEmpty()) return right.length();
        if (right.isEmpty()) return left.length();
        int[] previous = new int[right.length() + 1];
        int[] current = new int[right.length() + 1];
        for (int j = 0; j <= right.length(); j++) previous[j] = j;
        for (int i = 1; i <= left.length(); i++) {
            current[0] = i;
            for (int j = 1; j <= right.length(); j++) {
                if (left.charAt(i - 1) == right.charAt(j - 1)) {
                    current[j] = previous[j - 1];
                } else {
                    current[j] = Math.min(Math.min(previous[j] + 1, current[j - 1] + 1), previous[j - 1] + 1);
                }
            }
            int[] swap = previous;
            previous = current;
            current = swap;
        }
        return previous[right.length()];
    }
}

class SeedImportSummary {
    final int decks;
    final int words;
    final int cards;

    SeedImportSummary(int decks, int words, int cards) {
        this.decks = decks;
        this.words = words;
        this.cards = cards;
    }
}

class SeedImporter {
    SeedImportSummary parseDeckJson(String json) throws JSONException {
        JSONObject root = new JSONObject(json);
        JSONArray decks = root.getJSONArray("decks");
        int words = 0;
        for (int i = 0; i < decks.length(); i++) {
            words += decks.getJSONObject(i).getJSONArray("words").length();
        }
        return new SeedImportSummary(decks.length(), words, words * 2);
    }

    static String stableUuid(String value) {
        long hash = 0xcbf29ce484222325L;
        byte[] bytes = value.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        for (byte b : bytes) {
            hash ^= (b & 0xff);
            hash *= 0x100000001b3L;
        }
        String raw = String.format(Locale.US, "%016x", hash);
        return "00000000-0000-4000-8000-" + raw.substring(raw.length() - 12);
    }
}

class DeckRecord {
    String id;
    String name;
    String description;
    boolean starter;
    String wordIdsJson;
}

class WordRecord {
    String id;
    String term;
    String languageCode;
    String chineseMeaning;
    String partOfSpeech;
    String pronunciationNotes;
    String syllablesJson;
    String examplesJson;
    String sourceRefsJson;
    String reviewStatus;
    String learningStatus;
    Long learnedAt;
    long createdAt;
    long updatedAt;
}

class CardRecord {
    String id;
    String wordId;
    String direction;
    String prompt;
    String answer;
    String hint;
    long createdAt;
}

class DueReviewItem {
    WordRecord word;
    CardRecord card;
    ReviewState state;
}

class ReviewQueue {
    static boolean removeCard(List<DueReviewItem> items, String cardId) {
        if (items == null || cardId == null) return false;
        for (int i = 0; i < items.size(); i++) {
            DueReviewItem item = items.get(i);
            if (item != null && item.card != null && cardId.equals(item.card.id)) {
                items.remove(i);
                return true;
            }
        }
        return false;
    }
}

enum RefreshSurface {
    TODAY,
    LEARN,
    REVIEW,
    LIBRARY,
    ADD_WORD,
    SETTINGS
}

enum AutoRefreshAction {
    NONE,
    RENDER_SCREEN,
    LOAD_REVIEWS
}

class AutoRefreshPolicy {
    static AutoRefreshAction actionFor(RefreshSurface surface, boolean reviewLoaded, boolean reviewLoading, int dueItemCount) {
        if (surface == RefreshSurface.TODAY || surface == RefreshSurface.LEARN) {
            return AutoRefreshAction.RENDER_SCREEN;
        }
        if (surface == RefreshSurface.REVIEW && reviewLoaded && !reviewLoading && dueItemCount == 0) {
            return AutoRefreshAction.LOAD_REVIEWS;
        }
        return AutoRefreshAction.NONE;
    }
}

class LoadGate {
    private String requestKey;

    boolean shouldStart(Object data, boolean loading, String error, String key) {
        if (data != null || loading) return false;
        return error == null || !sameKey(requestKey, key);
    }

    void start(String key) {
        requestKey = key;
    }

    void fail(String key, String error) {
        requestKey = key;
    }

    void clear() {
        requestKey = null;
    }

    private static boolean sameKey(String left, String right) {
        if (left == null) return right == null;
        return left.equals(right);
    }
}

class LearnPlan {
    int dailyLimit;
    int learnedTodayCount;
    int remainingNewWordSlots;
    final List<WordRecord> words = new ArrayList<>();
}

class TodaySummary {
    int dueReviewCount;
    int learnedTodayCount;
    int remainingNewWordSlots;
    int newWordCount;
    Long nextDueAt;
}

class LibrarySection {
    String id;
    String name;
    String description;
    boolean starter;
    final List<WordRecord> words = new ArrayList<>();
}

class LibraryBrowseResult {
    final List<LibrarySection> sections = new ArrayList<>();
    int totalMatches;
    int visibleCount;
    boolean hasMore;
}

class AIEnrichment {
    String chineseMeaning;
    String partOfSpeech;
    String pronunciationNotes;
    List<String> syllables = new ArrayList<>();
    String examplesJson;
    List<String> practicePrompts = new ArrayList<>();
}
