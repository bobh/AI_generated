//
//  MorseTranslatorTests.swift
//  MorseTranslator
//
//  Created by bobh on 5/1/25.
//


//  MorseTranslatorTests.swift
//  MorseTranslatorTests
//
//  Created by bobh on 5/1/25.
//

import XCTest
@testable import MorseTranslator

class MorseTranslatorTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testCircularBufferPushPop() throws {
        var buffer = CircularBuffer<String>(capacity: 3)
        
        // Test push and count
        XCTAssertEqual(buffer.elementCount, 0)
        XCTAssertNil(buffer.push("A"))
        XCTAssertEqual(buffer.elementCount, 1)
        XCTAssertNil(buffer.push("B"))
        XCTAssertEqual(buffer.elementCount, 2)
        XCTAssertNil(buffer.push("C"))
        XCTAssertEqual(buffer.elementCount, 3)
        
        // Test overwrite when full
        XCTAssertEqual(buffer.push("D"), "A")
        XCTAssertEqual(buffer.elementCount, 3)
        
        // Test pop
        XCTAssertEqual(buffer.pop(), "B")
        XCTAssertEqual(buffer.elementCount, 2)
        XCTAssertEqual(buffer.pop(), "C")
        XCTAssertEqual(buffer.elementCount, 1)
        XCTAssertEqual(buffer.pop(), "D")
        XCTAssertEqual(buffer.elementCount, 0)
        XCTAssertNil(buffer.pop())
    }
    
    func testSafeCircularBufferPushPop() async throws {
        let buffer = SafeCircularBuffer<String>(capacity: 3)
        
        // Test push and count
        XCTAssertEqual(await buffer.count, 0)
        await XCTAssertNil(buffer.push("A"))
        XCTAssertEqual(await buffer.count, 1)
        await XCTAssertNil(buffer.push("B"))
        XCTAssertEqual(await buffer.count, 2)
        await XCTAssertNil(buffer.push("C"))
        XCTAssertEqual(await buffer.count, 3)
        
        // Test overwrite when full
        await XCTAssertEqual(buffer.push("D"), "A")
        XCTAssertEqual(await buffer.count, 3)
        
        // Test pop
        await XCTAssertEqual(buffer.pop(), "B")
        XCTAssertEqual(await buffer.count, 2)
        await XCTAssertEqual(buffer.pop(), "C")
        XCTAssertEqual(await buffer.count, 1)
        await XCTAssertEqual(buffer.pop(), "D")
        XCTAssertEqual(await buffer.count, 0)
        await XCTAssertNil(buffer.pop())
    }
    
    func testMorseCodePlayerEncoding() throws {
        let buffer = SafeCircularBuffer<String>(capacity: 10)
        let player = MorseCodePlayer(safeBuffer: buffer)
        
        // Test character mode
        player.setMode(.character)
        player.addWordToQueue("A")
        player.addWordToQueue("1")
        player.addWordToQueue("invalid")
        
        Task {
            await player.processMorseOutput()
            XCTAssertEqual(player.outWord, "A")
            await player.processMorseOutput()
            XCTAssertEqual(player.outWord, "1")
            await player.processMorseOutput()
            XCTAssertEqual(player.outWord, "#")
        }
        
        // Test word mode
        player.setMode(.word)
        player.addWordToQueue("SOS")
        
        Task {
            await player.processMorseOutput()
            XCTAssertEqual(player.outWord, "SOS")
        }
    }
    
    func testSpeechRecognizerWordFiltering() throws {
        let buffer = SafeCircularBuffer<String>(capacity: 10)
        let recognizer = SpeechRecognizerViewModel(safeBuffer: buffer)
        
        // Simulate word publishing
        let expectation = XCTestExpectation(description: "Word publisher sends valid words")
        var receivedWords: [String] = []
        
        recognizer.wordPublisher
            .sink { word in
                receivedWords.append(word)
                if receivedWords.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &recognizer.cancellables)
        
        // Publish test words
        recognizer.wordPublisher.send("hello")
        recognizer.wordPublisher.send("one")
        recognizer.wordPublisher.send("invalid")
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedWords, ["hello", "one", "#"])
    }
}
