//
//  MorseTextConverter.swift
//  MorseTranslator
//
//  Created by bobh on 5/10/25.
//

import Foundation

struct MorseTextConverter {
    public static let digitWords: [String: Character] = [
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
        "niner": "9"
    ]
    
    public static let specialCharacterMap: [String: Character] = [
        "comma": ",", "period": ".", "dot": ".", "exclamation": "!",
        "question": "?", "colon": ":", "semicolon": ";", "dash": "-",
        "hyphen": "-", "quote": "\"", "apostrophe": "'", "slash": "/",
        "backslash": "\\", "paren": ")", "bracket": "]"
        // Add more if needed
    ]
    
    static func convertToCharacters(_ input: String) -> String {
        let words = input.lowercased().split(separator: " ")
        var result = ""

        for word in words {
            if let digit = digitWords[String(word)] {
                result.append(digit)
            } else if let special = specialCharacterMap[String(word)] {
                result.append(special)
            } else if word.count == 1, let char = word.first, char.isLetter {
                result.append(char)
            } else {
                result.append("#") // fallback for unknowns
            }
        }

        return result
    }
}
