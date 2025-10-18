//
//  AnalyticsService.swift
//  ReceiptTracker
//
//  Analytics and insights generation service
//

import Foundation

struct SpendingAnalytics {
    let totalSpent: Double
    let averagePerTransaction: Double
    let categoryBreakdown: [ExpenseCategory: Double]
    let topCategories: [(category: ExpenseCategory, amount: Double)]
    let transactionCount: Int
    let comparisonToPrevious: Double // percentage change
}

struct SpendingInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let category: InsightCategory
    let impact: InsightImpact
    let recommendation: String
    let icon: String
}

enum InsightCategory {
    case spending
    case savings
    case patterns
    case alerts
}

enum InsightImpact {
    case high
    case medium
    case low
}

enum TimeGranularity {
    case weekly
    case monthly
    case annual
    
    var days: Int {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        case .annual: return 365
        }
    }
    
    var displayName: String {
        switch self {
        case .weekly: return "Week"
        case .monthly: return "Month"
        case .annual: return "Year"
        }
    }
}

class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Analytics Generation
    func generateAnalytics(
        receipts: [Receipt],
        granularity: TimeGranularity,
        compareWithPrevious: Bool = true
    ) -> SpendingAnalytics {
        let totalSpent = receipts.reduce(0) { $0 + $1.totalAmount }
        let transactionCount = receipts.count
        let averagePerTransaction = transactionCount > 0 ? totalSpent / Double(transactionCount) : 0
        
        // Category breakdown
        var categoryBreakdown: [ExpenseCategory: Double] = [:]
        for receipt in receipts {
            let category = receipt.categoryEnum
            categoryBreakdown[category, default: 0] += receipt.totalAmount
        }
        
        // Top categories
        let topCategories = categoryBreakdown
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { (category: $0.key, amount: $0.value) }
        
        // Comparison with previous period
        var comparisonToPrevious: Double = 0
        if compareWithPrevious {
            let currentPeriodEnd = Date()
            let currentPeriodStart = Calendar.current.date(
                byAdding: .day,
                value: -granularity.days,
                to: currentPeriodEnd
            ) ?? currentPeriodEnd
            
            let previousPeriodEnd = currentPeriodStart
            let previousPeriodStart = Calendar.current.date(
                byAdding: .day,
                value: -granularity.days,
                to: previousPeriodEnd
            ) ?? previousPeriodEnd
            
            let previousReceipts = receipts.filter {
                $0.date >= previousPeriodStart && $0.date < previousPeriodEnd
            }
            let previousTotal = previousReceipts.reduce(0) { $0 + $1.totalAmount }
            
            if previousTotal > 0 {
                comparisonToPrevious = ((totalSpent - previousTotal) / previousTotal) * 100
            }
        }
        
        return SpendingAnalytics(
            totalSpent: totalSpent,
            averagePerTransaction: averagePerTransaction,
            categoryBreakdown: categoryBreakdown,
            topCategories: topCategories,
            transactionCount: transactionCount,
            comparisonToPrevious: comparisonToPrevious
        )
    }
    
    // MARK: - Insights Generation
    func generateInsights(
        receipts: [Receipt],
        analytics: SpendingAnalytics,
        granularity: TimeGranularity
    ) -> [SpendingInsight] {
        var insights: [SpendingInsight] = []
        
        // 1. High spending alert
        if analytics.comparisonToPrevious > 20 {
            insights.append(SpendingInsight(
                title: "Spending Increase Alert",
                description: "Your spending increased by \(String(format: "%.1f", analytics.comparisonToPrevious))% compared to the previous \(granularity.displayName.lowercased()).",
                category: .alerts,
                impact: .high,
                recommendation: "Review your recent purchases and identify areas where you can cut back.",
                icon: "exclamationmark.triangle.fill"
            ))
        }
        
        // 2. Top category spending
        if let topCategory = analytics.topCategories.first {
            let percentage = (topCategory.amount / analytics.totalSpent) * 100
            insights.append(SpendingInsight(
                title: "Top Spending Category",
                description: "\(topCategory.category.rawValue) accounts for \(String(format: "%.0f", percentage))% of your spending.",
                category: .patterns,
                impact: .medium,
                recommendation: "Consider setting a budget limit for this category.",
                icon: topCategory.category.icon
            ))
        }
        
        // 3. Average transaction analysis
        let avgThreshold = 50.0
        if analytics.averagePerTransaction > avgThreshold {
            insights.append(SpendingInsight(
                title: "High Average Transaction",
                description: "Your average transaction is $\(String(format: "%.2f", analytics.averagePerTransaction)).",
                category: .spending,
                impact: .medium,
                recommendation: "Look for opportunities to reduce costs on larger purchases.",
                icon: "dollarsign.circle.fill"
            ))
        }
        
        // 4. Frequent small purchases
        let smallPurchases = receipts.filter { $0.totalAmount < 10 }.count
        if Double(smallPurchases) / Double(receipts.count) > 0.3 {
            let totalSmall = receipts.filter { $0.totalAmount < 10 }.reduce(0) { $0 + $1.totalAmount }
            insights.append(SpendingInsight(
                title: "Small Purchases Add Up",
                description: "You made \(smallPurchases) small purchases totaling $\(String(format: "%.2f", totalSmall)).",
                category: .patterns,
                impact: .medium,
                recommendation: "Track these small expenses carefully - they can accumulate quickly.",
                icon: "cart.fill"
            ))
        }
        
        // 5. Category-specific insights
        insights.append(contentsOf: generateCategoryInsights(analytics: analytics))
        
        // 6. Positive reinforcement
        if analytics.comparisonToPrevious < -10 {
            insights.append(SpendingInsight(
                title: "Great Job!",
                description: "You reduced spending by \(String(format: "%.1f", abs(analytics.comparisonToPrevious)))% this \(granularity.displayName.lowercased()).",
                category: .savings,
                impact: .high,
                recommendation: "Keep up the good work! Consider what changes helped you save.",
                icon: "star.fill"
            ))
        }
        
        return insights
    }
    
    private func generateCategoryInsights(analytics: SpendingAnalytics) -> [SpendingInsight] {
        var insights: [SpendingInsight] = []
        
        // Food & Dining insights
        if let foodSpending = analytics.categoryBreakdown[.food],
           foodSpending > 300 {
            insights.append(SpendingInsight(
                title: "Dining Out Frequently",
                description: "You spent $\(String(format: "%.2f", foodSpending)) on food and dining.",
                category: .spending,
                impact: .medium,
                recommendation: "Meal prep at home can save up to 40% on food costs.",
                icon: "fork.knife"
            ))
        }
        
        // Entertainment insights
        if let entertainmentSpending = analytics.categoryBreakdown[.entertainment],
           entertainmentSpending / analytics.totalSpent > 0.15 {
            insights.append(SpendingInsight(
                title: "Entertainment Budget",
                description: "Entertainment expenses are high this period.",
                category: .spending,
                impact: .low,
                recommendation: "Look for free or low-cost entertainment alternatives.",
                icon: "tv.fill"
            ))
        }
        
        return insights
    }
    
    // MARK: - Data for Charts
    func getSpendingTrend(
        receipts: [Receipt],
        granularity: TimeGranularity
    ) -> [(date: Date, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -granularity.days, to: now) ?? now
        
        // Group receipts by day
        var dailySpending: [Date: Double] = [:]
        
        for receipt in receipts where receipt.date >= startDate {
            let day = calendar.startOfDay(for: receipt.date)
            dailySpending[day, default: 0] += receipt.totalAmount
        }
        
        return dailySpending
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, amount: $0.value) }
    }
    
    func getCategoryChartData(
        analytics: SpendingAnalytics
    ) -> [(category: ExpenseCategory, amount: Double, percentage: Double)] {
        analytics.categoryBreakdown
            .sorted { $0.value > $1.value }
            .map { (
                category: $0.key,
                amount: $0.value,
                percentage: (($0.value / analytics.totalSpent) * 100)
            )}
    }
}

