import Foundation

enum Constants {
    enum App {
        static let bundleID = "com.yourname.wochi"
        static let cloudKitContainerID = "iCloud.com.yourname.wochi"
        static let urlScheme = "wochi"
    }

    enum Budget {
        static let flyerRefreshTaskID = "com.yourname.wochi.flyer-refresh"
        static let dealThresholdPercent = 15.0
        static let maxAlertsPerProductPerWeek = 1
        static let purchaseHistoryWeeks = 4
    }

    enum Pantry {
        static let expiryWarningDays = 3
        static let defaultLowStockThreshold = 1.0
    }

    enum Household {
        static let maxMembers = 10
        static let inviteLinkValidityHours = 72
    }

    enum Notifications {
        static let expiryAlert = "pantry.expiry"
        static let lowStockAlert = "pantry.lowStock"
        static let itemAdded = "list.itemAdded"
        static let itemChecked = "list.itemChecked"
        static let dealAlert = "alert.deal"
        static let monthlyBudget = "budget.monthly"
    }

    enum UserDefaults {
        static let onboardingCompleted = "onboardingCompleted"
        static let householdID = "householdID"
        static let notificationSettings = "notificationSettings"
    }
}
