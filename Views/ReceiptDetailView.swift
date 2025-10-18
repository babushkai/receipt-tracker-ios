//
//  ReceiptDetailView.swift
//  ReceiptTracker
//
//  Detailed view of a single receipt
//

import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Receipt image
                    if let imageData = receipt.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(12)
                            .shadow(radius: 5)
                            .padding(.horizontal)
                    }
                    
                    // Receipt info
                    VStack(spacing: 20) {
                        // Merchant & Category
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Merchant")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(receipt.merchantName ?? "Unknown")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 8) {
                                Text("Category")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Image(systemName: receipt.categoryEnum.icon)
                                    Text(receipt.categoryEnum.rawValue)
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        
                        // Amount & Date
                        HStack(spacing: 20) {
                            InfoCard(
                                title: "Total Amount",
                                value: String(format: "$%.2f", receipt.totalAmount),
                                icon: "dollarsign.circle.fill"
                            )
                            
                            InfoCard(
                                title: "Date",
                                value: receipt.date.formatted(date: .abbreviated, time: .omitted),
                                icon: "calendar"
                            )
                        }
                        
                        // Line items
                        if !receipt.itemsArray.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Items")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(receipt.itemsArray) { item in
                                    HStack {
                                        Text("\(item.quantity)x")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 30, alignment: .leading)
                                        
                                        Text(item.name)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        Text(String(format: "$%.2f", item.price))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Notes
                        if let notes = receipt.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.headline)
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Receipt Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Info Card
struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

