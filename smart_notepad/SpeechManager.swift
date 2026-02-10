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
        
        // Переконаємося, що все чисте перед початком
        resetAudioEngine()
        
        transcribedText = ""
        recognitionError = nil
        
        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else {
                recognitionError = "Не вдалося створити запит"
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // Спробуємо увімкнути on-device розпізнавання, якщо воно доступне
            if recognizer.supportsOnDeviceRecognition {
                recognitionRequest.requiresOnDeviceRecognition = true
            }
            
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let result = result {
                        self.transcribedText = result.bestTranscription.formattedString
                    }
                    
                    if let error = error {
                        let nsError = error as NSError
                        // Error 216 (kAFAssistantErrorDomain) часто виникає при спробі зупинити активну сесію
                        // Якщо ми вже маємо фінальний текст, ігноруємо цю помилку для користувача
                        if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                            print("⚠️ Отримано kAFAssistantErrorDomain 216 (це часто буває при завершенні)")
                        } else {
                            print("❌ Помилка розпізнавання: \(error.localizedDescription)")
                            self.recognitionError = "Помилка: \(error.localizedDescription)"
                        }
                        self.forceStopAndCleanup()
                    }
                    
                    if result?.isFinal == true {
                        print("⏹️ Сесія завершена успішно")
                        self.forceStopAndCleanup()
                    }
                }
            }
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            print("✅ Запис активовано")
            
        } catch {
            print("❌ Помилка запуску: \(error.localizedDescription)")
            recognitionError = "Не вдалося запустити запис: \(error.localizedDescription)"
            forceStopAndCleanup()
        }
    }
    
    func stopRecording() {
        print("⏹️ Користувач зупинив запис")
        // Просто припиняємо подачу аудіо, дозволяючи розпізнавачу надіслати фінальний результат
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        isRecording = false
    }
    
    private func resetAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
    
    private func forceStopAndCleanup() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
    
    nonisolated deinit {
        print("🗑️ SpeechManager звільнено")
    }
}
