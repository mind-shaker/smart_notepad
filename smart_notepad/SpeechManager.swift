import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
class SpeechManager: ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var recognitionError: String? = nil
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "uk-UA"))
        
        if speechRecognizer == nil {
            recognitionError = "Мова uk-UA не підтримується"
            print("❌ SpeechRecognizer не створено")
        } else if !(speechRecognizer?.isAvailable ?? false) {
            recognitionError = "Розпізнавання зараз недоступне"
            print("⚠️ SpeechRecognizer недоступний")
        } else {
            print("✅ SpeechManager готовий (uk-UA)")
        }
    }
    
    func toggleRecording() {
        print("🔄 Toggle: isRecording = \(isRecording)")
        if isRecording {
            stopRecording()
        } else {
            Task {
                await checkPermissionsAndStart()
            }
        }
    }
    
    private func checkPermissionsAndStart() async {
        print("🔐 Перевірка дозволів...")
        
        // Перевірка дозволу на мікрофон для macOS
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("📱 Статус мікрофону: \(micStatus.rawValue)")
        
        if micStatus == .denied || micStatus == .restricted {
            await MainActor.run {
                recognitionError = "Немає доступу до мікрофону.\n\nВідкрийте: System Settings → Privacy & Security → Microphone\nта увімкніть smart_notepad"
            }
            print("❌ Мікрофон заборонено")
            return
        }
        
        if micStatus == .notDetermined {
            print("⏳ Запит дозволу на мікрофон...")
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            print("🎤 Дозвіл на мікрофон: \(granted ? "надано" : "відхилено")")
            
            if !granted {
                await MainActor.run {
                    recognitionError = "Доступ до мікрофону відхилено.\n\nПерейдіть до System Settings → Privacy & Security → Microphone"
                }
                return
            }
        }
        
        // Перевірка розпізнавання мови
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        print("🗣️ Статус розпізнавання: \(authStatus.rawValue)")
        
        if authStatus == .denied || authStatus == .restricted {
            await MainActor.run {
                recognitionError = "Немає дозволу на розпізнавання мови.\n\nSystem Settings → Privacy & Security → Speech Recognition"
            }
            print("❌ Розпізнавання заборонено")
            return
        }
        
        if authStatus == .notDetermined {
            print("⏳ Запит дозволу на розпізнавання...")
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            print("🗣️ Дозвіл на розпізнавання: \(granted ? "надано" : "відхилено")")
            
            if !granted {
                await MainActor.run {
                    recognitionError = "Дозвіл на розпізнавання відхилено"
                }
                return
            }
        }
        
        // Якщо всі дозволи є - запускаємо
        print("✅ Всі дозволи надано, запускаємо запис...")
        await MainActor.run {
            startRecording()
        }
    }
    
    private func startRecording() {
        print("▶️ Початок запису...")
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            recognitionError = "Розпізнавання недоступне"
            print("❌ Розпізнавач недоступний")
            return
        }
        
        // Якщо вже йде запис - спочатку зупиняємо
        if audioEngine.isRunning {
            print("⚠️ AudioEngine вже працює, перезапускаємо...")
            stopRecording()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.startRecording()
            }
            return
        }
        
        transcribedText = ""
        recognitionError = nil
        
        do {
            // Створюємо запит
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else {
                recognitionError = "Не вдалося створити запит розпізнавання"
                print("❌ recognitionRequest = nil")
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false
            
            print("🎯 Створюємо recognitionTask...")
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self else { return }
                
                Task { @MainActor in
                    if let result {
                        self.transcribedText = result.bestTranscription.formattedString
                        let preview = self.transcribedText.prefix(50)
                        print("📝 Розпізнано (\(self.transcribedText.count) символів): \(preview)...")
                    }
                    
                    if let error {
                        print("❌ Помилка розпізнавання: \(error.localizedDescription)")
                        self.recognitionError = "Помилка: \(error.localizedDescription)"
                    }
                    
                    if error != nil || result?.isFinal == true {
                        print("⏹️ Завершуємо розпізнавання (помилка або фінальний результат)")
                        self.stopRecording()
                    }
                }
            }
            
            // Підключаємо аудіо вхід
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            print("🎤 Аудіо формат: \(recordingFormat)")
            print("   Sample Rate: \(recordingFormat.sampleRate)")
            print("   Channels: \(recordingFormat.channelCount)")
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak recognitionRequest] buffer, _ in
                recognitionRequest?.append(buffer)
            }
            
            print("🔧 Підготовка audioEngine...")
            audioEngine.prepare()
            
            print("▶️ Запуск audioEngine...")
            try audioEngine.start()
            
            isRecording = true
            print("✅✅✅ ЗАПИС АКТИВНИЙ! Говоріть українською...")
            
        } catch {
            print("❌ КРИТИЧНА ПОМИЛКА: \(error.localizedDescription)")
            recognitionError = "Не вдалося запустити запис: \(error.localizedDescription)"
            stopRecording()
        }
    }
    
    func stopRecording() {
        print("⏹️ Зупинка запису...")
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            print("  🔇 AudioEngine зупинено")
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        isRecording = false
        print("✅ Запис ЗУПИНЕНО")
        
        if !transcribedText.isEmpty {
            print("📄 Фінальний текст: \(transcribedText)")
        }
    }
    
    nonisolated deinit {
        print("🗑️ SpeechManager звільнено")
    }
}
