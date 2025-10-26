//
//  OCRService.swift
//  ReceiptTracker
//
//  Unified OCR service that uses DeepSeek-OCR
//

import UIKit
import Foundation

class OCRService {
    static let shared = OCRService()
    
    private init() {}
    
    // MARK: - Main Processing Method
    func processReceipt(image: UIImage) async throws -> OCRResult {
        print("\n🎯 ========== OCR PROCESSING STARTED ==========")
        print("📸 Image size: \(image.size.width) x \(image.size.height)")
        print("🤖 Using DeepSeek-OCR")
        
        // Use DeepSeek-OCR
        return try await DeepSeekOCRService.shared.processReceipt(image: image)
    }
}

// MARK: - OCR Result Model
struct OCRResult {
    let merchantName: String?
    let date: Date?
    let totalAmount: Double?
    let items: [ReceiptItemData]
    let rawText: String
    let structuredData: [StructuredReceiptData]?  // Added structured data from DeepSeek-OCR
    
    var isValid: Bool {
        return merchantName != nil || totalAmount != nil || !items.isEmpty || structuredData != nil
    }
}
