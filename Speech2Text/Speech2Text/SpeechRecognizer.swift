//
//  SpeechRecognizer.swift
//  Speech2Text
//
//  Created by bobh on 2/20/25.
//
//
//  SpeechRecognizer.swift
//  TextToSpeech
//
//  Created by bobh on 2/20/25.
//

import Foundation
import Speech
import AVFoundation

class SpeechRecognizer: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var transcribedText = "Tap the button to start speaking..."
    @Published var isRecording = false

    init() {
        requestPermissions()
    }
    
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus != .authorized {
                    self.transcribedText = "Speech recognition permission not granted."
                }
            }
        }
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.transcribedText = "Microphone access denied."
                }
            }
        }
    }
    
    func startRecording() {
        if audioEngine.isRunning {
            stopRecording()
        }

        do {
            transcribedText = "Listening..."
            isRecording = true

            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            let inputNode = audioEngine.inputNode
            guard let recognitionRequest = recognitionRequest else { return }

            recognitionRequest.shouldReportPartialResults = true

            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    DispatchQueue.main.async {
                        self.transcribedText = result.bestTranscription.formattedString
                    }
                }

                if error != nil || (result?.isFinal ?? false) {
                    self.stopRecording()
                }
            }

            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            transcribedText = "Error starting audio engine."
            stopRecording()
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        DispatchQueue.main.async {
            self.isRecording = false
            self.transcribedText += "\n(Stopped)"
        }
    }
}

