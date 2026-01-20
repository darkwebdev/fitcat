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

        NSLog("FITCAT OCR: Detected text:\n\(combinedText)")

        let protein = extractValue(from: combinedText, for: .protein)
        let fat = extractValue(from: combinedText, for: .fat)
        let fiber = extractValue(from: combinedText, for: .fiber)
        let moisture = extractValue(from: combinedText, for: .moisture)
        let ash = extractValue(from: combinedText, for: .ash)

        NSLog("FITCAT OCR: Parsed - Protein: \(protein?.description ?? "nil"), Fat: \(fat?.description ?? "nil"), Fiber: \(fiber?.description ?? "nil"), Moisture: \(moisture?.description ?? "nil"), Ash: \(ash?.description ?? "nil")")

        return NutritionInfo(
            protein: protein,
            fat: fat,
            fiber: fiber,
            moisture: moisture,
            ash: ash
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
                    // Dutch patterns (check first)
                    #"eiwit(?:gehalte)?\s*(\d+[,\.]?\d*)\s*%"#,
                    #"proteine\s*(\d+[,\.]?\d*)\s*%"#,
                    // German patterns
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
                    // Dutch patterns (check first)
                    #"vetgehalte\s*(\d+[,\.]?\d*)\s*%"#,
                    #"vet\s*(\d+[,\.]?\d*)\s*%"#,
                    #"tenore\s+in\s+materia\s+grassa\s*(\d+[,\.]?\d*)\s*%"#,
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
                    // Dutch/Italian patterns
                    #"vezel(?:stof)?(?:gehalte)?\s*(\d+[,\.]?\d*)\s*%"#,
                    #"fibra\s*(\d+[,\.]?\d*)\s*%"#,
                    // German patterns
                    #"rohfaser\s*(\d+[,\.]?\d*)\s*%"#,
                    #"faser\s*(\d+[,\.]?\d*)\s*%"#,
                    // English patterns
                    #"(?:crude\s+)?fib[er]+\s*(\d+[,\.]?\d*)\s*%"#,
                    #"fib[er]+.*?max.*?(\d+[,\.]?\d*)\s*%"#
                ]
            case .moisture:
                return [
                    // Dutch/Italian patterns
                    #"vocht(?:gehalte)?(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#,
                    #"umidità(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#,
                    // German patterns
                    #"feuchtegehalt(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#,
                    #"feucht(?:e|igkeit)?(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#,
                    #"wasser(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#,
                    // English patterns
                    #"moisture(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#,
                    #"water(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#
                ]
            case .ash:
                return [
                    // Dutch/Italian patterns
                    #"(?:ruwe\s+)?as(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#,
                    #"cenere(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#,
                    // German patterns
                    #"rohasche(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#,
                    #"asche(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#,
                    #"mineralstoffe(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#,
                    // English patterns
                    #"ash(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#,
                    #"mineral(?:s)?(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#
                ]
            }
        }
    }
}
