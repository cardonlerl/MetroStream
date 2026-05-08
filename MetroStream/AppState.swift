import Foundation
import Observation

enum AppScreen: Equatable {
    case home
    case stationSelection
    case cabin
    case memories
}

@Observable
final class AppState {
    private(set) var screen: AppScreen = .home
    private(set) var selectedStart: MetroStation?
    private(set) var selectedDestination: MetroStation?
    private(set) var currentRoute: RoutePlan?
    private(set) var currentRide: RideSession?
    private(set) var memories: [UserMemory]
    private(set) var lastPublishError: PublishError?

    let repository: MetroRepository
    let memoryStore: MemoryStore

    init(repository: MetroRepository = MetroRepository(), memoryStore: MemoryStore = MemoryStore()) {
        self.repository = repository
        self.memoryStore = memoryStore
        self.memories = memoryStore.load()
    }

    func openSelection() {
        screen = .stationSelection
    }

    func openMemories() {
        memories = memoryStore.load()
        screen = .memories
    }

    func closeToHome() {
        screen = .home
    }

    func selectStart(_ station: MetroStation) {
        selectedStart = station
        refreshRoute()
    }

    func selectDestination(_ station: MetroStation) {
        selectedDestination = station
        refreshRoute()
    }

    func enterCabin() {
        guard let currentRoute else { return }
        currentRide = RideSession(route: currentRoute)
        lastPublishError = nil
        screen = .cabin
    }

    func publish(_ entry: CabinEntry) throws {
        guard var ride = currentRide else { return }
        do {
            try ride.publish(entry)
            currentRide = ride
            lastPublishError = nil
        } catch let error as PublishError {
            lastPublishError = error
            throw error
        }
    }

    func endRide() {
        if let ride = currentRide {
            memoryStore.save(ride: ride)
            memories = memoryStore.load()
        }
        currentRide = nil
        currentRoute = nil
        selectedStart = nil
        selectedDestination = nil
        lastPublishError = nil
        screen = .home
    }

    private func refreshRoute() {
        guard let selectedStart, let selectedDestination else {
            currentRoute = nil
            return
        }
        currentRoute = repository.route(from: selectedStart, to: selectedDestination)
    }
}
