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
    private let ocrEngineKey = "ocrEngine"
    private let deepseekServerURLKey = "deepseekServerURL"
    private let easyocrServerURLKey = "easyocrServerURL"
    private let paddleocrServerURLKey = "paddleocrServerURL"
    private let olmocrServerURLKey = "olmocrServerURL"
    
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
    
    @Published var preferredOCREngine: OCREngine? {
        didSet {
            if let engine = preferredOCREngine {
                defaults.set(engine.rawValue, forKey: ocrEngineKey)
            } else {
                defaults.removeObject(forKey: ocrEngineKey)
            }
        }
    }
    
    @Published var deepseekServerURL: String {
        didSet {
            defaults.set(deepseekServerURL, forKey: deepseekServerURLKey)
        }
    }
    
    @Published var easyocrServerURL: String {
        didSet {
            defaults.set(easyocrServerURL, forKey: easyocrServerURLKey)
        }
    }
    
    @Published var paddleocrServerURL: String {
        didSet {
            defaults.set(paddleocrServerURL, forKey: paddleocrServerURLKey)
        }
    }
    
    @Published var olmocrServerURL: String {
        didSet {
            defaults.set(olmocrServerURL, forKey: olmocrServerURLKey)
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
    
    enum OCREngine: String, CaseIterable, Identifiable {
        case auto = "Auto"
        case deepseek = "DeepSeek-OCR"
        case olmocr = "OlmOCR"
        case easyocr = "EasyOCR"
        case paddleocr = "PaddleOCR"
        case tesseract = "Tesseract"
        
        var id: String { rawValue }
        
        var displayName: String {
            return rawValue
        }
        
        var description: String {
            switch self {
            case .auto:
                return "Automatically selects best available engine"
            case .deepseek:
                return "State-of-the-art document understanding. Requires GPU. Free."
            case .olmocr:
                return "7B model specialized for documents. Requires server. Free."
            case .easyocr:
                return "80+ languages support. Requires server. Free."
            case .paddleocr:
                return "Fast & accurate Chinese/Japanese. Requires server. Free."
            case .tesseract:
                return "Built-in, always available. Fast. Free."
            }
        }
        
        var requiresServer: Bool {
            switch self {
            case .auto, .tesseract:
                return false
            case .deepseek, .olmocr, .easyocr, .paddleocr:
                return true
            }
        }
        
        var icon: String {
            switch self {
            case .auto: return "wand.and.stars"
            case .deepseek: return "brain.head.profile"
            case .olmocr: return "doc.text.image"
            case .easyocr: return "globe"
            case .paddleocr: return "text.viewfinder"
            case .tesseract: return "textformat"
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
        
        // OCR Engine - defaults to auto
        if let engineString = defaults.string(forKey: ocrEngineKey),
           let engine = OCREngine(rawValue: engineString) {
            self.preferredOCREngine = engine
        } else {
            self.preferredOCREngine = .auto
        }
        
        // Server URLs - defaults to localhost
        self.deepseekServerURL = defaults.string(forKey: deepseekServerURLKey) ?? "http://localhost:5003"
        self.easyocrServerURL = defaults.string(forKey: easyocrServerURLKey) ?? "http://localhost:5001"
        self.paddleocrServerURL = defaults.string(forKey: paddleocrServerURLKey) ?? "http://localhost:5000"
        self.olmocrServerURL = defaults.string(forKey: olmocrServerURLKey) ?? "http://localhost:5002"
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

