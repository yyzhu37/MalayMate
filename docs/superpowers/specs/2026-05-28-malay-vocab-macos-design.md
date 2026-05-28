# Malay Vocabulary macOS App Design

Date: 2026-05-28
Status: Draft approved through brainstorming; awaiting written spec review

## Goal

Build a native macOS app for learning Malay vocabulary. The first version is a personal-use, local-first learning tool focused on vocabulary memory, AI-assisted enrichment, and spaced review.

The app should be usable without an API key or network, but should become more useful when an API key is configured.

## Product Scope

The MVP focuses on:

- Review-first daily vocabulary practice.
- Starter decks plus user-added personal words.
- Chinese-first explanations for Malay learners.
- Malay-to-Chinese recognition cards, with some Chinese-to-Malay recall cards.
- Simple Leitner scheduling with enough review history to support a later FSRS-style scheduler.
- Optional AI enrichment for definitions, examples, and exercises.
- Audio playback through macOS Malay text-to-speech when available.
- A local content build/import pipeline for open-access Malay vocabulary sources.

The MVP explicitly does not include:

- Speech recognition or pronunciation scoring.
- A full grammar course.
- Cloud sync or iOS support.
- FSRS/Anki-grade scheduling.
- Anki/CSV import.
- Bundled commercial dictionary or opaque scraped audio data.

## User Experience

The app opens directly into today's review queue. The main window uses a sidebar and a focused card area.

The sidebar contains:

- Today's due and new card counts.
- Starter decks.
- Personal word decks.
- Add Word.
- AI/content settings.

The card area shows one review card at a time:

- Prompt direction, such as Malay to Chinese or Chinese to Malay.
- The prompt word or meaning.
- Reveal answer.
- Optional play-audio button.
- Optional example sentence.
- `Again`, `Good`, and `Easy` rating buttons.

The primary habit loop is:

1. Open the app.
2. Start today's review.
3. Reveal each answer.
4. Rate it.
5. Let the scheduler update the next due date.
6. Add or enrich words only when needed.

## Architecture

Use a small SwiftUI macOS app with local-first data and optional network access.

Main modules:

- `SwiftUI Views`: `ReviewView`, `DecksView`, `AddWordView`, `SettingsView`.
- `App State`: `ReviewSession`, `DeckStore`, `SettingsStore`.
- `Services`: `Scheduler`, `AIProvider`, `TemplateGenerator`, `SpeechService`.
- `Persistence`: SwiftData-backed local store for decks, words, cards, review states, logs, and generated content cache.
- `ContentBuilder`: local scripts or tooling that generate starter data from open-access sources.

Views should stay thin. Scheduling, AI enrichment, content fallback, and speech playback should live behind small service interfaces.

## Data Model

Use separate models for words, cards, review state, and content provenance.

`Word`:

- `id`
- `term`
- `languageCode`, normally `ms` or `ms-MY`
- `chineseMeaning`
- `partOfSpeech`
- `pronunciationNotes`
- `syllables`
- `examples`
- `sourceRefs`
- `reviewStatus`
- `createdAt`
- `updatedAt`

`Card`:

- `id`
- `wordId`
- `direction`, such as `malayToChinese` or `chineseToMalay`
- `prompt`
- `answer`
- `hint`
- `createdAt`

`ReviewState`:

- `cardId`
- `box`
- `dueAt`
- `lapses`
- `lastReviewedAt`
- `easeHint`

`ReviewLog`:

- `id`
- `cardId`
- `rating`
- `reviewedAt`
- `previousBox`
- `nextBox`
- `previousDueAt`
- `nextDueAt`

`SourceRef`:

- `field`
- `sourceName`
- `sourceUrl`
- `license`
- `attribution`
- `retrievedAt`
- `reviewStatus`

This keeps user-facing vocabulary independent from review cards and preserves enough review history for later scheduler upgrades.

## Scheduling

Use a simple Leitner scheduler for the MVP.

Cards start in Box 1.

- `Again`: move to Box 1 and make due soon.
- `Good`: move up one box.
- `Easy`: move up two boxes.

Recommended initial intervals:

- Box 1: 10 minutes.
- Box 2: 1 day.
- Box 3: 3 days.
- Box 4: 7 days.
- Box 5: 14 days.
- Box 6: 30 days.

Exact intervals can be tuned during implementation, but the scheduler should be deterministic and covered by unit tests.

