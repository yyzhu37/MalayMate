# Malay Vocabulary macOS App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local-first native macOS app for Malay vocabulary review, starter decks, personal words, AI-assisted enrichment, and macOS TTS playback.

**Architecture:** Use a Swift Package with a testable `MalayMateCore` library target and a `MalayMate` SwiftUI executable target. Core owns domain models, SwiftData records, scheduling, content import, AI, Keychain settings, and speech selection. The app target owns SwiftUI views and wires services together.

**Tech Stack:** Swift 6.3, macOS 14+, SwiftUI, SwiftData, AVFoundation, Security framework, XCTest, Python 3 for local content building.

---

## File Structure

- Create: `Package.swift` - Swift Package manifest with `MalayMateCore`, `MalayMate`, and `MalayMateCoreTests`.
- Create: `Sources/MalayMate/MalayMateApp.swift` - macOS SwiftUI app entry point.
- Create: `Sources/MalayMate/Views/ContentView.swift` - root review-first window.
- Create: `Sources/MalayMate/Views/SidebarView.swift` - today's counts, deck list, add word, settings navigation.
- Create: `Sources/MalayMate/Views/ReviewView.swift` - current card prompt, reveal, rating buttons, audio button.
- Create: `Sources/MalayMate/Views/AddWordView.swift` - personal word form and enrichment state.
- Create: `Sources/MalayMate/Views/SettingsView.swift` - API key, model, audio voice status.
- Create: `Sources/MalayMateCore/PackageAnchor.swift` - package import smoke-test anchor.
- Create: `Sources/MalayMateCore/Domain/CardDirection.swift` - review direction enum.
- Create: `Sources/MalayMateCore/Domain/ReviewRating.swift` - Again, Good, Easy enum.
- Create: `Sources/MalayMateCore/Domain/ReviewSnapshot.swift` - scheduler input and output structs.
- Create: `Sources/MalayMateCore/Domain/LeitnerScheduler.swift` - deterministic Leitner scheduler.
- Create: `Sources/MalayMateCore/Content/SeedModels.swift` - Codable bundled starter deck schema.
- Create: `Sources/MalayMateCore/Content/SeedImporter.swift` - first-launch seed import into SwiftData.
- Create: `Sources/MalayMateCore/Content/TemplateGenerator.swift` - no-key fallback content generation.
- Create: `Sources/MalayMateCore/Content/AddWordService.swift` - add personal word with AI or template fallback.
- Create: `Sources/MalayMateCore/Persistence/Records.swift` - SwiftData `@Model` records.
- Create: `Sources/MalayMateCore/Persistence/ModelContainerFactory.swift` - app and test container setup.
- Create: `Sources/MalayMateCore/Review/ReviewSession.swift` - due-card query and rating application.
- Create: `Sources/MalayMateCore/AI/AIProvider.swift` - AI provider protocol and enrichment model.
- Create: `Sources/MalayMateCore/AI/OpenAIClient.swift` - Responses API client with structured output parsing.
- Create: `Sources/MalayMateCore/Settings/KeychainStore.swift` - macOS Keychain wrapper for API key storage.
- Create: `Sources/MalayMateCore/Settings/SettingsStore.swift` - model name, key availability, and AI settings.
- Create: `Sources/MalayMateCore/Speech/SpeechService.swift` - Malay voice detection and playback.
- Create: `Sources/MalayMateCore/Resources/starter_deck.json` - bundled starter deck.
- Create: `scripts/build_starter_deck.py` - local content builder for open-access sources.
- Create: `scripts/build_app_bundle.sh` - release `.app` bundle wrapper for the Swift executable.
- Create tests under `Tests/MalayMateCoreTests/` matching each service.

---

### Task 1: Swift Package Scaffold And Running App Shell

**Files:**
- Create: `Package.swift`
- Create: `Sources/MalayMateCore/PackageAnchor.swift`
- Create: `Sources/MalayMateCore/Resources/.gitkeep`
- Create: `Sources/MalayMate/MalayMateApp.swift`
- Create: `Sources/MalayMate/Views/ContentView.swift`
- Create: `Tests/MalayMateCoreTests/Fixtures/.gitkeep`
- Test: `Tests/MalayMateCoreTests/PackageSmokeTests.swift`

