//
//  SettingsView.swift
//  ReceiptTracker
//
//  Settings and configuration view
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var showAPIKeyInfo = false
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - LLM Enhancement Section
                Section {
                    Toggle(isOn: $settings.isLLMEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enhanced OCR")
                                .font(.headline)
                            Text("Use AI to improve receipt scanning accuracy")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if settings.isLLMEnabled {
                        // Provider picker
                        Picker("AI Provider", selection: $settings.llmProvider) {
                            ForEach(AppSettings.LLMProvider.allCases) { provider in
                                VStack(alignment: .leading) {
                                    Text(provider.displayName)
                                    Text(provider.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(provider)
                            }
                        }
                        
                        // API Key input
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("API Key")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: { showAPIKeyInfo = true }) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            SecureField("Enter your API key", text: $settings.llmAPIKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            
                            if !settings.llmAPIKey.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("API key configured")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                } header: {
                    Text("AI Enhancement")
                } footer: {
                    if settings.isLLMEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI processing happens after image scanning for maximum accuracy.")
                            Text(settings.llmProvider.description)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Uses only Apple's Vision framework. Fast and free, but less accurate for complex receipts.")
                    }
                }
                
                // MARK: - About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                        HStack {
                            Text("Get OpenAI API Key")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    
                    Link(destination: URL(string: "https://console.anthropic.com/")!) {
                        HStack {
                            Text("Get Anthropic API Key")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .alert("API Key Information", isPresented: $showAPIKeyInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("""
                Your API key is stored securely on your device and never shared.
                
                To get an API key:
                • OpenAI: Visit platform.openai.com/api-keys
                • Anthropic: Visit console.anthropic.com
                
                Costs are very low (~$0.0001-0.0003 per receipt).
                """)
            }
        }
    }
}

#Preview {
    SettingsView()
}

