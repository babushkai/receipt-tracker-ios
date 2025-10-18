//
//  AddReceiptViewModel.swift
//  ReceiptTracker
//
//  ViewModel for adding receipts
//

import UIKit
import Combine

struct EditableReceipt {
    var merchantName: String
    var date: Date
    var totalAmount: Double
    var category: ExpenseCategory
    var notes: String
    var items: [ReceiptItemData]
}

class AddReceiptViewModel: ObservableObject {
    @Published var selectedImage: UIImage? {
        didSet {
            if selectedImage != nil {
                processImage()
            }
        }
    }
    @Published var isProcessing = false
    @Published var processedReceipt: EditableReceipt?
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var rawOCRText = "" // To show users what was extracted
    
    private let ocrService = OCRService.shared
    private let persistenceController = PersistenceController.shared
    
    func processImage() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        
        Task { @MainActor in
            do {
                let result = try await ocrService.processReceipt(image: image)
                
                // Save raw OCR text for debugging/display
                rawOCRText = result.rawText
                
                // Print to console what was extracted
                print("🔍 OCR EXTRACTED:")
                print("  Merchant: \(result.merchantName ?? "Not found")")
                print("  Date: \(result.date?.formatted() ?? "Not found")")
                print("  Total: $\(result.totalAmount ?? 0)")
                print("  Items: \(result.items.count) items")
                print("  Raw text: \(result.rawText.prefix(100))...")
                
                // Convert OCR result to editable receipt
                processedReceipt = EditableReceipt(
                    merchantName: result.merchantName ?? "Unknown Merchant",
                    date: result.date ?? Date(),
                    totalAmount: result.totalAmount ?? 0.0,
                    category: .other,
                    notes: "",
                    items: result.items
                )
                
                isProcessing = false
            } catch {
                isProcessing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    func saveReceipt() {
        guard let receipt = processedReceipt,
              let imageData = selectedImage?.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        _ = persistenceController.createReceipt(
            date: receipt.date,
            merchantName: receipt.merchantName,
            totalAmount: receipt.totalAmount,
            category: receipt.category,
            imageData: imageData,
            notes: receipt.notes.isEmpty ? nil : receipt.notes,
            items: receipt.items
        )
        
        showSuccess = true
    }
    
    func reset() {
        selectedImage = nil
        processedReceipt = nil
        isProcessing = false
    }
}

