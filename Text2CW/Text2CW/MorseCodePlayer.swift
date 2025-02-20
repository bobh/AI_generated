
import AVFoundation

class MorseCodePlayer {
    private let sampleRate: Double = 44100.0
    private let frequency: Double = 1000.0 // 1 kHz
    private let shortBeep = 0.1
    private let longBeep = 0.3
    private let pauseBetweenSymbols = 0.2
    private let pauseBetweenLetters = 0.4
    private let pauseBetweenWords = 0.7

    private let morseCodeDict: [Character: String] = [
        "A": ".-",   "B": "-...", "C": "-.-.", "D": "-..",
        "E": ".",    "F": "..-.", "G": "--.",  "H": "....",
        "I": "..",   "J": ".---", "K": "-.-",  "L": ".-..",
        "M": "--",   "N": "-.",   "O": "---",  "P": ".--.",
        "Q": "--.-", "R": ".-.",  "S": "...",  "T": "-",
        "U": "..-",  "V": "...-", "W": ".--",  "X": "-..-",
        "Y": "-.--", "Z": "--..", "1": ".----", "2": "..---",
        "3": "...--", "4": "....-", "5": ".....", "6": "-....",
        "7": "--...", "8": "---..", "9": "----.", "0": "-----",
        " ": " "
    ]

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func playMorseCode(from text: String, completion: @escaping () -> Void) {
        let morseSequence = text.compactMap { morseCodeDict[$0] }.joined(separator: " ")
        DispatchQueue.global(qos: .userInitiated).async {
            for symbol in morseSequence {
                switch symbol {
                case ".":
                    self.playTone(duration: self.shortBeep)
                case "-":
                    self.playTone(duration: self.longBeep)
                case " ":
                    Thread.sleep(forTimeInterval: self.pauseBetweenWords)
                default:
                    Thread.sleep(forTimeInterval: self.pauseBetweenLetters)
                }
                Thread.sleep(forTimeInterval: self.pauseBetweenSymbols)
            }
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    private func playTone(duration: TimeInterval) {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: player.outputFormat(forBus: 0), frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let wave = buffer.floatChannelData![0]
        let phaseStep = Float(2.0 * .pi * frequency / sampleRate)

        for i in 0..<Int(frameCount) {
            wave[i] = sin(phaseStep * Float(i))
        }

        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
        Thread.sleep(forTimeInterval: duration)
    }
}

