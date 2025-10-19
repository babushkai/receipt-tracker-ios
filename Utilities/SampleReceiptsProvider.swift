//
//  SampleReceiptsProvider.swift
//  ReceiptTracker
//
//  Provides sample receipt images for testing
//

import UIKit

class SampleReceiptsProvider {
    static let shared = SampleReceiptsProvider()
    
    private init() {}
    
    /// Generate sample receipt images with text overlay
    func generateSampleReceipts() -> [UIImage] {
        let sampleTexts = loadSampleTexts()
        return sampleTexts.map { generateReceiptImage(from: $0) }
    }
    
    /// Load sample receipt texts from assets
    private func loadSampleTexts() -> [String] {
        var texts: [String] = []
        
        for i in 1...3 {
            if let url = Bundle.main.url(forResource: "sample_receipt_\(i)", withExtension: "txt", subdirectory: "SampleReceipts.dataset"),
               let content = try? String(contentsOf: url) {
                texts.append(content)
            }
        }
        
        // Fallback samples if files not found
        if texts.isEmpty {
            texts = [
                """
                COFFEE SHOP
                123 Main St
                
                Latte        $5.00
                Muffin       $3.50
                
                Total        $8.50
                10/19/2024
                """,
                """
                GROCERY STORE
                456 Oak Ave
                
                Milk         $4.99
                Bread        $3.49
                Eggs         $5.99
                
                Total       $14.47
                10/18/2024
                """,
                """
                RESTAURANT
                789 Pine Rd
                
                Burger       $12.99
                Fries         $4.99
                Soda          $2.99
                
                Total        $20.97
                10/17/2024
                """
            ]
        }
        
        return texts
    }
    
    /// Generate a receipt-like image from text
    private func generateReceiptImage(from text: String) -> UIImage {
        let width: CGFloat = 600
        let padding: CGFloat = 40
        
        // Calculate text height
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Courier", size: 24) ?? UIFont.systemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        
        let textSize = (text as NSString).boundingRect(
            with: CGSize(width: width - 2 * padding, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).size
        
        let height = textSize.height + 2 * padding + 100
        
        // Create image context
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        
        let image = renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            // Add receipt-like border
            UIColor.lightGray.setStroke()
            let borderPath = UIBezierPath(rect: CGRect(x: 10, y: 10, width: width - 20, height: height - 20))
            borderPath.lineWidth = 2
            borderPath.stroke()
            
            // Draw text
            let textRect = CGRect(x: padding, y: padding + 50, width: width - 2 * padding, height: textSize.height)
            (text as NSString).draw(in: textRect, withAttributes: attributes)
            
            // Draw receipt icon at top
            if let receiptIcon = UIImage(systemName: "receipt")?.withTintColor(.gray, renderingMode: .alwaysOriginal) {
                let iconSize: CGFloat = 40
                let iconRect = CGRect(x: (width - iconSize) / 2, y: 20, width: iconSize, height: iconSize)
                receiptIcon.draw(in: iconRect)
            }
        }
        
        return image
    }
    
    /// Get sample receipt info for display
    func getSampleReceiptsInfo() -> [(name: String, preview: String)] {
        return [
            (name: "Whole Foods", preview: "$50.44 • Grocery"),
            (name: "Target", preview: "$97.68 • Household"),
            (name: "Starbucks", preview: "$13.78 • Food & Dining")
        ]
    }
    
    /// Get known sample receipt data (bypasses OCR for demo purposes)
    func getSampleReceiptsData() -> [(merchantName: String, amount: Double, date: Date, category: ExpenseCategory)] {
        let calendar = Calendar.current
        let today = Date()
        
        return [
            (
                merchantName: "Whole Foods Market",
                amount: 50.44,
                date: calendar.date(byAdding: .day, value: -2, to: today) ?? today,
                category: .groceries
            ),
            (
                merchantName: "Target",
                amount: 97.68,
                date: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
                category: .shopping
            ),
            (
                merchantName: "Starbucks Coffee",
                amount: 13.78,
                date: today,
                category: .food
            )
        ]
    }
}

