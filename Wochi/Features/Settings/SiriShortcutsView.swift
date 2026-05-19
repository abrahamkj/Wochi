import SwiftUI

struct SiriShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    private struct ShortcutInfo: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let subtitle: String
        let phrase: String
    }

    private let shortcuts: [ShortcutInfo] = [
        ShortcutInfo(
            symbol: "cart.badge.plus",
            title: String(localized: "siri.shortcut1.title"),
            subtitle: String(localized: "siri.shortcut1.subtitle"),
            phrase: String(localized: "siri.shortcut1.phrase")
        ),
        ShortcutInfo(
            symbol: "list.bullet",
            title: String(localized: "siri.shortcut2.title"),
            subtitle: String(localized: "siri.shortcut2.subtitle"),
            phrase: String(localized: "siri.shortcut2.phrase")
        ),
        ShortcutInfo(
            symbol: "cabinet",
            title: String(localized: "siri.shortcut3.title"),
            subtitle: String(localized: "siri.shortcut3.subtitle"),
            phrase: String(localized: "siri.shortcut3.phrase")
        ),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("siri.description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                }

                // Disambiguate ForEach overload by providing an explicit id key path
                ForEach(shortcuts, id: \.id) { (shortcut: ShortcutInfo) in
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: shortcut.symbol)
                                    .foregroundColor(.white)
                                    .font(.title3)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: shortcut.title)
                                .font(.body)
                            Text(verbatim: shortcut.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(verbatim: shortcut.phrase)
                                .font(.caption).italic()
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("settings.siri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SiriShortcutsView()
}
