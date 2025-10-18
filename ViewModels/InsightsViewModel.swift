//
//  InsightsViewModel.swift
//  ReceiptTracker
//
//  ViewModel for insights view
//

import Foundation
import Combine

class InsightsViewModel: ObservableObject {
    @Published var insights: [SpendingInsight] = []
    
    private let persistenceController = PersistenceController.shared
    private let analyticsService = AnalyticsService.shared
    
    func loadInsights() {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        let receipts = persistenceController.fetchReceipts(startDate: startDate, endDate: endDate)
        
        guard !receipts.isEmpty else {
            insights = []
            return
        }
        
        let analytics = analyticsService.generateAnalytics(
            receipts: receipts,
            granularity: .monthly,
            compareWithPrevious: true
        )
        
        insights = analyticsService.generateInsights(
            receipts: receipts,
            analytics: analytics,
            granularity: .monthly
        )
    }
}

