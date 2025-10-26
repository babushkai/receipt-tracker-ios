//
//  EasyOCRService.swift
//  ReceiptTracker
//
//  EasyOCR integration via local server
//  EasyOCR supports 80+ languages including English, Japanese, Chinese, Korean
//

import UIKit
import Foundation

class EasyOCRService {
    static let shared = EasyOCRService()

    private var serverURL: String {
        return AppSettings.shared.easyocrServerURL
    }

    private init() {}

    // MARK: - Health Check
    func checkServerHealth() async throws -> Bool {
        print("🏥 Checking EasyOCR server health...")
        
        guard let url = URL(string: "\(serverURL)/health") else {
            throw EasyOCRError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw EasyOCRError.serverUnavailable
        }
        
        let healthResponse = try JSONDecoder().decode(HealthResponse.self, from: data)
        print("✅ Server is healthy: \(healthResponse.service) v\(healthResponse.version)")
        print("🌐 Supported languages: \(healthResponse.languages.joined(separator: ", "))")
        
        return healthResponse.status == "ok"
    }
    
    // MARK: - OCR Extraction
    func extractText(from image: UIImage, language: OCRLanguage = .multi) async throws -> String {
        print("\n🎯 ========== EASYOCR EXTRACTION STARTED ==========")
        print("📸 Original image size: \(image.size.width) x \(image.size.height)")
        print("🌐 Language mode: \(language.rawValue)")
        print("💡 Tip: For Japanese-only receipts, use .japanese for better accuracy")
        
        // Preprocess image for better OCR quality
        let preprocessedImage = preprocessImage(image)
        print("✨ Image preprocessed for better quality")
        
        // Convert image to base64 with higher quality for better OCR
        guard let imageData = preprocessedImage.jpegData(compressionQuality: 0.95) else {
            print("❌ Failed to convert image to JPEG")
            throw EasyOCRError.invalidImage
        }
        let base64Image = imageData.base64EncodedString()
        print("📦 Image data size: \(imageData.count / 1024)KB")
        
        // Create request
        guard let url = URL(string: "\(serverURL)/ocr") else {
            throw EasyOCRError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // 30 second timeout for OCR
        
        let requestBody: [String: String] = [
            "image": base64Image,
            "lang": language.rawValue
        ]
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // Send request
        print("📤 Sending request to EasyOCR server...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EasyOCRError.invalidResponse
        }
        
        print("📥 Received response with status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw EasyOCRError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let ocrResponse = try JSONDecoder().decode(OCRResponse.self, from: data)
        
        guard ocrResponse.success else {
            print("❌ OCR failed: \(ocrResponse.error ?? "Unknown error")")
            throw EasyOCRError.extractionFailed(ocrResponse.error ?? "Unknown error")
        }
        
        let text = ocrResponse.text ?? ""
        print("\n✅ ========== EXTRACTION SUCCESSFUL ==========")
        print("📝 Extracted Text Length: \(text.count) characters")
        print("📊 Lines detected: \(ocrResponse.lineCount ?? 0)")
        print("🎯 Confidence: \(String(format: "%.2f%%", (ocrResponse.confidence ?? 0) * 100))")
        if let detectedLang = ocrResponse.language {
            print("🌐 Language mode: \(detectedLang)")
        }
        print("📄 RAW EXTRACTED TEXT:")
        print("-------------------------------------------")
        print(text)
        print("-------------------------------------------")
        print("✅ ========== END OF EXTRACTION ==========\n")
        
        return text
    }
    
    // MARK: - Full Receipt Processing
    func processReceipt(image: UIImage, language: OCRLanguage = .multi) async throws -> OCRResult {
        // Extract text using EasyOCR
        let extractedText = try await extractText(from: image, language: language)
        
        // Use existing parsing logic
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
            confidence: 0.92 // EasyOCR typically has high confidence
        )
    }
    
    // MARK: - Helper Methods
    
    private func extractMerchantName(from lines: [String]) -> String? {
        let storeKeywords = ["market", "store", "shop", "grocery", "foods", "mart", "coffee", "cafe", "コンビニ", "スーパー", "マーケット"]
        
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
            "\\d{1,2}\\.\\d{1,2}\\.\\d{2,4}",
            "\\d{4}/\\d{1,2}/\\d{1,2}" // Japanese date format
        ]
        
        let dateFormatter = DateFormatter()
        let formats = ["MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "MM-dd-yyyy", "dd.MM.yyyy", "yyyy/MM/dd"]
        
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
        // Support both $ and ¥ currency symbols
        let totalPatterns = [
            "total[:\\s]*\\$?([0-9]+\\.[0-9]{2})",
            "amount[:\\s]*\\$?([0-9]+\\.[0-9]{2})",
            "\\$([0-9]+\\.[0-9]{2})\\s*total",
            "合計[:\\s]*¥?([0-9,]+)",
            "¥([0-9,]+)\\s*合計"
        ]
        
        for pattern in totalPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches where match.numberOfRanges > 1 {
                    let amountRange = match.range(at: 1)
                    if let range = Range(amountRange, in: text) {
                        let amountString = String(text[range]).replacingOccurrences(of: ",", with: "")
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
        
        // Support both $ and ¥
        let pricePattern = "[\\$¥]?([0-9,]+\\.[0-9]{2}|[0-9,]+)"
        let priceRegex = try? NSRegularExpression(pattern: pricePattern, options: [])
        
        for line in lines {
            guard let regex = priceRegex else { continue }
            let matches = regex.matches(in: line, options: [], range: NSRange(line.startIndex..., in: line))
            
            if let match = matches.last,
               match.numberOfRanges > 1 {
                let priceRange = match.range(at: 1)
                if let range = Range(priceRange, in: line) {
                    let priceStr = String(line[range]).replacingOccurrences(of: ",", with: "")
                    if let price = Double(priceStr) {
                        // Remove price from line to get item name
                        let pricePattern1 = "$" + String(format: "%.2f", price)
                        let pricePattern2 = "¥" + priceStr
                        
                        let itemName = line.replacingOccurrences(of: pricePattern1, with: "")
                            .replacingOccurrences(of: pricePattern2, with: "")
                            .replacingOccurrences(of: priceStr, with: "")
                            .trimmingCharacters(in: .whitespaces)
                        
                        if !itemName.isEmpty && itemName.count > 2 {
                            items.append(ReceiptItemData(name: itemName, price: price, quantity: 1))
                        }
                    }
                }
            }
        }
        
        return items
    }
    
    // MARK: - Image Preprocessing
    private func preprocessImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        var processedImage = ciImage
        
        // Step 1: Upscale if image is too small (helps with OCR)
        let minDimension = min(ciImage.extent.width, ciImage.extent.height)
        if minDimension < 1000 {
            let scale = 2000 / minDimension
            processedImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            print("📐 Upscaled image by \(String(format: "%.1f", scale))x")
        }
        
        // Step 2: Denoise (reduce grain)
        if let denoiseFilter = CIFilter(name: "CINoiseReduction") {
            denoiseFilter.setValue(processedImage, forKey: kCIInputImageKey)
            denoiseFilter.setValue(0.02, forKey: "inputNoiseLevel")
            denoiseFilter.setValue(0.4, forKey: "inputSharpness")
            if let output = denoiseFilter.outputImage {
                processedImage = output
            }
        }
        
        // Step 3: Sharpen (improve text clarity)
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(processedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(1.5, forKey: kCIInputSharpnessKey)
            if let output = sharpenFilter.outputImage {
                processedImage = output
            }
        }
        
        // Step 4: Adjust contrast (important for receipts)
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.4, forKey: kCIInputContrastKey)
            contrastFilter.setValue(0.1, forKey: kCIInputBrightnessKey)
            contrastFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Grayscale
            if let output = contrastFilter.outputImage {
                processedImage = output
            }
        }
        
        // Convert back to UIImage
        guard let finalCgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            print("⚠️ Preprocessing failed, using original")
            return image
        }
        
        return UIImage(cgImage: finalCgImage)
    }
}

// MARK: - Data Models

enum OCRLanguage: String, Codable {
    case english = "en"
    case japanese = "ja"
    case multi = "multi"
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

enum EasyOCRError: LocalizedError {
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
            return "EasyOCR server is not running. Please start the server first: ./start_paddle.sh"
        case .serverError(let code):
            return "Server error (status code: \(code))"
        case .extractionFailed(let message):
            return "OCR extraction failed: \(message)"
        }
    }
}

