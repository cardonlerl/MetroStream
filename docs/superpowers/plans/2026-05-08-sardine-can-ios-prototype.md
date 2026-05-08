# Sardine Can iOS Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the local SwiftUI iOS prototype for 「沙丁鱼罐头」 with home map, station selection, cabin publishing, arrival, and personal memories.

**Architecture:** Use XcodeGen to generate an iOS SwiftUI app target and unit test target. Keep behavior in small Swift types (`AppState`, `MetroRepository`, `MemoryStore`, `RideSession`) so publish limits, route planning, and local persistence can be tested independently of UI. SwiftUI screens remain shallow compositions over those models.

**Tech Stack:** Swift 6, SwiftUI, CoreLocation, XCTest, XcodeGen, local JSON/UserDefaults storage.

---

## File Map

- Create `project.yml`: XcodeGen configuration for `MetroStream` app and `MetroStreamTests`.
- Create `MetroStream/MetroStreamApp.swift`: app entry point with display name supplied by Info.plist settings.
- Create `MetroStream/AppState.swift`: page state, current ride, repositories, navigation actions.
- Create `MetroStream/Models/MetroModels.swift`: station, line, route, cabin entry, ride, memory, drawing stroke models.
- Create `MetroStream/Data/MetroRepository.swift`: local line/station/seed content and route estimation.
- Create `MetroStream/Data/MemoryStore.swift`: JSON persistence for user memories.
- Create `MetroStream/Services/LocationService.swift`: CoreLocation wrapper with fallback nearby stations.
- Create `MetroStream/Views/Shared/DesignSystem.swift`: colors, button styles, paper surfaces.
- Create `MetroStream/Views/Home/HomeView.swift`: shallow warm-paper home with map, record icon, departure button.
- Create `MetroStream/Views/Shared/MetroMapView.swift`: reusable simplified map with optional highlighted travelled segments.
- Create `MetroStream/Views/StationSelection/StationSelectionView.swift`: start, destination, confirm flow.
- Create `MetroStream/Views/Cabin/CabinView.swift`: route header, cabin content, single publish entry, arrival overlay.
- Create `MetroStream/Views/Cabin/PublishSheet.swift`: bottom sheet with 字/画/歌 modes.
- Create `MetroStream/Views/Cabin/DrawingPad.swift`: minimal drawing canvas and eraser.
- Create `MetroStream/Views/Memory/MemoryView.swift`: highlighted map and own content only.
- Create `MetroStreamTests/MetroStreamTests.swift`: unit tests for repository, session publish limit, and memory store.

## Task 1: Project Skeleton

**Files:**
- Create: `project.yml`
- Create: `MetroStream/MetroStreamApp.swift`
- Create: `MetroStream/Views/Shared/DesignSystem.swift`

- [ ] **Step 1: Add XcodeGen project config**

Create `project.yml` with an iOS app target named `MetroStream`, display name `沙丁鱼罐头`, bundle id `com.local.sardinecan`, deployment target iOS 17, and a unit test target.

- [ ] **Step 2: Add minimal SwiftUI app shell**

Create `MetroStreamApp.swift` with `WindowGroup { ContentBootstrapView() }` and a temporary bootstrap view.

- [ ] **Step 3: Generate project**

Run: `xcodegen generate`

Expected: `MetroStream.xcodeproj` is created.

- [ ] **Step 4: Build skeleton**

Run: `xcodebuild -project MetroStream.xcodeproj -scheme MetroStream -destination 'platform=iOS Simulator,name=iPhone 17' build`

Expected: build succeeds.

- [ ] **Step 5: Commit**

Run:

```bash
git add project.yml MetroStream MetroStream.xcodeproj
git commit -m "Add iOS project skeleton"
```

## Task 2: Local Models and Repository

**Files:**
- Create: `MetroStream/Models/MetroModels.swift`
- Create: `MetroStream/Data/MetroRepository.swift`
- Create: `MetroStreamTests/MetroStreamTests.swift`

- [ ] **Step 1: Write failing repository tests**

Test that the repository exposes core stations, finds nearby stations within 2 km, estimates a route, and returns seed cabin entries.

- [ ] **Step 2: Run tests to verify failure**

Run: `xcodebuild -project MetroStream.xcodeproj -scheme MetroStream -destination 'platform=iOS Simulator,name=iPhone 17' test`

Expected: tests fail because model/repository types do not exist or behavior is missing.

- [ ] **Step 3: Implement minimal models and repository**

Add value types and seed data for 5-8 Shanghai core lines with enough stations to draw a recognizable local map and support the selection flow.

- [ ] **Step 4: Run tests to verify pass**

Run the same `xcodebuild ... test` command.

