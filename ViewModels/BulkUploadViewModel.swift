//
//  BulkUploadViewModel.swift
//  ReceiptTracker
//
//  ViewModel for bulk receipt uploads
//

import UIKit
import Combine

struct BulkReceiptItem: Identifiable {
    let id = UUID()
    let image: UIImage
    var status: ProcessingStatus
    var result: EditableReceipt?
    var error: String?
    
    enum ProcessingStatus {
        case pending
        case processing
        case completed
        case failed
    }
}

class BulkUploadViewModel: ObservableObject {
    @Published var receipts: [BulkReceiptItem] = []
    @Published var isProcessing = false
    @Published var showSuccess = false
    @Published var processedCount = 0
    @Published var totalCount = 0
    
    private let ocrService = OCRService.shared
    private let persistenceController = PersistenceController.shared
    
    // MARK: - Load Sample Receipts
    func loadSampleReceipts() {
        let sampleImages = SampleReceiptsProvider.shared.generateSampleReceipts()
        let sampleData = SampleReceiptsProvider.shared.getSampleReceiptsData()
        
        // Create receipts with pre-filled data (bypasses OCR for samples)
        receipts = zip(sampleImages, sampleData).map { image, data in
            let editableReceipt = EditableReceipt(
                merchantName: data.merchantName,
                date: data.date,
                totalAmount: data.amount,
                category: data.category,
                notes: "Sample receipt for demo purposes",
                items: []
            )
            
            return BulkReceiptItem(
                image: image,
                status: .completed,  // Mark as completed immediately
                result: editableReceipt
            )
        }
        
        totalCount = receipts.count
        processedCount = receipts.count  // All already processed
    }
    
    // MARK: - Load from Photo Library
    func loadImages(_ images: [UIImage]) {
        receipts = images.map { BulkReceiptItem(image: $0, status: .pending) }
        totalCount = receipts.count
        processedCount = 0
    }
    
    // MARK: - Process All Receipts
    func processAllReceipts() {
        guard !isProcessing else { return }
        
        isProcessing = true
        processedCount = 0
        
        Task { @MainActor in
            for index in receipts.indices {
                await processReceipt(at: index)
            }
            
            isProcessing = false
            showSuccess = true
        }
    }
    
    // MARK: - Process Single Receipt
    private func processReceipt(at index: Int) async {
        guard index < receipts.count else { return }
        
        receipts[index].status = .processing
        
        do {
            let result = try await ocrService.processReceipt(image: receipts[index].image)
            
            let editableReceipt = EditableReceipt(
                merchantName: result.merchantName ?? "Unknown Merchant",
                date: result.date ?? Date(),
                totalAmount: result.totalAmount ?? 0.0,
                category: .other,
                notes: "",
                items: result.items
            )
            
            receipts[index].result = editableReceipt
            receipts[index].status = .completed
            processedCount += 1
            
        } catch {
            receipts[index].error = error.localizedDescription
            receipts[index].status = .failed
            processedCount += 1
        }
    }
    
    // MARK: - Save All Receipts
    func saveAllReceipts() {
        for receipt in receipts where receipt.status == .completed {
            guard let result = receipt.result,
                  let imageData = receipt.image.jpegData(compressionQuality: 0.8) else {
                continue
            }
            
            _ = persistenceController.createReceipt(
                date: result.date,
                merchantName: result.merchantName,
                totalAmount: result.totalAmount,
                category: result.category,
                imageData: imageData,
                notes: result.notes.isEmpty ? nil : result.notes,
                items: result.items
            )
        }
        
        HapticFeedback.success()
    }
    
    // MARK: - Remove Receipt
    func removeReceipt(at index: Int) {
        guard index < receipts.count else { return }
        receipts.remove(at: index)
        totalCount = receipts.count
    }
    
    // MARK: - Get Progress
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(processedCount) / Double(totalCount)
    }
    
    var completedReceipts: Int {
        receipts.filter { $0.status == .completed }.count
    }
    
    var failedReceipts: Int {
        receipts.filter { $0.status == .failed }.count
    }
}

