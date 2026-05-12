import Foundation

enum WochiError: LocalizedError {
    case networkUnavailable
    case cloudKitSyncFailed(underlying: Error)
    case receiptParsingFailed
    case householdNotFound
    case unauthorized
    case supabaseFetchFailed(underlying: Error)
    case householdFull
    case invalidInviteLink
    case alreadyMember

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Keine Internetverbindung. Deine Daten werden synchronisiert, sobald du wieder online bist."
        case .cloudKitSyncFailed:
            return "Synchronisierung fehlgeschlagen. Bitte prüfe deine iCloud-Einstellungen."
        case .receiptParsingFailed:
            return "Der Kassenbon konnte nicht gelesen werden. Bitte versuche es erneut."
        case .householdNotFound:
            return "Haushalt nicht gefunden. Bitte erstelle einen neuen Haushalt."
        case .unauthorized:
            return "Du hast keine Berechtigung für diese Aktion."
        case .supabaseFetchFailed:
            return "Preisdaten konnten nicht geladen werden. Bitte versuche es später erneut."
        case .householdFull:
            return "Der Haushalt hat bereits 10 Mitglieder und ist voll."
        case .invalidInviteLink:
            return "Der Einladungslink ist ungültig oder abgelaufen."
        case .alreadyMember:
            return "Du bist bereits Mitglied dieses Haushalts."
        }
    }
}
