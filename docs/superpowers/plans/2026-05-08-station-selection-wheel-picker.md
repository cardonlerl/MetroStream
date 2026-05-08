# Station Selection Wheel Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the station selection list with an iOS-style two-column wheel picker: left column for metro lines, right column for stations on the selected line.

**Architecture:** Keep navigation and route ownership in `AppState`. Add small query helpers to `MetroRepository` so the UI can ask for ordered stations on a line and lines containing a station set. Keep the wheel UI local to `StationSelectionView.swift` to avoid introducing a broader component hierarchy for one screen.

**Tech Stack:** Swift 6, SwiftUI, XCTest, existing `MetroStream.xcodeproj` iOS app target.

---

## File Map

- Modify `MetroStream/Data/MetroRepository.swift`: add ordered line/station lookup helpers used by the wheel picker.
- Modify `MetroStreamTests/MetroStreamTests.swift`: add unit tests for the new repository helpers.
- Modify `MetroStream/Views/StationSelection/StationSelectionView.swift`: replace the search/list body with the two-column wheel picker and keep existing page actions.

## Task 1: Add Repository Helpers for Wheel Data

**Files:**
- Modify: `MetroStream/Data/MetroRepository.swift`
- Modify: `MetroStreamTests/MetroStreamTests.swift`

- [ ] **Step 1: Write failing helper tests**

Add these tests inside `MetroRepositoryTests` in `MetroStreamTests/MetroStreamTests.swift`:

```swift
func testStationsOnLineAreReturnedInLineOrder() throws {
    let repository = MetroRepository()

    let stations = repository.stations(onLineID: "line2")

    XCTAssertEqual(stations.map(\.name), [
        "娄山关路",
        "中山公园",
        "静安寺",
        "南京西路",
        "人民广场",
        "南京东路",
        "陆家嘴",
        "世纪大道",
        "龙阳路"
    ])
}

func testLinesContainingStationsPreserveRepositoryOrder() throws {
    let repository = MetroRepository()
    let peopleSquare = try XCTUnwrap(repository.station(named: "人民广场"))
    let jingAnTemple = try XCTUnwrap(repository.station(named: "静安寺"))

    let lines = repository.lines(containingAnyStationIDs: Set([peopleSquare.id, jingAnTemple.id]))

    XCTAssertEqual(lines.map(\.name), ["1号线", "2号线", "7号线", "8号线"])
}

func testFirstLineReturnsNilWhenStationHasNoLine() {
    let repository = MetroRepository()
    let station = MetroStation(
        id: "temporary",
        name: "临时站",
        latitude: 0,
        longitude: 0,
        lineIDs: [],
        mapPoint: MapPoint(x: 0, y: 0)
    )

    XCTAssertNil(repository.firstLine(containing: station))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project MetroStream.xcodeproj -scheme MetroStream -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: the build fails because `stations(onLineID:)`, `lines(containingAnyStationIDs:)`, and `firstLine(containing:)` do not exist.

- [ ] **Step 3: Implement repository helpers**

In `MetroStream/Data/MetroRepository.swift`, add these methods after `station(id:)`:

```swift
func stations(onLineID lineID: String) -> [MetroStation] {
    guard let line = line(id: lineID) else { return [] }
    return line.stationIDs.compactMap(station(id:))
}

func lines(containingAnyStationIDs stationIDs: Set<String>) -> [MetroLine] {
    lines.filter { line in
        line.stationIDs.contains { stationIDs.contains($0) }
    }
}

func firstLine(containing station: MetroStation) -> MetroLine? {
    station.lineIDs.compactMap(line(id:)).first
}
```

- [ ] **Step 4: Run tests to verify pass**

Run:

```bash
xcodebuild -project MetroStream.xcodeproj -scheme MetroStream -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: all unit tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add MetroStream/Data/MetroRepository.swift MetroStreamTests/MetroStreamTests.swift
git commit -m "Add station selection repository helpers"
```

## Task 2: Replace Station List with Two-Column Wheel Picker

**Files:**
- Modify: `MetroStream/Views/StationSelection/StationSelectionView.swift`

- [ ] **Step 1: Prepare wheel state**

In `StationSelectionView`, replace the current `query` state with line/station state:

```swift
@State private var selectedLineID = ""
@State private var selectedStationID = ""
@State private var selectingDestination = false
@State private var showDistanceWarning = false
```

Add these computed properties below `nearbyStations`:

```swift
private var nearbyStationIDs: Set<String> {
    Set(nearbyStations.map(\.station.id))
}

