//
//  MorseMode.swift
//  MorseTranslator
//
//  Created by bobh on 5/1/25.
//


//  MorseDecoderApp.swift
//  MorseTranslator
//
//  Created by bobh on 4/28/25.
//

import SwiftUI
import AVFoundation
import os.log

enum MorseMode: String, CaseIterable {
    case word = "Word Mode"
    case character = "Character Mode"
}

//@main
/*
struct SpeechToMorseApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
*/
let logger = Logger(subsystem: "com.yourapp.speechtomorse", category: "morse")

func log(_ message: String, level: OSLogType = .default) {
    logger.log(level: level, "\(message)")
    print(message)
}

struct ContentView: View {
    @StateObject private var speechRecognizer: SpeechRecognizerViewModel
    @StateObject private var morsePlayer: MorseCodePlayer
    @State private var wpm: Double = 15.0
    @State private var currentMode: MorseMode = .word
    @State private var isTranscribing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init() {
        let buffer = SafeCircularBuffer<String>(capacity: 130)
        self._speechRecognizer = StateObject(wrappedValue: SpeechRecognizerViewModel(safeBuffer: buffer))
        self._morsePlayer = StateObject(wrappedValue: MorseCodePlayer(safeBuffer: buffer))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Morse Translator")
                .font(.largeTitle)
                .padding()
            
            Button(action: {
                isTranscribing.toggle()
                if isTranscribing {
                    setupAudioSystem()
                } else {
                    speechRecognizer.stopTranscribing()
                }
            }) {
                Text(isTranscribing ? "Stop Listening" : "Start Listening")
                    .padding()
                    .background(isTranscribing ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 1)
                    .background(Color(.systemBackground))
                
                ScrollView(.vertical, showsIndicators: true) {
                    Text(speechRecognizer.transcript)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxHeight: 150)
            .padding()
            
            VStack {
                Text("Current Word: \(morsePlayer.currentWord)")
                    .padding(.bottom)
            }
            
            VStack {
                HStack {
                    Circle()
                        .fill(modeColor)
                        .frame(width: 20, height: 20)
                    Text(currentMode.rawValue)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: { toggleMode() }) {
                        Text("Change Mode")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
            }
            
            VStack {
                Text("Speed: \(Int(wpm)) WPM")
                    .padding(.bottom, 5)
                Slider(value: $wpm, in: 5...30, step: 1)
                    .padding(.horizontal)
                    .onChange(of: wpm) { oldValue, newValue in
                        morsePlayer.setWPM(Int(newValue))
                    }
            }
            .padding()
            
            HStack {
                Circle()
                    .fill(speechRecognizer.isRecording ? Color.red : Color.gray)
                    .frame(width: 15, height: 15)
                Text("Listening")
                Spacer()
                Circle()
                    .fill(morsePlayer.isPlaying ? Color.green : Color.gray)
                    .frame(width: 15, height: 15)
                Text("Playing Morse")
            }
            .padding(.horizontal, 40)
            .padding(.top)
            
            if showingError {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .alert(isPresented: $showingError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onDisappear {
            stopAsyncTimer()
        }
    }
    
    private var modeColor: Color {
        switch currentMode {
        case .word: return Color.blue
        case .character: return Color.orange
        }
    }
    
    private func toggleMode() {
        withAnimation {
            currentMode = currentMode == .word ? .character : .word
            morsePlayer.setMode(currentMode)
        }
    }
    
    private func setupAudioSystem() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord,
                                         mode: .default,
                                         options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            morsePlayer.setMode(currentMode)
            
            speechRecognizer.checkPermissions { granted in
                if granted {
                    speechRecognizer.wordPublisher
                        .receive(on: RunLoop.main)
                        .sink { word in
                            if !word.isEmpty {
                                Task {
                                     await morsePlayer.addWordToQueue(word)
                                 }
                            }
                        }
                        .store(in: &speechRecognizer.cancellables)
                    
                    morsePlayer.setWPM(Int(self.wpm))
                    speechRecognizer.startTranscribing()
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Microphone or speech recognition permission denied"
                        self.showingError = true
                        self.isTranscribing = false
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to set up audio: \(error.localizedDescription)"
                self.showingError = true
                self.isTranscribing = false
                stopAsyncTimer()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

/*
Recommendations for future improvements:
1. Add UI to display buffer count (e.g., "Buffer: \(await safeBuffer.count)/130").
2. Consider adding Morse encoding (text-to-Morse) functionality.
*/
