//
//  MorseCodePlayer.swift
//  MorseTranslator
//
//  Created by bobh on 5/1/25.
//


//  MorseCodePlayer.swift
//  MorseTranslator
//
//  Created by bobh on 4/17/25.
//

import Foundation
import AVFoundation
import os.log

var timerTask: Task<Void, Never>?

@MainActor
class MorseCodePlayer: ObservableObject {
    private let sineFrequency: Float = 800.0
    private let logger = Logger(subsystem: "com.speechtomorse", category: "morse")
    private let audioEngine = AVAudioEngine()
    private let audioPlayerNode = AVAudioPlayerNode()
    private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private let safeBuffer: SafeCircularBuffer<String>
    
    private var isProcessingQueue = false
    @Published var isPlaying = false
    @Published var currentWord = ""
    
    private var mode: MorseMode = .word
    var outWord: String = ""
    var safeBufferEmpty: Bool = true
    
    private var dotDuration: Double = 0.1
    private var dashDuration: Double { return dotDuration * 3 }
    private var elementSpacing: Double { return dotDuration }
    private var letterSpacing: Double { return dotDuration * 3 }
    private var wordSpacing: Double { return dotDuration * 7 }
    
    private let morseCodeDict: [Character: String] = [
        "a": ".-", "b": "-...", "c": "-.-.", "d": "-..", "e": ".",
        "f": "..-.", "g": "--.", "h": "....", "i": "..", "j": ".---",
        "k": "-.-", "l": ".-..", "m": "--", "n": "-.", "o": "---",
        "p": ".--.", "q": "--.-", "r": ".-.", "s": "...", "t": "-",
        "u": "..-", "v": "...-", "w": ".--", "x": "-..-", "y": "-.--",
        "z": "--..", "1": ".----", "2": "..---", "3": "...--", "4": "....-",
        "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----.",
        "0": "-----", ".": ".-.-.-", ",": "--..--", "?": "..--..",
        "'": ".----.", "!": "-.-.--", "/": "-..-.", "(": "-.--.",
        ")": "-.--.-", "&": ".-...", ":": "---...", ";": "-.-.-.",
        "=": "-...-", "+": ".-.-.", "-": "-....-", "_": "..--.-",
        "\"": ".-..-.", "$": "...-..-", "@": ".--.-.", "#": "....-.-."
    ]
    
    private let digitWords: [String: Character] = [
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9"
    ]
    
    private let specialCharacterMap: [String: Character] = [
        "period": ".", "comma": ",", "question mark": "?", "exclamation mark": "!",
        "slash": "/", "at sign": "@", "colon": ":", "semicolon": ";",
        "equals": "=", "plus": "+", "minus": "-", "underscore": "_",
        "quote": "\"", "dollar": "$"
    ]
    
    private let validLetters: Set<String> = Set("abcdefghijklmnopqrstuvwxyz".map { String($0) })

    init(safeBuffer: SafeCircularBuffer<String>)// a buffer of Strings
    {
        self.safeBuffer = safeBuffer
        setupAudioEngine()
        Task {
            //async Timer to work off safeBuffer queue
            //on a periododic basis. you know--asynchronously
            startAsyncTimer(interval: dotDuration) {
                await self.processMorseOutput()
            }
        }
    }
    
    
    deinit {
        stopAsyncTimer()
    }
    
