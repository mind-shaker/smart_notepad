import SwiftUI

struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @State private var showSaveConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Voice Notepad")
                .font(.headline)
            
            Text(speechManager.transcribedText.isEmpty ? "Dictate your thoughts..." : speechManager.transcribedText)
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            
            HStack {
                Button(action: {
                    speechManager.toggleRecording()
                }) {
                    Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(speechManager.isRecording ? .red : .blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                if !speechManager.isRecording && !speechManager.transcribedText.isEmpty {
                    Button(action: {
                        NotesManager.shared.saveToNotes(content: speechManager.transcribedText)
                        showSaveConfirmation = true
                        speechManager.transcribedText = ""
                    }) {
                        Text("Save to Notes")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if showSaveConfirmation {
                Text("Saved to Notes!")
                    .foregroundColor(.green)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSaveConfirmation = false
                        }
                    }
            }
        }
        .padding()
        .frame(width: 300)
    }
}
