import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var cloudKit: CloudKitManager = .shared
    @State private var showHouseholdManagement = false
    @State private var showSiriShortcuts = false

    var body: some View {
        NavigationStack {
            List {
                Section("Haushalt") {
                    Button {
                        showHouseholdManagement = true
                    } label: {
                        HStack {
                            Label("Haushalt verwalten", systemImage: "house.fill")
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

                Section("iCloud") {
                    HStack {
                        Label("Synchronisierung", systemImage: "icloud")
                        Spacer()
                        syncStatusBadge
                    }
                    if let last = cloudKit.lastSyncDate {
                        Text("Zuletzt: \(last.germanDateString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await cloudKit.checkAccountStatus() }
                    } label: {
                        Label("Jetzt synchronisieren", systemImage: "arrow.clockwise")
                    }
                }

                Section("Siri") {
                    Button {
                        showSiriShortcuts = true
                    } label: {
                        HStack {
                            Label("Siri-Kurzbefehle", systemImage: "waveform")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section("Über Wochi") {
                    LabeledContent("Version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: URL(string: "https://wochi.app/privacy")!) {
                        Label("Datenschutz", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: "https://wochi.app/terms")!) {
                        Label("Nutzungsbedingungen", systemImage: "doc.text")
                    }
                    Link(destination: URL(string: "mailto:support@wochi.app")!) {
                        Label("Kontakt", systemImage: "envelope")
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
            Label("Synchronisiert", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .syncing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Synchronisiert...")
                    .font(.caption)
            }
        case .offline:
            Label("Offline", systemImage: "wifi.slash")
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
