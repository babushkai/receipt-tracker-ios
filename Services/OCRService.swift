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
        // Check if user has selected a specific OCR engine
        if let preferredEngine = AppSettings.shared.preferredOCREngine {
            print("🎯 Using preferred OCR engine: \(preferredEngine.displayName)")
            return try await processWithEngine(preferredEngine, image: image)
        }
        
        // Otherwise use auto-detection priority
        print("🔄 Auto-detecting best available OCR engine...")
        
        // Priority 1: Try DeepSeek-OCR if available (excellent for structured documents)
        do {
            if let _ = try? await DeepSeekOCRService.shared.checkServerHealth() {
                print("🚀 Using DeepSeek-OCR (state-of-the-art document understanding)")
                print("💡 Outputs structured markdown for superior parsing")
                return try await DeepSeekOCRService.shared.processReceipt(image: image)
            }
        } catch {
            print("⚠️ DeepSeek-OCR server not available, trying alternatives...")
        }
        
        // Priority 2: Try olmOCR if server is available (BEST free option!)
        do {
            if let _ = try? await OlmOCRService.shared.checkServerHealth() {
                print("🚀 Using olmOCR-7B (state-of-the-art document OCR)")
                print("💡 7B parameter model specialized for receipts")
                return try await OlmOCRService.shared.processReceipt(image: image)
            }
        } catch {
            print("⚠️ olmOCR server not available, trying alternatives...")
        }
        
        // Priority 3: Try LLM if enabled (excellent quality, costs money)
        if let llmConfig = AppSettings.shared.getLLMConfig() {
            print("🤖 Using LLM-enhanced OCR (\(AppSettings.shared.llmProvider.displayName))")
            return try await processReceiptWithLLM(image: image, llmConfig: llmConfig)
        }
        
        // Priority 4: Try EasyOCR if server is available (decent, free)
        do {
            if let _ = try? await EasyOCRService.shared.checkServerHealth() {
                print("🎯 Using EasyOCR (fallback multilingual)")
                return try await EasyOCRService.shared.processReceipt(image: image, language: .multi)
            }
        } catch {
            print("⚠️ EasyOCR server not available, trying Tesseract...")
        }
        
        // Priority 5: Fallback to Tesseract (always available)
        print("🔍 Using Tesseract OCR (final fallback)")
        return try await TesseractOCRService.shared.processReceipt(image: image)
    }
    
    // MARK: - Process with Specific Engine
    private func processWithEngine(_ engine: AppSettings.OCREngine, image: UIImage) async throws -> OCRResult {
        switch engine {
        case .auto:
            // Recursive call to auto-detect
            let savedEngine = AppSettings.shared.preferredOCREngine
            AppSettings.shared.preferredOCREngine = nil
            defer { AppSettings.shared.preferredOCREngine = savedEngine }
            return try await processReceipt(image: image)
            
        case .deepseek:
            return try await DeepSeekOCRService.shared.processReceipt(image: image)
            
        case .olmocr:
            return try await OlmOCRService.shared.processReceipt(image: image)
            
        case .easyocr:
            return try await EasyOCRService.shared.processReceipt(image: image, language: .multi)
            
        case .paddleocr:
            return try await PaddleOCRService.shared.processReceipt(image: image)
            
        case .tesseract:
            return try await TesseractOCRService.shared.processReceipt(image: image)
        }
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
        print("🔍 OCR: Extracting total from text:")
        print(text)
        
        let totalPatterns = [
            "(?i)total[:\\s]*\\$?([0-9,]+\\.\\d{2})",
            "(?i)amount[:\\s]*\\$?([0-9,]+\\.\\d{2})",
            "(?i)sum[:\\s]*\\$?([0-9,]+\\.\\d{2})",
            "\\$([0-9,]+\\.\\d{2})\\s*(?i)total",  // Amount before word "total"
            "(?i)total.*?\\$([0-9,]+\\.\\d{2})",   // More flexible
            "\\$\\s*([0-9,]+\\.\\d{2})\\s*$"       // Last dollar amount
        ]
        
        for (index, pattern) in totalPatterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                let amountString = String(text[range]).replacingOccurrences(of: ",", with: "")
                if let amount = Double(amountString) {
                    print("✅ Found total using pattern \(index): $\(amount)")
                    return amount
                }
            }
        }
        
        print("❌ No total found in text")
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

