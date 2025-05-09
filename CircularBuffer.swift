//
//  CircularBuffer.swift
//  MorseTranslator
//
//  Created by bobh on 5/1/25.
//
//


//  CircularBuffer.swift
//  MorseTranslator
//
//  Created by bobh on 4/28/25.
//

import Foundation

/*
Buffer sized for 130 words.
Based on conversational human speech and 10 wpm Morse Code before a wrap.
*/
/*
 AI code review hates .isEmpty
 Removed the safeBufferEmpty check since calling pop() directly handles empty cases.
 Eliminated the extra condition checking safeBuffer.isEmpty, since pop() returning nil naturally signals an empty buffer.
 I'm not sure it's the same thing
 */

// MARK: - Original Circular Buffer
struct CircularBuffer<T>: Sequence {
    private var buffer: [T?]
    private var readIndex = 0
    private var writeIndex = 0
    fileprivate var elementCount = 0
    private let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }
    
    var isEmpty: Bool {
        return elementCount == 0
    }
    
    var isFull: Bool {
        return elementCount == capacity
    }
    
    mutating func write(_ element: T) -> T? {
        //word overwritten with the write
        //returned to the caller
        //Necessary?
        let overwritten = buffer[writeIndex]
        buffer[writeIndex] = element
        
        if isFull {
            readIndex = (readIndex + 1) % capacity
        } else {
            elementCount += 1
        }
        
        writeIndex = (writeIndex + 1) % capacity
        return overwritten
    }
    
    mutating func read() -> T? {
        guard !isEmpty else { return nil }
        
        let element = buffer[readIndex]
        buffer[readIndex] = nil
        readIndex = (readIndex + 1) % capacity
        elementCount -= 1
        return element
    }
    
    func peek() -> T? {
        guard !isEmpty else { return nil }
        return buffer[readIndex]
    }
    
    mutating func clear() {
        buffer = Array(repeating: nil, count: capacity)
        readIndex = 0
        writeIndex = 0
        elementCount = 0
    }
    
    subscript(index: Int) -> T? {
        guard index >= 0 && index < elementCount else { return nil }
        let adjustedIndex = (readIndex + index) % capacity
        return buffer[adjustedIndex]
    }
    
    func toArray() -> [T] {
        var array: [T] = []
        for index in 0..<elementCount {
            if let element = self[index] {
                array.append(element)
            }
        }
        return array
    }
    
    func makeIterator() -> AnyIterator<T> {
        var currentIndex = 0
        return AnyIterator {
            guard currentIndex < self.elementCount else { return nil }
            let element = self[currentIndex]
            currentIndex += 1
            return element
        }
    }
    
    mutating func push(_ element: T) -> T? {
        return write(element)
    }
    
    mutating func pop() -> T? {
        return read()
    }
}

// MARK: - Safe Circular Buffer
actor SafeCircularBuffer<T> {
    private var buffer: CircularBuffer<T>
    
    init(capacity: Int) {
        self.buffer = CircularBuffer<T>(capacity: capacity)
    }
    
    var isEmpty: Bool {
        return buffer.isEmpty
    }
    
    var isFull: Bool {
        return buffer.isFull
    }
    
    var count: Int {
        return buffer.elementCount
    }
    
    func push(_ element: T) -> T? {
        return buffer.push(element)
    }
    
    func pop() -> T? {
        return buffer.pop()
    }
    
    func peek() -> T? {
        return buffer.peek()
    }
    
    func clear() {
        buffer.clear()
    }
    
    func toArray() -> [T] {
        return buffer.toArray()
    }
    
    func pushBatch(_ elements: [T]) {
        for element in elements {
            _ = buffer.push(element)
        }
    }
}

/*
Recommendations for future improvements:
1. Use pushBatch for batch operations in SpeechRecognizerViewModel.
2. Add UI to display buffer count (e.g., "Buffer: \(await safeBuffer.count)/130").
3. Consider adding Morse encoding (text-to-Morse) functionality.
*/
