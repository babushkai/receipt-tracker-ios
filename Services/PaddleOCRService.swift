//
//  PaddleOCRService.swift
//  ReceiptTracker
//
//  PaddleOCR integration via local server
//

import UIKit
import Foundation

class PaddleOCRService {
    static let shared = PaddleOCRService()
    
    private var serverURL: String {
        return AppSettings.shared.paddleocrServerURL
    }
    
    private init() {}
    
    // MARK: - Health Check
    func checkServerHealth() async throws -> Bool {
        print("🏥 Checking PaddleOCR server health...")
        
        guard let url = URL(string: "\(serverURL)/health") else {
            throw PaddleOCRError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PaddleOCRError.serverUnavailable
        }
        
        let healthResponse = try JSONDecoder().decode(HealthResponse.self, from: data)
        print("✅ Server is healthy: \(healthResponse.service) v\(healthResponse.version)")
        print("🌐 Supported languages: \(healthResponse.languages.joined(separator: ", "))")
        
        return healthResponse.status == "ok"
    }
    
    // MARK: - OCR Extraction
    func extractText(from image: UIImage, language: OCRLanguage = .auto) async throws -> String {
        print("\n🎯 ========== PADDLEOCR EXTRACTION STARTED ==========")
        print("📸 Image size: \(image.size.width) x \(image.size.height)")
        print("🌐 Language: \(language.rawValue)")
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert image to JPEG")
            throw PaddleOCRError.invalidImage
        }
        let base64Image = imageData.base64EncodedString()
        print("📦 Image data size: \(imageData.count / 1024)KB")
        
        // Create request
        guard let url = URL(string: "\(serverURL)/ocr") else {
            throw PaddleOCRError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: String] = [
            "image": base64Image,
            "lang": language.rawValue
        ]
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // Send request
        print("📤 Sending request to PaddleOCR server...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaddleOCRError.invalidResponse
        }
        
        print("📥 Received response with status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw PaddleOCRError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let ocrResponse = try JSONDecoder().decode(OCRResponse.self, from: data)
        
        guard ocrResponse.success else {
            print("❌ OCR failed: \(ocrResponse.error ?? "Unknown error")")
            throw PaddleOCRError.extractionFailed(ocrResponse.error ?? "Unknown error")
        }
        
        let text = ocrResponse.text ?? ""
        print("\n✅ ========== EXTRACTION SUCCESSFUL ==========")
        print("📝 Extracted Text Length: \(text.count) characters")
        print("📊 Lines detected: \(ocrResponse.lineCount ?? 0)")
        print("🎯 Confidence: \(String(format: "%.2f%%", (ocrResponse.confidence ?? 0) * 100))")
        if let detectedLang = ocrResponse.language {
            print("🌐 Detected language: \(detectedLang)")
        }
        print("📄 RAW EXTRACTED TEXT:")
        print("-------------------------------------------")
        print(text)
        print("-------------------------------------------")
        print("✅ ========== END OF EXTRACTION ==========\n")
        
        return text
    }
    
    // MARK: - Full Receipt Processing
    func processReceipt(image: UIImage, language: OCRLanguage = .auto) async throws -> OCRResult {
        // Extract text using PaddleOCR
        let extractedText = try await extractText(from: image, language: language)
        
        // Use existing parsing logic from TesseractOCRService
        return parseReceiptText(extractedText, rawText: extractedText)
    }
    
    // MARK: - Text Parsing (reused from Tesseract)
    private func parseReceiptText(_ text: String, rawText: String) -> OCRResult {
        print("\n🔧 ========== PARSING EXTRACTED TEXT ==========")
        
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        print("📊 Found \(lines.count) non-empty lines")
        
        var merchantName: String?
        var date: Date?
        var totalAmount: Double?
        var items: [ReceiptItemData] = []
        
        // Extract merchant name
        merchantName = extractMerchantName(from: lines)
        print("🏪 Merchant Name: \(merchantName ?? "NOT FOUND")")
        
        // Extract date
        date = extractDate(from: text)
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            print("📅 Date: \(formatter.string(from: date))")
        } else {
            print("📅 Date: NOT FOUND")
        }
        
        // Extract total amount
        totalAmount = extractTotal(from: text)
        if let amount = totalAmount {
            print("💰 Total Amount: $\(String(format: "%.2f", amount))")
        } else {
            print("💰 Total Amount: NOT FOUND")
        }
        
