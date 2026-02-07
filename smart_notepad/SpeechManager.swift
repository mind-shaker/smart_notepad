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
        print("SpeechManager ініціалізовано з локаллю uk-UA")
    }
    
    func toggleRecording() {
        print("toggleRecording викликано, зараз isRecording = \(isRecording)")
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        print("startRecording викликано")
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Розпізнавання недоступне")
            recognitionError = "Розпізнавання мови недоступне на цьому пристрої"
            return
        }
        
        print("Запит дозволу на розпізнавання мови")
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self else { return }
            
            DispatchQueue.main.async {
                print("Дозвіл отримано: \(authStatus.rawValue)")
                switch authStatus {
                case .authorized:
                    print("Дозвіл авторизовано → запускаємо запис")
                    self.performStartRecording()
                case .denied, .restricted, .notDetermined:
                    print("Дозвіл відхилено або не визначено")
                    self.recognitionError = "Немає дозволу на розпізнавання мови"
                @unknown default:
                    print("Невідомий статус дозволу")
                    self.recognitionError = "Невідомий статус дозволу"
                }
            }
        }
    }
    
    private func performStartRecording() {
        print("performStartRecording викликано")
        
        transcribedText = ""
        recognitionError = nil
        isRecording = true
        
        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else {
                print("Не вдалося створити recognitionRequest")
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false
            
            print("Створюємо recognitionTask")
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self else { return }
                
                if let result {
                    self.transcribedText = result.bestTranscription.formattedString
                    print("Оновлено текст: \(self.transcribedText.prefix(50))...")
                }
                
                if let error {
                    print("Помилка в recognitionTask: \(error.localizedDescription)")
                }
                
                if error != nil || result?.isFinal == true {
                    print("Завершуємо запис (error або isFinal)")
                    self.stopRecording()
                }
            }
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            print("Встановлюємо tap на inputNode")
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            print("Підготовка audioEngine")
            audioEngine.prepare()
            
            print("Запуск audioEngine")
            try audioEngine.start()
            print("audioEngine успішно запущено")
            
        } catch {
            print("Критична помилка в performStartRecording: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.recognitionError = "Помилка запуску запису: \(error.localizedDescription)"
                self.stopRecording()
            }
        }
    }
    
    func stopRecording() {
        print("stopRecording викликано")
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        isRecording = false
        print("Запис зупинено")
    }
    
    deinit {
        print("SpeechManager deinit")
        DispatchQueue.main.async { [weak self] in
            self?.stopRecording()
        }
    }
}
