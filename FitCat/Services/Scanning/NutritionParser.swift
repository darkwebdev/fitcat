//
//  NutritionParser.swift
//  FitCat
//
//  Parses OCR text to extract nutrition information
//

import Foundation

class NutritionParser {
    /// Parses nutrition information from OCR text
    /// - Parameter texts: Array of recognized text strings
    /// - Returns: NutritionInfo with extracted values
    func parseNutrition(from texts: [String]) -> NutritionInfo {
        let combinedText = texts.joined(separator: "\n").lowercased()

        return NutritionInfo(
            protein: extractValue(from: combinedText, for: .protein),
            fat: extractValue(from: combinedText, for: .fat),
            fiber: extractValue(from: combinedText, for: .fiber),
            moisture: extractValue(from: combinedText, for: .moisture),
            ash: extractValue(from: combinedText, for: .ash)
        )
    }

    private func extractValue(from text: String, for nutrient: Nutrient) -> Double? {
        for pattern in nutrient.patterns {
            if let value = findValue(in: text, pattern: pattern) {
                return value
            }
        }
        return nil
    }

    private func findValue(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else {
            return nil
        }

        // Extract the numeric value (first capture group)
        if match.numberOfRanges > 1,
           let valueRange = Range(match.range(at: 1), in: text) {
            var valueString = String(text[valueRange])

            // Handle German/European number format: replace comma with period
            valueString = valueString.replacingOccurrences(of: ",", with: ".")

            return Double(valueString)
        }

        return nil
    }

    enum Nutrient {
        case protein
        case fat
        case fiber
        case moisture
        case ash

        var patterns: [String] {
            switch self {
            case .protein:
                return [
                    // German patterns (check first as they're more specific)
                    #"rohprotein\s*(\d+[,\.]?\d*)\s*%"#,
                    #"(?:roh)?protein\s*(\d+[,\.]?\d*)\s*%"#,
                    #"eiweiß\s*(\d+[,\.]?\d*)\s*%"#,
                    #"eiweiss\s*(\d+[,\.]?\d*)\s*%"#,
                    // English patterns
                    #"(?:crude\s+)?protein\s*(\d+[,\.]?\d*)\s*%"#,
                    #"protein.*?min.*?(\d+[,\.]?\d*)\s*%"#,
                    #"prot\s*(\d+[,\.]?\d*)\s*%"#
                ]
            case .fat:
                return [
                    // German patterns
                    #"fettgehalt\s*(\d+[,\.]?\d*)\s*%"#,
                    #"rohfett\s*(\d+[,\.]?\d*)\s*%"#,
                    #"fett\s*(\d+[,\.]?\d*)\s*%"#,
                    // English patterns
                    #"(?:crude\s+)?fat\s*(\d+[,\.]?\d*)\s*%"#,
                    #"fat.*?min.*?(\d+[,\.]?\d*)\s*%"#
                ]
            case .fiber:
                return [
                    // German patterns
                    #"rohfaser\s*(\d+[,\.]?\d*)\s*%"#,
                    #"faser\s*(\d+[,\.]?\d*)\s*%"#,
                    // English patterns
                    #"(?:crude\s+)?fib[er]+\s*(\d+[,\.]?\d*)\s*%"#,
                    #"fib[er]+.*?max.*?(\d+[,\.]?\d*)\s*%"#
                ]
            case .moisture:
                return [
                    // German patterns
                    #"feuchtegehalt\s*(\d+[,\.]?\d*)\s*%"#,
                    #"feucht(?:e|igkeit)?\s*(\d+[,\.]?\d*)\s*%"#,
                    #"wasser\s*(\d+[,\.]?\d*)\s*%"#,
                    // English patterns
                    #"moisture\s*(\d+[,\.]?\d*)\s*%"#,
                    #"water\s*(\d+[,\.]?\d*)\s*%"#
                ]
            case .ash:
                return [
                    // German patterns
                    #"rohasche\s*(\d+[,\.]?\d*)\s*%"#,
                    #"asche\s*(\d+[,\.]?\d*)\s*%"#,
                    #"mineralstoffe\s*(\d+[,\.]?\d*)\s*%"#,
                    // English patterns
                    #"ash\s*(\d+[,\.]?\d*)\s*%"#,
                    #"mineral(?:s)?\s*(\d+[,\.]?\d*)\s*%"#
                ]
            }
        }
    }
}