## AI And Offline Fallback

AI enrichment is optional.

Settings stores the API key in macOS Keychain. If no key exists, the app remains fully usable with local starter data and deterministic templates.

AI can generate:

- Chinese explanations.
- Simple Malay example sentences.
- Practice prompts.
- Distractors for quiz-style exercises.
- Pronunciation tips for user-added words.

AI output should be structured before saving. Generated fields should be cached and marked with source metadata, such as `aiGenerated`, model name if available, and review status.

If AI fails:

- The word still saves.
- The app falls back to manual fields or templates.
- The word can be marked `needsEnrichment`.
- The user can retry enrichment later.

## Content Sources

Because this app is for personal use, the MVP can use open-access sources more aggressively than a commercial app would. The design should still preserve source metadata so data remains auditable and future sharing is not impossible.

Recommended sources:

- Leipzig Corpora Collection Malay corpora for frequency-ranked candidate words.
- Wiktionary and Kaikki Wiktionary extraction for machine-readable dictionary data.
- Tatoeba for example sentences and sentence pairs.
- Mozilla Common Voice Malay for optional sentence audio or later listening features.
- macOS system speech voices for reliable live playback of words and examples.

The content strategy is:

1. Use frequency data to pick candidate words.
2. Enrich candidates with dictionary fields where available.
3. Add Chinese meanings through available translations, AI generation, or manual correction.
4. Add examples from Tatoeba or templates.
5. Store field-level source and license information.
6. Generate a bundled `starter_deck.json` plus a source manifest for the app.

The app should avoid copying commercial dictionary data or bundling files from unknown sources. For personal use, permissive and attribution-based sources are acceptable, but every imported source should be recorded.

## Pronunciation And Audio

Malay spelling is relatively regular, so the MVP should not depend on a large pronunciation database.

Pronunciation data:

- Starter words can include syllable breakdown and simple pronunciation notes.
- Ambiguous items can include manual overrides.
- AI can suggest pronunciation notes for user-added words, but they should be marked as generated.

Audio:

- Use `AVSpeechSynthesizer` for live playback.
- Prefer a Malay voice such as `Amira` with language `ms_MY` when available.
- If no Malay voice exists, disable or hide the audio button and guide the user to install a Malay system voice.
- Do not bundle thousands of audio files in the MVP.

Common Voice and Tatoeba audio can be explored later for listening practice, but audio licensing and attribution should be handled per item before bundling anything.

## Error Handling

Errors should not interrupt the daily review loop when a fallback exists.

Expected behavior:

- Missing API key: use local templates and show AI as unavailable.
- Invalid API key: show a settings warning and keep review usable.
- Network failure: save the word locally and mark it for retry.
- Malformed AI response: reject generated fields and use templates.
- Missing Malay voice: disable playback and show setup guidance.
- Local data issue: avoid crashing the review screen; surface a recoverable error and preserve data when possible.

## Testing

Unit tests:

- Leitner scheduler transitions.
- Due-card ordering.
- New-card selection.
- Review log creation.
- Template fallback output.
- AI response parsing.
- Source metadata preservation.

Persistence tests:

- Save and reload words, cards, review states, and logs.
- App restart preserves review progress.
- Content seed import creates expected decks and cards.

Manual QA:

- First launch with starter deck.
- Daily review loop.
- Add a word with no API key.
- Add a word with valid API key.
- Bad API key path.
- Missing Malay voice path.
- Restart app and continue review.

## Implementation Notes

Use SwiftUI, SwiftData, Keychain, and native macOS frameworks. The `ContentBuilder` should output bundled JSON files, and the app should import them into SwiftData on first launch. The data model should not be tied to UI state.

The first implementation should optimize for a working personal tool rather than a polished distributable product.

## References

- Leipzig Corpora Collection Malay: https://corpora.uni-leipzig.de/en?corpusId=msa-sg_web_2019
- Wiktionary Malay frequency lists: https://en.wiktionary.org/wiki/Wiktionary:Frequency_lists/Malay
- Kaikki Wiktionary extraction: https://kaikki.org/mswiktionary/index.html
- Tatoeba downloads: https://tatoeba.org/gos/downloads
- Mozilla Common Voice Malay: https://datacollective.mozillafoundation.org/datasets/cmn29sqde018umm071bb6u1ot
- Apple speech voice setup: https://support.apple.com/en-lamr/guide/mac-help/mchlp2290
