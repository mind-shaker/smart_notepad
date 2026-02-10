import Foundation
import AppKit
import UserNotifications

class NotesManager {
    
    static let shared = NotesManager()
    
    private init() {
        // Запит дозволу на сповіщення
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Дозвіл на сповіщення отримано")
            }
        }
    }
    
    func saveToNotes(content: String) {
        print("🔵 saveToNotes викликано з контентом довжиною: \(content.count) символів")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy HH:mm"
        let dateString = dateFormatter.string(from: Date())
        
        let title = "Голосова нотатка \(dateString)"
        
        // Спробуємо найпростіший варіант — просто текст без HTML
        let simpleContent = "\(title)\n\n\(content)"
        let escapedContent = simpleContent.replacingOccurrences(of: "\\", with: "\\\\")
                                          .replacingOccurrences(of: "\"", with: "\\\"")
                                          .replacingOccurrences(of: "\n", with: "\\n")
        
        print("📝 Escaped content: \(escapedContent.prefix(100))...")
        
        // Додамо інформацію про оточення для діагностики
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        print("🔍 Environment Check:")
        print("   Is Sandboxed: \(isSandboxed)")
        print("   Process ID: \(ProcessInfo.processInfo.processIdentifier)")
        
        // Спроба 1: Найпростіший можливий скрипт
        let scriptSource = """
        tell application "Notes"
            activate
            try
                make new note with properties {body:"\(escapedContent)"}
                return "Success"
            on error errMsg number errNum
                return "Error: " & errMsg & " (" & errNum & ")"
            end try
        end tell
        """
        
        print("📜 AppleScript (with try/catch):\n\(scriptSource)")
        print("🚀 Виконую NSAppleScript...")
        
        var error: NSDictionary?
        let script = NSAppleScript(source: scriptSource)
        let result = script?.executeAndReturnError(&error)
        
        if let err = error {
            print("❌ NSAppleScript помилка (System level):")
            print("   Error dict: \(err)")
            if let errMsg = err["NSAppleScriptErrorMessage"] as? String {
                print("   Повідомлення: \(errMsg)")
            }
            if let errNum = err["NSAppleScriptErrorNumber"] as? Int {
                print("   Код помилки: \(errNum)")
            }
            
            // Спроба 2: Через osascript з детальним логуванням
            print("🔄 Пробую через osascript...")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", scriptSource]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                if !output.isEmpty {
                    print("📤 osascript output: \(output)")
                }
                
                if !errorOutput.isEmpty {
                    print("❌ osascript error: \(errorOutput)")
                    showNotification(title: "Помилка", message: "AppleScript error: \(errorOutput)")
                } else if output.contains("Error:") {
                    print("❌ osascript script-level error: \(output)")
                    showNotification(title: "Помилка", message: "Script Error: \(output)")
                } else {
                    print("✅ osascript завершився без помилок (exit code: \(process.terminationStatus))")
                    if process.terminationStatus == 0 {
                        showNotification(title: "Збережено", message: "Нотатка має бути в Notes")
                    } else {
                        showNotification(title: "Увага", message: "Скрипт виконано, код \(process.terminationStatus)")
                    }
                }
            } catch {
                print("❌ Не вдалося запустити osascript: \(error)")
                showNotification(title: "Помилка", message: "Системна помилка: \(error.localizedDescription)")
            }
        } else {
            let resultStr = result?.stringValue ?? "Unknown"
            print("✅ NSAppleScript виконано! Результат: \(resultStr)")
            
            if resultStr.contains("Error:") {
                print("❌ Але повернуто помилку скрипта: \(resultStr)")
                showNotification(title: "Помилка в скрипті", message: resultStr)
            } else {
                showNotification(title: "Збережено", message: "Нотатка додана в Notes")
            }
        }
    }
    
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Помилка надсилання сповіщення: \(error)")
            }
        }
    }
}