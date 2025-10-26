//
//  SettingsView.swift
//  ReceiptTracker
//
//  Settings and configuration view
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - DeepSeek-OCR Server Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("DeepSeek-OCR Server")
                                .font(.headline)
                        }
                        
                        Text("State-of-the-art document understanding model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Server URL", text: $settings.deepseekServerURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if settings.deepseekServerURL != "http://localhost:5003" {
                            Button(action: { 
                                settings.deepseekServerURL = "http://localhost:5003" 
                            }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset to Default")
                                }
                                .font(.caption)
                                .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("OCR Server")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Configure your DeepSeek-OCR server URL.")
                        Text("• For local: http://localhost:5003")
                            .font(.caption2)
                        Text("• For RunPod: https://your-pod-id-5003.proxy.runpod.net")
                            .font(.caption2)
                        Text("• For remote: https://your-server.com:5003")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                
                // MARK: - About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("OCR Engine")
                        Spacer()
                        Text("DeepSeek-OCR")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Powered by DeepSeek-OCR for best-in-class document understanding.")
                        .font(.caption)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
