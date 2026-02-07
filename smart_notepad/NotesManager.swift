import Foundation
import AppKit

class NotesManager {
    
    static let shared = NotesManager()
    
    private init() {} // Приватний ініціалізатор для singleton
    
    func saveToNotes(content: String) {
        // Екрануємо спеціальні символи для AppleScript
        let escapedContent = escapeForAppleScript(content)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy HH:mm"
        let dateString = dateFormatter.string(from: Date())
        
        // Спершу пробуємо зберегти в iCloud
        let iCloudScript = """
        tell application "Notes"
            activate
            tell account "iCloud"
                tell folder "Notes"
                    make new note with properties {name:"Голосова нотатка \(dateString)", body:"\(escapedContent)"}
                end tell
            end tell
        end tell
        """
        
        if executeScript(iCloudScript) {
            print("✅ Збережено в iCloud Notes")
            showNotification(title: "Збережено", message: "Нотатку додано в Notes (iCloud)")
            return
        }
        
        // Якщо не вдалося - пробуємо локальний акаунт
        print("⚠️ iCloud не спрацював, пробуємо локальний акаунт...")
        let localScript = """
        tell application "Notes"
            activate
            make new note with properties {name:"Голосова нотатка \(dateString)", body:"\(escapedContent)"}
        end tell
        """
        
        if executeScript(localScript) {
            print("✅ Збережено в локальні Notes")
            showNotification(title: "Збережено", message: "Нотатку додано в Notes (локально)")
        } else {
            print("❌ Не вдалося зберегти нотатку")
            showNotification(title: "Помилка", message: "Не вдалося зберегти в Notes. Перевірте дозволи.")
        }
    }
    
    private func escapeForAppleScript(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
    
    private func executeScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else {
            print("❌ Помилка створення AppleScript")
            return false
        }
        
        var error: NSDictionary?
        let output = script.executeAndReturnError(&error)
        
        if let error = error {
            print("❌ AppleScript помилка: \(error)")
            if let message = error["NSAppleScriptErrorMessage"] as? String {
                print("   Деталі: \(message)")
            }
            return false
        }
        
        print("✅ AppleScript виконано успішно: \(output)")
        return true
    }
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}