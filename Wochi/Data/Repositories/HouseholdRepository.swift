import Foundation
import SwiftData
import CloudKit

protocol HouseholdRepositoryProtocol {
    func fetchCurrentHousehold() async throws -> Household?
    func createHousehold(name: String) async throws -> Household
    func inviteMember(to household: Household) async throws -> URL
    func removeMember(_ member: HouseholdMember, from household: Household) async throws
    func updateMemberRole(_ member: HouseholdMember, role: MemberRole) async throws
    func leaveHousehold(_ household: Household) async throws
}

@MainActor
final class HouseholdRepository: HouseholdRepositoryProtocol {
    private let context: ModelContext
    private let shareManager: HouseholdShareManager

    init(context: ModelContext, shareManager: HouseholdShareManager = .shared) {
        self.context = context
        self.shareManager = shareManager
    }

    func fetchCurrentHousehold() async throws -> Household? {
        let descriptor = FetchDescriptor<Household>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).first
    }

    func createHousehold(name: String) async throws -> Household {
        let household = Household(name: name)
        context.insert(household)
        try context.save()
        return household
    }

    func inviteMember(to household: Household) async throws -> URL {
        guard household.members.count < Constants.Household.maxMembers else {
            throw WochiError.householdFull
        }
        return try await shareManager.createShareURL(for: household)
    }

    func removeMember(_ member: HouseholdMember, from household: Household) async throws {
        household.members.removeAll { $0.id == member.id }
        context.delete(member)
        try context.save()
    }

    func updateMemberRole(_ member: HouseholdMember, role: MemberRole) async throws {
        member.role = role
        try context.save()
    }

    func leaveHousehold(_ household: Household) async throws {
        try await shareManager.leaveShare(for: household)
        context.delete(household)
        try context.save()
    }
}