    private func setupAudioEngine() {
        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: audioFormat)
        do {
            try audioEngine.start()
            logger.debug("Audio engine started successfully")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    func setMode(_ newMode: MorseMode) {
        mode = newMode
    }
    
    //func setWPM(_ wpm: Int) {
    //    dotDuration = 60.0 / (50.0 * Double(wpm))
    //}
    
    //Initiate timer restart when WPM changes:
    func setWPM(_ wpm: Int) {
        let newDotDuration = 60.0 / (50.0 * Double(wpm))
        if newDotDuration != dotDuration {
            dotDuration = newDotDuration
            stopAsyncTimer()
            Task {
                startAsyncTimer(interval: dotDuration) {
                    await self.processMorseOutput()
                }
            }
        }
    }
    
    // two ways to output (sound) words from the safeBuffer Queue
    //1> SpeechRecognizer hears a word, addWordToQueue()
    //2> on a periodic timer, processMorseOutput()
    
    //runs on a periodic async timer to output any words
    //in the safeBuffer Queue
    //Its job is to take a word from the safeBuffer and initiate
    //the Morse code playback
    //************************************************************
    //************************************************************
    private func processMorseOutput() async {
        guard !isProcessingQueue,
                let word = await safeBuffer.pop() else
        {
            //logger.debug("Queue empty or processing, skipping")
            return
        }
        
        await processQueue(word: word)
    }
    //************************************************************
    //************************************************************
    
    //called asynchronously as the user speaks
    //first word is actually added in setupAudioSystem()
    //not in the SpeechRecognizer processing as one might think 🤔
    func addWordToQueue(_ word: String) async {
        //here we add the new word to safeBuffer
        if let overwritten = await safeBuffer.push(word) {
            logger.warning("Overwrote word: \(overwritten)")
        }
        safeBufferEmpty = await safeBuffer.isEmpty
        logger.debug("Inputting word: '\(word)'")
    }
    //Make `processQueue()` directly check if `outWord` is empty instead
    //of relying on `safeBufferEmpty`:
    //*******************************************************
    //*******************************************************
    private func processQueue(word: String) async {
        //don't do any processing if the Queue is empty
        //or not finished from last processing
        guard !isProcessingQueue, !word.isEmpty else {
            //logger.debug("Queue empty or processing, skipping")
            return
        }
        
        logger.debug("Processing word: '\(word)'")
        isProcessingQueue = true
        
        switch mode {
        case .word: //word mode
            playMorseForWord(word) {
                self.isProcessingQueue = false
                //potentially call processMorseOutput again here if needed
            }
        case .character: //character mode
            playMorseForCharacter(word) {
                self.isProcessingQueue = false
                //potentially call processMorseOutput again here if needed
            }
        }
    }
    //*******************************************************
    //*******************************************************
    
    private func playMorseForCharacter(_ word: String, completion: @escaping () -> Void) {
        currentWord = word
        
        let processedChar: Character
        let lowerWord = word.lowercased()
        
        if let specialChar = specialCharacterMap[lowerWord] {
            processedChar = specialChar
            logger.debug("Recognized special character '\(lowerWord)' as '\(specialChar)'")
        } else if lowerWord.count == 1, let firstChar = lowerWord.first, morseCodeDict.keys.contains(firstChar) {
            processedChar = firstChar
            logger.debug("Using single character: '\(processedChar)'")
        } else if let digitChar = digitWords[lowerWord] {
            processedChar = digitChar
            logger.debug("Recognized digit word '\(lowerWord)' as '\(digitChar)'")
        } else {
            processedChar = "#"
            logger.debug("Unrecognized word '\(lowerWord)' in character mode, using '#'")
        }
        
        var playCommands: [(duration: Double, isOn: Bool)] = []
        let lowerChar = processedChar
        
        if let morseChar = morseCodeDict[lowerChar] {
            logger.debug("Playing Morse code for '\(processedChar)': \(morseChar)")
            for (elementIndex, element) in morseChar.enumerated() {
                if element == "." {
                    playCommands.append((dotDuration, true))
                } else if element == "-" {
                    playCommands.append((dashDuration, true))
                }
                if elementIndex < morseChar.count - 1 {
                    playCommands.append((elementSpacing, false))
                }
            }
        } else {
            logger.debug("No Morse code found for character: '\(processedChar)'")
        }
        
        playCommands.append((wordSpacing, false))
        
        logger.debug("Total play commands: \(playCommands.count)")
        
        if playCommands.count > 1 {
            playSequence(playCommands) {
                self.isProcessingQueue = false
                completion()
            }
        } else {
            logger.debug("No valid Morse code to play for: \(word)")
            self.isProcessingQueue = false
            completion()
        }
    }
    
    func playMorseForWord(_ word: String, completion: @escaping () -> Void) {
        currentWord = word
        
        let lowerWord = word.lowercased()
        var playCommands: [(duration: Double, isOn: Bool)] = []
        
        let charsToEncode: [Character]
        if let digitChar = digitWords[lowerWord] {
            charsToEncode = [digitChar]
            logger.debug("Encoding digit word '\(lowerWord)' as '\(digitChar)'")
        } else if validLetters.contains(lowerWord) {
            charsToEncode = [Character(lowerWord)]
            logger.debug("Encoding single letter '\(lowerWord)'")
        } else {
            charsToEncode = lowerWord.map { morseCodeDict.keys.contains($0) ? $0 : "#" }
            logger.debug("Encoding word '\(lowerWord)' as characters: \(charsToEncode)")
        }
        
        for (index, char) in charsToEncode.enumerated() {
            if let morseChar = morseCodeDict[char] {
                for (elementIndex, element) in morseChar.enumerated() {
                    if element == "." {
                        playCommands.append((dotDuration, true))
                    } else if element == "-" {
                        playCommands.append((dashDuration, true))
                    }
                    if elementIndex < morseChar.count - 1 {
                        playCommands.append((elementSpacing, false))
                    }
                }
                if index < charsToEncode.count - 1 {
                    playCommands.append((letterSpacing, false))
                }
            }
        }
        
        playCommands.append((wordSpacing, false))
        
        playSequence(playCommands) {
            self.isProcessingQueue = false
            completion()
        }
    }
 
//playSequence
//commands: [(duration: Double, isOn: Bool)], completion: @escaping () -> Void)
/*
 Parameters:
 * commands: An array of tuples, each containing a duration (in seconds) and a Bool (isOn) indicating
       whether to play a tone.
 * completion: A closure that executes when all commands in the sequence have been processed.
 Base Case – Exit If No Commands Left:
 guard !commands.isEmpty else {
     completion()
     return
 }
 
 Process the Command:
 if command.isOn {
     playTone(duration: command.duration) {
         self.isPlaying = false
         self.playSequence(remainingCommands, completion: completion)
     }
 }
 If command.isOn is true, the function calls playTone(duration:) to generate a tone for the specified duration.
 Once playTone finishes, the function recursively calls playSequence with the remaining commands.

 Handle Silent Pause (isOn == false):
 DispatchQueue.main.asyncAfter(deadline: .now() + command.duration) {
     self.playSequence(remainingCommands, completion: completion)
 }
 If isOn is false, the function schedules a delay (asyncAfter) using DispatchQueue.main.
 This delay mimics the duration of the silent gap before recursively proceeding to the next command.

 */
    private func playSequence(_ commands: [(duration: Double, isOn: Bool)], completion: @escaping () -> Void) {
        guard !commands.isEmpty else {
            completion()
            return
        }
        
        var remainingCommands = commands
        let command = remainingCommands.removeFirst()
        
        if command.isOn {
            playTone(duration: command.duration) {
                DispatchQueue.main.async{
                    self.isPlaying = false
                }
                self.playSequence(remainingCommands, completion: completion)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + command.duration) {
                self.playSequence(remainingCommands, completion: completion)
            }
        }
    }
    
    private func playTone(duration: Double, completion: @escaping () -> Void) {
        let sampleRate: Float = 44100.0
        let totalSamples = UInt32(duration * Double(sampleRate))
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: totalSamples) else {
            logger.error("Could not create buffer")
            completion()
            return
        }
        
        buffer.frameLength = totalSamples
        
        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
        
        for frame in 0..<Int(totalSamples) {
            let value = sinf(2.0 * .pi * self.sineFrequency * Float(frame) / sampleRate)
            for channel in 0..<Int(buffer.format.channelCount) {
                channels[channel][frame] = Float(value) * 0.8
            }
        }
        
        isPlaying = true
        
        //logger.debug("Playing tone with duration: \(duration)")
        
        audioPlayerNode.scheduleBuffer(buffer) {
            DispatchQueue.main.async{
                self.isPlaying = false
            }
            completion()
        }
        
        if !audioPlayerNode.isPlaying {
            audioPlayerNode.play()
        }
    }
}

func startAsyncTimer(interval: TimeInterval, task: @escaping () async -> Void) {
    timerTask = Task {
        while !Task.isCancelled {
            let startTime = Date()
            await task()
            let elapsedTime = Date().timeIntervalSince(startTime)
            let remainingTime = max(0, interval - elapsedTime)
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }
    }
}

func stopAsyncTimer() {
    timerTask?.cancel()
    timerTask = nil
    logger.info("Timer stopped")
}

/*
Recommendations for future improvements:
1. Add UI to display buffer count (e.g., "Buffer: \(await safeBuffer.count)/130").
*/
