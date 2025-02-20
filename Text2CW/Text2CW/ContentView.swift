import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var textInput: String = ""
    @State private var isPlaying = false
    let morseCodeGenerator = MorseCodePlayer()

    var body: some View {
        VStack {
            Text("Morse Code Translator")
                .font(.largeTitle)
                .padding()

            TextField("Enter text", text: $textInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: {
                if !isPlaying {
                    isPlaying = true
                    morseCodeGenerator.playMorseCode(from: textInput.uppercased()) {
                        isPlaying = false
                    }
                }
            }) {
                Text(isPlaying ? "Playing..." : "Play Morse Code")
                    .padding()
                    .background(isPlaying ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isPlaying)
            .padding()

            Spacer()
        }
        .padding()
    }
}
