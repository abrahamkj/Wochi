import BackgroundTasks
import SwiftData

// MARK: - FlyerRefreshTask
//
// Registers and schedules a BGAppRefreshTask that fetches fresh flyer prices
// from Supabase and generates SubstitutionAlerts for the current household.
// Call `register(modelContainer:)` once at app launch (before the app finishes launching).

enum FlyerRefreshTask {
    static func register(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Constants.Budget.flyerRefreshTaskID,
            using: nil
        ) { task in
            handle(task as! BGAppRefreshTask, modelContainer: modelContainer)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Constants.Budget.flyerRefreshTaskID)
        // Earliest next fetch: 6 hours from now (system decides actual timing)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Handler

    private static func handle(_ task: BGAppRefreshTask, modelContainer: ModelContainer) {
        // Re-schedule for the next cycle before doing any work
        schedule()

        let context = ModelContext(modelContainer)
        task.expirationHandler = { task.setTaskCompleted(success: false) }

        Task { @MainActor in
            let household = try? await HouseholdRepository(context: context).fetchCurrentHousehold()
            guard let household else {
                task.setTaskCompleted(success: true)
                return
            }
            let preferredStores = (household.preferredStores ?? [])
                .filter { $0.isActive }
                .map { $0.storeChain }
            let stores = preferredStores.isEmpty ? StoreChain.allCases.filter { $0 != .other } : preferredStores

            await AlertGenerationService.shared.generateAlerts(
                for: household,
                stores: stores,
                context: context
            )
            task.setTaskCompleted(success: true)
        }
    }
}
