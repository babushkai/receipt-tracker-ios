//
//  SettingsView.swift
//  ReceiptTracker
//
//  Settings and preferences view
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultCurrency") private var defaultCurrency = "USD"
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("monthlyBudget") private var monthlyBudget = 1000.0
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // General Settings
                Section(header: Text("General")) {
                    Picker("Default Currency", selection: $defaultCurrency) {
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("GBP").tag("GBP")
                        Text("JPY").tag("JPY")
                    }
                    
                    HStack {
                        Text("Monthly Budget")
                        Spacer()
                        TextField("Budget", value: $monthlyBudget, format: .currency(code: defaultCurrency))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Notifications
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .tint(.blue)
                }
                
                // Data & Privacy
                Section(header: Text("Data & Privacy")) {
                    NavigationLink(destination: ExportDataView()) {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                // About
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com")!) {
                        Label("GitHub Repository", systemImage: "link")
                    }
                    
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Delete All Data", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This action cannot be undone. All your receipts and data will be permanently deleted.")
            }
        }
    }
    
    private func deleteAllData() {
        let receipts = PersistenceController.shared.fetchReceipts()
        for receipt in receipts {
            PersistenceController.shared.deleteReceipt(receipt)
        }
    }
}

// MARK: - Export Data View
struct ExportDataView: View {
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        List {
            Section(header: Text("Export Format")) {
                Button(action: { exportData(format: .csv) }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Export as CSV")
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
                
                Button(action: { exportData(format: .json) }) {
                    HStack {
                        Image(systemName: "doc.plaintext")
                        Text("Export as JSON")
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Section {
                Text("Export includes all receipts, transactions, and associated data.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    enum ExportFormat {
        case csv
        case json
    }
    
    private func exportData(format: ExportFormat) {
        let receipts = PersistenceController.shared.fetchReceipts()
        
        let content: String
        let fileExtension: String
        
        switch format {
        case .csv:
            content = generateCSV(receipts: receipts)
            fileExtension = "csv"
        case .json:
            content = generateJSON(receipts: receipts)
            fileExtension = "json"
        }
        
        // Save to temporary file
        let fileName = "receipts_export_\(Date().timeIntervalSince1970).\(fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showingShareSheet = true
        } catch {
            print("Error exporting data: \(error)")
        }
    }
    
    private func generateCSV(receipts: [Receipt]) -> String {
        var csv = "Date,Merchant,Amount,Category,Notes\n"
        
        for receipt in receipts {
            let date = ISO8601DateFormatter().string(from: receipt.date)
            let merchant = receipt.merchantName ?? "Unknown"
            let amount = String(format: "%.2f", receipt.totalAmount)
            let category = receipt.categoryEnum.rawValue
            let notes = receipt.notes?.replacingOccurrences(of: "\n", with: " ") ?? ""
            
            csv += "\(date),\(merchant),\(amount),\(category),\(notes)\n"
        }
        
        return csv
    }
    
    private func generateJSON(receipts: [Receipt]) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let exportData = receipts.map { receipt in
            [
                "id": receipt.id.uuidString,
                "date": ISO8601DateFormatter().string(from: receipt.date),
                "merchant": receipt.merchantName ?? "Unknown",
                "amount": receipt.totalAmount,
                "category": receipt.categoryEnum.rawValue,
                "notes": receipt.notes ?? ""
            ] as [String : Any]
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "[]"
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
}

