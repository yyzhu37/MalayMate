package com.malaymate;

import org.junit.Test;

import static org.junit.Assert.*;

public class DomainLogicTest {
    @Test
    public void leitnerSchedulesAgainGoodAndEasyLikeMacApp() {
        ReviewState state = new ReviewState("card-1", 2, 1_000L, 0, 500L, LeitnerScheduler.DEFAULT_EASE);
        LeitnerScheduler scheduler = new LeitnerScheduler();

        ReviewUpdate again = scheduler.update(state, ReviewRating.AGAIN, 10_000L);
        assertEquals(1, again.nextBox);
        assertEquals(1, again.lapses);
        assertEquals(610_000L, again.nextDueAt);
        assertEquals(2.3, again.easeHint, 0.0001);

        ReviewUpdate good = scheduler.update(state, ReviewRating.GOOD, 10_000L);
        assertEquals(3, good.nextBox);
        assertEquals(518_410_000L, good.nextDueAt);

        ReviewUpdate easy = scheduler.update(state, ReviewRating.EASY, 10_000L);
        assertEquals(4, easy.nextBox);
        assertEquals(1_785_898_000L, easy.nextDueAt);
        assertEquals(2.65, easy.easeHint, 0.0001);
    }

    @Test
    public void spellingEvaluatorMatchesMacNormalizationAndCloseThresholds() {
        SpellingEvaluation correct = SpellingEvaluator.evaluate("  MAKAN!! ", "makan");
        assertEquals(SpellingResult.CORRECT, correct.result);
        assertEquals("makan", correct.normalizedAnswer);

        SpellingEvaluation closeShort = SpellingEvaluator.evaluate("makam", "makan");
        assertEquals(SpellingResult.CLOSE, closeShort.result);
        assertEquals(1, closeShort.distance);

        SpellingEvaluation closeLong = SpellingEvaluator.evaluate("selamatt", "selamat");
        assertEquals(SpellingResult.CLOSE, closeLong.result);

        SpellingEvaluation incorrect = SpellingEvaluator.evaluate("air", "makan");
        assertEquals(SpellingResult.INCORRECT, incorrect.result);
    }

    @Test
    public void reviewQueueRemovesReviewedCardByIdInsteadOfPosition() {
        DueReviewItem first = dueItem("card-1");
        DueReviewItem second = dueItem("card-2");
        java.util.List<DueReviewItem> queue = new java.util.ArrayList<>();
        queue.add(first);
        queue.add(second);

        assertTrue(ReviewQueue.removeCard(queue, "card-2"));

        assertEquals(1, queue.size());
        assertEquals("card-1", queue.get(0).card.id);
    }

    @Test
    public void autoRefreshMatchesMacReviewAndTodayBehavior() {
        assertEquals(AutoRefreshAction.RENDER_SCREEN,
                AutoRefreshPolicy.actionFor(RefreshSurface.TODAY, true, false, 3));
        assertEquals(AutoRefreshAction.LOAD_REVIEWS,
                AutoRefreshPolicy.actionFor(RefreshSurface.REVIEW, true, false, 0));
        assertEquals(AutoRefreshAction.NONE,
                AutoRefreshPolicy.actionFor(RefreshSurface.REVIEW, true, false, 2));
        assertEquals(AutoRefreshAction.NONE,
                AutoRefreshPolicy.actionFor(RefreshSurface.LIBRARY, true, false, 0));
    }

    @Test
    public void loadStateDoesNotAutoRetryAfterErrorUntilUserRetries() {
        LoadGate loading = new LoadGate();

        assertTrue(loading.shouldStart(null, false, null, "current"));
        loading.start("current");
        assertFalse(loading.shouldStart(null, true, null, "current"));
        loading.fail("current", "Could not load.");

        assertFalse(loading.shouldStart(null, false, "Could not load.", "current"));
        loading.clear();
        assertTrue(loading.shouldStart(null, false, null, "current"));
    }

    @Test
    public void mobileNavigationUsesFourPrimaryTabsAndMoreForSecondaryScreens() {
        java.util.List<MobileNavItem> today = MobileNavigation.bottomItems(AppScreen.TODAY);

        assertEquals(5, today.size());
        assertEquals(AppScreen.TODAY, today.get(0).screen);
        assertEquals("Today", today.get(0).label);
        assertTrue(today.get(0).selected);
        assertEquals(AppScreen.LEARN, today.get(1).screen);
        assertEquals(AppScreen.REVIEW, today.get(2).screen);
        assertEquals(AppScreen.LIBRARY, today.get(3).screen);
        assertNull(today.get(4).screen);
        assertEquals("More", today.get(4).label);
        assertFalse(today.get(4).selected);

        java.util.List<MobileNavItem> settings = MobileNavigation.bottomItems(AppScreen.SETTINGS);
        assertTrue(settings.get(4).selected);
        assertEquals(AppScreen.ADD_WORD, MobileNavigation.moreItems().get(0).screen);
        assertEquals(AppScreen.SETTINGS, MobileNavigation.moreItems().get(1).screen);
    }

    @Test
    public void libraryOptionsExposeSegmentedStatusAndSortLabels() {
        java.util.List<LibraryUiOption> statuses = LibraryUiOptions.statusFilters();
        assertEquals("all", statuses.get(0).value);
        assertEquals("全部", statuses.get(0).label);
        assertEquals("new", statuses.get(1).value);
        assertEquals("新词", statuses.get(1).label);
        assertEquals("inReview", statuses.get(2).value);
        assertEquals("复习中", statuses.get(2).label);
        assertEquals("mastered", statuses.get(3).value);
        assertEquals("已掌握", statuses.get(3).label);

        java.util.List<LibraryUiOption> sorts = LibraryUiOptions.sorts();
        assertEquals("deckOrder", sorts.get(0).value);
        assertEquals("词库顺序", sorts.get(0).label);
        assertEquals("createdNewest", sorts.get(3).value);
        assertEquals("新添加", sorts.get(3).label);
    }

    private static DueReviewItem dueItem(String cardId) {
        DueReviewItem item = new DueReviewItem();
        item.card = new CardRecord();
        item.card.id = cardId;
        return item;
    }
}
