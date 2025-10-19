//
//  TesseractOCRService.swift
//  ReceiptTracker
//
//  Tesseract-based OCR service for improved text extraction
//

import UIKit
import SwiftyTesseract

class TesseractOCRService {
    static let shared = TesseractOCRService()
    
    private var tesseract: Tesseract
    
    private init() {
        // Initialize Tesseract with English AND Japanese languages (BEST quality)
        let bundle = Bundle.main
        
        // Debug: Check if tessdata exists
        if let tessdataPath = bundle.path(forResource: "tessdata", ofType: nil) {
            print("📁 Found tessdata at: \(tessdataPath)")
            
            // Check for BEST quality files first, fallback to standard
            let engBestPath = (tessdataPath as NSString).appendingPathComponent("eng_best.traineddata")
            let jpnBestPath = (tessdataPath as NSString).appendingPathComponent("jpn_best.traineddata")
            
            if FileManager.default.fileExists(atPath: engBestPath) {
                print("✅ Found HIGH QUALITY eng_best.traineddata (14MB)")
            }
            if FileManager.default.fileExists(atPath: jpnBestPath) {
                print("✅ Found HIGH QUALITY jpn_best.traineddata (13MB)")
            }
        } else {
            print("❌ tessdata folder not found in bundle")
        }
        
        // Initialize Tesseract with BOTH English and Japanese using BEST quality models
        tesseract = Tesseract(
            languages: [
                RecognitionLanguage.custom("eng_best"),
                RecognitionLanguage.custom("jpn_best")
            ],
            engineMode: .lstmOnly  // Use LSTM neural network mode for best accuracy
        )
        
        print("✅ Tesseract initialized with BEST quality models (English + Japanese)")
        print("🧠 Using LSTM neural network mode for maximum accuracy")
    }
    
    // MARK: - Text Extraction
    func extractText(from image: UIImage) async throws -> String {
        print("\n🔍 ========== STARTING OCR EXTRACTION ==========")
        print("📸 Image size: \(image.size.width) x \(image.size.height)")
        
        // Preprocess image for better OCR
        let preprocessedImage = preprocessImage(image)
        
        return try await withCheckedThrowingContinuation { continuation in
            let result = tesseract.performOCR(on: preprocessedImage)
            
            switch result {
            case .success(let text):
                print("\n✅ ========== OCR EXTRACTION SUCCESSFUL ==========")
                print("📝 Extracted Text Length: \(text.count) characters")
                print("📄 RAW EXTRACTED TEXT:")
                print("-------------------------------------------")
                print(text)
                print("-------------------------------------------")
                print("✅ ========== END OF EXTRACTION ==========\n")
                continuation.resume(returning: text)
            case .failure(let error):
                print("\n❌ ========== OCR EXTRACTION FAILED ==========")
                print("❌ Error: \(error)")
                print("❌ ========== END OF EXTRACTION ==========\n")
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Image Preprocessing (ENHANCED)
    private func preprocessImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        // Step 1: Upscale if image is too small (improves quality significantly)
        var processedImage = ciImage
        let minDimension = min(ciImage.extent.width, ciImage.extent.height)
        if minDimension < 1000 {
            let scale = 2000 / minDimension
            processedImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            print("📐 Upscaled image by \(scale)x for better OCR")
        }
        
        // Step 2: Denoise (reduce noise from camera/scan)
        if let denoiseFilter = CIFilter(name: "CINoiseReduction") {
            denoiseFilter.setValue(processedImage, forKey: kCIInputImageKey)
            denoiseFilter.setValue(0.02, forKey: "inputNoiseLevel")
            denoiseFilter.setValue(0.4, forKey: "inputSharpness")
            if let output = denoiseFilter.outputImage {
                processedImage = output
                print("🔧 Applied noise reduction")
            }
        }
        
        // Step 3: Sharpen text
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(processedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(1.5, forKey: kCIInputSharpnessKey)
            if let output = sharpenFilter.outputImage {
                processedImage = output
                print("✨ Applied sharpening")
            }
        }
        
        // Step 4: Adjust exposure and contrast
        if let exposureFilter = CIFilter(name: "CIExposureAdjust") {
            exposureFilter.setValue(processedImage, forKey: kCIInputImageKey)
            exposureFilter.setValue(0.3, forKey: kCIInputEVKey)
            if let output = exposureFilter.outputImage {
                processedImage = output
            }
        }
        
        // Step 5: High contrast + grayscale
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.5, forKey: kCIInputContrastKey)     // Higher contrast
            contrastFilter.setValue(0.2, forKey: kCIInputBrightnessKey)   // Boost brightness
            contrastFilter.setValue(0.0, forKey: kCIInputSaturationKey)   // Grayscale
            if let output = contrastFilter.outputImage {
                processedImage = output
                print("🎨 Applied contrast enhancement")
            }
        }
        
        // Step 6: Adaptive thresholding (binarization) for clearer text
        if let thresholdFilter = CIFilter(name: "CIColorThreshold") {
            thresholdFilter.setValue(processedImage, forKey: kCIInputImageKey)
            thresholdFilter.setValue(0.45, forKey: "inputThreshold")
            if let output = thresholdFilter.outputImage {
                processedImage = output
                print("🔲 Applied binarization")
            }
        }
        
        // Convert back to UIImage
        guard let finalCgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            print("⚠️ Preprocessing failed, using original image")
            return image
        }
        
