//
//  DashboardViewModel.swift
//  ReceiptTracker
//
//  ViewModel for Dashboard
//

import Foundation
import Combine

class DashboardViewModel: ObservableObject {
    @Published var analytics: SpendingAnalytics?
    @Published var trendData: [(date: Date, amount: Double)] = []
    @Published var categoryData: [(category: ExpenseCategory, amount: Double, percentage: Double)] = []
    @Published var recentReceipts: [Receipt] = []
    
    private var granularity: TimeGranularity = .monthly
    private let persistenceController = PersistenceController.shared
    private let analyticsService = AnalyticsService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for receipt changes
        NotificationCenter.default.publisher(for: .receiptsDidChange)
            .sink { [weak self] _ in
                self?.loadData()
            }
            .store(in: &cancellables)
    }
    
    func loadData() {
        let endDate = Date()
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -granularity.days,
            to: endDate
        ) ?? endDate
        
        let receipts = persistenceController.fetchReceipts(startDate: startDate, endDate: endDate)
        
        // Generate analytics
        analytics = analyticsService.generateAnalytics(
            receipts: receipts,
            granularity: granularity,
            compareWithPrevious: true
        )
        
        // Get trend data
        trendData = analyticsService.getSpendingTrend(receipts: receipts, granularity: granularity)
        
        // Get category data
        if let analytics = analytics {
            categoryData = analyticsService.getCategoryChartData(analytics: analytics)
        }
        
        // Get recent receipts
        recentReceipts = Array(receipts.prefix(5))
    }
    
    func updateGranularity(_ newGranularity: TimeGranularity) {
        granularity = newGranularity
        loadData()
    }
}

