import Foundation

/// Resolve catalog strings for labels assembled at runtime. SwiftUI only
/// extracts literal LocalizedStringKey values automatically.
enum L10n {
    static func text(_ source: String) -> String {
        Bundle.main.localizedString(forKey: source, value: source, table: "Localizable")
    }

    static func effect(_ id: String, _ field: String, fallback: String) -> String {
        Bundle.main.localizedString(forKey: "effect.\(id).\(field)", value: fallback,
                                            table: "Localizable")
    }

    static func format(_ source: String, _ args: CVarArg...) -> String {
        String(format: text(source), arguments: args)
    }
}