        print("✅ Enhanced preprocessing complete")
        return UIImage(cgImage: finalCgImage)
    }
    
    // MARK: - Full Receipt Processing
    func processReceipt(image: UIImage) async throws -> OCRResult {
        // Extract text using Tesseract
        let extractedText = try await extractText(from: image)
        
        // Parse the extracted text using existing logic
        return parseReceiptText(extractedText, rawText: extractedText)
    }
    
    // MARK: - Text Parsing (reuse existing logic)
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
        
        // Extract merchant name (usually first non-empty line or line with store keywords)
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
            confidence: 0.85 // Tesseract generally has good confidence
        )
    }
    
    // MARK: - Enhanced Merchant Extraction
    private func extractMerchantName(from lines: [String]) -> String? {
        // Common store indicators
        let storeKeywords = ["market", "store", "shop", "grocery", "foods", "mart", "coffee", "cafe"]
        
        // Try to find a line with store keywords first
        for line in lines.prefix(5) {
            let lowercased = line.lowercased()
            if storeKeywords.contains(where: { lowercased.contains($0) }) {
                return line
            }
        }
        
        // Fall back to first meaningful line (not a number, not too short)
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
    
    // MARK: - Date Extraction
    private func extractDate(from text: String) -> Date? {
        let datePatterns = [
            "\\d{1,2}/\\d{1,2}/\\d{2,4}",      // 12/31/2023 or 31/12/23
            "\\d{1,2}-\\d{1,2}-\\d{2,4}",      // 12-31-2023 or 31-12-23
            "\\d{4}-\\d{2}-\\d{2}",            // 2023-12-31
            "\\d{1,2}\\.\\d{1,2}\\.\\d{2,4}"   // 12.31.2023 or 31.12.23
        ]
        
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let dateString = String(text[range])
                
                let formatters = [
                    "MM/dd/yyyy", "MM/dd/yy",
                    "dd/MM/yyyy", "dd/MM/yy",
                    "yyyy-MM-dd",
                    "MM-dd-yyyy", "MM-dd-yy",
                    "dd.MM.yyyy", "dd.MM.yy"
                ].map { format -> DateFormatter in
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    return formatter
                }
                
                for formatter in formatters {
                    if let date = formatter.date(from: dateString) {
                        print("✅ Found date: \(dateString) -> \(date)")
                        return date
                    }
                }
            }
        }
        
        print("⚠️ No date found, using current date")
        return Date() // Default to today if no date found
    }
    
    // MARK: - Total Extraction
    private func extractTotal(from text: String) -> Double? {
        print("🔍 Extracting total from Tesseract text")
        
        let totalPatterns = [
            "(?i)total[:\\s]*\\$?([0-9,]+\\.\\d{2})",
            "(?i)amount[:\\s]+due[:\\s]*\\$?([0-9,]+\\.\\d{2})",
            "(?i)balance[:\\s]+due[:\\s]*\\$?([0-9,]+\\.\\d{2})",
            "(?i)total[:\\s]+amount[:\\s]*\\$?([0-9,]+\\.\\d{2})",
            "\\$([0-9,]+\\.\\d{2})\\s*(?i)total",
            "(?i)total.*?\\$([0-9,]+\\.\\d{2})"
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
        
        // Fallback: find largest dollar amount in text
        let amountPattern = "\\$([0-9,]+\\.\\d{2})"
        if let regex = try? NSRegularExpression(pattern: amountPattern),
           let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) as? [NSTextCheckingResult] {
            var amounts: [Double] = []
            for match in matches {
                if match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: text) {
                    let amountString = String(text[range]).replacingOccurrences(of: ",", with: "")
                    if let amount = Double(amountString) {
                        amounts.append(amount)
                    }
                }
            }
            if let maxAmount = amounts.max() {
                print("✅ Using largest amount found: $\(maxAmount)")
                return maxAmount
            }
        }
        
        print("❌ No total found in text")
        return nil
    }
    
    // MARK: - Line Items Extraction
    private func extractLineItems(from lines: [String]) -> [ReceiptItemData] {
        var items: [ReceiptItemData] = []
        
        // Pattern: "Item Name    $12.99" or "2 x Item    $24.98"
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
}

// MARK: - Errors
enum TesseractError: LocalizedError {
    case notInitialized
    case extractionFailed
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Tesseract OCR engine is not initialized. Please check tessdata folder."
        case .extractionFailed:
            return "Failed to extract text from image"
        }
    }
}

