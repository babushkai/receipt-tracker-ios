//
//  InsightsView.swift
//  ReceiptTracker
//
//  Financial insights and recommendations view
//

import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.insights.isEmpty {
                        EmptyInsightsView()
                    } else {
                        // Insights header
                        InsightsHeaderView(count: viewModel.insights.count)
                            .padding(.horizontal)
                        
                        // Insights list
                        ForEach(viewModel.insights) { insight in
                            InsightCard(insight: insight)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Insights")
            .refreshable {
                viewModel.loadInsights()
            }
            .onAppear {
                viewModel.loadInsights()
            }
        }
    }
}

// MARK: - Empty State
struct EmptyInsightsView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                    .rotationEffect(.degrees(isAnimating ? 5 : -5))
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            }
            
            Text("No Insights Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Add more receipts to get personalized\nfinancial insights and recommendations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("💡 Tip: Add at least 5 receipts to see insights")
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 8)
        }
        .padding(.top, 100)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Insights Header
struct InsightsHeaderView: View {
    let count: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Financial Insights")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("We've analyzed your spending and found \(count) insights to help you manage your finances better.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    let insight: SpendingInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: insight.icon)
                    .font(.title2)
                    .foregroundColor(impactColor)
                    .frame(width: 44, height: 44)
                    .background(impactColor.opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.headline)
                    
                    Text(categoryText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ImpactBadge(impact: insight.impact)
            }
            
            // Description
            Text(insight.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Recommendation
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Text(insight.recommendation)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var impactColor: Color {
        switch insight.impact {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
    
    private var categoryText: String {
        switch insight.category {
        case .spending: return "Spending Pattern"
        case .savings: return "Savings Opportunity"
        case .patterns: return "Behavioral Insight"
        case .alerts: return "Alert"
        }
    }
}

// MARK: - Impact Badge
struct ImpactBadge: View {
    let impact: InsightImpact
    
    var body: some View {
        Text(impactText)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(impactColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(impactColor.opacity(0.1))
            .cornerRadius(6)
    }
    
    private var impactText: String {
        switch impact {
        case .high: return "HIGH"
        case .medium: return "MEDIUM"
        case .low: return "LOW"
        }
    }
    
    private var impactColor: Color {
        switch impact {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

#Preview {
    InsightsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