private var lineOptions: [MetroLine] {
    if selectingDestination {
        return appState.repository.lines
    }
    let nearbyIDs = nearbyStationIDs
    let nearbyLines = appState.repository.lines(containingAnyStationIDs: nearbyIDs)
    return nearbyLines.isEmpty ? appState.repository.lines : nearbyLines
}

private var stationOptions: [MetroStation] {
    let activeLineID = selectedLineID.isEmpty ? lineOptions.first?.id : selectedLineID
    guard let activeLineID else { return [] }
    return appState.repository.stations(onLineID: activeLineID)
}

```

- [ ] **Step 2: Replace body stack content**

Replace the main `VStack` body content with:

```swift
VStack(spacing: 18) {
    topBar
    selectedStrip
    wheelSelector
    enterButton
}
.padding(.horizontal, 22)
.padding(.vertical, 18)
```

Then extend the existing `.task` modifier so it initializes the picker:

```swift
.task {
    locationService.requestAuthorization()
    synchronizeWheelSelection()
}
.onChange(of: selectingDestination) { _, _ in
    synchronizeWheelSelection()
}
.onChange(of: nearbyStations) { _, _ in
    if !selectingDestination {
        synchronizeWheelSelection()
    }
}
```

- [ ] **Step 3: Update top bar chip actions**

Inside `topBar`, remove `query = ""` from both chip actions and call `synchronizeWheelSelection()` after changing mode:

```swift
Button("出发站") {
    selectingDestination = false
    synchronizeWheelSelection()
}
.buttonStyle(TextChipStyle(isSelected: !selectingDestination))

