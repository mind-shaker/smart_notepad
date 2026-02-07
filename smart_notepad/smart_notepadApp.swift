//
//  SmartNotepadApp.swift
//  smart_notepad
//
//  Created by Oleg Danilchenko on 07.02.2026.
//

import SwiftUI

@main
struct SmartNotepadApp: App {
    
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var notesManager = NotesManager()
    
    var body: some Scene {
        // Це робить додаток менюбарним (тільки іконка вгорі праворуч)
        MenuBarExtra("Smart Notepad", systemImage: "mic") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Розумний блокнот")
                    .font(.headline)
                    .padding(.top, 8)
                
                if speechManager.recognitionError != nil {
                    Text(speechManager.recognitionError ?? "")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Text(speechManager.isRecording ? "Запис..." : "Готовий до диктування")
                    .foregroundColor(speechManager.isRecording ? .red : .green)
                
                Text(speechManager.transcribedText.isEmpty ? "Натисни для диктування" : speechManager.transcribedText)
                    .font(.body)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                HStack {
                    Button(speechManager.isRecording ? "Зупинити" : "Почати диктувати") {
                        speechManager.toggleRecording()
                    }
                    .keyboardShortcut(speechManager.isRecording ? .cancelAction : .defaultAction)
                    
                    if !speechManager.transcribedText.isEmpty && !speechManager.isRecording {
                        Button("Зберегти в Notes") {
                            notesManager.saveToNotes(content: speechManager.transcribedText)
                            speechManager.transcribedText = ""
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .padding()
            .frame(minWidth: 300)
        }
        // Стиль вікна менюбарного меню
        .menuBarExtraStyle(.window)
    }
}
