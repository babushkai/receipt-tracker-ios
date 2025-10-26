//
//  DeepSeekOCRService.swift
//  ReceiptTracker
//
//  DeepSeek-OCR integration via remote server
//  State-of-the-art document understanding with vLLM
//

import UIKit
import Foundation

class DeepSeekOCRService {
    static let shared = DeepSeekOCRService()
    
    private var serverURL: String {
        return AppSettings.shared.deepseekServerURL
    }
    
    private init() {}
    
    // MARK: - Health Check
    func checkServerHealth() async throws -> Bool {
        print("🏥 Checking DeepSeek-OCR server health...")
        
        guard let url = URL(string: "\(serverURL)/health") else {
            throw DeepSeekOCRError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DeepSeekOCRError.serverUnavailable
        }
        
        let healthResponse = try JSONDecoder().decode(HealthResponse.self, from: data)
        print("✅ Server is healthy: \(healthResponse.status)")
        if let model = healthResponse.model {
            print("🤖 Model: \(model)")
        }
        
        return healthResponse.status == "healthy"
    }
    
    // MARK: - OCR Extraction
    func extractText(from image: UIImage) async throws -> String {
        print("\n🎯 ========== DEEPSEEK-OCR EXTRACTION STARTED ==========")
        print("📸 Original image size: \(image.size.width) x \(image.size.height)")
        print("🧠 Using state-of-the-art DeepSeek-OCR model")
        
        // Preprocess image for better OCR quality
        let preprocessedImage = preprocessImage(image)
        print("✨ Image preprocessed for better quality")
        
        // Convert image to base64 with high quality
        guard let imageData = preprocessedImage.jpegData(compressionQuality: 0.95) else {
            print("❌ Failed to convert image to JPEG")
            throw DeepSeekOCRError.invalidImage
        }
        let base64Image = imageData.base64EncodedString()
        print("📦 Image data size: \(imageData.count / 1024)KB")
        
        // Create request
        guard let url = URL(string: "\(serverURL)/ocr") else {
            throw DeepSeekOCRError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // 60 second timeout for model inference
        
        let requestBody: [String: String] = [
            "image": base64Image
        ]
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // Send request
        print("📤 Sending request to DeepSeek-OCR server...")
        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let processingTime = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekOCRError.invalidResponse
        }
        
        print("📥 Received response with status code: \(httpResponse.statusCode)")
        print("⏱️  Processing time: \(String(format: "%.2f", processingTime))s")
        
        guard httpResponse.statusCode == 200 else {
            throw DeepSeekOCRError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let ocrResponse = try JSONDecoder().decode(DeepSeekOCRResponse.self, from: data)
        
        let text = ocrResponse.text
        print("\n✅ ========== EXTRACTION SUCCESSFUL ==========")
        print("📝 Extracted Text Length: \(text.count) characters")
        print("🤖 Model: \(ocrResponse.model ?? "unknown")")
        print("⏱️  Server processing: \(String(format: "%.2f", ocrResponse.processing_time ?? 0))s")
        print("📄 RAW EXTRACTED TEXT:")
        print("-------------------------------------------")
        print(text)
        print("-------------------------------------------")
        print("✅ ========== END OF EXTRACTION ==========\n")
        
        return text
    }
    
    // MARK: - Full Receipt Processing
    func processReceipt(image: UIImage) async throws -> OCRResult {
        // Extract text using DeepSeek-OCR
        let extractedText = try await extractText(from: image)
        
        // Use existing parsing logic
        return parseReceiptText(extractedText, rawText: extractedText)
    }
    
    // MARK: - Text Parsing
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
        totalAmount = extractTotalAmount(from: lines)
        if let total = totalAmount {
            print("💵 Total Amount: $\(String(format: "%.2f", total))")
        } else {
            print("💵 Total Amount: NOT FOUND")
        }
        
        // Extract items
        items = extractItems(from: lines)
        print("📦 Items Found: \(items.count)")
        for (index, item) in items.enumerated() {
            print("   \(index + 1). \(item.name) - $\(String(format: "%.2f", item.price))")
        }
        
        print("✅ ========== PARSING COMPLETE ==========\n")
        
        return OCRResult(
            merchantName: merchantName,
            date: date,
            totalAmount: totalAmount,
            items: items,
            rawText: rawText,
            confidence: 1.0 // DeepSeek-OCR is highly confident
        )
    }
    