Button("到达站") {
    selectingDestination = true
    synchronizeWheelSelection()
}
.buttonStyle(TextChipStyle(isSelected: selectingDestination))
```

- [ ] **Step 4: Add the wheel selector view property**

Replace `searchField` and `stationList` with this `wheelSelector` property:

```swift
private var wheelSelector: some View {
    WheelStationSelector(
        lineOptions: lineOptions,
        stationOptions: stationOptions,
        selectedLineID: Binding(
            get: { selectedLineID },
            set: { selectLine($0) }
        ),
        selectedStationID: Binding(
            get: { selectedStationID },
            set: { selectStationID($0) }
        ),
        stationIsEnabled: { station in
            selectingDestination || nearbyStationIDs.contains(station.id)
        }
    )
    .overlay(alignment: .bottom) {
        if showDistanceWarning {
            Text("你还没到站")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(SardineColors.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(SardineColors.paperRaised)
                .clipShape(Capsule())
                .shadow(color: SardineColors.softShadow, radius: 10, y: 4)
                .padding(.bottom, 10)
        }
    }
}
```

- [ ] **Step 5: Add line and station selection methods**

Replace `choose(_:)` with these methods:

```swift
private func synchronizeWheelSelection() {
    let currentStation = selectingDestination ? appState.selectedDestination : appState.selectedStart
    let fallbackLine = currentStation.flatMap(appState.repository.firstLine(containing:)) ?? lineOptions.first

    selectedLineID = fallbackLine?.id ?? ""

    let fallbackStation = currentStation.flatMap { station in
        station.lineIDs.contains(selectedLineID) ? station : nil
    } ?? stationOptions.first { station in
        selectingDestination || nearbyStationIDs.contains(station.id)
    } ?? stationOptions.first

    selectedStationID = fallbackStation?.id ?? ""
}

private func selectLine(_ lineID: String) {
    selectedLineID = lineID
    let stations = appState.repository.stations(onLineID: lineID)
    guard let station = stations.first(where: { station in
        selectingDestination || nearbyStationIDs.contains(station.id)
    }) ?? stations.first else {
        selectedStationID = ""
        return
    }
    selectStation(station)
}

private func selectStationID(_ stationID: String) {
    guard let station = appState.repository.station(id: stationID) else { return }
    selectStation(station)
}

private func selectStation(_ station: MetroStation) {
    if selectingDestination {
        appState.selectDestination(station)
    } else if nearbyStationIDs.contains(station.id) {
        appState.selectStart(station)
        selectingDestination = true
    } else {
        showDistanceWarning = true
        let currentOptionIDs = Set(stationOptions.map(\.id))
        let committedStartID = appState.selectedStart?.id
        selectedStationID = committedStartID.flatMap { currentOptionIDs.contains($0) ? $0 : nil }
            ?? stationOptions.first(where: { nearbyStationIDs.contains($0.id) })?.id
            ?? selectedStationID
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showDistanceWarning = false
        }
        return
    }

    selectedStationID = station.id
}
```

- [ ] **Step 6: Add wheel subviews**

Add these private views below `StationPill` in `StationSelectionView.swift`:

```swift
private struct WheelStationSelector: View {
    let lineOptions: [MetroLine]
    let stationOptions: [MetroStation]
    @Binding var selectedLineID: String
    @Binding var selectedStationID: String
    var stationIsEnabled: (MetroStation) -> Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(SardineColors.paperRaised)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(SardineColors.hairline, lineWidth: 1))

            Rectangle()
                .fill(SardineColors.ink.opacity(0.07))
                .frame(height: 52)
                .overlay(Rectangle().stroke(SardineColors.hairline.opacity(0.65), lineWidth: 1))

            HStack(spacing: 0) {
                Picker("线路", selection: $selectedLineID) {
                    ForEach(lineOptions) { line in
                        Text(line.name)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .tag(line.id)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Rectangle()
                    .fill(SardineColors.hairline)
                    .frame(width: 1, height: 170)

                Picker("站点", selection: $selectedStationID) {
                    ForEach(stationOptions) { station in
                        Text(station.name)
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .foregroundStyle(stationIsEnabled(station) ? SardineColors.ink : SardineColors.mutedInk.opacity(0.48))
                            .tag(station.id)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 252)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.18),
                    .init(color: .black, location: 0.82),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
```

- [ ] **Step 7: Remove unused list/search code**

Delete these now-unused members from `StationSelectionView.swift`:

```swift
private var displayedStations: [MetroStation] { ... }
private var searchField: some View { ... }
private var stationList: some View { ... }
private func choose(_ station: MetroStation) { ... }
```

Keep `distanceText(_:)` only if it is still referenced; otherwise delete it too.

- [ ] **Step 8: Build to verify**

Run:

```bash
xcodebuild -project MetroStream.xcodeproj -scheme MetroStream -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: build succeeds and there are no unused-property compile errors.

- [ ] **Step 9: Commit**

Run:

```bash
git add MetroStream/Views/StationSelection/StationSelectionView.swift
git commit -m "Add wheel picker station selection"
```

## Task 3: Verify Interaction and Regressions

**Files:**
- No planned source edits unless verification exposes a defect.

- [ ] **Step 1: Run unit tests**

Run:

```bash
xcodebuild -project MetroStream.xcodeproj -scheme MetroStream -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: all tests pass.

- [ ] **Step 2: Run the app in simulator**

Run:

```bash
xcodebuild -project MetroStream.xcodeproj -scheme MetroStream -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: build succeeds. Launch through Xcode or the existing simulator workflow if available.

- [ ] **Step 3: Manual verification checklist**

Check these behaviors in the simulator:

```text
1. Home opens normally.
2. Tap 出发.
3. Station selection shows two wheel columns.
4. Left wheel changes the station options on the right.
5. Start mode writes a nearby station and switches to 到达站.
6. Destination mode writes the destination.
7. 已选 route strip updates with both station names.
8. 进入车厢 becomes enabled when a route exists.
9. No explanatory copy was added to the screen.
```

- [ ] **Step 4: Commit any verification fixes**

If a defect fix is needed, commit only the touched files:

```bash
git add MetroStream/Views/StationSelection/StationSelectionView.swift MetroStream/Data/MetroRepository.swift MetroStreamTests/MetroStreamTests.swift
git commit -m "Fix wheel picker station selection"
```

Expected: no commit is created if verification finds no defect.

## Self-Review

- Spec coverage: Task 1 adds data helpers for line/station wheel data. Task 2 implements the two-column wheel, keeps top chips, keeps selected route strip, keeps the enter button, preserves distance warning, and removes the search/list main UI. Task 3 verifies build, tests, and the no-extra-copy rule.
- Placeholder scan: no unfinished markers, repeated-step shortcuts, or undefined follow-up steps remain.
- Type consistency: helper names in tests match implementation snippets; UI snippets call existing `AppState.selectStart(_:)`, `AppState.selectDestination(_:)`, and existing design-system symbols.