- [ ] **Step 1: Create the package manifest and core anchor**

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MalayMate",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MalayMateCore", targets: ["MalayMateCore"]),
        .executable(name: "MalayMate", targets: ["MalayMate"])
    ],
    targets: [
        .target(
            name: "MalayMateCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "MalayMate",
            dependencies: ["MalayMateCore"]
        ),
        .testTarget(
            name: "MalayMateCoreTests",
            dependencies: ["MalayMateCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
```

```swift
// Sources/MalayMateCore/PackageAnchor.swift
public enum PackageAnchor {
    public static let name = "MalayMateCore"
}
```

Create empty resource sentinels so the package manifest paths exist before starter data is added:

```text
Sources/MalayMateCore/Resources/.gitkeep
Tests/MalayMateCoreTests/Fixtures/.gitkeep
```

- [ ] **Step 2: Write the package smoke test**

```swift
// Tests/MalayMateCoreTests/PackageSmokeTests.swift
import XCTest
@testable import MalayMateCore

final class PackageSmokeTests: XCTestCase {
    func testCoreTargetIsImportable() {
        XCTAssertEqual(PackageAnchor.name, "MalayMateCore")
    }
}
```

- [ ] **Step 3: Run the smoke test**

Run: `swift test --filter PackageSmokeTests`

Expected: PASS.

- [ ] **Step 4: Add the minimal SwiftUI app shell**

```swift
// Sources/MalayMate/MalayMateApp.swift
import SwiftUI

@main
struct MalayMateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 560)
        }
    }
}
```

```swift
// Sources/MalayMate/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Section("Today") {
                    Label("Review", systemImage: "rectangle.stack")
                    Label("Add Word", systemImage: "plus.circle")
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .navigationTitle("MalayMate")
        } detail: {
            VStack(spacing: 16) {
                Text("MalayMate")
                    .font(.largeTitle.weight(.semibold))
                Text("Review-first Malay vocabulary practice")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
```

- [ ] **Step 5: Verify the app target builds**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "feat: scaffold MalayMate Swift package"
```

---

### Task 2: Starter Deck Schema And Bundled Resource

**Files:**
- Create: `Sources/MalayMateCore/Content/SeedModels.swift`
- Create: `Sources/MalayMateCore/Resources/starter_deck.json`
- Test: `Tests/MalayMateCoreTests/SeedModelsTests.swift`

- [ ] **Step 1: Write the failing seed decoding test**

```swift
// Tests/MalayMateCoreTests/SeedModelsTests.swift
import XCTest
@testable import MalayMateCore

final class SeedModelsTests: XCTestCase {
    func testBundledStarterDeckDecodes() throws {
        let data = try SeedResource.bundledStarterDeckData()
        let collection = try JSONDecoder.seedDecoder.decode(SeedDeckCollection.self, from: data)

        XCTAssertEqual(collection.version, 1)
        XCTAssertGreaterThanOrEqual(collection.decks.count, 2)
        XCTAssertTrue(collection.decks.flatMap(\.words).contains { $0.term == "makan" })
        XCTAssertTrue(collection.decks.flatMap(\.words).allSatisfy { !$0.sourceRefs.isEmpty })
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter SeedModelsTests`

Expected: FAIL with `cannot find 'SeedDeckCollection' in scope` or missing resource.

- [ ] **Step 3: Implement the seed models**

```swift
// Sources/MalayMateCore/Content/SeedModels.swift
import Foundation

public struct SeedDeckCollection: Codable, Equatable {
    public var version: Int
    public var generatedAt: Date
    public var decks: [SeedDeck]
}

public struct SeedDeck: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var isStarter: Bool
    public var words: [SeedWord]
}

public struct SeedWord: Codable, Equatable, Identifiable {
    public var id: String
    public var term: String
    public var languageCode: String
    public var chineseMeaning: String
    public var partOfSpeech: String
    public var pronunciationNotes: String
    public var syllables: [String]
    public var examples: [SeedExample]
    public var sourceRefs: [SeedSourceRef]
}

public struct SeedExample: Codable, Equatable, Identifiable {
    public var id: String
    public var malay: String
    public var chinese: String
    public var sourceRefs: [SeedSourceRef]
}

public struct SeedSourceRef: Codable, Equatable {
    public var field: String
    public var sourceName: String
    public var sourceUrl: String
    public var license: String
    public var attribution: String
    public var retrievedAt: Date
    public var reviewStatus: String
}

public extension JSONDecoder {
    static var seedDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public extension JSONEncoder {
    static var seedEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

public enum SeedResource {
    public static func bundledStarterDeckData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "starter_deck", withExtension: "json") else {
            throw SeedResourceError.missingBundledStarterDeck
        }
        return try Data(contentsOf: url)
    }
}

public enum SeedResourceError: Error, Equatable {
    case missingBundledStarterDeck
}
```

- [ ] **Step 4: Add the bundled starter deck**

```json
{
  "version": 1,
  "generatedAt": "2026-05-28T00:00:00Z",
  "decks": [
    {
      "id": "starter-basics",
      "name": "Starter Basics",
      "description": "Core Malay words for daily recognition practice.",
      "isStarter": true,
      "words": [
        {
          "id": "starter-basics-makan",
          "term": "makan",
          "languageCode": "ms-MY",
          "chineseMeaning": "吃；进食",
          "partOfSpeech": "verb",
          "pronunciationNotes": "ma-kan; both syllables are clear and short",
          "syllables": ["ma", "kan"],
          "examples": [
            {
              "id": "starter-basics-makan-example-1",
              "malay": "Saya makan nasi.",
              "chinese": "我吃米饭。",
              "sourceRefs": [
                {
                  "field": "example",
                  "sourceName": "MalayMate starter template",
                  "sourceUrl": "local://starter-template",
                  "license": "personal-use-local",
                  "attribution": "MalayMate generated starter content",
                  "retrievedAt": "2026-05-28T00:00:00Z",
                  "reviewStatus": "reviewed"
                }
              ]
            }
          ],
          "sourceRefs": [
            {
              "field": "term",
              "sourceName": "MalayMate curated starter list",
              "sourceUrl": "local://starter-list",
              "license": "personal-use-local",
              "attribution": "MalayMate curated starter content",
              "retrievedAt": "2026-05-28T00:00:00Z",
              "reviewStatus": "reviewed"
            }
          ]
        },
        {
          "id": "starter-basics-minum",
          "term": "minum",
          "languageCode": "ms-MY",
          "chineseMeaning": "喝；饮用",
          "partOfSpeech": "verb",
          "pronunciationNotes": "mi-num",
          "syllables": ["mi", "num"],
          "examples": [
            {
              "id": "starter-basics-minum-example-1",
              "malay": "Saya minum air.",
              "chinese": "我喝水。",
              "sourceRefs": [
                {
                  "field": "example",
                  "sourceName": "MalayMate starter template",
                  "sourceUrl": "local://starter-template",
                  "license": "personal-use-local",
                  "attribution": "MalayMate generated starter content",
                  "retrievedAt": "2026-05-28T00:00:00Z",
                  "reviewStatus": "reviewed"
                }
              ]
            }
          ],
          "sourceRefs": [
            {
              "field": "term",
              "sourceName": "MalayMate curated starter list",
              "sourceUrl": "local://starter-list",
              "license": "personal-use-local",
              "attribution": "MalayMate curated starter content",
              "retrievedAt": "2026-05-28T00:00:00Z",
              "reviewStatus": "reviewed"
            }
          ]
        },
        {
          "id": "starter-basics-air",
          "term": "air",
          "languageCode": "ms-MY",
          "chineseMeaning": "水",
          "partOfSpeech": "noun",
          "pronunciationNotes": "a-ir; Malay air means water",
          "syllables": ["a", "ir"],
          "examples": [
            {
              "id": "starter-basics-air-example-1",
              "malay": "Ini air.",
              "chinese": "这是水。",
              "sourceRefs": [
                {
                  "field": "example",
                  "sourceName": "MalayMate starter template",
                  "sourceUrl": "local://starter-template",
                  "license": "personal-use-local",
                  "attribution": "MalayMate generated starter content",
                  "retrievedAt": "2026-05-28T00:00:00Z",
                  "reviewStatus": "reviewed"
                }
              ]
            }
          ],
          "sourceRefs": [
            {
              "field": "term",
              "sourceName": "MalayMate curated starter list",
              "sourceUrl": "local://starter-list",
              "license": "personal-use-local",
              "attribution": "MalayMate curated starter content",
              "retrievedAt": "2026-05-28T00:00:00Z",
              "reviewStatus": "reviewed"
            }
          ]
        },
        {
          "id": "starter-basics-saya",
          "term": "saya",
          "languageCode": "ms-MY",
          "chineseMeaning": "我",
          "partOfSpeech": "pronoun",
          "pronunciationNotes": "sa-ya",
          "syllables": ["sa", "ya"],
          "examples": [
            {
              "id": "starter-basics-saya-example-1",
              "malay": "Saya belajar.",
              "chinese": "我学习。",
              "sourceRefs": [
                {
                  "field": "example",
                  "sourceName": "MalayMate starter template",
                  "sourceUrl": "local://starter-template",
                  "license": "personal-use-local",
                  "attribution": "MalayMate generated starter content",
                  "retrievedAt": "2026-05-28T00:00:00Z",
                  "reviewStatus": "reviewed"
                }
              ]
            }
          ],
          "sourceRefs": [
            {
              "field": "term",
              "sourceName": "MalayMate curated starter list",
              "sourceUrl": "local://starter-list",
              "license": "personal-use-local",
              "attribution": "MalayMate curated starter content",
              "retrievedAt": "2026-05-28T00:00:00Z",
              "reviewStatus": "reviewed"
            }
          ]
        }
      ]
    },
    {
      "id": "starter-food",
      "name": "Food And Daily Life",
      "description": "Food and daily words used in simple examples.",
      "isStarter": true,
      "words": [
        {
          "id": "starter-food-nasi",
          "term": "nasi",
          "languageCode": "ms-MY",
          "chineseMeaning": "米饭",
          "partOfSpeech": "noun",
          "pronunciationNotes": "na-si",
          "syllables": ["na", "si"],
          "examples": [
            {
              "id": "starter-food-nasi-example-1",
              "malay": "Nasi ini panas.",
              "chinese": "这份米饭是热的。",
              "sourceRefs": [
                {
                  "field": "example",
                  "sourceName": "MalayMate starter template",
                  "sourceUrl": "local://starter-template",
                  "license": "personal-use-local",
                  "attribution": "MalayMate generated starter content",
                  "retrievedAt": "2026-05-28T00:00:00Z",
                  "reviewStatus": "reviewed"
                }
              ]
            }
          ],
          "sourceRefs": [
            {
              "field": "term",
              "sourceName": "MalayMate curated starter list",
              "sourceUrl": "local://starter-list",
              "license": "personal-use-local",
              "attribution": "MalayMate curated starter content",
              "retrievedAt": "2026-05-28T00:00:00Z",
              "reviewStatus": "reviewed"
            }
          ]
        },
        {
          "id": "starter-food-kopi",
          "term": "kopi",
          "languageCode": "ms-MY",
          "chineseMeaning": "咖啡",
          "partOfSpeech": "noun",
          "pronunciationNotes": "ko-pi",
          "syllables": ["ko", "pi"],
          "examples": [
            {
              "id": "starter-food-kopi-example-1",
              "malay": "Saya minum kopi.",
              "chinese": "我喝咖啡。",
              "sourceRefs": [
                {
                  "field": "example",
                  "sourceName": "MalayMate starter template",
                  "sourceUrl": "local://starter-template",
                  "license": "personal-use-local",
                  "attribution": "MalayMate generated starter content",
                  "retrievedAt": "2026-05-28T00:00:00Z",
                  "reviewStatus": "reviewed"
                }
              ]
            }
          ],
          "sourceRefs": [
            {
              "field": "term",
              "sourceName": "MalayMate curated starter list",
              "sourceUrl": "local://starter-list",
              "license": "personal-use-local",
              "attribution": "MalayMate curated starter content",
              "retrievedAt": "2026-05-28T00:00:00Z",
              "reviewStatus": "reviewed"
            }
          ]
        }
      ]
    }
  ]
}
```

- [ ] **Step 5: Run the seed tests**

Run: `swift test --filter SeedModelsTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/MalayMateCore/Content Sources/MalayMateCore/Resources Tests/MalayMateCoreTests/SeedModelsTests.swift
git commit -m "feat: add starter deck schema"
```

---

### Task 3: Leitner Scheduler Domain Logic

**Files:**
- Create: `Sources/MalayMateCore/Domain/CardDirection.swift`
- Create: `Sources/MalayMateCore/Domain/ReviewRating.swift`
- Create: `Sources/MalayMateCore/Domain/ReviewSnapshot.swift`
- Create: `Sources/MalayMateCore/Domain/LeitnerScheduler.swift`
- Test: `Tests/MalayMateCoreTests/LeitnerSchedulerTests.swift`

- [ ] **Step 1: Write scheduler tests**

```swift
// Tests/MalayMateCoreTests/LeitnerSchedulerTests.swift
import XCTest
@testable import MalayMateCore

final class LeitnerSchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testAgainResetsToBoxOneAndAddsLapse() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 4, dueAt: now, lapses: 2, lastReviewedAt: nil, easeHint: 1.0)

        let update = scheduler.update(from: snapshot, rating: .again, now: now)

        XCTAssertEqual(update.nextBox, 1)
        XCTAssertEqual(update.lapses, 3)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(10 * 60))
    }

    func testGoodMovesUpOneBox() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 2, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 1.0)

        let update = scheduler.update(from: snapshot, rating: .good, now: now)

        XCTAssertEqual(update.nextBox, 3)
        XCTAssertEqual(update.lapses, 0)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(3 * 24 * 60 * 60))
    }

    func testEasyMovesUpTwoBoxesAndCapsAtSix() {
        let scheduler = LeitnerScheduler()
        let snapshot = ReviewSnapshot(box: 5, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 1.0)

        let update = scheduler.update(from: snapshot, rating: .easy, now: now)

        XCTAssertEqual(update.nextBox, 6)
        XCTAssertEqual(update.nextDueAt, now.addingTimeInterval(30 * 24 * 60 * 60))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter LeitnerSchedulerTests`

Expected: FAIL with missing scheduler/domain types.

- [ ] **Step 3: Implement the domain types and scheduler**

```swift
// Sources/MalayMateCore/Domain/CardDirection.swift
public enum CardDirection: String, Codable, CaseIterable, Sendable {
    case malayToChinese
    case chineseToMalay
}
```

```swift
// Sources/MalayMateCore/Domain/ReviewRating.swift
public enum ReviewRating: String, Codable, CaseIterable, Sendable {
    case again
    case good
    case easy
}
```

```swift
// Sources/MalayMateCore/Domain/ReviewSnapshot.swift
import Foundation

public struct ReviewSnapshot: Equatable, Sendable {
    public var box: Int
    public var dueAt: Date
    public var lapses: Int
    public var lastReviewedAt: Date?
    public var easeHint: Double

    public init(box: Int, dueAt: Date, lapses: Int, lastReviewedAt: Date?, easeHint: Double) {
        self.box = box
        self.dueAt = dueAt
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
        self.easeHint = easeHint
    }
}

public struct ReviewUpdate: Equatable, Sendable {
    public var rating: ReviewRating
    public var reviewedAt: Date
    public var previousBox: Int
    public var nextBox: Int
    public var previousDueAt: Date
    public var nextDueAt: Date
    public var lapses: Int
    public var easeHint: Double
}
```

```swift
// Sources/MalayMateCore/Domain/LeitnerScheduler.swift
import Foundation

public struct LeitnerScheduler: Sendable {
    public static let maximumBox = 6

    private let intervals: [Int: TimeInterval]

    public init(intervals: [Int: TimeInterval] = LeitnerScheduler.defaultIntervals) {
        self.intervals = intervals
    }

    public static let defaultIntervals: [Int: TimeInterval] = [
        1: 10 * 60,
        2: 24 * 60 * 60,
        3: 3 * 24 * 60 * 60,
        4: 7 * 24 * 60 * 60,
        5: 14 * 24 * 60 * 60,
        6: 30 * 24 * 60 * 60
    ]

    public func initialState(now: Date) -> ReviewSnapshot {
        ReviewSnapshot(box: 1, dueAt: now, lapses: 0, lastReviewedAt: nil, easeHint: 1.0)
    }

    public func update(from snapshot: ReviewSnapshot, rating: ReviewRating, now: Date) -> ReviewUpdate {
        let nextBox: Int
        let lapses: Int

        switch rating {
        case .again:
            nextBox = 1
            lapses = snapshot.lapses + 1
        case .good:
            nextBox = min(Self.maximumBox, max(1, snapshot.box + 1))
            lapses = snapshot.lapses
        case .easy:
            nextBox = min(Self.maximumBox, max(1, snapshot.box + 2))
            lapses = snapshot.lapses
        }

        let interval = intervals[nextBox] ?? Self.defaultIntervals[nextBox] ?? Self.defaultIntervals[1]!
        return ReviewUpdate(
            rating: rating,
            reviewedAt: now,
            previousBox: snapshot.box,
            nextBox: nextBox,
            previousDueAt: snapshot.dueAt,
            nextDueAt: now.addingTimeInterval(interval),
            lapses: lapses,
            easeHint: snapshot.easeHint
        )
    }
}
```

- [ ] **Step 4: Run scheduler tests**

Run: `swift test --filter LeitnerSchedulerTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MalayMateCore/Domain Tests/MalayMateCoreTests/LeitnerSchedulerTests.swift
git commit -m "feat: add Leitner scheduler"
```

---

### Task 4: SwiftData Records And Test Container

**Files:**
- Create: `Sources/MalayMateCore/Persistence/Records.swift`
- Create: `Sources/MalayMateCore/Persistence/ModelContainerFactory.swift`
- Test: `Tests/MalayMateCoreTests/PersistenceTests.swift`

- [ ] **Step 1: Write persistence tests**

```swift
// Tests/MalayMateCoreTests/PersistenceTests.swift
import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class PersistenceTests: XCTestCase {
    func testWordCardAndReviewStateCanRoundTripInMemory() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let wordID = UUID()
        let cardID = UUID()

        context.insert(WordRecord(
            id: wordID,
            term: "makan",
            languageCode: "ms-MY",
            chineseMeaning: "吃；进食",
            partOfSpeech: "verb",
            pronunciationNotes: "ma-kan",
            syllablesJSON: #"["ma","kan"]"#,
            examplesJSON: "[]",
            sourceRefsJSON: "[]",
            reviewStatus: "reviewed",
            createdAt: .now,
            updatedAt: .now
        ))
        context.insert(CardRecord(
            id: cardID,
            wordID: wordID,
            directionRaw: CardDirection.malayToChinese.rawValue,
            prompt: "makan",
            answer: "吃；进食",
            hint: "verb",
            createdAt: .now
        ))
        context.insert(ReviewStateRecord(
            cardID: cardID,
            box: 1,
            dueAt: .now,
            lapses: 0,
            lastReviewedAt: nil,
            easeHint: 1.0
        ))
        try context.save()

        let words = try context.fetch(FetchDescriptor<WordRecord>())
        let cards = try context.fetch(FetchDescriptor<CardRecord>())
        let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())

        XCTAssertEqual(words.map(\.term), ["makan"])
        XCTAssertEqual(cards.map(\.directionRaw), [CardDirection.malayToChinese.rawValue])
        XCTAssertEqual(states.map(\.box), [1])
    }
}
```

- [ ] **Step 2: Run persistence tests to verify they fail**

Run: `swift test --filter PersistenceTests`

Expected: FAIL with missing record and container types.

- [ ] **Step 3: Implement SwiftData records**

```swift
// Sources/MalayMateCore/Persistence/Records.swift
import Foundation
import SwiftData

@Model
public final class DeckRecord {
    @Attribute(.unique) public var id: String
    public var name: String
    public var deckDescription: String
    public var isStarter: Bool
    public var wordIDsJSON: String
    public var createdAt: Date

    public init(id: String, name: String, deckDescription: String, isStarter: Bool, wordIDsJSON: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.deckDescription = deckDescription
        self.isStarter = isStarter
        self.wordIDsJSON = wordIDsJSON
        self.createdAt = createdAt
    }
}

@Model
public final class WordRecord {
    @Attribute(.unique) public var id: UUID
    public var term: String
    public var languageCode: String
    public var chineseMeaning: String
    public var partOfSpeech: String
    public var pronunciationNotes: String
    public var syllablesJSON: String
    public var examplesJSON: String
    public var sourceRefsJSON: String
    public var reviewStatus: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, term: String, languageCode: String, chineseMeaning: String, partOfSpeech: String, pronunciationNotes: String, syllablesJSON: String, examplesJSON: String, sourceRefsJSON: String, reviewStatus: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.term = term
        self.languageCode = languageCode
        self.chineseMeaning = chineseMeaning
        self.partOfSpeech = partOfSpeech
        self.pronunciationNotes = pronunciationNotes
        self.syllablesJSON = syllablesJSON
        self.examplesJSON = examplesJSON
        self.sourceRefsJSON = sourceRefsJSON
        self.reviewStatus = reviewStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class CardRecord {
    @Attribute(.unique) public var id: UUID
    public var wordID: UUID
    public var directionRaw: String
    public var prompt: String
    public var answer: String
    public var hint: String
    public var createdAt: Date

    public init(id: UUID, wordID: UUID, directionRaw: String, prompt: String, answer: String, hint: String, createdAt: Date) {
        self.id = id
        self.wordID = wordID
        self.directionRaw = directionRaw
        self.prompt = prompt
        self.answer = answer
        self.hint = hint
        self.createdAt = createdAt
    }
}

@Model
public final class ReviewStateRecord {
    @Attribute(.unique) public var cardID: UUID
    public var box: Int
    public var dueAt: Date
    public var lapses: Int
    public var lastReviewedAt: Date?
    public var easeHint: Double

    public init(cardID: UUID, box: Int, dueAt: Date, lapses: Int, lastReviewedAt: Date?, easeHint: Double) {
        self.cardID = cardID
        self.box = box
        self.dueAt = dueAt
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
        self.easeHint = easeHint
    }
}

@Model
public final class ReviewLogRecord {
    @Attribute(.unique) public var id: UUID
    public var cardID: UUID
    public var ratingRaw: String
    public var reviewedAt: Date
    public var previousBox: Int
    public var nextBox: Int
    public var previousDueAt: Date
    public var nextDueAt: Date

    public init(id: UUID, cardID: UUID, ratingRaw: String, reviewedAt: Date, previousBox: Int, nextBox: Int, previousDueAt: Date, nextDueAt: Date) {
        self.id = id
        self.cardID = cardID
        self.ratingRaw = ratingRaw
        self.reviewedAt = reviewedAt
        self.previousBox = previousBox
        self.nextBox = nextBox
        self.previousDueAt = previousDueAt
        self.nextDueAt = nextDueAt
    }
}
```

- [ ] **Step 4: Implement the container factory**

```swift
// Sources/MalayMateCore/Persistence/ModelContainerFactory.swift
import SwiftData

public enum ModelContainerFactory {
    public static var schema: Schema {
        Schema([
            DeckRecord.self,
            WordRecord.self,
            CardRecord.self,
            ReviewStateRecord.self,
            ReviewLogRecord.self
        ])
    }

    @MainActor
    public static func makeAppContainer() throws -> ModelContainer {
        try ModelContainer(for: schema)
    }

    @MainActor
    public static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
```

- [ ] **Step 5: Run persistence tests**

Run: `swift test --filter PersistenceTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/MalayMateCore/Persistence Tests/MalayMateCoreTests/PersistenceTests.swift
git commit -m "feat: add SwiftData persistence records"
```

---

### Task 5: First-Launch Seed Import

**Files:**
- Create: `Sources/MalayMateCore/Content/SeedImporter.swift`
- Test: `Tests/MalayMateCoreTests/SeedImporterTests.swift`

- [ ] **Step 1: Write seed importer tests**

```swift
// Tests/MalayMateCoreTests/SeedImporterTests.swift
import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class SeedImporterTests: XCTestCase {
    func testImportCreatesDeckWordsCardsAndReviewStates() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let data = try SeedResource.bundledStarterDeckData()

        let summary = try SeedImporter().importDecks(from: data, into: context, now: Date(timeIntervalSince1970: 1_800_000_000))

        XCTAssertGreaterThanOrEqual(summary.wordsInserted, 6)
        XCTAssertEqual(summary.cardsInserted, summary.wordsInserted * 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DeckRecord>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CardRecord>()).count, summary.cardsInserted)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewStateRecord>()).count, summary.cardsInserted)
    }

    func testSecondImportDoesNotDuplicateStarterDecks() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let data = try SeedResource.bundledStarterDeckData()
        let importer = SeedImporter()

        _ = try importer.importDecks(from: data, into: context, now: .now)
        let second = try importer.importDecks(from: data, into: context, now: .now)

        XCTAssertEqual(second.wordsInserted, 0)
        XCTAssertEqual(second.cardsInserted, 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SeedImporterTests`

Expected: FAIL with missing `SeedImporter`.

- [ ] **Step 3: Implement the seed importer**

```swift
// Sources/MalayMateCore/Content/SeedImporter.swift
import Foundation
import SwiftData

public struct SeedImportSummary: Equatable {
    public var decksInserted: Int
    public var wordsInserted: Int
    public var cardsInserted: Int
}

public struct SeedImporter {
    public init() {}

    @MainActor
    public func importBundledSeed(into context: ModelContext, now: Date = .now) throws -> SeedImportSummary {
        return try importDecks(from: SeedResource.bundledStarterDeckData(), into: context, now: now)
    }

    @MainActor
    public func importDecks(from data: Data, into context: ModelContext, now: Date) throws -> SeedImportSummary {
        let starterDescriptor = FetchDescriptor<DeckRecord>(predicate: #Predicate { $0.isStarter == true })
        let existingStarterDecks = try context.fetch(starterDescriptor)
        guard existingStarterDecks.isEmpty else {
            return SeedImportSummary(decksInserted: 0, wordsInserted: 0, cardsInserted: 0)
        }

        let collection = try JSONDecoder.seedDecoder.decode(SeedDeckCollection.self, from: data)
        var decksInserted = 0
        var wordsInserted = 0
        var cardsInserted = 0
        let scheduler = LeitnerScheduler()

        for deck in collection.decks {
            var wordIDs: [String] = []

            for seedWord in deck.words {
                let wordID = stableUUID(from: seedWord.id)
                wordIDs.append(wordID.uuidString)
                let word = WordRecord(
                    id: wordID,
                    term: seedWord.term,
                    languageCode: seedWord.languageCode,
                    chineseMeaning: seedWord.chineseMeaning,
                    partOfSpeech: seedWord.partOfSpeech,
                    pronunciationNotes: seedWord.pronunciationNotes,
                    syllablesJSON: try encodeJSONString(seedWord.syllables),
                    examplesJSON: try encodeJSONString(seedWord.examples),
                    sourceRefsJSON: try encodeJSONString(seedWord.sourceRefs),
                    reviewStatus: "reviewed",
                    createdAt: now,
                    updatedAt: now
                )
                context.insert(word)
                wordsInserted += 1

                let directions: [CardDirection] = [.malayToChinese, .chineseToMalay]
                for direction in directions {
                    let cardID = stableUUID(from: "\(seedWord.id)-\(direction.rawValue)")
                    let card = CardRecord(
                        id: cardID,
                        wordID: wordID,
                        directionRaw: direction.rawValue,
                        prompt: direction == .malayToChinese ? seedWord.term : seedWord.chineseMeaning,
                        answer: direction == .malayToChinese ? seedWord.chineseMeaning : seedWord.term,
                        hint: seedWord.partOfSpeech,
                        createdAt: now
                    )
                    context.insert(card)
                    let state = scheduler.initialState(now: now)
                    context.insert(ReviewStateRecord(
                        cardID: cardID,
                        box: state.box,
                        dueAt: state.dueAt,
                        lapses: state.lapses,
                        lastReviewedAt: state.lastReviewedAt,
                        easeHint: state.easeHint
                    ))
                    cardsInserted += 1
                }
            }

            context.insert(DeckRecord(
                id: deck.id,
                name: deck.name,
                deckDescription: deck.description,
                isStarter: deck.isStarter,
                wordIDsJSON: try encodeJSONString(wordIDs),
                createdAt: now
            ))
            decksInserted += 1
        }

        try context.save()
        return SeedImportSummary(decksInserted: decksInserted, wordsInserted: wordsInserted, cardsInserted: cardsInserted)
    }

    private func encodeJSONString<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try JSONEncoder.seedEncoder.encode(value), as: UTF8.self)
    }

    private func stableUUID(from string: String) -> UUID {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let raw = String(format: "%016llx", hash)
        let suffix = String(raw.suffix(12))
        return UUID(uuidString: "00000000-0000-4000-8000-\(suffix)")!
    }
}
```

- [ ] **Step 4: Run seed importer tests**

Run: `swift test --filter SeedImporterTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MalayMateCore/Content/SeedImporter.swift Tests/MalayMateCoreTests/SeedImporterTests.swift
git commit -m "feat: import bundled starter decks"
```

---

### Task 6: Review Session Due Queue And Rating

**Files:**
- Create: `Sources/MalayMateCore/Review/ReviewSession.swift`
- Test: `Tests/MalayMateCoreTests/ReviewSessionTests.swift`

- [ ] **Step 1: Write review session tests**

```swift
// Tests/MalayMateCoreTests/ReviewSessionTests.swift
import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class ReviewSessionTests: XCTestCase {
    func testDueCardsReturnSeededReviewItems() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        try SeedImporter().importBundledSeed(into: context, now: Date(timeIntervalSince1970: 1_800_000_000))

        let items = try ReviewSession(context: context).dueCards(now: Date(timeIntervalSince1970: 1_800_000_100))

        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.contains { $0.word.term == "makan" })
        XCTAssertTrue(items.allSatisfy { $0.state.dueAt <= Date(timeIntervalSince1970: 1_800_000_100) })
    }

    func testApplyingRatingUpdatesStateAndCreatesLog() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        try SeedImporter().importBundledSeed(into: context, now: Date(timeIntervalSince1970: 1_800_000_000))
        let session = ReviewSession(context: context)
        let item = try XCTUnwrap(session.dueCards(now: Date(timeIntervalSince1970: 1_800_000_100)).first)

        try session.apply(rating: .good, to: item.card.id, now: Date(timeIntervalSince1970: 1_800_000_100))

        let state = try XCTUnwrap(try context.fetch(FetchDescriptor<ReviewStateRecord>()).first { $0.cardID == item.card.id })
        XCTAssertEqual(state.box, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewLogRecord>()).count, 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ReviewSessionTests`

Expected: FAIL with missing `ReviewSession`.

- [ ] **Step 3: Implement review session**

```swift
// Sources/MalayMateCore/Review/ReviewSession.swift
import Foundation
import SwiftData

public struct DueReviewItem: Identifiable {
    public var id: UUID { card.id }
    public var word: WordRecord
    public var card: CardRecord
    public var state: ReviewStateRecord
}

@MainActor
public final class ReviewSession {
    private let context: ModelContext
    private let scheduler: LeitnerScheduler

    public init(context: ModelContext, scheduler: LeitnerScheduler = LeitnerScheduler()) {
        self.context = context
        self.scheduler = scheduler
    }

    public func dueCards(now: Date, limit: Int = 100) throws -> [DueReviewItem] {
        let states = try context.fetch(FetchDescriptor<ReviewStateRecord>()).filter { $0.dueAt <= now }
        let cards = try context.fetch(FetchDescriptor<CardRecord>())
        let words = try context.fetch(FetchDescriptor<WordRecord>())
        let cardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        let wordsByID = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })

        return states
            .sorted { left, right in
                if left.dueAt != right.dueAt {
                    return left.dueAt < right.dueAt
                }
                return left.cardID.uuidString < right.cardID.uuidString
            }
            .compactMap { state in
                guard let card = cardsByID[state.cardID], let word = wordsByID[card.wordID] else {
                    return nil
                }
                return DueReviewItem(word: word, card: card, state: state)
            }
            .prefix(limit)
            .map { $0 }
    }

    public func apply(rating: ReviewRating, to cardID: UUID, now: Date) throws {
        let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())
        guard let state = states.first(where: { $0.cardID == cardID }) else {
            throw ReviewSessionError.missingReviewState(cardID)
        }

        let snapshot = ReviewSnapshot(
            box: state.box,
            dueAt: state.dueAt,
            lapses: state.lapses,
            lastReviewedAt: state.lastReviewedAt,
            easeHint: state.easeHint
        )
        let update = scheduler.update(from: snapshot, rating: rating, now: now)

        state.box = update.nextBox
        state.dueAt = update.nextDueAt
        state.lapses = update.lapses
        state.lastReviewedAt = update.reviewedAt
        state.easeHint = update.easeHint

        context.insert(ReviewLogRecord(
            id: UUID(),
            cardID: cardID,
            ratingRaw: rating.rawValue,
            reviewedAt: update.reviewedAt,
            previousBox: update.previousBox,
            nextBox: update.nextBox,
            previousDueAt: update.previousDueAt,
            nextDueAt: update.nextDueAt
        ))
        try context.save()
    }
}

public enum ReviewSessionError: Error, Equatable {
    case missingReviewState(UUID)
}
```

- [ ] **Step 4: Run review tests**

Run: `swift test --filter ReviewSessionTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MalayMateCore/Review Tests/MalayMateCoreTests/ReviewSessionTests.swift
git commit -m "feat: add review session"
```

---

### Task 7: Template Fallback And Add Word Service

**Files:**
- Create: `Sources/MalayMateCore/AI/AIProvider.swift`
- Create: `Sources/MalayMateCore/Content/TemplateGenerator.swift`
- Create: `Sources/MalayMateCore/Content/AddWordService.swift`
- Test: `Tests/MalayMateCoreTests/AddWordServiceTests.swift`

- [ ] **Step 1: Write add-word fallback tests**

```swift
// Tests/MalayMateCoreTests/AddWordServiceTests.swift
import SwiftData
import XCTest
@testable import MalayMateCore

@MainActor
final class AddWordServiceTests: XCTestCase {
    func testAddWordWithoutProviderUsesTemplateAndCreatesCards() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let service = AddWordService(context: context, aiProvider: nil, scheduler: LeitnerScheduler())

        let wordID = try await service.addWord(term: "belajar", userMeaning: "学习", note: "daily study", now: Date(timeIntervalSince1970: 1_800_000_000))

        let word = try XCTUnwrap(try context.fetch(FetchDescriptor<WordRecord>()).first { $0.id == wordID })
        let cards = try context.fetch(FetchDescriptor<CardRecord>()).filter { $0.wordID == wordID }
        XCTAssertEqual(word.term, "belajar")
        XCTAssertEqual(word.reviewStatus, "needsEnrichment")
        XCTAssertEqual(cards.count, 2)
        XCTAssertTrue(cards.contains { $0.directionRaw == CardDirection.malayToChinese.rawValue })
        XCTAssertTrue(cards.contains { $0.directionRaw == CardDirection.chineseToMalay.rawValue })
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AddWordServiceTests`

Expected: FAIL with missing `AddWordService`.

- [ ] **Step 3: Implement AI enrichment models and protocol**

```swift
// Sources/MalayMateCore/AI/AIProvider.swift
import Foundation

public struct AIEnrichment: Codable, Equatable, Sendable {
    public var chineseMeaning: String
    public var partOfSpeech: String
    public var pronunciationNotes: String
    public var syllables: [String]
    public var examples: [SeedExample]
    public var practicePrompts: [String]

    public init(chineseMeaning: String, partOfSpeech: String, pronunciationNotes: String, syllables: [String], examples: [SeedExample], practicePrompts: [String]) {
        self.chineseMeaning = chineseMeaning
        self.partOfSpeech = partOfSpeech
        self.pronunciationNotes = pronunciationNotes
        self.syllables = syllables
        self.examples = examples
        self.practicePrompts = practicePrompts
    }
}

public protocol AIProvider {
    func enrich(term: String, userMeaning: String, note: String?) async throws -> AIEnrichment
}
```

- [ ] **Step 4: Implement template generator**

```swift
// Sources/MalayMateCore/Content/TemplateGenerator.swift
import Foundation

public struct TemplateGenerator: Sendable {
    public init() {}

    public func enrichment(term: String, userMeaning: String, note: String?, now: Date) -> AIEnrichment {
        let syllables = term.split(separator: "-").map(String.init)
        let inferredSyllables = syllables.count > 1 ? syllables : [term]
        let source = SeedSourceRef(
            field: "example",
            sourceName: "MalayMate template fallback",
            sourceUrl: "local://template-fallback",
            license: "personal-use-local",
            attribution: "MalayMate deterministic template",
            retrievedAt: now,
            reviewStatus: "generated"
        )
        let example = SeedExample(
            id: "template-\(term)-example-1",
            malay: "Saya belajar perkataan \(term).",
            chinese: "我学习单词 \(term)。",
            sourceRefs: [source]
        )
        return AIEnrichment(
            chineseMeaning: userMeaning.isEmpty ? term : userMeaning,
            partOfSpeech: "unknown",
            pronunciationNotes: inferredSyllables.joined(separator: "-"),
            syllables: inferredSyllables,
            examples: [example],
            practicePrompts: ["看到 \(term) 时，先回忆中文意思。"]
        )
    }
}
```

- [ ] **Step 5: Implement add-word service**

```swift
// Sources/MalayMateCore/Content/AddWordService.swift
import Foundation
import SwiftData

@MainActor
public final class AddWordService {
    private let context: ModelContext
    private let aiProvider: AIProvider?
    private let scheduler: LeitnerScheduler
    private let templateGenerator: TemplateGenerator

    public init(context: ModelContext, aiProvider: AIProvider?, scheduler: LeitnerScheduler = LeitnerScheduler(), templateGenerator: TemplateGenerator = TemplateGenerator()) {
        self.context = context
        self.aiProvider = aiProvider
        self.scheduler = scheduler
        self.templateGenerator = templateGenerator
    }

    public func addWord(term: String, userMeaning: String, note: String?, now: Date = .now) async throws -> UUID {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else {
            throw AddWordError.emptyTerm
        }

        let enrichment: AIEnrichment
        let reviewStatus: String
        do {
            if let aiProvider {
                enrichment = try await aiProvider.enrich(term: trimmedTerm, userMeaning: userMeaning, note: note)
                reviewStatus = "aiGenerated"
            } else {
                enrichment = templateGenerator.enrichment(term: trimmedTerm, userMeaning: userMeaning, note: note, now: now)
                reviewStatus = "needsEnrichment"
            }
        } catch {
            enrichment = templateGenerator.enrichment(term: trimmedTerm, userMeaning: userMeaning, note: note, now: now)
            reviewStatus = "needsEnrichment"
        }

        let wordID = UUID()
        let sourceRefs = [
            SeedSourceRef(
                field: "term",
                sourceName: "User input",
                sourceUrl: "local://user-input",
                license: "personal-use-local",
                attribution: "User-added word",
                retrievedAt: now,
                reviewStatus: reviewStatus
            )
        ]
        let word = WordRecord(
            id: wordID,
            term: trimmedTerm,
            languageCode: "ms-MY",
            chineseMeaning: enrichment.chineseMeaning,
            partOfSpeech: enrichment.partOfSpeech,
            pronunciationNotes: enrichment.pronunciationNotes,
            syllablesJSON: try encodeJSONString(enrichment.syllables),
            examplesJSON: try encodeJSONString(enrichment.examples),
            sourceRefsJSON: try encodeJSONString(sourceRefs),
            reviewStatus: reviewStatus,
            createdAt: now,
            updatedAt: now
        )
        context.insert(word)

        for direction in [CardDirection.malayToChinese, .chineseToMalay] {
            let cardID = UUID()
            context.insert(CardRecord(
                id: cardID,
                wordID: wordID,
                directionRaw: direction.rawValue,
                prompt: direction == .malayToChinese ? trimmedTerm : enrichment.chineseMeaning,
                answer: direction == .malayToChinese ? enrichment.chineseMeaning : trimmedTerm,
                hint: enrichment.partOfSpeech,
                createdAt: now
            ))
            let state = scheduler.initialState(now: now)
            context.insert(ReviewStateRecord(
                cardID: cardID,
                box: state.box,
                dueAt: state.dueAt,
                lapses: state.lapses,
                lastReviewedAt: state.lastReviewedAt,
                easeHint: state.easeHint
            ))
        }

        try context.save()
        return wordID
    }

    private func encodeJSONString<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try JSONEncoder.seedEncoder.encode(value), as: UTF8.self)
    }
}

public enum AddWordError: Error, Equatable {
    case emptyTerm
}
```

- [ ] **Step 6: Run add-word tests**

Run: `swift test --filter AddWordServiceTests`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/MalayMateCore/AI Sources/MalayMateCore/Content Tests/MalayMateCoreTests/AddWordServiceTests.swift
git commit -m "feat: add word fallback service"
```

---

### Task 8: Settings, Keychain, And OpenAI Structured Enrichment

**Files:**
- Create: `Sources/MalayMateCore/Settings/KeychainStore.swift`
- Create: `Sources/MalayMateCore/Settings/SettingsStore.swift`
- Create: `Sources/MalayMateCore/AI/OpenAIClient.swift`
- Test: `Tests/MalayMateCoreTests/SettingsStoreTests.swift`
- Test: `Tests/MalayMateCoreTests/OpenAIClientTests.swift`

**API notes:** Use the OpenAI Responses API and structured outputs. Official docs currently show latest models are available through `v1/responses`, and structured outputs can be requested with `text.format` using JSON Schema. Use `gpt-5.4-mini` as the editable default because the current model page positions mini variants for lower latency and cost than the flagship model.

- [ ] **Step 1: Write settings and AI parsing tests**

```swift
// Tests/MalayMateCoreTests/SettingsStoreTests.swift
import XCTest
@testable import MalayMateCore

final class SettingsStoreTests: XCTestCase {
    func testSettingsReportsMissingKeyAndDefaultModel() throws {
        let keychain = InMemorySecretStore()
        let store = SettingsStore(secretStore: keychain)

        XCTAssertFalse(try store.hasAPIKey())
        XCTAssertEqual(store.modelName, "gpt-5.4-mini")
    }

    func testSettingsStoresAndClearsAPIKey() throws {
        let keychain = InMemorySecretStore()
        let store = SettingsStore(secretStore: keychain)

        try store.saveAPIKey("sk-test")
        XCTAssertTrue(try store.hasAPIKey())
        XCTAssertEqual(try keychain.read(service: SettingsStore.keychainService, account: SettingsStore.apiKeyAccount), "sk-test")

        try store.clearAPIKey()
        XCTAssertFalse(try store.hasAPIKey())
    }
}
```

```swift
// Tests/MalayMateCoreTests/OpenAIClientTests.swift
import XCTest
@testable import MalayMateCore

final class OpenAIClientTests: XCTestCase {
    func testResponseParserExtractsStructuredEnrichment() throws {
        let json = """
        {
          "output": [
            {
              "type": "message",
              "content": [
                {
                  "type": "output_text",
                  "text": "{\\"chineseMeaning\\":\\"学习\\",\\"partOfSpeech\\":\\"verb\\",\\"pronunciationNotes\\":\\"be-la-jar\\",\\"syllables\\":[\\"be\\",\\"la\\",\\"jar\\"],\\"examples\\":[{\\"id\\":\\"ai-belajar-1\\",\\"malay\\":\\"Saya belajar bahasa Melayu.\\",\\"chinese\\":\\"我学习马来语。\\",\\"sourceRefs\\":[]}],\\"practicePrompts\\":[\\"看到 belajar 时回忆中文意思。\\"]}"
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let enrichment = try OpenAIClient.parseEnrichmentResponse(data: json)

        XCTAssertEqual(enrichment.chineseMeaning, "学习")
        XCTAssertEqual(enrichment.syllables, ["be", "la", "jar"])
        XCTAssertEqual(enrichment.examples.first?.malay, "Saya belajar bahasa Melayu.")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SettingsStoreTests && swift test --filter OpenAIClientTests`

Expected: FAIL with missing settings and client types.

- [ ] **Step 3: Implement settings and secret-store abstractions**

```swift
// Sources/MalayMateCore/Settings/SettingsStore.swift
import Foundation

public protocol SecretStore {
    func save(_ value: String, service: String, account: String) throws
    func read(service: String, account: String) throws -> String?
    func delete(service: String, account: String) throws
}

public final class SettingsStore {
    public static let keychainService = "local.zhuyingtao.MalayMate"
    public static let apiKeyAccount = "openai-api-key"

    private let secretStore: SecretStore
    public var modelName: String

    public init(secretStore: SecretStore, modelName: String = "gpt-5.4-mini") {
        self.secretStore = secretStore
        self.modelName = modelName
    }

    public func saveAPIKey(_ key: String) throws {
        try secretStore.save(key, service: Self.keychainService, account: Self.apiKeyAccount)
    }

    public func hasAPIKey() throws -> Bool {
        try secretStore.read(service: Self.keychainService, account: Self.apiKeyAccount)?.isEmpty == false
    }

    public func apiKey() throws -> String? {
        try secretStore.read(service: Self.keychainService, account: Self.apiKeyAccount)
    }

    public func clearAPIKey() throws {
        try secretStore.delete(service: Self.keychainService, account: Self.apiKeyAccount)
    }
}

public final class InMemorySecretStore: SecretStore {
    private var values: [String: String] = [:]

    public init() {}

    public func save(_ value: String, service: String, account: String) throws {
        values["\(service):\(account)"] = value
    }

    public func read(service: String, account: String) throws -> String? {
        values["\(service):\(account)"]
    }

    public func delete(service: String, account: String) throws {
        values.removeValue(forKey: "\(service):\(account)")
    }
}
```

- [ ] **Step 4: Implement Keychain store**

```swift
// Sources/MalayMateCore/Settings/KeychainStore.swift
import Foundation
import Security

public final class KeychainStore: SecretStore {
    public init() {}

    public func save(_ value: String, service: String, account: String) throws {
        try delete(service: service, account: account)
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    public func read(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.unhandledStatus(status)
        }
        return String(decoding: data, as: UTF8.self)
    }

    public func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}

public enum KeychainError: Error, Equatable {
    case unhandledStatus(OSStatus)
}
```

- [ ] **Step 5: Implement OpenAI client parsing and request body**

```swift
// Sources/MalayMateCore/AI/OpenAIClient.swift
import Foundation

public struct OpenAIClient: AIProvider {
    public var apiKey: String
    public var model: String
    public var urlSession: URLSession

    public init(apiKey: String, model: String = "gpt-5.4-mini", urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.urlSession = urlSession
    }

    public func enrich(term: String, userMeaning: String, note: String?) async throws -> AIEnrichment {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(term: term, userMeaning: userMeaning, note: note))

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OpenAIClientError.badHTTPResponse
        }
        return try Self.parseEnrichmentResponse(data: data)
    }

    public func requestBody(term: String, userMeaning: String, note: String?) -> [String: Any] {
        [
            "model": model,
            "input": [
                [
                    "role": "system",
                    "content": "Return strict JSON for a Malay vocabulary learning card for a Chinese-speaking learner. Keep Malay examples simple and natural."
                ],
                [
                    "role": "user",
                    "content": "Malay term: \(term)\nKnown Chinese meaning: \(userMeaning)\nUser note: \(note ?? "")"
                ]
            ],
            "max_output_tokens": 800,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "malay_vocab_enrichment",
                    "strict": true,
                    "schema": enrichmentSchema
                ]
            ]
        ]
    }

    public static func parseEnrichmentResponse(data: Data) throws -> AIEnrichment {
        let response = try JSONDecoder().decode(ResponsesEnvelope.self, from: data)
        guard let text = response.outputText ?? response.output?.compactMap({ item in
            item.content.compactMap { content in content.text }.joined(separator: "\n")
        }).first(where: { !$0.isEmpty }) else {
            throw OpenAIClientError.missingOutputText
        }
        let payload = Data(text.utf8)
        return try JSONDecoder.seedDecoder.decode(AIEnrichment.self, from: payload)
    }

    private var enrichmentSchema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "chineseMeaning": ["type": "string"],
                "partOfSpeech": ["type": "string"],
                "pronunciationNotes": ["type": "string"],
                "syllables": ["type": "array", "items": ["type": "string"]],
                "examples": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "id": ["type": "string"],
                            "malay": ["type": "string"],
                            "chinese": ["type": "string"],
                            "sourceRefs": ["type": "array", "items": ["type": "object"]]
                        ],
                        "required": ["id", "malay", "chinese", "sourceRefs"]
                    ]
                ],
                "practicePrompts": ["type": "array", "items": ["type": "string"]]
            ],
            "required": ["chineseMeaning", "partOfSpeech", "pronunciationNotes", "syllables", "examples", "practicePrompts"]
        ]
    }
}

private struct ResponsesEnvelope: Decodable {
    var outputText: String?
    var output: [ResponsesOutputItem]?

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }
}

private struct ResponsesOutputItem: Decodable {
    var content: [ResponsesContentItem]
}

private struct ResponsesContentItem: Decodable {
    var text: String?
}

public enum OpenAIClientError: Error, Equatable {
    case badHTTPResponse
    case missingOutputText
}
```

- [ ] **Step 6: Run settings and OpenAI tests**

Run: `swift test --filter SettingsStoreTests && swift test --filter OpenAIClientTests`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/MalayMateCore/Settings Sources/MalayMateCore/AI Tests/MalayMateCoreTests/SettingsStoreTests.swift Tests/MalayMateCoreTests/OpenAIClientTests.swift
git commit -m "feat: add AI settings and OpenAI client"
```

---

### Task 9: Malay Speech Service

**Files:**
- Create: `Sources/MalayMateCore/Speech/SpeechService.swift`
- Test: `Tests/MalayMateCoreTests/SpeechServiceTests.swift`

- [ ] **Step 1: Write speech selection tests**

```swift
// Tests/MalayMateCoreTests/SpeechServiceTests.swift
import XCTest
@testable import MalayMateCore

final class SpeechServiceTests: XCTestCase {
    func testMalayVoiceSelectionPrefersMsMY() {
        let voices = [
            SpeechVoice(identifier: "en", name: "Samantha", language: "en_US"),
            SpeechVoice(identifier: "ms", name: "Amira", language: "ms_MY")
        ]

        let selected = SpeechService.chooseMalayVoice(from: voices)

        XCTAssertEqual(selected?.name, "Amira")
    }

    func testMalayVoiceSelectionFallsBackToAnyMalayVoice() {
        let voices = [
            SpeechVoice(identifier: "id", name: "Damayanti", language: "id_ID"),
            SpeechVoice(identifier: "ms", name: "Malay Voice", language: "ms")
        ]

        let selected = SpeechService.chooseMalayVoice(from: voices)

        XCTAssertEqual(selected?.identifier, "ms")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SpeechServiceTests`

Expected: FAIL with missing speech service types.

- [ ] **Step 3: Implement speech service**

```swift
// Sources/MalayMateCore/Speech/SpeechService.swift
import AVFoundation
import Foundation

public struct SpeechVoice: Equatable, Sendable {
    public var identifier: String
    public var name: String
    public var language: String

    public init(identifier: String, name: String, language: String) {
        self.identifier = identifier
        self.name = name
        self.language = language
    }
}

@MainActor
public final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public var availableMalayVoice: SpeechVoice? {
        Self.chooseMalayVoice(from: AVSpeechSynthesisVoice.speechVoices().map {
            SpeechVoice(identifier: $0.identifier, name: $0.name, language: $0.language)
        })
    }

    public func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        if let voice = availableMalayVoice {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voice.identifier)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "ms-MY")
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    public static func chooseMalayVoice(from voices: [SpeechVoice]) -> SpeechVoice? {
        voices.first { $0.language == "ms_MY" }
            ?? voices.first { $0.language.lowercased().hasPrefix("ms") }
            ?? voices.first { $0.name.lowercased().contains("malay") || $0.name.lowercased().contains("melayu") }
    }
}
```

- [ ] **Step 4: Run speech tests**

Run: `swift test --filter SpeechServiceTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MalayMateCore/Speech Tests/MalayMateCoreTests/SpeechServiceTests.swift
git commit -m "feat: add Malay speech service"
```

---

### Task 10: Wire SwiftData App Container And Review-First UI

**Files:**
- Modify: `Sources/MalayMate/MalayMateApp.swift`
- Modify: `Sources/MalayMate/Views/ContentView.swift`
- Create: `Sources/MalayMate/Views/SidebarView.swift`
- Create: `Sources/MalayMate/Views/ReviewView.swift`
- Create: `Sources/MalayMate/Views/AddWordView.swift`
- Create: `Sources/MalayMate/Views/SettingsView.swift`

- [ ] **Step 1: Update app entry to create SwiftData container and import seed**

```swift
// Sources/MalayMate/MalayMateApp.swift
import MalayMateCore
import SwiftData
import SwiftUI

@main
struct MalayMateApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainerFactory.makeAppContainer()
            try SeedImporter().importBundledSeed(into: container.mainContext)
        } catch {
            fatalError("Failed to start MalayMate: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .frame(minWidth: 980, minHeight: 620)
        }
    }
}
```

- [ ] **Step 2: Replace root view with review-first navigation**

```swift
// Sources/MalayMate/Views/ContentView.swift
import MalayMateCore
import SwiftData
import SwiftUI

struct ContentView: View {
    enum Selection: Hashable {
        case review
        case addWord
        case settings
    }

    @State private var selection: Selection = .review

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .review:
                ReviewView()
            case .addWord:
                AddWordView()
            case .settings:
                SettingsView()
            }
        }
    }
}
```

- [ ] **Step 3: Add sidebar**

```swift
// Sources/MalayMate/Views/SidebarView.swift
import MalayMateCore
import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selection: ContentView.Selection
    @Query(sort: \DeckRecord.name) private var decks: [DeckRecord]
    @Query private var states: [ReviewStateRecord]

    var dueCount: Int {
        states.filter { $0.dueAt <= .now }.count
    }

    var body: some View {
        List(selection: $selection) {
            Section("Today") {
                Label("Review \(dueCount)", systemImage: "rectangle.stack")
                    .tag(ContentView.Selection.review)
                Label("Add Word", systemImage: "plus.circle")
                    .tag(ContentView.Selection.addWord)
                Label("Settings", systemImage: "gearshape")
                    .tag(ContentView.Selection.settings)
            }

            Section("Decks") {
                ForEach(decks) { deck in
                    Label(deck.name, systemImage: deck.isStarter ? "book.closed" : "person.crop.square")
                }
            }
        }
        .navigationTitle("MalayMate")
    }
}
```

- [ ] **Step 4: Add review view**

```swift
// Sources/MalayMate/Views/ReviewView.swift
import MalayMateCore
import SwiftData
import SwiftUI

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var items: [DueReviewItem] = []
    @State private var currentIndex = 0
    @State private var isAnswerRevealed = false
    @State private var errorMessage: String?
    private let speechService = SpeechService()

    var current: DueReviewItem? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Today Review")
                        .font(.title2.weight(.semibold))
                    Text(items.isEmpty ? "No due cards" : "Card \(currentIndex + 1) of \(items.count)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    reload()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            if let current {
                VStack(spacing: 16) {
                    Text(current.card.directionRaw == CardDirection.malayToChinese.rawValue ? "Malay to Chinese" : "Chinese to Malay")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(current.card.prompt)
                        .font(.system(size: 44, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                    if isAnswerRevealed {
                        VStack(spacing: 8) {
                            Text(current.card.answer)
                                .font(.title2.weight(.medium))
                            Text(current.word.pronunciationNotes)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Think of the answer, then reveal.")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button {
                            isAnswerRevealed = true
                        } label: {
                            Label("Reveal", systemImage: "eye")
                        }

                        Button {
                            speechService.speak(current.word.term)
                        } label: {
                            Label("Play", systemImage: "speaker.wave.2")
                        }

                        Spacer()

                        ForEach(ReviewRating.allCases, id: \.self) { rating in
                            Button(rating.rawValue.capitalized) {
                                apply(rating)
                            }
                            .disabled(!isAnswerRevealed)
                        }
                    }
                }
            } else {
                ContentUnavailableView("No due cards", systemImage: "checkmark.circle", description: Text("Add a word or come back after the next due time."))
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
        .onAppear(perform: reload)
    }

    private func reload() {
        do {
            items = try ReviewSession(context: modelContext).dueCards(now: .now)
            currentIndex = 0
            isAnswerRevealed = false
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func apply(_ rating: ReviewRating) {
        guard let current else { return }
        do {
            try ReviewSession(context: modelContext).apply(rating: rating, to: current.card.id, now: .now)
            if currentIndex + 1 < items.count {
                currentIndex += 1
                isAnswerRevealed = false
            } else {
                reload()
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
```

- [ ] **Step 5: Add add-word and settings views**

```swift
// Sources/MalayMate/Views/AddWordView.swift
import MalayMateCore
import SwiftData
import SwiftUI

struct AddWordView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var term = ""
    @State private var meaning = ""
    @State private var note = ""
    @State private var status = ""

    var body: some View {
        Form {
            TextField("Malay word", text: $term)
            TextField("Chinese meaning", text: $meaning)
            TextField("Note", text: $note)
            Button {
                Task { await addWord() }
            } label: {
                Label("Save Word", systemImage: "plus.circle")
            }
            Text(status)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding(24)
        .navigationTitle("Add Word")
    }

    private func addWord() async {
        do {
            let settings = SettingsStore(secretStore: KeychainStore())
            let provider: AIProvider?
            if let apiKey = try settings.apiKey(), !apiKey.isEmpty {
                provider = OpenAIClient(apiKey: apiKey, model: settings.modelName)
            } else {
                provider = nil
            }
            let service = AddWordService(context: modelContext, aiProvider: provider)
            _ = try await service.addWord(term: term, userMeaning: meaning, note: note.isEmpty ? nil : note)
            term = ""
            meaning = ""
            note = ""
            status = provider == nil ? "Saved with local template." : "Saved with AI enrichment."
        } catch {
            status = "Save failed: \(error)"
        }
    }
}
```

```swift
// Sources/MalayMate/Views/SettingsView.swift
import MalayMateCore
import SwiftUI

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var status = ""
    @State private var modelName = "gpt-5.4-mini"
    private let store = SettingsStore(secretStore: KeychainStore())
    private let speechService = SpeechService()

    var body: some View {
        Form {
            Section("AI") {
                TextField("Model", text: $modelName)
                SecureField("OpenAI API key", text: $apiKey)
                HStack {
                    Button("Save Key") {
                        saveKey()
                    }
                    Button("Clear Key") {
                        clearKey()
                    }
                }
                Text(status)
                    .foregroundStyle(.secondary)
            }

            Section("Audio") {
                if let voice = speechService.availableMalayVoice {
                    Label("Malay voice: \(voice.name) (\(voice.language))", systemImage: "speaker.wave.2")
                } else {
                    Label("No Malay system voice found", systemImage: "speaker.slash")
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .navigationTitle("Settings")
    }

    private func saveKey() {
        do {
            try store.saveAPIKey(apiKey)
            status = "API key saved in Keychain."
        } catch {
            status = "Save failed: \(error)"
        }
    }

    private func clearKey() {
        do {
            try store.clearAPIKey()
            apiKey = ""
            status = "API key cleared."
        } catch {
            status = "Clear failed: \(error)"
        }
    }
}
```

- [ ] **Step 6: Build and launch the app**

Run: `swift build && swift run MalayMate`

Expected: app window opens with sidebar, seeded decks, due-card review, add-word form, and settings view.

- [ ] **Step 7: Commit**

```bash
git add Sources/MalayMate
git commit -m "feat: wire review-first SwiftUI app"
```

---

### Task 11: Local Content Builder For Open-Access Sources

**Files:**
- Create: `scripts/build_starter_deck.py`
- Create: `scripts/test_content_builder.py`
- Create: `content/raw/sample_frequency.tsv`
- Create: `content/raw/sample_dictionary.jsonl`
- Create: `content/raw/sample_sentences.tsv`
- Create: `content/generated/.gitkeep`

- [ ] **Step 1: Write content builder tests**

```python
# scripts/test_content_builder.py
import json
import tempfile
import unittest
from pathlib import Path

from build_starter_deck import build_deck


class ContentBuilderTests(unittest.TestCase):
    def test_build_deck_merges_frequency_dictionary_and_sentences(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            frequency = root / "frequency.tsv"
            dictionary = root / "dictionary.jsonl"
            sentences = root / "sentences.tsv"
            output = root / "starter_deck.json"

            frequency.write_text("makan\\t100\\nminum\\t90\\n", encoding="utf-8")
            dictionary.write_text(
                json.dumps({
                    "word": "makan",
                    "pos": "verb",
                    "zh": "吃；进食",
                    "syllables": ["ma", "kan"],
                    "sourceUrl": "https://kaikki.org/mswiktionary/"
                }, ensure_ascii=False) + "\\n",
                encoding="utf-8"
            )
            sentences.write_text("makan\\tSaya makan nasi.\\t我吃米饭。\\n", encoding="utf-8")

            build_deck(frequency, dictionary, sentences, output, limit=2)
            payload = json.loads(output.read_text(encoding="utf-8"))

            self.assertEqual(payload["version"], 1)
            first_word = payload["decks"][0]["words"][0]
            self.assertEqual(first_word["term"], "makan")
            self.assertEqual(first_word["chineseMeaning"], "吃；进食")
            self.assertEqual(first_word["examples"][0]["malay"], "Saya makan nasi.")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 -m unittest scripts/test_content_builder.py`

Expected: FAIL with missing `build_starter_deck`.

- [ ] **Step 3: Implement content builder**

```python
# scripts/build_starter_deck.py
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def source(field, source_name, source_url, license_name, attribution, status="imported"):
    return {
        "field": field,
        "sourceName": source_name,
        "sourceUrl": source_url,
        "license": license_name,
        "attribution": attribution,
        "retrievedAt": datetime(2026, 5, 28, tzinfo=timezone.utc).isoformat().replace("+00:00", "Z"),
        "reviewStatus": status,
    }


def read_frequency(path):
    rows = []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        term, rank_or_count = line.split("\\t")[:2]
        rows.append((term.strip(), int(rank_or_count)))
    return rows


def read_dictionary(path):
    entries = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        item = json.loads(line)
        entries[item["word"]] = item
    return entries


def read_sentences(path):
    examples = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        term, malay, chinese = line.split("\\t")[:3]
        examples.setdefault(term, []).append((malay, chinese))
    return examples


def build_deck(frequency_path, dictionary_path, sentences_path, output_path, limit=500):
    frequency = read_frequency(frequency_path)
    dictionary = read_dictionary(dictionary_path)
    sentences = read_sentences(sentences_path)
    words = []

    for term, _score in frequency[:limit]:
        entry = dictionary.get(term, {})
        syllables = entry.get("syllables") or [term]
        examples = []
        for index, (malay, chinese) in enumerate(sentences.get(term, [])[:2], start=1):
            examples.append({
                "id": f"open-{term}-example-{index}",
                "malay": malay,
                "chinese": chinese,
                "sourceRefs": [
                    source("example", "Tatoeba or local sentence import", "local://sample_sentences.tsv", "CC BY or local personal-use", "Imported sentence source")
                ],
            })
        if not examples:
            examples.append({
                "id": f"template-{term}-example-1",
                "malay": f"Saya belajar perkataan {term}.",
                "chinese": f"我学习单词 {term}。",
                "sourceRefs": [
                    source("example", "MalayMate template fallback", "local://template-fallback", "personal-use-local", "MalayMate deterministic template", "generated")
                ],
            })

        words.append({
            "id": f"open-{term}",
            "term": term,
            "languageCode": "ms-MY",
            "chineseMeaning": entry.get("zh", term),
            "partOfSpeech": entry.get("pos", "unknown"),
            "pronunciationNotes": "-".join(syllables),
            "syllables": syllables,
            "examples": examples,
            "sourceRefs": [
                source("term", "Leipzig or local frequency import", "local://sample_frequency.tsv", "open-access or local personal-use", "Imported frequency source"),
                source("dictionary", "Kaikki Wiktionary extraction", entry.get("sourceUrl", "https://kaikki.org/mswiktionary/"), "Wiktionary-derived", "Wiktionary contributors")
            ],
        })

    payload = {
        "version": 1,
        "generatedAt": datetime(2026, 5, 28, tzinfo=timezone.utc).isoformat().replace("+00:00", "Z"),
        "decks": [
            {
                "id": "open-frequency-starter",
                "name": "Open Frequency Starter",
                "description": "Starter deck generated from local open-access source files.",
                "isStarter": True,
                "words": words,
            }
        ],
    }
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--frequency", required=True)
    parser.add_argument("--dictionary", required=True)
    parser.add_argument("--sentences", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--limit", type=int, default=500)
    args = parser.parse_args()
    build_deck(Path(args.frequency), Path(args.dictionary), Path(args.sentences), Path(args.output), args.limit)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Add sample raw files**

```text
# content/raw/sample_frequency.tsv
makan	100
minum	90
belajar	80
```

```json
{"word":"makan","pos":"verb","zh":"吃；进食","syllables":["ma","kan"],"sourceUrl":"https://kaikki.org/mswiktionary/"}
{"word":"minum","pos":"verb","zh":"喝；饮用","syllables":["mi","num"],"sourceUrl":"https://kaikki.org/mswiktionary/"}
{"word":"belajar","pos":"verb","zh":"学习","syllables":["be","la","jar"],"sourceUrl":"https://kaikki.org/mswiktionary/"}
```

```text
# content/raw/sample_sentences.tsv
makan	Saya makan nasi.	我吃米饭。
minum	Saya minum air.	我喝水。
belajar	Saya belajar bahasa Melayu.	我学习马来语。
```

- [ ] **Step 5: Run builder tests and generate sample output**

Run: `python3 -m unittest scripts/test_content_builder.py`

Expected: PASS.

Run:

```bash
python3 scripts/build_starter_deck.py \
  --frequency content/raw/sample_frequency.tsv \
  --dictionary content/raw/sample_dictionary.jsonl \
  --sentences content/raw/sample_sentences.tsv \
  --output content/generated/starter_deck.json \
  --limit 3
```

Expected: `content/generated/starter_deck.json` exists and decodes with the seed schema.

- [ ] **Step 6: Commit**

```bash
git add scripts content
git commit -m "feat: add local content builder"
```

---

### Task 12: Build App Bundle And Final Verification

**Files:**
- Create: `scripts/build_app_bundle.sh`
- Create: `packaging/Info.plist`
- Modify: `.gitignore`

- [ ] **Step 1: Add `.app` bundle packaging files**

```xml
<!-- packaging/Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>MalayMate</string>
  <key>CFBundleIdentifier</key>
  <string>local.zhuyingtao.MalayMate</string>
  <key>CFBundleName</key>
  <string>MalayMate</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
```

```bash
#!/usr/bin/env bash
# scripts/build_app_bundle.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release

APP_DIR="$ROOT/build/MalayMate.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT/.build/release/MalayMate" "$MACOS_DIR/MalayMate"
cp "$ROOT/packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$MACOS_DIR/MalayMate"

echo "$APP_DIR"
```

Add to `.gitignore`:

```gitignore
build/
```

- [ ] **Step 2: Make the packaging script executable**

Run: `chmod +x scripts/build_app_bundle.sh`

Expected: command exits 0.

- [ ] **Step 3: Run all automated tests**

Run: `swift test && python3 -m unittest scripts/test_content_builder.py`

Expected: all tests pass.

- [ ] **Step 4: Build the release app bundle**

Run: `scripts/build_app_bundle.sh`

Expected: prints `/Users/zhuyingtao/Documents/engineering/build/MalayMate.app`.

- [ ] **Step 5: Manual QA**

Run: `open build/MalayMate.app`

Expected:

- App opens to review-first UI.
- Sidebar shows at least two starter decks.
- Review card can reveal answer.
- Again, Good, and Easy advance through the queue.
- Add Word saves a personal word with local template fallback.
- Settings can save and clear an API key.
- Audio Play uses a Malay system voice when installed.
- Quit and reopen keeps review progress.

- [ ] **Step 6: Commit**

```bash
git add .gitignore packaging scripts/build_app_bundle.sh
git commit -m "chore: add macOS app bundle packaging"
```

---

## Final Verification

Run these commands from `/Users/zhuyingtao/Documents/engineering` after all tasks are complete:

```bash
swift test
python3 -m unittest scripts/test_content_builder.py
swift build -c release
scripts/build_app_bundle.sh
```

Expected result:

- Swift tests pass.
- Python content builder tests pass.
- Release build succeeds.
- `build/MalayMate.app` exists and opens.

## Documentation And Source Notes

Keep `docs/superpowers/specs/2026-05-28-malay-vocab-macos-design.md` as the product spec. Add implementation notes to `README.md` after the first runnable app exists. The README should include:

- How to run tests.
- How to run the app with `swift run MalayMate`.
- How to build `build/MalayMate.app`.
- Where the starter deck is stored.
- How API key storage works.
- What data sources are personal-use imports.

OpenAI implementation references checked while writing this plan:

- Models are available through the Responses API, and current docs list lower-cost mini variants for latency and cost-sensitive work: https://developers.openai.com/api/docs/models/all
- Structured output should use structured outputs rather than JSON mode when available: https://developers.openai.com/api/docs/guides/structured-outputs
- Responses API structured output can use `text.format` with JSON Schema: https://developers.openai.com/api/docs/guides/structured-outputs
