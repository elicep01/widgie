import Foundation

enum CommandAction {
    case list
    case remove(String)
    case theme(WidgetTheme)
    case layoutAuto
    case templates
    case createTemplate(String)
    case exportWidgets
    case importWidgets
    case settings
    case generate(String)
}

struct CommandParser {
    static func parse(_ rawInput: String) -> CommandAction {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else {
            return .generate(trimmed)
        }

        let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        guard let command = components.first?.lowercased() else {
            return .generate(trimmed)
        }

        switch command {
        case "/list":
            return .list
        case "/remove":
            let name = components.dropFirst().joined(separator: " ")
            if name.isEmpty {
                return .generate(trimmed)
            }
            return .remove(name)
        case "/theme":
            guard components.count >= 2,
                  let theme = WidgetTheme(rawValue: components[1].lowercased()) else {
                return .generate(trimmed)
            }
            return .theme(theme)
        case "/layout":
            if components.count >= 2, components[1].lowercased() == "auto" {
                return .layoutAuto
            }
            return .generate(trimmed)
        case "/templates":
            return .templates
        case "/template":
            let name = components.dropFirst().joined(separator: " ")
            if name.isEmpty {
                return .generate(trimmed)
            }
            return .createTemplate(name)
        case "/export":
            return .exportWidgets
        case "/import":
            return .importWidgets
        case "/settings":
            return .settings
        default:
            return .generate(trimmed)
        }
    }
}
