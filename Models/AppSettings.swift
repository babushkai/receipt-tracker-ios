//
//  AppSettings.swift
//  ReceiptTracker
//
//  App-wide settings storage
//

import Foundation

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private let llmEnabledKey = "llmEnabled"
    private let llmProviderKey = "llmProvider"
    private let llmAPIKeyKey = "llmAPIKey"
    
    // Published properties
    @Published var isLLMEnabled: Bool {
        didSet {
            defaults.set(isLLMEnabled, forKey: llmEnabledKey)
        }
    }
    
    @Published var llmProvider: LLMProvider {
        didSet {
            defaults.set(llmProvider.rawValue, forKey: llmProviderKey)
        }
    }
    
    @Published var llmAPIKey: String {
        didSet {
            defaults.set(llmAPIKey, forKey: llmAPIKeyKey)
        }
    }
    
    enum LLMProvider: String, CaseIterable, Identifiable {
        case openAI = "OpenAI"
        case anthropic = "Anthropic"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .openAI: return "OpenAI (GPT-4o-mini)"
            case .anthropic: return "Anthropic (Claude Haiku)"
            }
        }
        
        var description: String {
            switch self {
            case .openAI: return "Fast & affordable. ~$0.0001 per receipt."
            case .anthropic: return "Fast & accurate. ~$0.0003 per receipt."
            }
        }
    }
    
    private init() {
        // LLM is disabled by default - Tesseract is free and works great!
        self.isLLMEnabled = false
        
        if let providerString = defaults.string(forKey: llmProviderKey),
           let provider = LLMProvider(rawValue: providerString) {
            self.llmProvider = provider
        } else {
            self.llmProvider = .openAI
        }
        
        self.llmAPIKey = defaults.string(forKey: llmAPIKeyKey) ?? ""
    }
    
    // Get LLM config
    func getLLMConfig() -> LLMConfig? {
        guard isLLMEnabled, !llmAPIKey.isEmpty else {
            return nil
        }
        
        switch llmProvider {
        case .openAI:
            return LLMConfig(
                apiKey: llmAPIKey,
                apiEndpoint: "https://api.openai.com/v1/chat/completions",
                model: "gpt-4o-mini"
            )
        case .anthropic:
            return LLMConfig(
                apiKey: llmAPIKey,
                apiEndpoint: "https://api.anthropic.com/v1/messages",
                model: "claude-sonnet-4-5-20250929"
            )
        }
    }
}

