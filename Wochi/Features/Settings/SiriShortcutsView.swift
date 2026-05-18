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
            title: "Artikel hinzufügen",
            subtitle: "Füge einen Artikel direkt zu deiner aktiven Einkaufsliste hinzu.",
            phrase: "\u{201E}Füge Milch zu Wochi hinzu\u{201C}"
        ),
        ShortcutInfo(
            symbol: "list.bullet",
            title: "Wochi Liste anzeigen",
            subtitle: "Öffne deine aktuelle Einkaufsliste.",
            phrase: "\u{201E}Öffne meine Wochi Liste\u{201C}"
        ),
        ShortcutInfo(
            symbol: "cabinet",
            title: "Vorräte prüfen",
            subtitle: "Sieh dir deinen aktuellen Vorrat an.",
            phrase: "\u{201E}Zeige meine Vorräte in Wochi\u{201C}"
        ),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Sage einfach den Satz zu Siri, um den Kurzbefehl zu nutzen. Du kannst die Kurzbefehle auch in der Shortcuts-App anpassen.")
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
                            Text(shortcut.title)
                                .font(.body)
                            Text(shortcut.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(shortcut.phrase)
                                .font(.caption).italic()
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Siri-Kurzbefehle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SiriShortcutsView()
}
