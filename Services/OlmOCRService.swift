//
//  OlmOCRService.swift
//  ReceiptTracker
//
//  Allen AI olmOCR-7B integration via local server
//  State-of-the-art document OCR model
//  Model: https://huggingface.co/allenai/olmOCR-7B-0225-preview
//

import UIKit
import Foundation

class OlmOCRService {
    static let shared = OlmOCRService()
    
    private var serverURL: String {
        return AppSettings.shared.olmocrServerURL
    }
    
    private init() {}
    
    // MARK: - Health Check
    func checkServerHealth() async throws -> Bool {
        print("🏥 Checking olmOCR server health...")
        
        guard let url = URL(string: "\(serverURL)/health") else {
            throw OlmOCRError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OlmOCRError.serverUnavailable
        }
        
        let healthResponse = try JSONDecoder().decode(OlmHealthResponse.self, from: data)
        print("✅ Server is healthy: \(healthResponse.service)")
        print("🤖 Model: \(healthResponse.model)")
        print("🖥️  Device: \(healthResponse.device)")
        
        return healthResponse.status == "ok"
    }
    
    // MARK: - OCR Extraction
    func extractText(from image: UIImage, customPrompt: String? = nil) async throws -> String {
        print("\n🎯 ========== OLMOCR EXTRACTION STARTED ==========")
        print("📸 Original image size: \(image.size.width) x \(image.size.height)")
        print("🤖 Model: olmOCR-7B (7 billion parameters)")
        print("📚 Specialized for: Document OCR")
        
        // Preprocess image for better quality
        let preprocessedImage = preprocessImage(image)
        print("✨ Image preprocessed")
        
        // Convert to base64 with high quality
        guard let imageData = preprocessedImage.jpegData(compressionQuality: 0.95) else {
            print("❌ Failed to convert image to JPEG")
            throw OlmOCRError.invalidImage
        }
        let base64Image = imageData.base64EncodedString()
        print("📦 Image data size: \(imageData.count / 1024)KB")
        
        // Create request
        guard let url = URL(string: "\(serverURL)/ocr") else {
            throw OlmOCRError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // olmOCR takes longer (7B params)
        
        var requestBody: [String: String] = [
            "image": base64Image
        ]
        
        if let prompt = customPrompt {
            requestBody["prompt"] = prompt
        }
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // Send request
        print("📤 Sending request to olmOCR server...")
        print("⏳ Note: First request may take 2-3 minutes (downloading 14GB model)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OlmOCRError.invalidResponse
        }
        
        print("📥 Received response with status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw OlmOCRError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let ocrResponse = try JSONDecoder().decode(OlmOCRResponse.self, from: data)
        
        guard ocrResponse.success else {
            print("❌ OCR failed: \(ocrResponse.error ?? "Unknown error")")
            throw OlmOCRError.extractionFailed(ocrResponse.error ?? "Unknown error")
        }
        
        let text = ocrResponse.text ?? ""
        print("\n✅ ========== EXTRACTION SUCCESSFUL ==========")
        print("📝 Extracted Text Length: \(text.count) characters")
        print("🎯 Model Confidence: \(String(format: "%.2f%%", (ocrResponse.confidence ?? 0) * 100))")
        print("📄 RAW EXTRACTED TEXT:")
        print("-------------------------------------------")
        print(text)
        print("-------------------------------------------")
        print("✅ ========== END OF EXTRACTION ==========\n")
        
        return text
    }
    
    // MARK: - Full Receipt Processing
    func processReceipt(image: UIImage) async throws -> OCRResult {
        // Extract text using olmOCR
        let extractedText = try await extractText(from: image)
        
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
        
        print("✅ ========== PARSING COMPLETE ==========\n")
        
        return OCRResult(
            merchantName: merchantName,
            date: date,
            totalAmount: totalAmount,
            items: items,
            rawText: rawText,
            confidence: 0.95 // olmOCR is highly confident
        )
    }
    
    // MARK: - Helper Methods (same as EasyOCR)
    
    private func extractMerchantName(from lines: [String]) -> String? {
        let storeKeywords = ["market", "store", "shop", "grocery", "foods", "mart", "coffee", "cafe", "コンビニ", "スーパー", "マーケット", "セブン", "ファミリー"]
        
        for line in lines.prefix(5) {
            let lowercased = line.lowercased()
            if storeKeywords.contains(where: { lowercased.contains($0) }) {
                return line
            }
        }
        
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count >= 3, trimmed.count <= 50 {
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
            "\\d{4}/\\d{1,2}/\\d{1,2}",
            "\\d{4}年\\d{1,2}月\\d{1,2}日"
        ]
        
        let dateFormatter = DateFormatter()
        let formats = ["MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "yyyy/MM/dd", "yyyy年MM月dd日"]
        
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
            "合計[:\\s]*[¥￥]?([0-9,]+)",
            "[¥￥]([0-9,]+)\\s*合計"
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
        
        let pricePattern = "[\\$¥￥]?([0-9,]+\\.?[0-9]*)"
        let priceRegex = try? NSRegularExpression(pattern: pricePattern, options: [])
        
        for line in lines {
            guard let regex = priceRegex else { continue }
            let matches = regex.matches(in: line, options: [], range: NSRange(line.startIndex..., in: line))
            
            if let match = matches.last, match.numberOfRanges > 1 {
                let priceRange = match.range(at: 1)
                if let range = Range(priceRange, in: line) {
                    let priceStr = String(line[range]).replacingOccurrences(of: ",", with: "")
                    if let price = Double(priceStr) {
                        let itemName = line.components(separatedBy: priceStr).first?
                            .trimmingCharacters(in: .whitespaces) ?? ""
                        
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
        
        // Upscale if needed (olmOCR works best at 1024px longest dimension)
        let maxDim = max(ciImage.extent.width, ciImage.extent.height)
        if maxDim < 1024 {
            let scale = 1024 / maxDim
            processedImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        
        // Enhance contrast for better OCR
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.3, forKey: kCIInputContrastKey)
            contrastFilter.setValue(0.1, forKey: kCIInputBrightnessKey)
            if let output = contrastFilter.outputImage {
                processedImage = output
            }
        }
        
        guard let finalCgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: finalCgImage)
    }
}

// MARK: - Data Models

struct OlmHealthResponse: Codable {
    let status: String
    let service: String
    let version: String
    let model: String
    let device: String
}

struct OlmOCRResponse: Codable {
    let success: Bool
    let text: String?
    let confidence: Double?
    let model: String?
    let length: Int?
    let error: String?
}

enum OlmOCRError: LocalizedError {
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
            return "olmOCR server is not running. Start it with the setup script."
        case .serverError(let code):
            return "Server error (status code: \(code))"
        case .extractionFailed(let message):
            return "OCR extraction failed: \(message)"
        }
    }
}