        // Extract line items
        items = extractLineItems(from: lines)
        print("🛒 Line Items: Found \(items.count) items")
        for (index, item) in items.prefix(3).enumerated() {
            print("   [\(index + 1)] \(item.name) - $\(String(format: "%.2f", item.price)) x\(item.quantity)")
        }
        if items.count > 3 {
            print("   ... and \(items.count - 3) more items")
        }
        
        print("✅ ========== PARSING COMPLETE ==========\n")
        
        return OCRResult(
            merchantName: merchantName,
            date: date,
            totalAmount: totalAmount,
            items: items,
            rawText: rawText,
            confidence: 0.90 // PaddleOCR generally has high confidence
        )
    }
    
    // MARK: - Helper Methods (from TesseractOCRService)
    
    private func extractMerchantName(from lines: [String]) -> String? {
        let storeKeywords = ["market", "store", "shop", "grocery", "foods", "mart", "coffee", "cafe"]
        
        for line in lines.prefix(5) {
            let lowercased = line.lowercased()
            if storeKeywords.contains(where: { lowercased.contains($0) }) {
                return line
            }
        }
        
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count >= 3,
               trimmed.count <= 50,
               !trimmed.allSatisfy({ $0.isNumber || $0 == "-" || $0 == "/" }) {
                return trimmed
            }
        }
        
        return lines.first
    }
    
    private func extractDate(from text: String) -> Date? {
        let datePatterns = [
            "\\d{1,2}/\\d{1,2}/\\d{2,4}",
            "\\d{1,2}-\\d{1,2}-\\d{2,4}",
            "\\d{4}-\\d{2}-\\d{2}",
            "\\d{1,2}\\.\\d{1,2}\\.\\d{2,4}"
        ]
        
        let dateFormatter = DateFormatter()
        let formats = ["MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "MM-dd-yyyy", "dd.MM.yyyy"]
        
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let range = Range(match.range, in: text) {
                        let dateString = String(text[range])
                        
                        for format in formats {
                            dateFormatter.dateFormat = format
                            if let date = dateFormatter.date(from: dateString) {
                                return date
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractTotal(from text: String) -> Double? {
        let totalPatterns = [
            "total[:\\s]*\\$?([0-9]+\\.[0-9]{2})",
            "amount[:\\s]*\\$?([0-9]+\\.[0-9]{2})",
            "\\$([0-9]+\\.[0-9]{2})\\s*total"
        ]
        
        for pattern in totalPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches where match.numberOfRanges > 1 {
                    let amountRange = match.range(at: 1)
                    if let range = Range(amountRange, in: text) {
                        let amountString = String(text[range])
                        if let amount = Double(amountString) {
                            return amount
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractLineItems(from lines: [String]) -> [ReceiptItemData] {
        var items: [ReceiptItemData] = []
        
        let pricePattern = "\\$?([0-9]+\\.[0-9]{2})"
        let priceRegex = try? NSRegularExpression(pattern: pricePattern, options: [])
        
        for line in lines {
            guard let regex = priceRegex else { continue }
            let matches = regex.matches(in: line, options: [], range: NSRange(line.startIndex..., in: line))
            
            if let match = matches.last,
               match.numberOfRanges > 1 {
                let priceRange = match.range(at: 1)
                if let range = Range(priceRange, in: line),
                   let price = Double(String(line[range])) {
                    
                    let itemName = line.replacingOccurrences(of: "$\\(String(format: "%.2f", price))", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    
                    if !itemName.isEmpty && itemName.count > 2 {
                        items.append(ReceiptItemData(name: itemName, price: price, quantity: 1))
                    }
                }
            }
        }
        
        return items
    }
}

// MARK: - Data Models

enum OCRLanguage: String, Codable {
    case english = "en"
    case japanese = "japan"
    case auto = "auto"
}

struct HealthResponse: Codable {
    let status: String
    let service: String
    let version: String
    let languages: [String]
}

struct OCRResponse: Codable {
    let success: Bool
    let text: String?
    let lines: [String]?
    let confidence: Double?
    let language: String?
    let lineCount: Int?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success, text, lines, confidence, language, error
        case lineCount = "line_count"
    }
}

enum PaddleOCRError: LocalizedError {
    case invalidURL
    case invalidImage
    case invalidResponse
    case serverUnavailable
    case serverError(statusCode: Int)
    case extractionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidImage:
            return "Invalid image format"
        case .invalidResponse:
            return "Invalid server response"
        case .serverUnavailable:
            return "PaddleOCR server is not running. Please start the server first."
        case .serverError(let code):
            return "Server error (status code: \(code))"
        case .extractionFailed(let message):
            return "OCR extraction failed: \(message)"
        }
    }
}

