package com.malaymate;

import android.app.Activity;
import android.content.res.ColorStateList;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.TextToSpeech;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.DateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends Activity {
    private static final String ALL_DECKS_ID = "__all_decks__";
    private static final int PAGE_SIZE = 100;
    private static final long REFRESH_INTERVAL_MS = 60_000L;
    private static final int CANVAS = 0xFFF4F0E6;
    private static final int SURFACE = 0xFFFFFCF5;
    private static final int SURFACE_TINT = 0xFFEAF3EC;
    private static final int INK = 0xFF162825;
    private static final int MUTED = 0xFF66746E;
    private static final int LINE = 0xFFD8DDD6;
    private static final int JADE = 0xFF0D7E71;
    private static final int JADE_DARK = 0xFF075F56;
    private static final int SAFFRON = 0xFFC7851A;
    private static final int SAFFRON_SOFT = 0xFFFFE7B0;
    private static final int DISABLED = 0xFFADB7B2;
    private static final Typeface BODY_TYPEFACE = Typeface.create("sans-serif", Typeface.NORMAL);
    private static final Typeface BODY_MEDIUM_TYPEFACE = Typeface.create("sans-serif-medium", Typeface.NORMAL);
    private static final Typeface DISPLAY_TYPEFACE = Typeface.create(Typeface.SERIF, Typeface.BOLD);

    private MalayMateRepository repository;
    private MalayMateSettings settings;
    private OpenAIClient openAIClient;
    private ExecutorService executor;
    private Handler mainHandler;
    private LinearLayout root;
    private AppScreen currentScreen = AppScreen.TODAY;
    private boolean showMoreMenu;
    private final Runnable periodicRefreshRunnable = new Runnable() {
        @Override
        public void run() {
            if (importFinished) {
                handlePeriodicRefresh();
            }
            if (mainHandler != null) {
                mainHandler.postDelayed(this, REFRESH_INTERVAL_MS);
            }
        }
    };

    private boolean importFinished;
    private String importError;

    private TodaySummary todaySummary;
    private boolean todayLoading;
    private String todayError;
    private int todayDailyLimit = -1;
    private final LoadGate todayLoadGate = new LoadGate();

    private TextToSpeech tts;
    private boolean ttsReady;
    private boolean canSpeakMalay;
    private Locale ttsLocale;
    private String ttsStatus = "Malay TTS is starting.";

    private String learnSelectedDeckId;
    private final Set<String> skippedWordIds = new HashSet<>();
    private String learnStatus;
    private String lastAutoSpokenWordId;
    private LearnScreenData learnData;
    private boolean learnLoading;
    private String learnError;
    private String learnDataDeckId;
    private int learnDataDailyLimit = -1;
    private final LoadGate learnLoadGate = new LoadGate();

    private final List<DueReviewItem> dueItems = new ArrayList<>();
    private boolean reviewLoaded;
    private boolean reviewLoading;
    private boolean reviewSaving;
    private boolean answerRevealed;
    private String spellingAnswer = "";
    private SpellingEvaluation spellingEvaluation;
    private String reviewStatus;

    private String librarySelectedDeckId;
    private String librarySearchText = "";
    private String libraryStatusFilter = "all";
    private String librarySort = "deckOrder";
    private int libraryVisibleLimit = PAGE_SIZE;
    private final Set<String> expandedWordIds = new HashSet<>();
    private LibraryScreenData libraryData;
    private boolean libraryLoading;
    private String libraryError;
    private String libraryDataDeckId;
    private String libraryDataSearchText = "";
    private String libraryDataStatusFilter = "all";
    private String libraryDataSort = "deckOrder";
    private int libraryDataVisibleLimit = -1;
    private final LoadGate libraryLoadGate = new LoadGate();
    private Runnable pendingLibrarySearchRunnable;

    private String addTerm = "";
    private String addMeaning = "";
    private String addNote = "";
    private boolean addSaving;
    private String addStatus;

    private String settingsStatus;

    private interface Work<T> {
        T run() throws Exception;
    }

    private interface Done<T> {
        void accept(T value);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        repository = new MalayMateRepository(this);
        settings = new MalayMateSettings(this);
        openAIClient = new OpenAIClient();
        executor = Executors.newSingleThreadExecutor();
        mainHandler = new Handler(Looper.getMainLooper());

        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(CANVAS);
        setContentView(root);

        initializeTts();
        startPeriodicRefresh();
        renderLoading("Importing starter decks...");
        executor.execute(() -> {
            try {
                repository.ensureSeedImported();
                mainHandler.post(() -> {
                    importFinished = true;
                    importError = null;
                    invalidateAllData();
                    renderScreen();
                });
            } catch (Exception e) {
                mainHandler.post(() -> {
                    importFinished = false;
                    importError = message(e);
                    renderImportError();
                });
            }
        });
    }

    @Override
    protected void onDestroy() {
        if (mainHandler != null) {
            mainHandler.removeCallbacks(periodicRefreshRunnable);
        }
        if (tts != null) {
            tts.stop();
            tts.shutdown();
        }
        if (executor != null) {
            executor.shutdownNow();
        }
        super.onDestroy();
    }

    private void initializeTts() {
        tts = new TextToSpeech(this, status -> mainHandler.post(() -> {
            ttsReady = status == TextToSpeech.SUCCESS;
            canSpeakMalay = false;
            ttsLocale = null;
            if (!ttsReady || tts == null) {
                ttsStatus = "No Malay system voice available.";
                renderIfSettings();
                return;
            }

            Locale msMy = Locale.forLanguageTag("ms-MY");
            if (trySetLanguage(msMy)) {
                ttsLocale = msMy;
                canSpeakMalay = true;
            } else {
                Locale ms = Locale.forLanguageTag("ms");
                if (trySetLanguage(ms)) {
                    ttsLocale = ms;
                    canSpeakMalay = true;
                }
            }

            if (canSpeakMalay) {
                ttsStatus = "Malay voice available: " + ttsLocale.toLanguageTag();
            } else {
                ttsStatus = "No Malay system voice available.";
            }
            renderIfSettings();
        }));
    }

    private boolean trySetLanguage(Locale locale) {
        if (tts == null) return false;
        int result = tts.setLanguage(locale);
        return result != TextToSpeech.LANG_MISSING_DATA && result != TextToSpeech.LANG_NOT_SUPPORTED;
    }

    private void renderIfSettings() {
        if (importFinished && currentScreen == AppScreen.SETTINGS) renderScreen();
    }

    private void startPeriodicRefresh() {
        mainHandler.removeCallbacks(periodicRefreshRunnable);
        mainHandler.postDelayed(periodicRefreshRunnable, REFRESH_INTERVAL_MS);
    }

    private void handlePeriodicRefresh() {
        if (showMoreMenu) return;
        AutoRefreshAction action = AutoRefreshPolicy.actionFor(
                refreshSurface(currentScreen),
                reviewLoaded,
                reviewLoading,
                dueItems.size()
        );
        if (action == AutoRefreshAction.LOAD_REVIEWS) {
            loadReviewItems();
        } else if (action == AutoRefreshAction.RENDER_SCREEN) {
            if (currentScreen == AppScreen.TODAY) invalidateTodayData();
            if (currentScreen == AppScreen.LEARN) invalidateLearnData();
            renderScreen();
        }
    }

    private RefreshSurface refreshSurface(AppScreen screen) {
        switch (screen) {
            case TODAY:
                return RefreshSurface.TODAY;
            case LEARN:
                return RefreshSurface.LEARN;
            case REVIEW:
                return RefreshSurface.REVIEW;
            case LIBRARY:
                return RefreshSurface.LIBRARY;
            case ADD_WORD:
                return RefreshSurface.ADD_WORD;
            case SETTINGS:
            default:
                return RefreshSurface.SETTINGS;
        }
    }

    private void invalidateAllData() {
        invalidateTodayData();
        invalidateLearnData();
        invalidateLibraryData();
    }

    private void invalidateTodayData() {
        todaySummary = null;
        todayError = null;
        todayDailyLimit = -1;
        todayLoadGate.clear();
    }

    private void invalidateLearnData() {
        learnData = null;
        learnError = null;
        learnDataDeckId = null;
        learnDataDailyLimit = -1;
        learnLoadGate.clear();
    }

    private void invalidateLibraryData() {
        libraryData = null;
        libraryError = null;
        libraryDataDeckId = null;
        libraryDataSearchText = "";
        libraryDataStatusFilter = "all";
        libraryDataSort = "deckOrder";
        libraryDataVisibleLimit = -1;
        libraryLoadGate.clear();
    }

    private void renderScreen() {
        if (!importFinished) {
            if (importError != null) renderImportError();
            else renderLoading("Importing starter decks...");
            return;
        }
        root.removeAllViews();
        addAppHeader();

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(false);
        LinearLayout body = vertical();
        body.setPadding(dp(18), dp(10), dp(18), dp(28));
        scroll.addView(body, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        ));
        root.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
        ));

        try {
            if (showMoreMenu) {
                renderMore(body);
            } else {
                switch (currentScreen) {
                    case TODAY:
                        renderToday(body);
                        break;
                    case LEARN:
                        renderLearn(body);
                        break;
                    case REVIEW:
                        renderReview(body);
                        break;
                    case LIBRARY:
                        renderLibrary(body);
                        break;
                    case ADD_WORD:
                        renderAddWord(body);
                        break;
                    case SETTINGS:
                        renderSettings(body);
                        break;
                }
            }
        } catch (Exception e) {
            body.removeAllViews();
            body.addView(title("Something went wrong"));
            body.addView(paragraph(message(e)));
            TextView retry = button("Retry");
            retry.setOnClickListener(v -> renderScreen());
            body.addView(retry);
        }
        addBottomNavBar();
    }

    private void renderLoading(String text) {
        root.removeAllViews();
        LinearLayout body = vertical();
        body.setGravity(Gravity.CENTER);
        body.setPadding(dp(24), dp(24), dp(24), dp(24));
        root.addView(body, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        ));
        body.addView(title("MalayMate"));
        TextView loading = paragraph(text);
        loading.setGravity(Gravity.CENTER);
        body.addView(loading);
    }

    private void renderImportError() {
        root.removeAllViews();
        LinearLayout body = vertical();
        body.setPadding(dp(24), dp(24), dp(24), dp(24));
        root.addView(body, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        ));
        body.addView(title("Import failed"));
        body.addView(paragraph(importError == null ? "Unknown error." : importError));
        TextView retry = button("Retry import");
        retry.setOnClickListener(v -> {
            importError = null;
            renderLoading("Importing starter decks...");
            executor.execute(() -> {
                try {
                    repository.ensureSeedImported();
                    mainHandler.post(() -> {
                        importFinished = true;
                        importError = null;
                        invalidateAllData();
                        renderScreen();
                    });
                } catch (Exception e) {
                    mainHandler.post(() -> {
                        importError = message(e);
                        renderImportError();
                    });
                }
            });
        });
        body.addView(retry);
    }

    private void addAppHeader() {
        LinearLayout header = horizontal();
        header.setPadding(dp(18), statusBarInset() + dp(8), dp(18), dp(10));
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setBackgroundColor(CANVAS);
        LinearLayout copy = vertical();
        TextView brand = label("MALAYMATE");
        brand.setTextSize(10);
        brand.setTypeface(BODY_MEDIUM_TYPEFACE);
        brand.setIncludeFontPadding(false);
        brand.setLetterSpacing(0.08f);
        brand.setTextColor(JADE_DARK);
        brand.setPadding(0, 0, 0, 0);
        copy.addView(brand);
        TextView appTitle = new TextView(this);
        appTitle.setText(showMoreMenu ? "More" : currentScreen.title);
        appTitle.setTextSize(31);
        appTitle.setTypeface(DISPLAY_TYPEFACE);
        appTitle.setIncludeFontPadding(false);
        appTitle.setTextColor(INK);
        appTitle.setPadding(0, dp(5), 0, dp(5));
        copy.addView(appTitle);
        TextView subtitle = small(screenSubtitle());
        copy.addView(subtitle);
        header.addView(copy, new LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f
        ));
        header.addView(chip(headerChipText()), wrapMargins(12, 0, 0, 0));
        root.addView(header);
    }

    private String screenSubtitle() {
        if (showMoreMenu) return "Add words, AI settings, and audio status.";
        switch (currentScreen) {
            case TODAY:
                return "先学新词，再清复习队列。";
            case LEARN:
                return "Small daily steps with Malay audio.";
            case REVIEW:
                return "Spelling, recall, and scheduled ratings.";
            case LIBRARY:
                return "Search, filter, and inspect every word.";
            case ADD_WORD:
                return "Create a local word with optional AI enrichment.";
            case SETTINGS:
            default:
                return "Model, API key, daily limit, and audio.";
        }
    }

    private String headerChipText() {
        if (todaySummary != null) {
            return todaySummary.dueReviewCount > 0 ? todaySummary.dueReviewCount + " due" : settings.dailyLimit() + "/day";
        }
        return settings.dailyLimit() + "/day";
    }

    private void addBottomNavBar() {
        LinearLayout nav = horizontal();
        nav.setPadding(dp(12), dp(8), dp(12), dp(10));
        nav.setBackgroundColor(SURFACE);
        for (MobileNavItem item : MobileNavigation.bottomItems(currentScreen)) {
            boolean selected = item.selected || (item.screen == null && showMoreMenu);
            TextView navItem = navItem(item.label, selected);
            navItem.setOnClickListener(v -> {
                if (item.screen == null) {
                    showMoreMenu = true;
                    renderScreen();
                } else {
                    navigate(item.screen);
                }
            });
            nav.addView(navItem, weightMargins(1f, 2, 0, 2, 0));
        }
        root.addView(nav);
    }

    private void navigate(AppScreen screen) {
        showMoreMenu = false;
        currentScreen = screen;
        if (screen == AppScreen.REVIEW) {
            loadReviewItems();
        } else {
            renderScreen();
        }
    }

    private void renderMore(LinearLayout body) {
        body.addView(paragraph("管理自定义词、AI enrichment 和系统发音。"));
        for (MobileNavItem item : MobileNavigation.moreItems()) {
            LinearLayout box = card(vertical());
            box.addView(subtitle(item.label));
            if (item.screen == AppScreen.ADD_WORD) {
                box.addView(paragraph("添加一个马来语词条，可用 AI 补全释义、词性、例句。"));
            } else {
                box.addView(paragraph("管理模型、API key、每日新词数量和 Malay TTS 状态。"));
            }
            TextView open = primaryButton("Open " + item.label);
            open.setOnClickListener(v -> navigate(item.screen));
            box.addView(open, matchMargins(0, 10, 0, 0));
            body.addView(box, matchMargins(0, 0, 0, 12));
        }
    }

    private void renderToday(LinearLayout body) {
        int dailyLimit = settings.dailyLimit();
        if (todaySummary == null || todayDailyLimit != dailyLimit) {
            if (todayError == null) {
                loadTodaySummary(dailyLimit);
                body.addView(loadingCard("Loading today..."));
            } else {
                body.addView(statusCard("Today could not load", todayError));
                TextView retry = button("Retry");
                retry.setOnClickListener(v -> {
                    todayLoadGate.clear();
                    todayError = null;
                    loadTodaySummary(settings.dailyLimit());
                    renderScreen();
                });
                body.addView(retry);
            }
            return;
        }
        TodaySummary summary = todaySummary;
        LinearLayout hero = tintedCard(vertical());
        hero.addView(label("Next best action"));
        hero.addView(subtitle(summary.dueReviewCount > 0 ? "Review due words" : "Learn new Malay words"));
        hero.addView(paragraph(summary.dueReviewCount > 0
                ? "先清到期复习，再继续学新词。"
                : "今天还有 " + summary.remainingNewWordSlots + " 个新词名额。"));
        LinearLayout actions = horizontal();
        TextView learn = primaryButton("Learn");
        learn.setEnabled(summary.remainingNewWordSlots > 0 && summary.newWordCount > 0);
        learn.setOnClickListener(v -> navigate(AppScreen.LEARN));
        actions.addView(learn, weightMargins(1f, 0, 12, 6, 0));
        TextView review = button("Review");
        review.setEnabled(summary.dueReviewCount > 0);
        review.setOnClickListener(v -> navigate(AppScreen.REVIEW));
        actions.addView(review, weightMargins(1f, 6, 12, 0, 0));
        hero.addView(actions, matchMargins(0, 12, 0, 0));
        body.addView(hero, matchMargins(0, 0, 0, 14));

        body.addView(metricGrid(
                metric("待复习", String.valueOf(summary.dueReviewCount)),
                metric("今日已学", String.valueOf(summary.learnedTodayCount)),
                metric("还可学新词", String.valueOf(summary.remainingNewWordSlots)),
                metric("词库新词", String.valueOf(summary.newWordCount))
        ), matchMargins(0, 0, 0, 12));

        if (summary.dueReviewCount > 0) {
            body.addView(statusCard("Review ready", "现在可以复习。"));
        } else if (summary.nextDueAt != null) {
            body.addView(statusCard("Next review", formatTime(summary.nextDueAt)));
        } else {
            body.addView(statusCard("No review scheduled", "还没有已安排的复习。"));
        }
    }

    private void loadTodaySummary(int dailyLimit) {
        String key = String.valueOf(dailyLimit);
        if (!todayLoadGate.shouldStart(todaySummary, todayLoading, todayError, key)) return;
        todayLoadGate.start(key);
        todayLoading = true;
        todayDailyLimit = dailyLimit;
        executor.execute(() -> {
            try {
                TodaySummary summary = repository.todaySummary(dailyLimit, System.currentTimeMillis());
                mainHandler.post(() -> {
                    if (todayDailyLimit != dailyLimit) return;
                    todaySummary = summary;
                    todayLoading = false;
                    todayError = null;
                    if (currentScreen == AppScreen.TODAY) renderScreen();
                });
            } catch (Exception e) {
                mainHandler.post(() -> {
                    if (todayDailyLimit != dailyLimit) return;
                    todayLoading = false;
                    todayError = "Could not load today: " + message(e);
                    todayLoadGate.fail(key, todayError);
                    if (currentScreen == AppScreen.TODAY) renderScreen();
                });
            }
        });
    }

    private void renderLearn(LinearLayout body) {
        int dailyLimit = settings.dailyLimit();
        if (learnData == null || learnDataDailyLimit != dailyLimit || !sameString(learnDataDeckId, learnSelectedDeckId)) {
            if (learnError == null) {
                loadLearnData(learnSelectedDeckId, dailyLimit);
                body.addView(paragraph("Loading learn plan..."));
            } else {
                body.addView(paragraph(learnError));
                TextView retry = button("Retry");
                retry.setOnClickListener(v -> {
                    learnLoadGate.clear();
                    learnError = null;
                    loadLearnData(learnSelectedDeckId, settings.dailyLimit());
                    renderScreen();
                });
                body.addView(retry);
            }
            return;
        }
        LearnPlan plan = learnData.plan;
        List<DeckRecord> decks = learnData.decks;
        List<WordRecord> visibleWords = new ArrayList<>();
        for (WordRecord word : plan.words) {
            if (!skippedWordIds.contains(word.id)) visibleWords.add(word);
        }
        WordRecord currentWord = visibleWords.isEmpty() ? null : visibleWords.get(0);

        body.addView(paragraph(plan.learnedTodayCount + " learned today / " + plan.remainingNewWordSlots + " new-word slots left"));

        LinearLayout controls = vertical();
        controls.addView(label("Deck"));
        Spinner deckSpinner = spinner(deckNames(decks));
        int selected = deckSelectionIndex(decks, learnSelectedDeckId);
        deckSpinner.setSelection(selected, false);
        deckSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                String nextDeck = position == 0 ? null : decks.get(position - 1).id;
                if (!sameString(learnSelectedDeckId, nextDeck)) {
                    learnSelectedDeckId = nextDeck;
                    skippedWordIds.clear();
                    learnStatus = null;
                    lastAutoSpokenWordId = null;
                    renderScreen();
                }
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
            }
        });
        controls.addView(deckSpinner, matchMargins(0, 4, 0, 12));

        LinearLayout daily = horizontalWrap();
        TextView dailyText = paragraph("Daily limit: " + dailyLimit);
        daily.addView(dailyText, wrapMargins(0, 0, 12, 0));
        TextView minus = button("-1");
        minus.setOnClickListener(v -> {
            settings.setDailyLimit(settings.dailyLimit() - 1);
            skippedWordIds.clear();
            learnStatus = null;
            invalidateTodayData();
            invalidateLearnData();
            renderScreen();
        });
        daily.addView(minus, wrapMargins(0, 0, 8, 0));
        TextView plus = button("+1");
        plus.setOnClickListener(v -> {
            settings.setDailyLimit(settings.dailyLimit() + 1);
            skippedWordIds.clear();
            learnStatus = null;
            invalidateTodayData();
            invalidateLearnData();
            renderScreen();
        });
        daily.addView(plus, wrapMargins(0, 0, 8, 0));
        if (!skippedWordIds.isEmpty()) {
            TextView reset = button("显示跳过");
            reset.setOnClickListener(v -> {
                skippedWordIds.clear();
                learnStatus = null;
                renderScreen();
            });
            daily.addView(reset);
        }
        controls.addView(daily);
        body.addView(card(controls), matchMargins(0, 12, 0, 16));

        if (currentWord == null) {
            body.addView(emptyLearnState(plan));
        } else {
            body.addView(learnCard(currentWord), matchMargins(0, 0, 0, 12));
            autoSpeakLearnWord(currentWord);
        }

        if (learnStatus != null) body.addView(paragraph(learnStatus));
    }

    private void loadLearnData(String selectedDeckId, int dailyLimit) {
        String key = (selectedDeckId == null ? ALL_DECKS_ID : selectedDeckId) + ":" + dailyLimit;
        if (!learnLoadGate.shouldStart(learnData, learnLoading, learnError, key)) return;
        learnLoadGate.start(key);
        learnLoading = true;
        learnDataDailyLimit = dailyLimit;
        learnDataDeckId = selectedDeckId;
        executor.execute(() -> {
            try {
                LearnPlan plan = repository.learnPlan(selectedDeckId, dailyLimit, System.currentTimeMillis());
                List<DeckRecord> decks = repository.decks();
                LearnScreenData data = new LearnScreenData(plan, decks);
                mainHandler.post(() -> {
                    if (learnDataDailyLimit != dailyLimit || !sameString(learnDataDeckId, selectedDeckId)) return;
                    learnData = data;
                    learnLoading = false;
                    learnError = null;
                    if (currentScreen == AppScreen.LEARN) renderScreen();
                });
            } catch (Exception e) {
                mainHandler.post(() -> {
                    if (learnDataDailyLimit != dailyLimit || !sameString(learnDataDeckId, selectedDeckId)) return;
                    learnLoading = false;
                    learnError = "Could not load learn plan: " + message(e);
                    learnLoadGate.fail(key, learnError);
                    if (currentScreen == AppScreen.LEARN) renderScreen();
                });
            }
        });
    }

    private View emptyLearnState(LearnPlan plan) {
        LinearLayout box = card(vertical());
        if (plan.remainingNewWordSlots == 0) {
            box.addView(subtitle("今日新词已完成"));
            box.addView(paragraph("到 Review 里复习已经进入队列的词。"));
        } else if (!skippedWordIds.isEmpty() && !plan.words.isEmpty()) {
            box.addView(subtitle("这一组已跳过"));
            box.addView(paragraph("重新显示跳过的词，或切换词库。"));
            TextView reset = button("显示跳过的词");
            reset.setOnClickListener(v -> {
                skippedWordIds.clear();
                renderScreen();
            });
            box.addView(reset);
        } else {
            box.addView(subtitle("没有可学习的新词"));
            box.addView(paragraph("切换词库，或先导入/添加更多词。"));
        }
        return box;
    }

    private LinearLayout learnCard(WordRecord word) {
        LinearLayout box = card(vertical());
        TextView term = new TextView(this);
        term.setText(word.term);
        term.setTextSize(38);
        term.setTypeface(headingTypeface(word.term));
        term.setIncludeFontPadding(false);
        term.setTextColor(INK);
        box.addView(term);
        String meta = joinNonEmpty(word.partOfSpeech, word.pronunciationNotes);
        if (!meta.isEmpty()) box.addView(chip(meta.replace("\n", " / ")));
        box.addView(divider());
        TextView meaning = subtitle(word.chineseMeaning);
        box.addView(meaning);

        for (String example : examplesFor(word, 2)) {
            TextView exampleText = paragraph(example);
            exampleText.setPadding(0, dp(6), 0, 0);
            box.addView(exampleText);
        }

        LinearLayout actions = horizontalWrap();
        TextView audio = button("发音");
        audio.setEnabled(canSpeakMalay);
        audio.setOnClickListener(v -> speakMalay(word.term, true));
        actions.addView(audio, wrapMargins(0, 12, 8, 0));
        TextView skip = button("跳过");
        skip.setOnClickListener(v -> {
            skippedWordIds.add(word.id);
            learnStatus = null;
            renderScreen();
        });
        actions.addView(skip, wrapMargins(0, 12, 8, 0));
        TextView learned = button("学会了");
        learned.setOnClickListener(v -> runTask(
                "Saving learning progress...",
                () -> {
                    repository.markLearned(word.id, System.currentTimeMillis());
                    return word.term;
                },
                termText -> {
                    skippedWordIds.remove(word.id);
                    learnStatus = termText + " 已加入 Review，10 分钟后出现。";
                    invalidateTodayData();
                    invalidateLearnData();
                    invalidateLibraryData();
                    renderScreen();
                }
        ));
        actions.addView(learned, wrapMargins(0, 12, 0, 0));
        box.addView(actions);
        return box;
    }

    private void autoSpeakLearnWord(WordRecord word) {
        if (sameString(lastAutoSpokenWordId, word.id)) return;
        lastAutoSpokenWordId = word.id;
        if (canSpeakMalay) speakMalay(word.term, false);
    }

    private void loadReviewItems() {
        reviewLoading = true;
        reviewLoaded = false;
        reviewSaving = false;
        answerRevealed = false;
        spellingAnswer = "";
        spellingEvaluation = null;
        reviewStatus = null;
        renderScreen();
        executor.execute(() -> {
            try {
                List<DueReviewItem> items = repository.dueCards(System.currentTimeMillis(), 100);
                mainHandler.post(() -> {
                    dueItems.clear();
                    dueItems.addAll(items);
                    reviewLoading = false;
                    reviewLoaded = true;
                    reviewStatus = dueItems.isEmpty() ? "All caught up." : null;
                    renderScreen();
                });
            } catch (Exception e) {
                mainHandler.post(() -> {
                    reviewLoading = false;
                    reviewLoaded = true;
                    reviewStatus = "Could not load reviews: " + message(e);
                    renderScreen();
                });
            }
        });
    }

    private void renderReview(LinearLayout body) {
        if (reviewLoading) {
            body.addView(paragraph("Loading due cards..."));
            return;
        }
        if (!reviewLoaded) {
            body.addView(paragraph("Review queue not loaded."));
            TextView load = button("Load reviews");
            load.setOnClickListener(v -> loadReviewItems());
            body.addView(load);
            return;
        }

        body.addView(paragraph(dueItems.size() + " loaded due cards"));
        TextView refresh = button("Refresh");
        refresh.setOnClickListener(v -> loadReviewItems());
        body.addView(refresh, wrapMargins(0, 8, 0, 12));

        if (dueItems.isEmpty()) {
            LinearLayout empty = card(vertical());
            empty.addView(subtitle("今天没有待复习"));
            empty.addView(paragraph("Add a word or come back when cards are due."));
            body.addView(empty);
        } else {
            body.addView(reviewCard(dueItems.get(0)), matchMargins(0, 0, 0, 12));
        }
        if (reviewStatus != null) body.addView(paragraph(reviewStatus));
    }

    private LinearLayout reviewCard(DueReviewItem item) {
        LinearLayout box = card(vertical());
        box.addView(small(directionTitle(item.card.direction)));
        TextView prompt = new TextView(this);
        prompt.setText(item.card.prompt);
        prompt.setTextSize(containsCjk(item.card.prompt) ? 30 : 35);
        prompt.setTypeface(headingTypeface(item.card.prompt));
        prompt.setIncludeFontPadding(false);
        prompt.setLineSpacing(dp(1), 1.02f);
        prompt.setTextColor(INK);
        box.addView(prompt);
        if (!item.card.hint.isEmpty()) box.addView(small(item.card.hint));
        box.addView(divider());

        EditText spellingInput = null;
        boolean spellingPractice = isSpellingPractice(item);
        if (answerRevealed) {
            box.addView(label("答案"));
            box.addView(subtitle(item.card.answer));
            if (spellingEvaluation != null) box.addView(paragraph(spellingText(spellingEvaluation)));
            if (!item.word.pronunciationNotes.isEmpty()) box.addView(small(item.word.pronunciationNotes));
        } else if (spellingPractice) {
            box.addView(label("输入马来语拼写"));
            spellingInput = input("Malay answer", spellingAnswer, false);
            box.addView(spellingInput, matchMargins(0, 4, 0, 8));
            box.addView(small("Check 后再自己评分。"));
        } else {
            box.addView(paragraph("先想答案，再点击 Reveal。"));
        }

        LinearLayout actions = horizontalWrap();
        TextView reveal = button("Reveal");
        reveal.setEnabled(!answerRevealed && !reviewSaving);
        reveal.setOnClickListener(v -> {
            answerRevealed = true;
            reviewStatus = null;
            renderScreen();
        });
        actions.addView(reveal, wrapMargins(0, 12, 8, 0));

        if (spellingPractice) {
            EditText finalSpellingInput = spellingInput;
            TextView check = button("Check");
            check.setEnabled(!answerRevealed && !reviewSaving && finalSpellingInput != null
                    && !finalSpellingInput.getText().toString().trim().isEmpty());
            if (finalSpellingInput != null) {
                finalSpellingInput.addTextChangedListener(new TextWatcher() {
                    @Override
                    public void beforeTextChanged(CharSequence s, int start, int count, int after) {
                    }

                    @Override
                    public void onTextChanged(CharSequence s, int start, int before, int count) {
                        spellingAnswer = s == null ? "" : s.toString();
                        check.setEnabled(!answerRevealed && !reviewSaving && !spellingAnswer.trim().isEmpty());
                    }

                    @Override
                    public void afterTextChanged(Editable s) {
                    }
                });
            }
            check.setOnClickListener(v -> {
                spellingAnswer = finalSpellingInput == null ? spellingAnswer : finalSpellingInput.getText().toString();
                if (spellingAnswer.trim().isEmpty()) {
                    reviewStatus = "Enter a Malay answer first.";
                } else {
                    spellingEvaluation = SpellingEvaluator.evaluate(spellingAnswer, item.card.answer);
                    answerRevealed = true;
                    reviewStatus = spellingText(spellingEvaluation);
                }
                renderScreen();
            });
            actions.addView(check, wrapMargins(0, 12, 8, 0));
        }

        TextView audio = button("Audio");
        audio.setEnabled(canSpeakMalay && canPlayVisibleMalayAudio(item));
        audio.setOnClickListener(v -> playReviewAudio(item));
        actions.addView(audio, wrapMargins(0, 12, 8, 0));

        TextView again = button("Again");
        again.setEnabled(answerRevealed && !reviewSaving);
        again.setOnClickListener(v -> applyReviewRating(item, ReviewRating.AGAIN));
        actions.addView(again, wrapMargins(0, 12, 8, 0));
        TextView good = button("Good");
        good.setEnabled(answerRevealed && !reviewSaving);
        good.setOnClickListener(v -> applyReviewRating(item, ReviewRating.GOOD));
        actions.addView(good, wrapMargins(0, 12, 8, 0));
        TextView easy = button("Easy");
        easy.setEnabled(answerRevealed && !reviewSaving);
        easy.setOnClickListener(v -> applyReviewRating(item, ReviewRating.EASY));
        actions.addView(easy, wrapMargins(0, 12, 0, 0));
        box.addView(actions);
        return box;
    }

    private void playReviewAudio(DueReviewItem item) {
        if (!canPlayVisibleMalayAudio(item)) {
            reviewStatus = "Reveal the answer before playing Malay audio.";
            renderScreen();
            return;
        }
        speakMalay(CardDirection.MALAY_TO_CHINESE.raw.equals(item.card.direction) ? item.card.prompt : item.card.answer, true);
    }

    private void applyReviewRating(DueReviewItem item, ReviewRating rating) {
        if (reviewSaving || item == null || item.card == null) return;
        reviewSaving = true;
        String cardId = item.card.id;
        reviewStatus = "Saving review...";
        renderScreen();
        executor.execute(() -> {
            try {
                ReviewUpdate update = repository.applyRating(cardId, rating, System.currentTimeMillis());
                mainHandler.post(() -> {
                    ReviewQueue.removeCard(dueItems, cardId);
                    reviewSaving = false;
                    answerRevealed = false;
                    spellingAnswer = "";
                    spellingEvaluation = null;
                    reviewStatus = "下次复习: " + formatTime(update.nextDueAt);
                    invalidateTodayData();
                    invalidateLibraryData();
                    renderScreen();
                });
            } catch (Exception e) {
                mainHandler.post(() -> {
                    reviewSaving = false;
                    reviewStatus = "Could not save review: " + message(e);
                    renderScreen();
                });
            }
        });
    }

    private void renderLibrary(LinearLayout body) {
        if (libraryData == null
                || !sameString(libraryDataDeckId, librarySelectedDeckId)
                || !sameString(libraryDataSearchText, librarySearchText)
                || !sameString(libraryDataStatusFilter, libraryStatusFilter)
                || !sameString(libraryDataSort, librarySort)
                || libraryDataVisibleLimit != libraryVisibleLimit) {
            if (libraryError == null) {
                loadLibraryData();
                body.addView(loadingCard("Loading library..."));
            } else {
                body.addView(statusCard("Library could not load", libraryError));
                TextView retry = button("Retry");
                retry.setOnClickListener(v -> {
                    libraryLoadGate.clear();
                    libraryError = null;
                    loadLibraryData();
                    renderScreen();
                });
                body.addView(retry);
            }
            return;
        }
        List<DeckRecord> decks = libraryData.decks;
        LibraryBrowseResult result = libraryData.result;
        body.addView(paragraph(result.sections.size() + " 个词库 / 显示 " + result.visibleCount + " / " + result.totalMatches + " 个词"));

        LinearLayout controls = card(vertical());
        controls.addView(label("Deck"));
        Spinner deckSpinner = spinner(deckNames(decks));
        deckSpinner.setSelection(deckSelectionIndex(decks, librarySelectedDeckId), false);
        deckSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                String nextDeck = position == 0 ? null : decks.get(position - 1).id;
                if (!sameString(librarySelectedDeckId, nextDeck)) {
                    librarySelectedDeckId = nextDeck;
                    resetLibraryPage();
                    renderScreen();
                }
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
            }
        });
        controls.addView(deckSpinner, matchMargins(0, 4, 0, 8));

        controls.addView(label("Search"));
        EditText search = input("搜索词、中文、词性或发音", librarySearchText, false);
        search.setImeOptions(EditorInfo.IME_ACTION_SEARCH);
        search.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                scheduleLibrarySearch(s == null ? "" : s.toString());
            }

            @Override
            public void afterTextChanged(Editable s) {
            }
        });
        search.setOnEditorActionListener((v, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_SEARCH) {
                applyLibrarySearch(search.getText().toString());
                return true;
            }
            return false;
        });
        search.setOnFocusChangeListener((v, hasFocus) -> {
            if (!hasFocus) applyLibrarySearch(search.getText().toString());
        });
        LinearLayout searchRow = horizontal();
        searchRow.addView(search, weightMargins(1f, 0, 4, 4, 0));
        TextView clear = optionButton("Clear", false);
        clear.setOnClickListener(v -> {
            search.setText("");
            applyLibrarySearch("");
        });
        searchRow.addView(clear, wrapMargins(4, 4, 0, 0));
        controls.addView(searchRow);

        controls.addView(label("Status"));
        controls.addView(segmentedOptions(LibraryUiOptions.statusFilters(), libraryStatusFilter, value -> {
            libraryStatusFilter = value;
            resetLibraryPage();
            renderScreen();
        }), matchMargins(0, 6, 0, 8));

        controls.addView(label("Sort"));
        List<LibraryUiOption> sortOptions = LibraryUiOptions.sorts();
        Spinner sort = spinner(optionLabels(sortOptions));
        sort.setSelection(sortIndex(librarySort), false);
        sort.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                String next = sortOptions.get(position).value;
                if (!sameString(librarySort, next)) {
                    librarySort = next;
                    resetLibraryPage();
                    renderScreen();
                }
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
            }
        });
        controls.addView(sort, matchMargins(0, 4, 0, 0));
        body.addView(controls, matchMargins(0, 12, 0, 16));

        if (result.sections.isEmpty()) {
            LinearLayout empty = card(vertical());
            empty.addView(subtitle("没有词条"));
            empty.addView(paragraph(librarySearchText.isEmpty() ? "Add a word or import a starter deck." : "换一个搜索词或筛选条件。"));
            body.addView(empty);
        } else {
            for (LibrarySection section : result.sections) {
                body.addView(librarySection(section), matchMargins(0, 0, 0, 16));
            }
            if (result.hasMore) {
                TextView more = button("显示更多");
                more.setOnClickListener(v -> {
                    libraryVisibleLimit += PAGE_SIZE;
                    renderScreen();
                });
                body.addView(more);
            }
        }
    }

    private void loadLibraryData() {
        if (libraryLoading
                && sameString(libraryDataDeckId, librarySelectedDeckId)
                && sameString(libraryDataSearchText, librarySearchText)
                && sameString(libraryDataStatusFilter, libraryStatusFilter)
                && sameString(libraryDataSort, librarySort)
                && libraryDataVisibleLimit == libraryVisibleLimit) {
            return;
        }
        String selectedDeckId = librarySelectedDeckId;
        String searchText = librarySearchText;
        String statusFilter = libraryStatusFilter;
        String sort = librarySort;
        int visibleLimit = libraryVisibleLimit;
        String key = libraryLoadKey(selectedDeckId, searchText, statusFilter, sort, visibleLimit);
        if (!libraryLoadGate.shouldStart(libraryData, libraryLoading, libraryError, key)) return;
        libraryLoadGate.start(key);
        libraryLoading = true;
        libraryDataDeckId = selectedDeckId;
        libraryDataSearchText = searchText;
        libraryDataStatusFilter = statusFilter;
        libraryDataSort = sort;
        libraryDataVisibleLimit = visibleLimit;
        executor.execute(() -> {
            try {
                List<DeckRecord> decks = repository.decks();
                LibraryBrowseResult result = repository.browseLibrary(selectedDeckId, searchText, statusFilter, sort, visibleLimit);
                LibraryScreenData data = new LibraryScreenData(decks, result);
                mainHandler.post(() -> {
                    if (!sameString(libraryDataDeckId, selectedDeckId)
                            || !sameString(libraryDataSearchText, searchText)
                            || !sameString(libraryDataStatusFilter, statusFilter)
                            || !sameString(libraryDataSort, sort)
                            || libraryDataVisibleLimit != visibleLimit) return;
                    libraryData = data;
                    libraryLoading = false;
                    libraryError = null;
                    if (currentScreen == AppScreen.LIBRARY) renderScreen();
                });
            } catch (Exception e) {
                mainHandler.post(() -> {
                    if (!sameString(libraryDataDeckId, selectedDeckId)
                            || !sameString(libraryDataSearchText, searchText)
                            || !sameString(libraryDataStatusFilter, statusFilter)
                            || !sameString(libraryDataSort, sort)
                            || libraryDataVisibleLimit != visibleLimit) return;
                    libraryLoading = false;
                    libraryError = "Could not load library: " + message(e);
                    libraryLoadGate.fail(key, libraryError);
                    if (currentScreen == AppScreen.LIBRARY) renderScreen();
                });
            }
        });
    }

    private String libraryLoadKey(String selectedDeckId, String searchText, String statusFilter, String sort, int visibleLimit) {
        return (selectedDeckId == null ? ALL_DECKS_ID : selectedDeckId)
                + ":" + (searchText == null ? "" : searchText)
                + ":" + (statusFilter == null ? "all" : statusFilter)
                + ":" + (sort == null ? "deckOrder" : sort)
                + ":" + visibleLimit;
    }

    private void scheduleLibrarySearch(String value) {
        String next = value == null ? "" : value;
        if (sameString(librarySearchText, next)) return;
        librarySearchText = next;
        if (pendingLibrarySearchRunnable != null) {
            mainHandler.removeCallbacks(pendingLibrarySearchRunnable);
        }
        pendingLibrarySearchRunnable = () -> {
            pendingLibrarySearchRunnable = null;
            resetLibraryPage();
            if (currentScreen == AppScreen.LIBRARY && !showMoreMenu) renderScreen();
        };
        mainHandler.postDelayed(pendingLibrarySearchRunnable, 350);
    }

    private void applyLibrarySearch(String value) {
        if (pendingLibrarySearchRunnable != null) {
            mainHandler.removeCallbacks(pendingLibrarySearchRunnable);
            pendingLibrarySearchRunnable = null;
        }
        String next = value == null ? "" : value;
        if (!sameString(librarySearchText, next)) {
            librarySearchText = next;
        }
        resetLibraryPage();
        if (currentScreen == AppScreen.LIBRARY && !showMoreMenu) renderScreen();
    }

    private LinearLayout librarySection(LibrarySection section) {
        LinearLayout box = card(vertical());
        TextView sectionTitle = subtitle(section.name + " (" + section.words.size() + ")");
        sectionTitle.setTextSize(containsCjk(section.name) ? 20 : 19);
        box.addView(sectionTitle);
        if (!section.description.isEmpty()) box.addView(paragraph(section.description));
        for (WordRecord word : section.words) {
            box.addView(divider());
            box.addView(libraryWordRow(word));
        }
        return box;
    }

    private LinearLayout libraryWordRow(WordRecord word) {
        LinearLayout row = vertical();
        LinearLayout header = horizontal();
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(dp(2), dp(8), dp(2), dp(8));
        header.setClickable(true);
        header.setFocusable(true);
        header.setBackground(rounded(Color.TRANSPARENT, Color.TRANSPARENT));
        LinearLayout copy = vertical();
        TextView term = subtitle(word.term);
        term.setTextSize(19);
        copy.addView(term);
        TextView meaning = small(word.chineseMeaning);
        copy.addView(meaning);
        header.addView(copy, weightMargins(1f, 0, 0, 8, 0));
        header.addView(chip(learningStatusText(LearningStatus.fromWord(word))));
        header.setOnClickListener(v -> {
            if (expandedWordIds.contains(word.id)) {
                expandedWordIds.remove(word.id);
            } else {
                expandedWordIds.add(word.id);
                if (canSpeakMalay) speakMalay(word.term, false);
            }
            renderScreen();
        });
        row.addView(header);
        if (!word.partOfSpeech.isEmpty() || !word.pronunciationNotes.isEmpty()) {
            row.addView(small(joinNonEmpty(word.partOfSpeech, word.pronunciationNotes)));
        }

        if (expandedWordIds.contains(word.id)) {
            LinearLayout details = vertical();
            details.setPadding(dp(12), dp(8), dp(12), dp(8));
            List<String> examples = examplesFor(word, 20);
            if (examples.isEmpty()) {
                details.addView(paragraph("No examples"));
            } else {
                for (String example : examples) details.addView(paragraph(example));
            }
            TextView audio = button("Audio");
            audio.setEnabled(canSpeakMalay);
            audio.setOnClickListener(v -> speakMalay(word.term, true));
            details.addView(audio, wrapMargins(0, 6, 0, 0));
            row.addView(details);
        }
        return row;
    }

    private void renderAddWord(LinearLayout body) {
        LinearLayout form = card(vertical());
        form.addView(label("Malay word"));
        EditText termInput = input("Malay word", addTerm, false);
        form.addView(termInput, matchMargins(0, 4, 0, 10));
        form.addView(label("中文意思"));
        EditText meaningInput = input("中文意思", addMeaning, false);
        form.addView(meaningInput, matchMargins(0, 4, 0, 10));
        form.addView(label("Note"));
        EditText noteInput = input("Note", addNote, true);
        noteInput.setMinLines(3);
        form.addView(noteInput, matchMargins(0, 4, 0, 12));

        TextView save = primaryButton(addSaving ? "Saving..." : "Save");
        save.setEnabled(!addSaving && !addTerm.trim().isEmpty());
        TextWatcher draftWatcher = new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                addTerm = termInput.getText().toString();
                addMeaning = meaningInput.getText().toString();
                addNote = noteInput.getText().toString();
                save.setEnabled(!addSaving && !addTerm.trim().isEmpty());
            }

            @Override
            public void afterTextChanged(Editable s) {
            }
        };
        termInput.addTextChangedListener(draftWatcher);
        meaningInput.addTextChangedListener(draftWatcher);
        noteInput.addTextChangedListener(draftWatcher);
        save.setOnClickListener(v -> {
            addTerm = termInput.getText().toString();
            addMeaning = meaningInput.getText().toString();
            addNote = noteInput.getText().toString();
            saveWord();
        });
        form.addView(save);
        body.addView(form);
        if (addStatus != null) body.addView(paragraph(addStatus), matchMargins(0, 12, 0, 0));
    }

    private void saveWord() {
        if (addTerm.trim().isEmpty()) {
            addStatus = "Malay word is required.";
            renderScreen();
            return;
        }
        addSaving = true;
        addStatus = settings.hasApiKey() ? "Saving with AI enrichment..." : "Saving with local template fallback...";
        renderScreen();

        String submittedTerm = addTerm;
        String submittedMeaning = addMeaning;
        String submittedNote = addNote;
        executor.execute(() -> {
            boolean usedProvider = false;
            boolean aiSucceeded = false;
            try {
                long now = System.currentTimeMillis();
                AIEnrichment enrichment = null;
                if (settings.hasApiKey()) {
                    usedProvider = true;
                    try {
                        String apiKey = settings.apiKey();
                        if (apiKey != null && !apiKey.trim().isEmpty()) {
                            enrichment = openAIClient.enrich(apiKey.trim(), settings.modelName(), submittedTerm, submittedMeaning, submittedNote);
                            aiSucceeded = true;
                        }
                    } catch (Exception ignored) {
                        enrichment = null;
                    }
                }
                String reviewStatus = aiSucceeded ? "aiGenerated" : "needsEnrichment";
                if (enrichment == null) enrichment = repository.template(submittedTerm, submittedMeaning, submittedNote, now);
                repository.addWord(submittedTerm, submittedMeaning, submittedNote, enrichment, reviewStatus, now);
                boolean finalUsedProvider = usedProvider;
                boolean finalAiSucceeded = aiSucceeded;
                mainHandler.post(() -> {
                    addSaving = false;
                    addTerm = "";
                    addMeaning = "";
                    addNote = "";
                    invalidateTodayData();
                    invalidateLearnData();
                    invalidateLibraryData();
                    if (finalAiSucceeded) {
                        addStatus = "Saved with AI enrichment.";
                    } else if (finalUsedProvider) {
                        addStatus = "Saved with local template fallback after AI failed.";
                    } else {
                        addStatus = "Saved with local template fallback.";
                    }
                    renderScreen();
                });
            } catch (Exception e) {
                mainHandler.post(() -> {
                    addSaving = false;
                    addStatus = "Could not save word: " + message(e);
                    renderScreen();
                });
            }
        });
    }

    private void renderSettings(LinearLayout body) {
        LinearLayout ai = card(vertical());
        ai.addView(subtitle("AI"));
        ai.addView(label("Model"));
        EditText modelInput = input("Model", settings.modelName(), false);
        ai.addView(modelInput, matchMargins(0, 4, 0, 8));
        TextView saveModel = button("Save model");
        saveModel.setOnClickListener(v -> {
            settings.setModelName(modelInput.getText().toString());
            settingsStatus = "Model saved.";
            renderScreen();
        });
        ai.addView(saveModel, matchMargins(0, 0, 0, 12));

        ai.addView(label("OpenAI API key"));
        EditText keyInput = input("OpenAI API key", "", false);
        keyInput.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        ai.addView(keyInput, matchMargins(0, 4, 0, 8));
        ai.addView(paragraph(settings.hasApiKey() ? "API key saved" : "No API key saved"));
        LinearLayout keyActions = horizontalWrap();
        TextView saveKey = button("Save key");
        saveKey.setOnClickListener(v -> {
            String key = keyInput.getText().toString().trim();
            if (key.isEmpty()) {
                settingsStatus = "Enter an API key first.";
                renderScreen();
                return;
            }
            try {
                settings.saveApiKey(key);
                settingsStatus = "API key saved.";
            } catch (Exception e) {
                settingsStatus = "Could not save API key: " + message(e);
            }
            renderScreen();
        });
        keyActions.addView(saveKey, wrapMargins(0, 8, 8, 0));
        TextView clearKey = button("Clear key");
        clearKey.setOnClickListener(v -> {
            settings.clearApiKey();
            settingsStatus = "API key cleared.";
            renderScreen();
        });
        keyActions.addView(clearKey, wrapMargins(0, 8, 0, 0));
        ai.addView(keyActions);
        body.addView(ai, matchMargins(0, 12, 0, 16));

        LinearLayout audio = card(vertical());
        audio.addView(subtitle("Audio"));
        audio.addView(paragraph(ttsStatus));
        if (!canSpeakMalay) audio.addView(paragraph("Audio buttons are disabled until Android has a Malay TTS voice."));
        body.addView(audio);

        if (settingsStatus != null) body.addView(paragraph(settingsStatus), matchMargins(0, 12, 0, 0));
    }

    private <T> void runTask(String loadingMessage, Work<T> work, Done<T> done) {
        Toast.makeText(this, loadingMessage, Toast.LENGTH_SHORT).show();
        executor.execute(() -> {
            try {
                T result = work.run();
                mainHandler.post(() -> done.accept(result));
            } catch (Exception e) {
                mainHandler.post(() -> {
                    Toast.makeText(this, message(e), Toast.LENGTH_LONG).show();
                    renderScreen();
                });
            }
        });
    }

    private void speakMalay(String text, boolean showMessage) {
        if (!canSpeakMalay || tts == null) {
            if (showMessage) {
                Toast.makeText(this, "No Malay system voice available. Audio is disabled.", Toast.LENGTH_SHORT).show();
            }
            return;
        }
        tts.speak(text == null ? "" : text, TextToSpeech.QUEUE_FLUSH, null, "malaymate-" + System.currentTimeMillis());
    }

    private boolean canPlayVisibleMalayAudio(DueReviewItem item) {
        return CardDirection.MALAY_TO_CHINESE.raw.equals(item.card.direction) || answerRevealed;
    }

    private boolean isSpellingPractice(DueReviewItem item) {
        return CardDirection.CHINESE_TO_MALAY.raw.equals(item.card.direction);
    }

    private String directionTitle(String raw) {
        if (CardDirection.MALAY_TO_CHINESE.raw.equals(raw)) return "Malay -> Chinese";
        if (CardDirection.CHINESE_TO_MALAY.raw.equals(raw)) return "Chinese -> Malay";
        return "Review";
    }

    private String spellingText(SpellingEvaluation evaluation) {
        switch (evaluation.result) {
            case CORRECT:
                return "拼写正确";
            case CLOSE:
                return "接近，差 " + evaluation.distance + " 处";
            case INCORRECT:
            default:
                return "拼写不对，先看正确答案";
        }
    }

    private String learningStatusText(LearningStatus status) {
        if (status == LearningStatus.NEW) return "新词";
        if (status == LearningStatus.MASTERED) return "已掌握";
        return "复习中";
    }

    private List<String> deckNames(List<DeckRecord> decks) {
        List<String> names = new ArrayList<>();
        names.add("All decks");
        for (DeckRecord deck : decks) names.add(deck.name);
        return names;
    }

    private int deckSelectionIndex(List<DeckRecord> decks, String selectedDeckId) {
        if (selectedDeckId == null) return 0;
        for (int i = 0; i < decks.size(); i++) {
            if (selectedDeckId.equals(decks.get(i).id)) return i + 1;
        }
        return 0;
    }

    private int sortIndex(String sort) {
        if ("term".equals(sort)) return 1;
        if ("status".equals(sort)) return 2;
        if ("createdNewest".equals(sort)) return 3;
        return 0;
    }

    private void resetLibraryPage() {
        libraryVisibleLimit = PAGE_SIZE;
        expandedWordIds.clear();
        libraryError = null;
        libraryLoadGate.clear();
    }

    private List<String> examplesFor(WordRecord word, int limit) {
        List<String> examples = new ArrayList<>();
        try {
            JSONArray array = new JSONArray(word.examplesJson == null ? "[]" : word.examplesJson);
            for (int i = 0; i < array.length() && examples.size() < limit; i++) {
                JSONObject object = array.getJSONObject(i);
                String malay = object.optString("malay", "");
                String chinese = object.optString("chinese", "");
                examples.add(joinNonEmpty(malay, chinese));
            }
        } catch (Exception ignored) {
        }
        return examples;
    }

    private String joinNonEmpty(String first, String second) {
        String left = first == null ? "" : first.trim();
        String right = second == null ? "" : second.trim();
        if (left.isEmpty()) return right;
        if (right.isEmpty()) return left;
        return left + "\n" + right;
    }

    private String formatTime(long millis) {
        return DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(new Date(millis));
    }

    private String message(Exception e) {
        String message = e.getMessage();
        return message == null || message.isEmpty() ? e.getClass().getSimpleName() : message;
    }

    private int statusBarInset() {
        int resourceId = getResources().getIdentifier("status_bar_height", "dimen", "android");
        return resourceId > 0 ? getResources().getDimensionPixelSize(resourceId) : dp(24);
    }

    private Typeface headingTypeface(String text) {
        return containsCjk(text) ? BODY_MEDIUM_TYPEFACE : DISPLAY_TYPEFACE;
    }

    private boolean containsCjk(String text) {
        if (text == null) return false;
        for (int i = 0; i < text.length(); i++) {
            char ch = text.charAt(i);
            if ((ch >= '\u3400' && ch <= '\u9FFF')
                    || (ch >= '\uF900' && ch <= '\uFAFF')
                    || (ch >= '\u3000' && ch <= '\u303F')) {
                return true;
            }
        }
        return false;
    }

    private boolean sameString(String left, String right) {
        if (left == null) return right == null;
        return left.equals(right);
    }

    private LinearLayout vertical() {
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        return layout;
    }

    private LinearLayout horizontal() {
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.HORIZONTAL);
        layout.setBaselineAligned(false);
        layout.setClipChildren(false);
        layout.setClipToPadding(false);
        layout.setGravity(Gravity.CENTER_VERTICAL);
        return layout;
    }

    private LinearLayout horizontalWrap() {
        LinearLayout layout = horizontal();
        return layout;
    }

    private LinearLayout card(LinearLayout content) {
        return panel(content, SURFACE, LINE);
    }

    private LinearLayout tintedCard(LinearLayout content) {
        return panel(content, SURFACE_TINT, Color.rgb(188, 211, 202));
    }

    private LinearLayout panel(LinearLayout content, int fill, int stroke) {
        content.setPadding(dp(18), dp(16), dp(18), dp(16));
        GradientDrawable background = new GradientDrawable();
        background.setColor(fill);
        background.setCornerRadius(dp(8));
        background.setStroke(dp(1), stroke);
        content.setBackground(background);
        return content;
    }

    private LinearLayout statusCard(String heading, String text) {
        LinearLayout box = tintedCard(vertical());
        box.addView(label(heading));
        box.addView(paragraph(text));
        return box;
    }

    private LinearLayout loadingCard(String text) {
        LinearLayout box = statusCard("Loading", text);
        box.setGravity(Gravity.CENTER_VERTICAL);
        return box;
    }

    private View divider() {
        View view = new View(this);
        view.setBackgroundColor(LINE);
        view.setLayoutParams(matchMargins(0, 12, 0, 12));
        return view;
    }

    private TextView title(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(containsCjk(text) ? 28 : 31);
        view.setTypeface(headingTypeface(text));
        view.setIncludeFontPadding(false);
        view.setTextColor(INK);
        view.setPadding(0, 0, 0, dp(6));
        return view;
    }

    private TextView subtitle(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(containsCjk(text) ? 20 : 21);
        view.setTypeface(headingTypeface(text));
        view.setLineSpacing(dp(1), 1.02f);
        view.setTextColor(INK);
        view.setPadding(0, dp(2), 0, dp(6));
        return view;
    }

    private TextView label(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(13);
        view.setTypeface(BODY_MEDIUM_TYPEFACE);
        view.setLineSpacing(dp(1), 1.0f);
        view.setTextColor(MUTED);
        view.setPadding(0, 0, 0, dp(6));
        return view;
    }

    private TextView paragraph(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(16);
        view.setTypeface(BODY_TYPEFACE);
        view.setTextColor(INK);
        view.setLineSpacing(dp(2), 1.05f);
        return view;
    }

    private TextView small(String text) {
        TextView view = paragraph(text);
        view.setTextSize(14);
        view.setTextColor(MUTED);
        return view;
    }

    private TextView button(String text) {
        TextView button = new LedgerButton();
        button.setText(text);
        button.setAllCaps(false);
        button.setMinHeight(dp(42));
        styleButton(button, false, false);
        return button;
    }

    private TextView primaryButton(String text) {
        TextView button = button(text);
        styleButton(button, true, false);
        return button;
    }

    private TextView optionButton(String text, boolean selected) {
        TextView button = button(text);
        styleButton(button, selected, true);
        return button;
    }

    private void styleButton(TextView button, boolean primary, boolean compact) {
        button.setBackgroundColor(Color.TRANSPARENT);
        if (button instanceof LedgerButton) {
            ((LedgerButton) button).setLedgerStyle(primary);
        }
        button.setTextColor(new ColorStateList(
                new int[][]{
                        new int[]{-android.R.attr.state_enabled},
                        new int[]{}
                },
                new int[]{
                        primary ? Color.WHITE : DISABLED,
                        primary ? Color.WHITE : INK
                }
        ));
        int minHeight = dp(compact ? 44 : 56);
        button.setGravity(Gravity.CENTER);
        button.setClickable(true);
        button.setFocusable(true);
        button.setMinHeight(minHeight);
        button.setMinimumHeight(minHeight);
        button.setHeight(minHeight);
        button.setIncludeFontPadding(true);
        button.setTypeface(BODY_MEDIUM_TYPEFACE);
        button.setTextSize(compact ? 13 : 15);
        button.setPadding(dp(10), dp(5), dp(10), dp(9));
    }

    private GradientDrawable rounded(int fill, int stroke) {
        GradientDrawable background = new GradientDrawable();
        background.setCornerRadius(dp(8));
        background.setColor(fill);
        background.setStroke(dp(1), stroke);
        return background;
    }

    private final class LedgerButton extends TextView {
        private final Paint shapePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF rect = new RectF();
        private boolean enabled = true;
        private boolean pressed;
        private boolean primary;

        LedgerButton() {
            super(MainActivity.this);
            setWillNotDraw(false);
        }

        void setLedgerStyle(boolean primary) {
            this.primary = primary;
            invalidate();
        }

        @Override
        protected void drawableStateChanged() {
            super.drawableStateChanged();
            boolean nextEnabled = isEnabled();
            boolean nextPressed = isPressed();
            boolean changed = nextEnabled != enabled || nextPressed != pressed;
            enabled = nextEnabled;
            pressed = nextPressed;
            if (changed) invalidate();
        }

        @Override
        protected void onDraw(Canvas canvas) {
            int fill;
            int stroke;
            if (!enabled) {
                fill = primary ? DISABLED : Color.rgb(235, 232, 222);
                stroke = LINE;
            } else if (pressed) {
                fill = primary ? JADE_DARK : SURFACE_TINT;
                stroke = primary ? JADE_DARK : Color.rgb(188, 211, 202);
            } else {
                fill = primary ? JADE : SURFACE;
                stroke = primary ? JADE : LINE;
            }

            float inset = dp(1);
            rect.set(inset, inset, getWidth() - inset, getHeight() - dp(6));
            float radius = dp(8);
            shapePaint.setStyle(Paint.Style.FILL);
            shapePaint.setColor(fill);
            canvas.drawRoundRect(rect, radius, radius, shapePaint);
            shapePaint.setStyle(Paint.Style.STROKE);
            shapePaint.setStrokeWidth(dp(1));
            shapePaint.setColor(stroke);
            canvas.drawRoundRect(rect, radius, radius, shapePaint);

            Paint textPaint = getPaint();
            textPaint.setTextAlign(Paint.Align.CENTER);
            textPaint.setColor(getCurrentTextColor());
            Paint.FontMetrics metrics = textPaint.getFontMetrics();
            float x = rect.centerX();
            float y = rect.centerY() - (metrics.ascent + metrics.descent) / 2f;
            canvas.drawText(getText().toString(), x, y, textPaint);
        }
    }

    private TextView navItem(String text, boolean selected) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setGravity(Gravity.CENTER);
        view.setTextSize(11);
        view.setTypeface(BODY_MEDIUM_TYPEFACE);
        view.setIncludeFontPadding(false);
        view.setMinHeight(dp(44));
        view.setTextColor(selected ? JADE_DARK : MUTED);
        view.setPadding(dp(4), 0, dp(4), 0);
        GradientDrawable background = new GradientDrawable();
        background.setCornerRadius(dp(8));
        background.setColor(selected ? SURFACE_TINT : Color.TRANSPARENT);
        view.setBackground(background);
        return view;
    }

    private TextView chip(String text) {
        TextView view = small(text);
        view.setGravity(Gravity.CENTER);
        view.setTextSize(13);
        view.setTypeface(BODY_MEDIUM_TYPEFACE);
        view.setIncludeFontPadding(false);
        boolean due = text != null && text.endsWith("due") && !text.startsWith("0 ");
        view.setTextColor(due ? Color.rgb(92, 59, 0) : JADE_DARK);
        view.setPadding(dp(11), dp(7), dp(11), dp(7));
        GradientDrawable background = new GradientDrawable();
        background.setCornerRadius(dp(999));
        background.setColor(due ? SAFFRON_SOFT : SURFACE_TINT);
        view.setBackground(background);
        return view;
    }

    private EditText input(String hint, String value, boolean multiline) {
        EditText input = new EditText(this);
        input.setHint(hint);
        input.setText(value == null ? "" : value);
        input.setSingleLine(!multiline);
        input.setTextSize(16);
        input.setTypeface(BODY_TYPEFACE);
        input.setTextColor(INK);
        input.setHintTextColor(MUTED);
        input.setPadding(dp(12), dp(9), dp(12), dp(9));
        input.setBackground(rounded(SURFACE, LINE));
        if (multiline) input.setGravity(Gravity.TOP | Gravity.START);
        return input;
    }

    private Spinner spinner(List<String> values) {
        ArrayAdapter<String> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_item, values);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        Spinner spinner = new Spinner(this);
        spinner.setAdapter(adapter);
        spinner.setBackground(rounded(SURFACE, LINE));
        return spinner;
    }

    private Spinner spinner(String[] values) {
        ArrayAdapter<String> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_item, values);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        Spinner spinner = new Spinner(this);
        spinner.setAdapter(adapter);
        spinner.setBackground(rounded(SURFACE, LINE));
        return spinner;
    }

    private List<String> optionLabels(List<LibraryUiOption> options) {
        List<String> labels = new ArrayList<>();
        for (LibraryUiOption option : options) labels.add(option.label);
        return labels;
    }

    private LinearLayout segmentedOptions(List<LibraryUiOption> options, String selectedValue, Done<String> onSelect) {
        LinearLayout row = horizontal();
        row.setBaselineAligned(false);
        for (LibraryUiOption option : options) {
            boolean selected = option.value.equals(selectedValue);
            TextView item = optionButton(option.label, selected);
            item.setOnClickListener(v -> {
                if (!selected) onSelect.accept(option.value);
            });
            row.addView(item, weightMargins(1f, 0, 0, 6, 0));
        }
        return row;
    }

    private LinearLayout metric(String label, String value) {
        LinearLayout box = card(vertical());
        box.addView(small(label));
        TextView number = new TextView(this);
        number.setText(value);
        number.setTextSize(29);
        number.setTypeface(DISPLAY_TYPEFACE);
        number.setIncludeFontPadding(false);
        number.setTextColor(JADE_DARK);
        number.setPadding(0, dp(8), 0, 0);
        box.addView(number);
        return box;
    }

    private LinearLayout metricGrid(LinearLayout first, LinearLayout second, LinearLayout third, LinearLayout fourth) {
        LinearLayout grid = vertical();
        LinearLayout top = horizontal();
        top.addView(first, weightMargins(1f, 0, 0, 6, 6));
        top.addView(second, weightMargins(1f, 6, 0, 0, 6));
        LinearLayout bottom = horizontal();
        bottom.addView(third, weightMargins(1f, 0, 6, 6, 0));
        bottom.addView(fourth, weightMargins(1f, 6, 6, 0, 0));
        grid.addView(top);
        grid.addView(bottom);
        return grid;
    }

    private LinearLayout.LayoutParams matchMargins(int left, int top, int right, int bottom) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        );
        params.setMargins(dp(left), dp(top), dp(right), dp(bottom));
        return params;
    }

    private LinearLayout.LayoutParams wrapMargins(int left, int top, int right, int bottom) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        );
        params.setMargins(dp(left), dp(top), dp(right), dp(bottom));
        return params;
    }

    private LinearLayout.LayoutParams weightMargins(float weight, int left, int top, int right, int bottom) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                weight
        );
        params.setMargins(dp(left), dp(top), dp(right), dp(bottom));
        return params;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private static final class LearnScreenData {
        final LearnPlan plan;
        final List<DeckRecord> decks;

        LearnScreenData(LearnPlan plan, List<DeckRecord> decks) {
            this.plan = plan;
            this.decks = decks;
        }
    }

    private static final class LibraryScreenData {
        final List<DeckRecord> decks;
        final LibraryBrowseResult result;

        LibraryScreenData(List<DeckRecord> decks, LibraryBrowseResult result) {
            this.decks = decks;
            this.result = result;
        }
    }
}
