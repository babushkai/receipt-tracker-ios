//
//  OCRService.swift
//  ReceiptTracker
//
//  OCR service using Vision framework and LLM for parsing
//

import UIKit
import Vision
import CoreImage

struct OCRResult {
    let merchantName: String?
    let date: Date?
    let totalAmount: Double?
    let items: [ReceiptItemData]
    let rawText: String
    let confidence: Float
}

class OCRService {
    static let shared = OCRService()
    
    private init() {}
    
    // MARK: - Main OCR Processing
    func processReceipt(image: UIImage) async throws -> OCRResult {
        // Step 1: Extract text using Vision
        let extractedText = try await extractText(from: image)
        
        // Step 2: Parse the extracted text
        let parsedData = parseReceiptText(extractedText)
        
        return parsedData
    }
    
    // MARK: - Vision Text Recognition
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            // Configure for accurate text recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Text Parsing
    private func parseReceiptText(_ text: String) -> OCRResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var merchantName: String?
        var date: Date?
        var totalAmount: Double?
        var items: [ReceiptItemData] = []
        
        // Extract merchant name (usually first non-empty line)
        if let firstLine = lines.first {
            merchantName = firstLine
        }
        
        // Extract date
        date = extractDate(from: text)
        
        // Extract total amount
        totalAmount = extractTotal(from: text)
        
        // Extract line items
        items = extractLineItems(from: lines)
        
        return OCRResult(
            merchantName: merchantName,
            date: date,
            totalAmount: totalAmount,
            items: items,
            rawText: text,
            confidence: 0.8
        )
    }
    
    // MARK: - Helper Parsing Methods
    private func extractDate(from text: String) -> Date? {
        let datePatterns = [
            "\\d{1,2}/\\d{1,2}/\\d{2,4}",
            "\\d{1,2}-\\d{1,2}-\\d{2,4}",
            "\\d{4}-\\d{2}-\\d{2}"
        ]
        
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let dateString = String(text[range])
                
                let formatters = [
                    "MM/dd/yyyy", "MM/dd/yy",
                    "dd/MM/yyyy", "dd/MM/yy",
                    "yyyy-MM-dd"
                ].map { format -> DateFormatter in
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    return formatter
                }
                
                for formatter in formatters {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractTotal(from text: String) -> Double? {
        let totalPatterns = [
            "(?i)total[:\\s]*\\$?([0-9,]+\\.\\d{2})",
            "(?i)amount[:\\s]*\\$?([0-9,]+\\.\\d{2})",
            "(?i)sum[:\\s]*\\$?([0-9,]+\\.\\d{2})"
        ]
        
        for pattern in totalPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                let amountString = String(text[range]).replacingOccurrences(of: ",", with: "")
                return Double(amountString)
            }
        }
        
        return nil
    }
    
    private func extractLineItems(from lines: [String]) -> [ReceiptItemData] {
        var items: [ReceiptItemData] = []
        
        // Pattern to match item lines like "Item Name    $12.99" or "2 x Item    $24.98"
        let itemPattern = "^(?:(\\d+)\\s*x?\\s*)?(.+?)\\s+\\$?([0-9,]+\\.\\d{2})$"
        guard let regex = try? NSRegularExpression(pattern: itemPattern, options: [.caseInsensitive]) else {
            return items
        }
        
        for line in lines {
            if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges > 3 {
                
                let quantityRange = match.range(at: 1)
                let nameRange = match.range(at: 2)
                let priceRange = match.range(at: 3)
                
                let quantity: Int
                if quantityRange.location != NSNotFound,
                   let qRange = Range(quantityRange, in: line),
                   let q = Int(String(line[qRange])) {
                    quantity = q
                } else {
                    quantity = 1
                }
                
                guard let nRange = Range(nameRange, in: line),
                      let pRange = Range(priceRange, in: line) else {
                    continue
                }
                
                let name = String(line[nRange]).trimmingCharacters(in: .whitespaces)
                let priceString = String(line[pRange]).replacingOccurrences(of: ",", with: "")
                
                if let price = Double(priceString) {
                    items.append(ReceiptItemData(
                        name: name,
                        price: price / Double(quantity),
                        quantity: quantity
                    ))
                }
            }
        }
        
        return items
    }
    
    // MARK: - LLM Integration (Optional Enhancement)
    func enhanceWithLLM(ocrResult: OCRResult, apiKey: String) async throws -> OCRResult {
        // This is a placeholder for LLM integration
        // You can integrate with OpenAI, Anthropic, or other LLM providers
        // to improve parsing accuracy and category detection
        
        let prompt = """
        Parse this receipt text and extract:
        1. Merchant name
        2. Date (format: YYYY-MM-DD)
        3. Total amount
        4. Line items with quantities and prices
        5. Suggested expense category
        
        Receipt text:
        \(ocrResult.rawText)
        
        Return as JSON.
        """
        
        // TODO: Implement actual LLM API call
        // For now, return the original result
        return ocrResult
    }
}

// MARK: - Errors
enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noTextFound:
            return "No text found in image"
        case .parsingFailed:
            return "Failed to parse receipt"
        }
    }
}

