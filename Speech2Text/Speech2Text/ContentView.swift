//
//  ContentView.swift
//  Speech2Text
//
//  Created by bobh on 2/20/25.
//

//
//  ContentView.swift
//  TextToSpeech
//
//  Created by bobh on 2/20/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    
    var body: some View {
        VStack {
            Text(speechRecognizer.transcribedText)
                .padding()
                .font(.title)
            
            Button(speechRecognizer.isRecording ? "Stop Listening" : "Start Listening") {
                if speechRecognizer.isRecording {
                    speechRecognizer.stopRecording()
                } else {
                    speechRecognizer.startRecording()
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .padding()
    }
}


#Preview {
    ContentView()
}
