# MalayMate 3000-Word Learning Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand MalayMate to a 3000-word starter library and strengthen the daily learn/review loop.

**Architecture:** Keep the existing Swift Package split: `MalayMateCore` owns content import, scheduling, learning, library search, and tests; `MalayMate` owns SwiftUI screens. Reuse existing SwiftData records and evolve behavior through deterministic service functions so unit tests cover the risky parts.

**Tech Stack:** Swift 6.3, SwiftUI, SwiftData, AVFoundation, XCTest, Python 3 local content scripts.

---

### Task 1: Update Spec And Plan

**Files:**
- Modify: `docs/superpowers/specs/2026-05-28-malay-vocab-macos-design.md`
- Modify: `docs/superpowers/plans/2026-05-28-malay-vocab-macos-implementation.md`

- [ ] Write the approved scope into the design doc.
- [ ] Write this implementation plan.
- [ ] Review both files for placeholders and contradictions.

### Task 2: Expand Generated Content To 3000 Words

**Files:**
- Modify: `scripts/extract_kaikki_dictionary.py`
- Modify: `scripts/build_starter_deck.py`
- Modify: `scripts/test_content_builder.py`
- Modify: `content/raw/kaikki_malay_dictionary.jsonl`
- Modify: `content/raw/kaikki_selection.tsv`
- Modify: `content/generated/starter_deck.json`
- Modify: `Sources/MalayMateCore/Resources/open_frequency_starter_deck.json`
- Modify: `Tests/MalayMateCoreTests/GeneratedContentTests.swift`
- Modify: `Tests/MalayMateCoreTests/SeedImporterTests.swift`

- [ ] Preserve source audio URLs in extracted dictionary rows when Kaikki provides `mp3_url` or `ogg_url`.
- [ ] Generate 3000 open-dictionary rows excluding authored starter terms.
- [ ] Build `Open Dictionary Malay 3000`.
- [ ] Update Swift tests from 300/600 generated records to 3000/6000 and 3006/6012 bundled records.
- [ ] Run Python content tests and generated content Swift tests.

### Task 3: Replace Fixed Leitner Scheduling With SM-2 Lite

**Files:**
- Modify: `Sources/MalayMateCore/Domain/LeitnerScheduler.swift`
- Modify: `Sources/MalayMateCore/Domain/ReviewSnapshot.swift`
- Modify: `Sources/MalayMateCore/Learning/LearnSession.swift`
- Modify: `Sources/MalayMateCore/Review/ReviewSession.swift`
- Modify: `Tests/MalayMateCoreTests/LeitnerSchedulerTests.swift`
- Modify: `Tests/MalayMateCoreTests/LearnSessionTests.swift`
- Modify: `Tests/MalayMateCoreTests/ReviewSessionTests.swift`

- [ ] Treat `box` as the repetition stage and cap it at 10.
- [ ] Initialize learned cards with ease `2.5`.
- [ ] Map Again to a 10-minute relearn interval and ease reduction.
- [ ] Map Good to stage +1 and interval growth.
- [ ] Map Easy to stage +2 and ease increase.
- [ ] Keep `ReviewSession` log creation unchanged except for updated interval/ease expectations.

### Task 4: Make Library Usable At 3000 Words

**Files:**
- Modify: `Sources/MalayMateCore/Library/VocabularyLibrary.swift`
- Modify: `Sources/MalayMate/Views/LibraryView.swift`
- Modify: `Tests/MalayMateCoreTests/VocabularyLibraryTests.swift`

- [ ] Add a query/filter/sort/page helper in `VocabularyLibrary`.
- [ ] Add search, learning-status filter, sort picker, and "show more" in LibraryView.
- [ ] Keep deck-specific browsing and all-deck browsing working.
- [ ] Test search, status filtering, sorting, and display limit.

### Task 5: Improve Review Feedback And Audio Metadata

**Files:**
- Modify: `Sources/MalayMate/Views/ReviewView.swift`
- Modify: `scripts/extract_kaikki_dictionary.py`
- Modify: `scripts/build_starter_deck.py`
- Modify: `scripts/test_content_builder.py`

- [ ] Show a concise next-review message after rating.
- [ ] Store source audio URL metadata in generated seed source refs.
- [ ] Do not add network audio playback yet; TTS remains the active player.

### Task 6: Verify, Bundle, Launch, Commit

**Commands:**
- `python3 -m unittest scripts/test_content_builder.py`
- `swift test`
- `scripts/build_app_bundle.sh`
- `codesign --verify --deep --strict --verbose=2 build/MalayMate.app`

- [ ] Run all verification commands.
- [ ] Relaunch `build/MalayMate.app` if possible and verify process starts.
- [ ] Commit the completed changes.
