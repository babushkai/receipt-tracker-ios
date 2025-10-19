//
//  ReceiptsListViewModel.swift
//  ReceiptTracker
//
//  ViewModel for receipts list
//

import Foundation
import Combine

class ReceiptsListViewModel: ObservableObject {
    @Published var receipts: [Receipt] = []
    @Published var selectedCategory: ExpenseCategory?
    @Published var startDate: Date?
    @Published var endDate: Date?
    
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for receipt changes
        NotificationCenter.default.publisher(for: .receiptsDidChange)
            .sink { [weak self] _ in
                self?.loadReceipts()
            }
            .store(in: &cancellables)
    }
    
    var hasActiveFilters: Bool {
        selectedCategory != nil || startDate != nil || endDate != nil
    }
    
    var groupedReceipts: [Date: [Receipt]] {
        let calendar = Calendar.current
        var grouped: [Date: [Receipt]] = [:]
        
        for receipt in receipts {
            let startOfDay = calendar.startOfDay(for: receipt.date)
            grouped[startOfDay, default: []].append(receipt)
        }
        
        return grouped
    }
    
    func loadReceipts() {
        receipts = persistenceController.fetchReceipts(
            startDate: startDate,
            endDate: endDate,
            category: selectedCategory
        )
    }
    
    func applyFilters() {
        loadReceipts()
    }
    
    func clearFilters() {
        selectedCategory = nil
        startDate = nil
        endDate = nil
        loadReceipts()
    }
    
    func deleteReceipt(_ receipt: Receipt) {
        persistenceController.deleteReceipt(receipt)
        loadReceipts()
    }
}

