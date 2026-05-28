# MalayMate 3000-Word Learning Loop Design

Date: 2026-05-28
Status: Approved for implementation

## Goal

Improve MalayMate from a small vocabulary prototype into a usable personal Malay study app with a 3000-word starter library, clear daily learning entry points, spaced review, search-friendly vocabulary browsing, and reliable audio fallback.

## Scope

This iteration includes:

- Expand the generated open-dictionary starter deck from 300 to 3000 words.
- Keep the authored starter deck and generated open deck imported together.
- Preserve first-launch and incremental seed import behavior for existing local databases.
- Improve Library so 3000 words remain browsable with search, status filtering, sorting, and a display limit.
- Keep Today, Learn, and Review as the primary learning loop.
- Replace the fixed Leitner interval table with an SM-2-lite scheduler using existing review state fields.
- Improve review feedback by showing the next scheduled review time after rating.
- Preserve macOS text-to-speech as the reliable audio path.
- Capture open-dictionary source audio URLs in seed source metadata when available, without bundling audio files yet.

This iteration does not include:

- Cloud sync.
- Account login.
- Pronunciation scoring.
- Downloading or caching thousands of audio files.
- Full AI tutor chat.
- A full grammar curriculum.

## User Flow

The app opens to Today. Today shows due review count, learned-today count, remaining new-word slots, and available new words. The main actions are Learn and Review.

Learn lets the user choose a deck, set the daily new-word limit, inspect one new word at a time, play TTS audio, skip it, or mark it learned. Marking a word learned moves its cards into the review queue after the first short delay.

Review shows due cards, supports recognition and spelling practice, reveals the answer, lets the user rate Again, Good, or Easy, then schedules the next review with SM-2-lite.

Library shows all decks and words. At 3000 words, it must support quick search and filtering instead of forcing the user to scroll through every expanded detail row.

## Content Pipeline

The generated starter deck is built from local open-source inputs:

- `content/cache/kaikki-malay.jsonl`
- `content/cache/ms_50k.txt`
- `content/raw/sample_dictionary.jsonl`
- `content/raw/sample_sentences.tsv`

The extraction script selects 3000 frequency-ranked entries from Kaikki/Wiktionary, excluding authored starter terms. The build script generates `content/generated/starter_deck.json`; the same JSON is copied into `Sources/MalayMateCore/Resources/open_frequency_starter_deck.json`.

The generated deck name should reflect the size: `Open Dictionary Malay 3000`.

## Scheduling

Use SM-2-lite with the existing `ReviewStateRecord` fields:

- `box` represents repetition stage, capped at 10.
- `easeHint` stores the ease factor, defaulting to 2.5 for new learned cards.
- `lapses` counts Again ratings.
- `lastReviewedAt` records the latest review.

Ratings map to quality:

- Again: reset to stage 1, reduce ease, due again in 10 minutes.
- Good: advance one stage, use the current ease factor.
- Easy: advance two stages, increase ease and schedule a longer interval.

The scheduler remains deterministic and unit-tested.

## Library

Library should avoid rendering all word details by default. It should:

- Search term, Chinese meaning, part of speech, and pronunciation notes.
- Filter by learning status: all, new, in review, mastered.
- Sort by deck order, term, status, or created date.
- Limit the visible rows with a "show more" action.
- Keep disclosure rows for examples, but only render them for visible rows.

## Audio

MalayMate continues to use `AVSpeechSynthesizer` as the stable audio path. Kaikki/Wiktionary source audio URLs should be preserved in source metadata under the `audio` field when available. This keeps the data ready for a future source-audio-first player without introducing network playback or local audio caching in this iteration.

## Testing

Required verification:

- Python content builder tests pass.
- Generated content test verifies 3000 generated words and 6000 generated cards.
- Bundled seed import test verifies 3006 total words and 6012 total cards.
- Scheduler tests cover Again, Good, Easy, ease changes, and interval growth.
- Library tests cover search/filter/sort/display-limit behavior.
- Swift test suite passes.
- App bundle builds and codesign verification passes.
