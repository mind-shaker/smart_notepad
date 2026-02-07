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
    
    var body: some Scene {
        MenuBarExtra("Smart Notepad", systemImage: "mic") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Розумний блокнот")
                    .font(.headline)
                    .padding(.top, 8)
                
                if let error = speechManager.recognitionError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .lineLimit(3)
                }
                
                Text(speechManager.isRecording ? "🔴 Запис..." : "🟢 Готовий до диктування")
                    .foregroundColor(speechManager.isRecording ? .red : .green)
                    .font(.subheadline)
                
                ScrollView {
                    Text(speechManager.transcribedText.isEmpty ? "Натисни для диктування" : speechManager.transcribedText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                .frame(minHeight: 80, maxHeight: 150)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                HStack(spacing: 10) {
                    Button(speechManager.isRecording ? "⏹ Зупинити" : "🎤 Почати") {
                        speechManager.toggleRecording()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(speechManager.isRecording ? .red : .blue)
                    .keyboardShortcut(speechManager.isRecording ? .cancelAction : .defaultAction)
                    
                    if !speechManager.transcribedText.isEmpty && !speechManager.isRecording {
                        Button("💾 Зберегти") {
                            NotesManager.shared.saveToNotes(content: speechManager.transcribedText)
                            speechManager.transcribedText = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                Button("Вийти") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .font(.caption)
            }
            .padding()
            .frame(minWidth: 320, maxWidth: 400)
        }
        .menuBarExtraStyle(.window)
    }
}