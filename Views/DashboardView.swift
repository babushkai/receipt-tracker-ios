//
//  DashboardView.swift
//  ReceiptTracker
//
//  Main dashboard with spending overview
//

import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedGranularity: TimeGranularity = .monthly
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time granularity picker
                    Picker("Time Period", selection: $selectedGranularity) {
                        Text("Week").tag(TimeGranularity.weekly)
                        Text("Month").tag(TimeGranularity.monthly)
                        Text("Year").tag(TimeGranularity.annual)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedGranularity) { newValue in
                        viewModel.updateGranularity(newValue)
                    }
                    
                    // Total spending card
                    SpendingSummaryCard(analytics: viewModel.analytics)
                        .padding(.horizontal)
                    
                    // Spending trend chart
                    if !viewModel.trendData.isEmpty {
                        SpendingTrendChart(data: viewModel.trendData, granularity: selectedGranularity)
                            .frame(height: 200)
                            .padding(.horizontal)
                    }
                    
                    // Category breakdown
                    if !viewModel.categoryData.isEmpty {
                        CategoryBreakdownView(data: viewModel.categoryData)
                            .padding(.horizontal)
                    }
                    
                    // Recent transactions
                    RecentTransactionsSection(receipts: viewModel.recentReceipts)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .onAppear {
                viewModel.loadData()
                withAnimation(.easeIn(duration: 0.3)) {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Summary Card
struct SpendingSummaryCard: View {
    let analytics: SpendingAnalytics?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Spending")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(String(format: "$%.2f", analytics?.totalSpent ?? 0))
                        .font(.system(size: 36, weight: .bold))
                }
                Spacer()
                
                if let comparison = analytics?.comparisonToPrevious, comparison != 0 {
                    ComparisonBadge(percentage: comparison)
                }
            }
            
            Divider()
            
            HStack {
                StatItem(
                    title: "Transactions",
                    value: "\(analytics?.transactionCount ?? 0)"
                )
                Spacer()
                StatItem(
                    title: "Average",
                    value: String(format: "$%.2f", analytics?.averagePerTransaction ?? 0)
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

struct ComparisonBadge: View {
    let percentage: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: percentage > 0 ? "arrow.up" : "arrow.down")
                .font(.caption2)
            Text(String(format: "%.1f%%", abs(percentage)))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(percentage > 0 ? .red : .green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(percentage > 0 ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Spending Trend Chart
struct SpendingTrendChart: View {
    let data: [(date: Date, amount: Double)]
    let granularity: TimeGranularity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spending Trend")
                .font(.headline)
            
            Chart {
                ForEach(data, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(Color.blue.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Category Breakdown
struct CategoryBreakdownView: View {
    let data: [(category: ExpenseCategory, amount: Double, percentage: Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)
            
            ForEach(data.prefix(5), id: \.category) { item in
                CategoryRow(
                    category: item.category,
                    amount: item.amount,
                    percentage: item.percentage
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct CategoryRow: View {
    let category: ExpenseCategory
    let amount: Double
    let percentage: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundColor(categoryColor)
                .frame(width: 32, height: 32)
                .background(categoryColor.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(categoryColor)
                            .frame(width: geometry.size.width * (percentage / 100), height: 4)
                    }
                }
                .frame(height: 4)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "$%.2f", amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(String(format: "%.0f%%", percentage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var categoryColor: Color {
        switch category.color {
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

// MARK: - Recent Transactions
struct RecentTransactionsSection: View {
    let receipts: [Receipt]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: ReceiptsListView()) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if receipts.isEmpty {
                Text("No transactions yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(receipts.prefix(5)) { receipt in
                    TransactionRow(receipt: receipt)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct TransactionRow: View {
    let receipt: Receipt
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: receipt.categoryEnum.icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.merchantName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(receipt.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "$%.2f", receipt.totalAmount))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DashboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

