import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var cloudKit: CloudKitManager = .shared
    @State private var showHouseholdManagement = false
    @State private var showSiriShortcuts = false

    var body: some View {
        NavigationStack {
            List {
                Section("settings.section.household") {
                    Button {
                        showHouseholdManagement = true
                    } label: {
                        HStack {
                            Label("settings.household.manage", systemImage: "house.fill")
                            Spacer()
                            if let h = appState.currentHousehold {
                                Text(h.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section("settings.section.icloud") {
                    HStack {
                        Label("settings.sync.label", systemImage: "icloud")
                        Spacer()
                        syncStatusBadge
                    }
                    if let last = cloudKit.lastSyncDate {
                        Text(verbatim: String(format: String(localized: "settings.sync.last"), last.germanDateString))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await cloudKit.checkAccountStatus() }
                    } label: {
                        Label("settings.sync.now", systemImage: "arrow.clockwise")
                    }
                }

                Section("settings.section.siri") {
                    Button {
                        showSiriShortcuts = true
                    } label: {
                        HStack {
                            Label("settings.siri", systemImage: "waveform")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section("settings.section.about") {
                    LabeledContent("settings.version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: URL(string: "https://wochi.app/privacy")!) {
                        Label("settings.privacy", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: "https://wochi.app/terms")!) {
                        Label("settings.terms", systemImage: "doc.text")
                    }
                    Link(destination: URL(string: "mailto:support@wochi.app")!) {
                        Label("settings.contact", systemImage: "envelope")
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("tab.settings"))
            .sheet(isPresented: $showHouseholdManagement) {
                if let h = appState.currentHousehold {
                    HouseholdManagementView(household: h)
                }
            }
            .sheet(isPresented: $showSiriShortcuts) {
                SiriShortcutsView()
            }
        }
    }

    @ViewBuilder
    private var syncStatusBadge: some View {
        switch cloudKit.syncStatus {
        case .synced:
            Label("settings.sync.synced", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .syncing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("settings.sync.syncing")
                    .font(.caption)
            }
        case .offline:
            Label("settings.sync.offline", systemImage: "wifi.slash")
                .foregroundStyle(.orange)
                .font(.caption)
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
