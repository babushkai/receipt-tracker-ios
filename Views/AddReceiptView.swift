//
//  AddReceiptView.swift
//  ReceiptTracker
//
//  View for adding new receipts via camera or photo library
//

import SwiftUI
import PhotosUI

struct AddReceiptView: View {
    @StateObject private var viewModel = AddReceiptViewModel()
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingBulkUpload = false
    @State private var sourceType: ImageSourceType = .camera
    
    enum ImageSourceType {
        case camera
        case photoLibrary
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                if viewModel.isProcessing {
                    ProcessingView()
                } else if let receipt = viewModel.processedReceipt {
                    ReceiptEditView(viewModel: viewModel, receipt: receipt)
                } else {
                    EmptyStateView(
                        onCameraButtonTap: {
                            sourceType = .camera
                            showingCamera = true
                        },
                        onPhotoLibraryButtonTap: {
                            sourceType = .photoLibrary
                            showingImagePicker = true
                        },
                        onBulkUploadTap: {
                            showingBulkUpload = true
                        }
                    )
                }
            }
            .navigationTitle("Add Receipt")
            .toolbar {
                if viewModel.processedReceipt == nil && !viewModel.isProcessing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingBulkUpload = true
                        }) {
                            Label("Bulk Upload", systemImage: "photo.stack")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(
                    sourceType: .camera,
                    selectedImage: $viewModel.selectedImage
                )
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(
                    sourceType: .photoLibrary,
                    selectedImage: $viewModel.selectedImage
                )
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    viewModel.reset()
                }
            } message: {
                Text("Receipt saved successfully!")
            }
            .sheet(isPresented: $showingBulkUpload) {
                BulkUploadView()
            }
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let onCameraButtonTap: () -> Void
    let onPhotoLibraryButtonTap: () -> Void
    let onBulkUploadTap: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "receipt")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("Add a Receipt")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Take a photo or select from your library to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                Button(action: onCameraButtonTap) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Take Photo")
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
                
                Button(action: onPhotoLibraryButtonTap) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Library")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Button(action: onBulkUploadTap) {
                    HStack {
                        Image(systemName: "photo.stack")
                        Text("Bulk Upload")
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
}

// MARK: - Processing View
struct ProcessingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text("Processing receipt...")
                .font(.headline)
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "text.viewfinder")
                        .foregroundColor(.blue)
                    Text("Scanning text with Vision AI")
                        .font(.caption)
                }
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.blue)
                    Text("Extracting merchant, date, and amount")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
            .padding(.top, 8)
        }
        .padding()
    }
}

// MARK: - Receipt Edit View
struct ReceiptEditView: View {
    @ObservedObject var viewModel: AddReceiptViewModel
    let receipt: EditableReceipt
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Receipt image preview
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                if let processedReceipt = Binding($viewModel.processedReceipt) {
                    VStack(spacing: 16) {
                        // Merchant Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Merchant Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Merchant", text: processedReceipt.merchantName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Date
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            DatePicker("", selection: processedReceipt.date, displayedComponents: .date)
                                .labelsHidden()
                        }
                        
                        // Total Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Total Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("0.00", value: processedReceipt.totalAmount, format: .currency(code: "USD"))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Category", selection: processedReceipt.category) {
                                ForEach(ExpenseCategory.allCases) { category in
                                    HStack {
                                        Image(systemName: category.icon)
                                        Text(category.rawValue)
                                    }
                                    .tag(category)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (Optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: processedReceipt.notes)
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Save button
                Button(action: {
                    viewModel.saveReceipt()
                }) {
                    Text("Save Receipt")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .padding(.vertical)
        }
    }
}

#Preview {
    AddReceiptView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