    // MARK: - Image Preprocessing
    private func preprocessImage(_ image: UIImage) -> UIImage {
        // Resize if too large (max 2048x2048 for optimal performance)
        let maxDimension: CGFloat = 2048
        let size = image.size
        
        if size.width > maxDimension || size.height > maxDimension {
            let scale = min(maxDimension / size.width, maxDimension / size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return resizedImage ?? image
        }
        
        return image
    }
    
    // MARK: - Extraction Helpers (reused from TesseractOCRService)
    private func extractMerchantName(from lines: [String]) -> String? {
        // First few lines usually contain merchant name
        for line in lines.prefix(5) {
            // Skip lines with prices, dates, or common receipt terms
            if line.contains(":") || line.contains("$") || line.contains("Tel") || line.contains("Tel") {
                continue
            }
            
            // Merchant name is usually capitalized and longer than 3 characters
            if line.count > 3 && !line.allSatisfy({ $0.isNumber }) {
                return line
            }
        }
        return nil
    }
    
    private func extractDate(from text: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Try different date formats
        let dateFormats = [
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy-MM-dd",
            "MMM dd, yyyy",
            "MMMM dd, yyyy",
            "dd-MM-yyyy"
        ]
        
        for format in dateFormats {
            dateFormatter.dateFormat = format
            
            // Search for date patterns in text
            let pattern = format
                .replacingOccurrences(of: "yyyy", with: "\\d{4}")
                .replacingOccurrences(of: "MM", with: "\\d{2}")
                .replacingOccurrences(of: "dd", with: "\\d{2}")
                .replacingOccurrences(of: "MMM", with: "[A-Za-z]{3}")
                .replacingOccurrences(of: "MMMM", with: "[A-Za-z]+")
            
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                let dateString = String(text[Range(match.range, in: text)!])
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    private func extractTotalAmount(from lines: [String]) -> Double? {
        // Look for "Total", "TOTAL", "Grand Total", etc.
        let totalKeywords = ["total", "合計", "小計", "計"]
        
        for line in lines.reversed() {
            let lowercasedLine = line.lowercased()
            
            // Check if line contains total keyword
            if totalKeywords.contains(where: { lowercasedLine.contains($0) }) {
                // Extract amount using regex
                if let amount = extractAmountFromLine(line) {
                    return amount
                }
            }
        }
        
        // Fallback: Look for largest amount (likely the total)
        var largestAmount: Double = 0
        for line in lines {
            if let amount = extractAmountFromLine(line) {
                largestAmount = max(largestAmount, amount)
            }
        }
        
        return largestAmount > 0 ? largestAmount : nil
    }
    
    private func extractItems(from lines: [String]) -> [ReceiptItemData] {
        var items: [ReceiptItemData] = []
        
        for line in lines {
            // Skip lines with total/subtotal
            let lowercased = line.lowercased()
            if lowercased.contains("total") || lowercased.contains("tax") || lowercased.contains("change") {
                continue
            }
            
            // Look for lines with prices
            if let price = extractAmountFromLine(line) {
                // Get item name (everything before the price)
                let itemName = line
                    .replacingOccurrences(of: #"\$?[\d,]+\.?\d*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                
                if !itemName.isEmpty && itemName.count > 2 {
                    items.append(ReceiptItemData(name: itemName, price: price))
                }
            }
        }
        
        return items
    }
    
    private func extractAmountFromLine(_ line: String) -> Double? {
        // Pattern to match prices: $1.99, 1.99, $1,234.56, etc.
        let pattern = #"\$?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            let amountString = String(line[range]).replacingOccurrences(of: ",", with: "")
            return Double(amountString)
        }
        
        return nil
    }
}

// MARK: - Response Models
struct DeepSeekOCRResponse: Codable {
    let text: String
    let processing_time: Double?
    let model: String?
}

struct HealthResponse: Codable {
    let status: String
    let model_loaded: Bool?
    let model: String?
}

// MARK: - Error Types
enum DeepSeekOCRError: Error {
    case invalidURL
    case invalidImage
    case serverUnavailable
    case invalidResponse
    case serverError(statusCode: Int)
    case extractionFailed(String)
}

