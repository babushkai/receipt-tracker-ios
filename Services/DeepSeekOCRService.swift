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
    func extractOCRResponse(from image: UIImage) async throws -> DeepSeekOCRResponse {
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
        
        guard ocrResponse.success else {
            throw DeepSeekOCRError.extractionFailed("OCR extraction failed")
        }
        
        // Use raw_text if available, otherwise text
        let text = ocrResponse.raw_text ?? ocrResponse.text ?? ""
        
        print("\n✅ ========== EXTRACTION SUCCESSFUL ==========")
        print("📝 Extracted Text Length: \(text.count) characters")
        print("🤖 Model: \(ocrResponse.model ?? "unknown")")
        print("🚀 Engine: \(ocrResponse.engine ?? "unknown")")
        print("⏱️  Server processing: \(String(format: "%.2f", ocrResponse.processing_time ?? 0))s")
        
        if let structuredData = ocrResponse.structured_data {
            print("📊 Structured Data: \(structuredData.count) sections")
        }
        
        print("📄 RAW EXTRACTED TEXT:")
        print("-------------------------------------------")
        print(text)
        print("-------------------------------------------")
        print("✅ ========== END OF EXTRACTION ==========\n")
        
        return ocrResponse
    }
    
    func extractText(from image: UIImage) async throws -> String {
        let ocrResponse = try await extractOCRResponse(from: image)
        return ocrResponse.raw_text ?? ocrResponse.text ?? ""
    }
    
    // MARK: - Full Receipt Processing
    func processReceipt(image: UIImage) async throws -> OCRResult {
        // Extract structured data and text using DeepSeek-OCR
        let ocrResponse = try await extractOCRResponse(from: image)
        let extractedText = ocrResponse.raw_text ?? ocrResponse.text ?? ""
        
        // If we have structured data, use it directly
        if let structuredData = ocrResponse.structured_data {
            return parseStructuredData(structuredData, rawText: extractedText)
        }
        
        // Fall back to text parsing if no structured data
        return parseReceiptText(extractedText, rawText: extractedText)
    }
    
    // MARK: - Structured Data Parsing
    private func parseStructuredData(_ structuredData: [StructuredReceiptData], rawText: String) -> OCRResult {
        print("\n🔧 ========== PARSING STRUCTURED DATA ==========")
        
        var merchantName: String?
        var date: Date?
        var totalAmount: Double?
        var items: [ReceiptItemData] = []
        
        // Extract merchant info
        for entry in structuredData {
            if let name = entry.name {
                merchantName = [name, entry.address, entry.city]
                    .compactMap { $0 }
                    .joined(separator: " ")
                break
            }
        }
        
        // Extract date from invoice info
        for entry in structuredData {
            if let invoice = entry.invoice, let dateStr = invoice.date {
                date = parseDate(from: dateStr)
                break
            }
        }
        
        // Extract items
        for entry in structuredData {
            if let itemName = entry.item, let totalPriceStr = entry.total_price {
                let quantity = entry.quantity ?? 1
                // Extract numeric value from price string (e.g., "54.50 CHF" -> 54.50)
                if let price = extractPrice(from: totalPriceStr) {
                    items.append(ReceiptItemData(name: itemName, price: price, quantity: quantity))
                }
            }
        }
        
        // Extract total from summary
        for entry in structuredData {
            if let summary = entry.summary, let totalStr = summary.total {
                totalAmount = extractPrice(from: totalStr)
                break
            }
        }
        
        print("🏪 Merchant: \(merchantName ?? "NOT FOUND")")
        print("📅 Date: \(date?.description ?? "NOT FOUND")")
        print("💵 Total: \(totalAmount != nil ? String(format: "%.2f", totalAmount!) : "NOT FOUND")")
        print("📦 Items: \(items.count)")
        
        print("✅ ========== STRUCTURED PARSING COMPLETE ==========\n")
        
        return OCRResult(
            merchantName: merchantName,
            date: date,
            totalAmount: totalAmount,
            items: items,
            rawText: rawText,
            structuredData: structuredData
        )
    }
    
    private func parseDate(from dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Try common formats
        let formats = ["dd.MM.yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "MM/dd/yyyy"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }
        return nil
    }
    
    private func extractPrice(from priceStr: String) -> Double? {
        // Extract number from string like "54.50 CHF" or "€10.50"
        let pattern = #"(\d{1,}(?:[,\.]\d{2}))"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: priceStr, range: NSRange(priceStr.startIndex..., in: priceStr)),
           let range = Range(match.range(at: 1), in: priceStr) {
            var numStr = String(priceStr[range])
                .replacingOccurrences(of: ",", with: ".")
                .replacingOccurrences(of: " ", with: "")
            return Double(numStr)
        }
        return nil
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
            structuredData: nil
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
    
    // MARK: - Extraction Helpers
    private func extractMerchantName(from lines: [String]) -> String? {
        // Combine first few lines that look like merchant/address info
        var merchantLines: [String] = []
        
        for line in lines.prefix(5) {
            // Skip lines with prices, dates, or common receipt terms
            if line.contains(":") || line.contains("$") || line.contains("CHF") || line.contains("EUR") ||
               line.lowercased().contains("tel") || line.lowercased().contains("fax") || 
               line.lowercased().contains("rech") || line.lowercased().contains("bill") {
                break
            }
            
            // Merchant name/address lines are usually longer than 3 characters
            if line.count > 3 && !line.allSatisfy({ $0.isNumber }) {
                merchantLines.append(line)
            }
        }
        
        // Combine up to 2-3 lines for full merchant name/location
        if !merchantLines.isEmpty {
            return merchantLines.prefix(min(3, merchantLines.count)).joined(separator: " ")
        }
        
        return nil
    }
    
    private func extractDate(from text: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Try different date formats (including European formats)
        let dateFormats = [
            "dd.MM.yyyy/HH:mm:ss",  // European with time: 30.07.2007/13:29:17
            "dd.MM.yyyy HH:mm:ss",   // European with time (space)
            "dd.MM.yyyy",             // European: 30.07.2007
            "MM/dd/yyyy",             // US: 07/30/2007
            "dd/MM/yyyy",             // International: 30/07/2007
            "yyyy-MM-dd",             // ISO: 2007-07-30
            "MMM dd, yyyy",           // Text month: Jul 30, 2007
            "MMMM dd, yyyy",          // Full month: July 30, 2007
            "dd-MM-yyyy",             // Dash format: 30-07-2007
            "dd/MM/yy",               // Short year: 30/07/07
        ]
        
        for format in dateFormats {
            dateFormatter.dateFormat = format
            
            // Search for date patterns in text
            let pattern = format
                .replacingOccurrences(of: "yyyy", with: "\\d{4}")
                .replacingOccurrences(of: "yy", with: "\\d{2}")
                .replacingOccurrences(of: "MM", with: "\\d{2}")
                .replacingOccurrences(of: "dd", with: "\\d{2}")
                .replacingOccurrences(of: "HH", with: "\\d{2}")
                .replacingOccurrences(of: "mm", with: "\\d{2}")
                .replacingOccurrences(of: "ss", with: "\\d{2}")
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
            // Skip lines with total/subtotal/tax
            let lowercased = line.lowercased()
            if lowercased.contains("total") || lowercased.contains("tax") || 
               lowercased.contains("change") || lowercased.contains("mwst") ||
               lowercased.contains("---") {
                continue
            }
            
            // Try to parse quantity and item (format: "2xLatte Macchiato à 4.50 CHF 9.00")
            var quantity = 1
            var itemName = line
            var price: Double? = nil
            
            // Extract quantity (e.g., "2x")
            if let qtyRegex = try? NSRegularExpression(pattern: #"^(\d+)x"#),
               let match = qtyRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                if let qty = Int(String(line[range])) {
                    quantity = qty
                }
                // Remove quantity prefix from item name
                itemName = line.replacingOccurrences(of: #"^\d+x"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }
            
            // Look for lines with prices - extract the LAST price (usually the total for that item)
            let pricePattern = #"(\d{1,3}(?:[,\s]\d{3})*(?:[.,]\d{2}))\s*(?:CHF|EUR|USD|€|\$|$)"#
            if let regex = try? NSRegularExpression(pattern: pricePattern),
               let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line)) as? [NSTextCheckingResult],
               !matches.isEmpty {
                // Get the last price match (the line total, not unit price)
                if let lastMatch = matches.last,
                   let range = Range(lastMatch.range(at: 1), in: line) {
                    var amountString = String(line[range])
                        .replacingOccurrences(of: ",", with: "")
                        .replacingOccurrences(of: " ", with: "")
                    
                    // Handle European decimal
                    if amountString.contains(",") && !amountString.contains(".") {
                        amountString = amountString.replacingOccurrences(of: ",", with: ".")
                    }
                    
                    price = Double(amountString)
                }
            }
            
            // Clean up item name - remove prices, currency symbols, "à", etc.
            itemName = itemName
                .replacingOccurrences(of: #"[àa]\s*[\d,.\s]+\s*(?:CHF|EUR|USD|€|\$)"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"[\d,.\s]+\s*(?:CHF|EUR|USD|€|\$)"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            
            // Add item if we have a valid name and price
            if let price = price, !itemName.isEmpty && itemName.count > 2 {
                items.append(ReceiptItemData(name: itemName, price: price, quantity: quantity))
            }
        }
        
        return items
    }
    
    private func extractAmountFromLine(_ line: String) -> Double? {
        // Pattern to match prices with various currencies:
        // $1.99, 1.99, CHF 54.50, 4.50 CHF, €10.50, 1,234.56, etc.
        let patterns = [
            #"(\d{1,3}(?:[,\s]\d{3})*(?:[.,]\d{2}))\s*(?:CHF|EUR|USD|€|\$)"#,  // Amount before currency
            #"(?:CHF|EUR|USD|€|\$)\s*(\d{1,3}(?:[,\s]\d{3})*(?:[.,]\d{2}))"#,  // Currency before amount
            #"(\d{1,3}(?:[,\s]\d{3})*(?:[.,]\d{2}))"#,                          // Plain amount
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                var amountString = String(line[range])
                    .replacingOccurrences(of: ",", with: "")   // Remove thousands separator
                    .replacingOccurrences(of: " ", with: "")   // Remove spaces
                
                // Handle European decimal separator (comma instead of dot)
                if amountString.contains(",") && !amountString.contains(".") {
                    amountString = amountString.replacingOccurrences(of: ",", with: ".")
                }
                
                if let amount = Double(amountString) {
                    return amount
                }
            }
        }
        
        return nil
    }
}

// MARK: - Response Models
private struct DeepSeekOCRResponse: Codable {
    let success: Bool
    let text: String?
    let structured_data: [StructuredReceiptData]?
    let raw_text: String?
    let engine: String?
    let model: String?
    let processing_time: Double?
}

struct StructuredReceiptData: Codable {
    let name: String?
    let address: String?
    let city: String?
    let email: String?
    let invoice: InvoiceInfo?
    let item: String?
    let quantity: Int?
    let unit_price: String?
    let total_price: String?
    let summary: SummaryInfo?
    let server: String?
    let contact: ContactInfo?
    let conversion: ConversionInfo?
}

struct InvoiceInfo: Codable {
    let number: String?
    let date: String?
    let time: String?
    let table: String?
}

struct SummaryInfo: Codable {
    let total: String?
    let tax_included: String?
}

struct ContactInfo: Codable {
    let mwst_number: String?
    let phone: String?
    let fax: String?
    let email: String?
}

struct ConversionInfo: Codable {
    let currency: String?
    let amount: String?
}

private struct HealthResponse: Codable {
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


