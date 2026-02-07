import Foundation
import Combine  // обов'язково для ObservableObject

class NotesManager: ObservableObject {
    
    static let shared = NotesManager()
    
    // Якщо хочеш показувати статус збереження в UI, можеш додати @Published
    // @Published var lastSaveStatus: String = ""
    
    func saveToNotes(content: String) {
        // Екрануємо лапки в тексті, щоб AppleScript не зламався
        let escapedContent = content.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")  // краще екранувати і нові рядки
        
        let scriptSource = """
        tell application "Notes"
            tell account "iCloud"  -- або "default account", якщо хочеш останній активний
                tell folder "Notes"
                    make new note with properties {name:"Нотатка від \(Date().formatted(date: .abbreviated, time: .shortened))", body:"\(escapedContent)"}
                end tell
            end tell
        end tell
        """
        
        guard let script = NSAppleScript(source: scriptSource) else {
            print("Помилка створення AppleScript")
            // self.lastSaveStatus = "Помилка створення скрипту"
            return
        }
        
        var error: NSDictionary?

        _ = script.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript помилка: \(error)")
            // self.lastSaveStatus = "Не вдалося зберегти: \(error["NSAppleScriptErrorMessage"] ?? "невідома помилка")"
        } else {
            print("Нотатку успішно збережено в Notes")
            // self.lastSaveStatus = "Збережено"
        }
    }
}
