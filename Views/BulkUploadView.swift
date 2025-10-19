//
//  BulkUploadView.swift
//  ReceiptTracker
//
//  View for bulk receipt upload
//

import SwiftUI

struct BulkUploadView: View {
    @StateObject private var viewModel = BulkUploadViewModel()
    @State private var showingImagePicker = false
    @State private var showingSampleOptions = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.receipts.isEmpty {
                    emptyStateView
                } else {
                    receiptListView
                }
            }
            .navigationTitle("Bulk Upload")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if !viewModel.receipts.isEmpty && !viewModel.isProcessing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if viewModel.receipts.allSatisfy({ $0.status == .completed }) {
                            // All receipts are completed, show Save button
                            Button("Save All") {
                                viewModel.saveAllReceipts()
                                dismiss()
                            }
                            .foregroundColor(.green)
                        } else if viewModel.receipts.contains(where: { $0.status == .pending }) {
                            // Some receipts are pending, show Process button
                            Button("Process All") {
                                viewModel.processAllReceipts()
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                MultiImagePickerView(viewModel: viewModel)
            }
            .alert("Success!", isPresented: $viewModel.showSuccess) {
                Button("Save All") {
                    viewModel.saveAllReceipts()
                    dismiss()
                }
                Button("Review", role: .cancel) { }
            } message: {
                Text("Processed \(viewModel.completedReceipts) receipts successfully. \(viewModel.failedReceipts) failed.")
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "photo.stack")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("Bulk Upload Receipts")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select multiple receipts at once or try sample receipts")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                Button(action: {
                    showingImagePicker = true
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Select from Library")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Button(action: {
                    viewModel.loadSampleReceipts()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Try Sample Receipts")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Receipt List
    private var receiptListView: some View {
        VStack(spacing: 0) {
            // Progress bar
            if viewModel.isProcessing {
                VStack(spacing: 12) {
                    ProgressView(value: viewModel.progress)
                        .tint(.blue)
                    
                    Text("Processing \(viewModel.processedCount) of \(viewModel.totalCount)...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            
            // List of receipts
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(viewModel.receipts.enumerated()), id: \.element.id) { index, receipt in
                        ReceiptCardView(
                            receipt: receipt,
                            onRemove: {
                                viewModel.removeReceipt(at: index)
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Receipt Card
struct ReceiptCardView: View {
    let receipt: BulkReceiptItem
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Image(uiImage: receipt.image)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                if let result = receipt.result {
                    Text(result.merchantName)
                        .font(.headline)
                    Text(result.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(result.totalAmount, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else if let error = receipt.error {
                    Text("Failed")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Receipt")
                        .font(.headline)
                    Text("Ready to process")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status
            statusIcon
            
            // Remove button
            if receipt.status != .processing {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch receipt.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.gray)
        case .processing:
            ProgressView()
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }
}

// MARK: - Multi Image Picker Wrapper
struct MultiImagePickerView: View {
    @ObservedObject var viewModel: BulkUploadViewModel
    @State private var selectedImages: [UIImage] = []
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        MultiImagePicker(selectedImages: $selectedImages)
            .onChange(of: selectedImages) { newImages in
                if !newImages.isEmpty {
                    viewModel.loadImages(newImages)
                    dismiss()
                }
            }
    }
}

#Preview {
    BulkUploadView()
}