Expected: repository tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add MetroStream/Models MetroStream/Data MetroStreamTests
git commit -m "Add local metro data model"
```

## Task 3: Ride Session and Persistence

**Files:**
- Modify: `MetroStream/Models/MetroModels.swift`
- Modify: `MetroStream/Data/MemoryStore.swift`
- Modify: `MetroStreamTests/MetroStreamTests.swift`

- [ ] **Step 1: Write failing ride and memory tests**

Test that a ride accepts three entries, rejects the fourth, and that memory store saves only user-published entries for later display.

- [ ] **Step 2: Run tests to verify failure**

Run: `xcodebuild -project MetroStream.xcodeproj -scheme MetroStream -destination 'platform=iOS Simulator,name=iPhone 17' test`

Expected: tests fail because ride publishing and memory persistence are missing.

- [ ] **Step 3: Implement ride publishing and JSON persistence**

Add `RideSession.publish(_:)`, `PublishError.limitReached`, and `MemoryStore` with injectable file URL for tests.

- [ ] **Step 4: Run tests to verify pass**

Run the same test command.

Expected: all unit tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add MetroStream/Models MetroStream/Data MetroStreamTests
git commit -m "Add ride publishing and memory storage"
```

## Task 4: App State and Location

**Files:**
- Create: `MetroStream/AppState.swift`
- Create: `MetroStream/Services/LocationService.swift`
- Modify: `MetroStreamTests/MetroStreamTests.swift`

- [ ] **Step 1: Write failing app state tests**

Test that selecting stations creates a route, starting a ride sets current ride, publishing records content, and ending a ride stores memories only when content exists.

- [ ] **Step 2: Run tests to verify failure**

Run the app test command.

Expected: app state tests fail because `AppState` is missing.

- [ ] **Step 3: Implement app state and location fallback**

Add observable app state, location authorization request, nearest station fallback, and navigation enum.

- [ ] **Step 4: Run tests to verify pass**

Run the app test command.

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add MetroStream/AppState.swift MetroStream/Services MetroStreamTests
git commit -m "Add app state and location fallback"
```

## Task 5: Home and Station Selection UI

**Files:**
- Create: `MetroStream/Views/Home/HomeView.swift`
- Create: `MetroStream/Views/Shared/MetroMapView.swift`
- Create: `MetroStream/Views/StationSelection/StationSelectionView.swift`
- Modify: `MetroStream/MetroStreamApp.swift`

- [ ] **Step 1: Build home UI**

Implement a light paper home with only map, record icon, and `出发`.

- [ ] **Step 2: Build station selection UI**

Implement start/destination/confirm flow with search and `你还没到站` validation.

- [ ] **Step 3: Build app shell navigation**

Wire `AppState.screen` to home, selection, cabin, and memory placeholders.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project MetroStream.xcodeproj -scheme MetroStream -destination 'platform=iOS Simulator,name=iPhone 17' build`

Expected: build succeeds.

- [ ] **Step 5: Commit**

Run:

```bash
git add MetroStream
git commit -m "Add home and station selection"
```

## Task 6: Cabin and Publishing UI

**Files:**
- Create: `MetroStream/Views/Cabin/CabinView.swift`
- Create: `MetroStream/Views/Cabin/PublishSheet.swift`
- Create: `MetroStream/Views/Cabin/DrawingPad.swift`
- Modify: `MetroStream/AppState.swift`

- [ ] **Step 1: Build cabin screen**

Implement route header, countdown, historical content bubbles, people outlines, horizontal cabin paging, and early exit.

- [ ] **Step 2: Build single-entry publisher**

Keep only one `＋` button in the cabin. Present a bottom sheet where the user chooses 字、画、歌 and then publishes.

- [ ] **Step 3: Build drawing mode**

Use SwiftUI drawing gestures for rough strokes, eraser, and clear.

- [ ] **Step 4: Verify publish limit manually through state and build**

Run app build command.

Expected: build succeeds and no UI compile errors.

- [ ] **Step 5: Commit**

Run:

```bash
git add MetroStream
git commit -m "Add cabin publisher"
```

## Task 7: Memory UI and Final Verification

**Files:**
- Create: `MetroStream/Views/Memory/MemoryView.swift`
- Modify: `MetroStream/Views/Shared/MetroMapView.swift`
- Modify: `MetroStream/MetroStreamApp.swift`

- [ ] **Step 1: Build memory screen**

Show the same map with only user-published route segments highlighted and a compact list of the user's own entries.

- [ ] **Step 2: Final build**

Run: `xcodebuild -project MetroStream.xcodeproj -scheme MetroStream -destination 'platform=iOS Simulator,name=iPhone 17' build`

Expected: build succeeds.

- [ ] **Step 3: Run tests**

Run: `xcodebuild -project MetroStream.xcodeproj -scheme MetroStream -destination 'platform=iOS Simulator,name=iPhone 17' test`

Expected: all unit tests pass.

- [ ] **Step 4: Commit**

Run:

```bash
git add MetroStream MetroStreamTests
git commit -m "Add memory map"
```
