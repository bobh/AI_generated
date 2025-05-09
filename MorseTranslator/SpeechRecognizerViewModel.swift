//
//  SpeechRecognizerViewModel.swift
//  MorseTranslator
//
//  Created by bobh on 5/1/25.
//


//  SpeechRecognizerViewModel.swift
//  MorseTranslator
//
//  Created by bobh on 4/17/25.
//

import Foundation
import Speech
import Combine
import os.log

@MainActor
class SpeechRecognizerViewModel: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let logger = Logger(subsystem: "com.yourapp.MorseTranslator", category: "speech")
    private let safeBuffer: SafeCircularBuffer<String>
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    private var processedWords: [String] = []
    let wordPublisher = PassthroughSubject<String, Never>()
    var cancellables = Set<AnyCancellable>()
    
    private let digitWords: [String: Character] = [
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
        "niner": "9"
    ]
    
    private let validLetters: Set<String> = Set("abcdefghijklmnopqrstuvwxyz".map { String($0) })
    
    init(safeBuffer: SafeCircularBuffer<String>) {
        self.safeBuffer = safeBuffer
        super.init()
        speechRecognizer.delegate = self
    }
    
    func checkPermissions(completion: @escaping (Bool) -> Void) {
        let speechAuthStatus = SFSpeechRecognizer.authorizationStatus()
        
        switch speechAuthStatus {
        case .authorized:
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        AVAudioApplication.requestRecordPermission { granted in
                            DispatchQueue.main.async {
                                completion(granted)
                            }
                        }
                    } else {
                        completion(false)
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
    
    func startTranscribing() {
        do {
            if isRecording {
                return
            }
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else {
                fatalError("Unable to create a speech recognition request")
            }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.taskHint = .dictation
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            
            let inputNode2 = audioEngine.inputNode
            let inputFormat = inputNode2.inputFormat(forBus: 0)
            let eqNode = AVAudioUnitEQ(numberOfBands: 1)
            let eqBand = eqNode.bands[0]
            
            eqBand.filterType = .parametric
            eqBand.frequency = 800.0
            eqBand.bandwidth = 0.1
            eqBand.gain = -96.0
            eqBand.bypass = false
            
            audioEngine.attach(eqNode)
            audioEngine.connect(inputNode, to: eqNode, format: inputFormat)
            audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: inputFormat)
            
            do {
                audioEngine.prepare()
                try audioEngine.start()
                isRecording = true
                print("Audio engine started with 800 Hz notch filter enabled.")
            } catch {
                print("Failed to start audio engine: \(error.localizedDescription)")
            }
            
            logger.debug("Started speech transcription")
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    let rawText = result.bestTranscription.formattedString
                    self.logger.debug("Raw transcript: '\(rawText)'")
                    let words = rawText.split(separator: " ").map { String($0) }
                    var newWords: [String] = []
                    
                    for word in words {
                        let lowerWord = word.lowercased()
                        if self.digitWords[lowerWord] != nil || self.validLetters.contains(lowerWord) {
                            newWords.append(lowerWord)
                            self.logger.debug("Publishing valid word: '\(lowerWord)'")
                            self.wordPublisher.send(lowerWord)
                        } else if lowerWord.allSatisfy({ $0.isLetter }) {
                            newWords.append(lowerWord)
                            self.logger.debug("Publishing valid word: '\(lowerWord)'")
                            self.wordPublisher.send(lowerWord)
                        } else {
                            self.logger.debug("Unrecognized word '\(word)', publishing '#'")
                            self.wordPublisher.send("#")
                        }
                    }
                    
                    if !newWords.isEmpty {
                        self.processedWords.append(contentsOf: newWords)
                        if self.processedWords.count > 20 {
                            self.processedWords.removeFirst(self.processedWords.count - 20)
                        }
                    }
                    
                    let text = self.processedWords.joined(separator: " ")
                    self.transcript = text
                    self.logger.debug("Transcript updated, length: \(text.count)")
                }
                
                if let error = error, self.isRecording {
                    self.stopTranscribing()
                    self.logger.error("Speech recognition error: \(error.localizedDescription)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if self.isRecording {
                            self.startTranscribing()
                        }
                    }
                }
            }
        }
    }
    
    func stopTranscribing() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        
        self.processedWords = []
        self.transcript = ""
        self.logger.debug("Stopped speech transcription")
    }
}

/*
Recommendations for future improvements:
1. Use pushBatch to push multiple words to SafeCircularBuffer.
2. Add UI to display buffer count (e.g., "Buffer: \(await safeBuffer.count)/130").
*/
