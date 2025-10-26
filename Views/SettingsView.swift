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
                // MARK: - OCR Engine Section
                Section {
                    Picker("OCR Engine", selection: $settings.preferredOCREngine) {
                        ForEach(AppSettings.OCREngine.allCases) { engine in
                            HStack {
                                Image(systemName: engine.icon)
                                    .frame(width: 24)
                                Text(engine.displayName)
                            }
                            .tag(engine as AppSettings.OCREngine?)
                        }
                    }
                    
                    if let engine = settings.preferredOCREngine {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: engine.icon)
                                    .foregroundColor(.blue)
                                Text(engine.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                if engine.requiresServer {
                                    Image(systemName: "server.rack")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                            }
                            
                            Text(engine.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if engine.requiresServer {
                                Text("Requires running server: ./start_\(engine.rawValue.lowercased().replacingOccurrences(of: "-", with: "_")).sh")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("OCR Engine")
                } footer: {
                    Text("Choose which OCR engine to use for scanning receipts. 'Auto' will automatically select the best available engine.")
                }
                
                // MARK: - Server URLs Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        ServerURLField(
                            title: "DeepSeek-OCR",
                            url: $settings.deepseekServerURL,
                            defaultURL: "http://localhost:5003",
                            icon: "brain.head.profile"
                        )
                        
                        ServerURLField(
                            title: "OlmOCR",
                            url: $settings.olmocrServerURL,
                            defaultURL: "http://localhost:5002",
                            icon: "doc.text.image"
                        )
                        
                        ServerURLField(
                            title: "EasyOCR",
                            url: $settings.easyocrServerURL,
                            defaultURL: "http://localhost:5001",
                            icon: "globe"
                        )
                        
                        ServerURLField(
                            title: "PaddleOCR",
                            url: $settings.paddleocrServerURL,
                            defaultURL: "http://localhost:5000",
                            icon: "text.viewfinder"
                        )
                    }
                } header: {
                    Text("Server URLs")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Configure server URLs for OCR engines. Use localhost for local servers or remote URLs for cloud-hosted servers.")
                        Text("💡 Tip: For remote GPU hosting, see REMOTE_GPU_SETUP.md")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
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

// MARK: - Helper Views

struct ServerURLField: View {
    let title: String
    @Binding var url: String
    let defaultURL: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if url != defaultURL {
                    Button(action: { url = defaultURL }) {
                        Text("Reset")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            TextField("Server URL", text: $url)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }
}

#Preview {
    SettingsView()
}

