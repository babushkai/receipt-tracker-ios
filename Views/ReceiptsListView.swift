//
//  ReceiptsListView.swift
//  ReceiptTracker
//
//  List view of all receipts with filtering
//

import SwiftUI

struct ReceiptsListView: View {
    @StateObject private var viewModel = ReceiptsListViewModel()
    @State private var showingFilters = false
    @State private var selectedReceipt: Receipt?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter bar
                if viewModel.hasActiveFilters {
                    FilterBarView(
                        categoryFilter: viewModel.selectedCategory,
                        onClearFilters: {
                            viewModel.clearFilters()
                        }
                    )
                }
                
                // Receipts list
                if viewModel.receipts.isEmpty {
                    EmptyReceiptsView()
                } else {
                    List {
                        ForEach(viewModel.groupedReceipts.keys.sorted(by: >), id: \.self) { date in
                            Section(header: Text(date, style: .date)) {
                                ForEach(viewModel.groupedReceipts[date] ?? []) { receipt in
                                    ReceiptListRow(receipt: receipt)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedReceipt = receipt
                                        }
                                }
                                .onDelete { indexSet in
                                    if let receiptsForDate = viewModel.groupedReceipts[date] {
                                        for index in indexSet {
                                            viewModel.deleteReceipt(receiptsForDate[index])
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Receipts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterView(viewModel: viewModel)
            }
            .sheet(item: $selectedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
            }
            .onAppear {
                viewModel.loadReceipts()
            }
        }
    }
}

// MARK: - Receipt List Row
struct ReceiptListRow: View {
    let receipt: Receipt
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: receipt.categoryEnum.icon)
                .font(.title3)
                .foregroundColor(categoryColor)
                .frame(width: 44, height: 44)
                .background(categoryColor.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.merchantName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 8) {
                    Text(receipt.categoryEnum.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(receipt.date, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(String(format: "$%.2f", receipt.totalAmount))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
    
    private var categoryColor: Color {
        switch receipt.categoryEnum.color {
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "indigo": return .indigo
        case "cyan": return .cyan
        case "brown": return .brown
        default: return .gray
        }
    }
}

// MARK: - Empty State
struct EmptyReceiptsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Receipts")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start adding receipts to track your spending")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Filter Bar
struct FilterBarView: View {
    let categoryFilter: ExpenseCategory?
    let onClearFilters: () -> Void
    
    var body: some View {
        HStack {
            if let category = categoryFilter {
                FilterChip(text: category.rawValue, onRemove: onClearFilters)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

struct FilterChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(16)
    }
}

// MARK: - Filter View
struct FilterView: View {
    @ObservedObject var viewModel: ReceiptsListViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category")) {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        Text("All Categories").tag(nil as ExpenseCategory?)
                        ForEach(ExpenseCategory.allCases) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category as ExpenseCategory?)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section(header: Text("Date Range")) {
                    DatePicker("Start Date", selection: Binding(
                        get: { viewModel.startDate ?? Date() },
                        set: { viewModel.startDate = $0 }
                    ), displayedComponents: .date)
                    
                    DatePicker("End Date", selection: Binding(
                        get: { viewModel.endDate ?? Date() },
                        set: { viewModel.endDate = $0 }
                    ), displayedComponents: .date)
                }
                
                Section {
                    Button("Clear All Filters", role: .destructive) {
                        viewModel.clearFilters()
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.applyFilters()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ReceiptsListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

