import Foundation
import SwiftData

@Model
final class HouseholdMember {
    @Attribute(.unique) var id: UUID
    var appleUserID: String
    var displayName: String
    var email: String?
    var avatarColor: String
    var role: MemberRole
    var joinedAt: Date
    var isCurrentDevice: Bool

    var household: Household?

    init(appleUserID: String, displayName: String, role: MemberRole = .member) {
        self.id = UUID()
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.role = role
        self.joinedAt = Date()
        self.avatarColor = MemberRole.randomAvatarColor()
        self.isCurrentDevice = false
    }
}

enum MemberRole: String, Codable {
    case owner
    case admin
    case member
    case viewer

    var localizedName: String {
        switch self {
        case .owner: return "Inhaber"
        case .admin: return "Admin"
        case .member: return "Mitglied"
        case .viewer: return "Gast"
        }
    }

    static func randomAvatarColor() -> String {
        let colors = ["#4ade80", "#60a5fa", "#f87171", "#fbbf24", "#a78bfa", "#34d399"]
        return colors.randomElement() ?? "#4ade80"
    }
}
