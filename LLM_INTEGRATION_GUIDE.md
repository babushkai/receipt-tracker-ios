# LLM Integration Guide

This guide explains how to integrate Large Language Models (LLMs) to enhance OCR accuracy and receipt parsing.

## 🤖 Supported LLM Providers

- **OpenAI** (GPT-4, GPT-4o, GPT-4o-mini)
- **Anthropic Claude** (Claude 3 Haiku, Sonnet, Opus)
- Any **OpenAI-compatible API** (LocalAI, LM Studio, Ollama with openai compatibility)

## 🚀 Quick Start

### Option 1: OpenAI Integration

1. **Get API Key**:
   - Sign up at [OpenAI Platform](https://platform.openai.com/)
   - Create an API key
   - Add credits to your account

2. **Add API Key to Project**:
```swift
// In your view or service
let config = LLMConfig(
    apiKey: "sk-your-api-key-here",
    apiEndpoint: "https://api.openai.com/v1/chat/completions",
    model: "gpt-4o-mini"  // Most cost-effective
)
```

3. **Use Enhanced OCR**:
```swift
// In AddReceiptViewModel
let result = try await ocrService.processReceiptWithLLM(
    image: image,
    llmConfig: config
)
```

### Option 2: Anthropic Claude

1. **Get API Key**:
   - Sign up at [Anthropic Console](https://console.anthropic.com/)
   - Create an API key

2. **Configure**:
```swift
let config = LLMConfig(
    apiKey: "sk-ant-your-api-key-here",
    apiEndpoint: "https://api.anthropic.com/v1/messages",
    model: "claude-3-haiku-20240307"
)
```

### Option 3: Local LLM (Free!)

Use a local model with OpenAI-compatible API:

1. **Install Ollama**:
```bash
brew install ollama
ollama serve
ollama pull llama3.2
```

2. **Configure**:
```swift
let config = LLMConfig(
    apiKey: "not-needed",
    apiEndpoint: "http://localhost:11434/v1/chat/completions",
    model: "llama3.2"
)
```

## 📝 Implementation Steps

### Step 1: Secure API Key Storage

**Option A: Environment Variables (Recommended for Development)**

Create `Config.swift`:
```swift
import Foundation

struct Config {
    static var openAIKey: String {
        // Read from environment variable
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    }
    
    static var anthropicKey: String {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    }
}
```

Add to Xcode scheme:
1. Product → Scheme → Edit Scheme
2. Run → Arguments → Environment Variables
3. Add: `OPENAI_API_KEY` = `your-key-here`

**Option B: Secure Keychain Storage (Recommended for Production)**

```swift
import Security

class KeychainService {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }
}
```

### Step 2: Update AddReceiptViewModel

```swift
class AddReceiptViewModel: ObservableObject {
    @Published var useLLM: Bool = true // Toggle for LLM enhancement
    
    func processImage() {
        guard let image = selectedImage else { return }
        isProcessing = true
        
        Task { @MainActor in
            do {
                let result: OCRResult
                
                if useLLM && !Config.openAIKey.isEmpty {
                    // Use LLM-enhanced OCR
                    let config = LLMConfig.openAI
                    result = try await ocrService.processReceiptWithLLM(
                        image: image,
                        llmConfig: config
                    )
                } else {
                    // Use standard Vision OCR
                    result = try await ocrService.processReceipt(image: image)
                }
                
                // Convert to editable receipt...
                processedReceipt = EditableReceipt(...)
                isProcessing = false
            } catch {
                isProcessing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
```

### Step 3: Add LLM Toggle to Settings

```swift
// In SettingsView.swift
Section(header: Text("OCR Settings")) {
    Toggle("Use AI Enhancement", isOn: $useAIEnhancement)
        .onChange(of: useAIEnhancement) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "useAIEnhancement")
        }
    
    if useAIEnhancement {
        Picker("AI Provider", selection: $aiProvider) {
            Text("OpenAI").tag("openai")
            Text("Anthropic Claude").tag("anthropic")
            Text("Local (Ollama)").tag("local")
        }
        
        if aiProvider != "local" {
            SecureField("API Key", text: $apiKey)
                .textContentType(.password)
        }
    }
}
```

## 💰 Cost Considerations

### OpenAI Pricing (as of 2024)
- **GPT-4o-mini**: $0.15 / 1M input tokens, $0.60 / 1M output tokens
  - Average receipt: ~500 tokens input, ~200 tokens output
  - Cost per receipt: ~$0.0002 (2 cents per 100 receipts)
- **GPT-4o**: $2.50 / 1M input tokens, $10.00 / 1M output tokens
  - Cost per receipt: ~$0.003

### Anthropic Pricing
- **Claude 3 Haiku**: $0.25 / 1M input tokens, $1.25 / 1M output tokens
  - Cost per receipt: ~$0.0004
- **Claude 3.5 Sonnet**: $3.00 / 1M input tokens, $15.00 / 1M output tokens
  - Cost per receipt: ~$0.004

### Recommendation
- For personal use: **GPT-4o-mini** or **Local Ollama** (free)
- For production: **GPT-4o-mini** for best cost/performance balance
- For maximum accuracy: **GPT-4o** or **Claude 3.5 Sonnet**

## 🎯 Benefits of LLM Enhancement

### Accuracy Improvements
- **Merchant Name**: Better extraction even with poor print quality
- **Date Parsing**: Handles various date formats internationally
- **Amount Detection**: Distinguishes between subtotal, tax, and total
- **Item Extraction**: Better parsing of line items
- **Category Detection**: AI suggests appropriate expense category
- **Currency Recognition**: Identifies currency from symbols and context

### Additional Features
- **Tax Calculation**: Extracts tax amounts separately
- **Payment Method**: Identifies how payment was made
- **Tip Detection**: Recognizes tips on restaurant receipts
- **Multi-language**: Works with receipts in various languages
- **Error Correction**: Fixes common OCR mistakes

## 🔧 Advanced Configuration

### Custom Prompts

Modify the prompt in `LLMService.swift` to customize parsing:

```swift
private func buildPrompt(rawText: String) -> String {
    return """
    Parse this receipt and extract:
    1. Store name
    2. Date (ISO format)
    3. Total amount
    4. Tax amount
    5. Each item with quantity and price
    6. Expense category (Food, Transport, etc.)
    7. Payment method
    
    Additional rules:
    - If total is unclear, calculate from items + tax
    - Categorize restaurant receipts as "Food & Dining"
    - For gas stations, check if items include food vs just fuel
    
    Receipt:
    \(rawText)
    
    Return valid JSON only.
    """
}
```

### Rate Limiting

Add rate limiting to avoid API quota issues:

```swift
class RateLimiter {
    private var lastCallTime: Date?
    private let minimumInterval: TimeInterval = 1.0 // 1 second between calls
    
    func waitIfNeeded() async {
        if let lastCall = lastCallTime {
            let elapsed = Date().timeIntervalSince(lastCall)
            if elapsed < minimumInterval {
                try? await Task.sleep(nanoseconds: UInt64((minimumInterval - elapsed) * 1_000_000_000))
            }
        }
        lastCallTime = Date()
    }
}
```

### Caching

Cache LLM responses to avoid duplicate API calls:

```swift
class LLMCache {
    private var cache: [String: ParsedReceiptData] = [:]
    
    func get(for text: String) -> ParsedReceiptData? {
        let key = text.md5 // Implement MD5 hash
        return cache[key]
    }
    
    func set(_ data: ParsedReceiptData, for text: String) {
        let key = text.md5
        cache[key] = data
    }
}
```

## 🧪 Testing

### Test with Sample Receipts

Create test cases:

```swift
func testLLMParsing() async throws {
    let sampleReceipt = """
    WHOLE FOODS MARKET
    Date: 12/25/2024
    
    Organic Apples      $4.99
    Almond Milk         $3.49
    Bread               $2.99
    
    Subtotal           $11.47
    Tax                 $0.92
    Total              $12.39
    """
    
    let config = LLMConfig.openAI
    let result = try await LLMService.shared.enhanceOCR(
        rawText: sampleReceipt,
        config: config
    )
    
    XCTAssertEqual(result.merchantName, "Whole Foods Market")
    XCTAssertEqual(result.totalAmount, 12.39)
    XCTAssertEqual(result.items?.count, 3)
}
```

## 🔒 Security Best Practices

1. **Never commit API keys** to version control
2. **Use environment variables** or keychain for storage
3. **Implement request signing** for production
4. **Monitor API usage** to detect unauthorized access
5. **Rotate keys regularly**
6. **Use separate keys** for development and production

## 📊 Monitoring

Track LLM usage and costs:

```swift
class LLMAnalytics {
    static var totalRequests = 0
    static var totalTokensUsed = 0
    static var estimatedCost: Double {
        Double(totalTokensUsed) / 1_000_000.0 * 0.15 // GPT-4o-mini rate
    }
    
    static func logRequest(tokensUsed: Int) {
        totalRequests += 1
        totalTokensUsed += tokensUsed
        print("LLM Stats - Requests: \(totalRequests), Cost: $\(estimatedCost)")
    }
}
```

## 🚦 Fallback Strategy

Always have a fallback to Vision-only OCR:

```swift
func processWithFallback(image: UIImage) async throws -> OCRResult {
    do {
        // Try LLM first
        return try await processReceiptWithLLM(image: image, llmConfig: config)
    } catch {
        print("LLM failed, falling back to Vision: \(error)")
        // Fallback to standard OCR
        return try await processReceipt(image: image)
    }
}
```

## 📚 Resources

- [OpenAI API Documentation](https://platform.openai.com/docs)
- [Anthropic Claude API](https://docs.anthropic.com/)
- [Ollama Local Models](https://ollama.ai/)
- [LM Studio](https://lmstudio.ai/)

---

**Pro Tip**: Start with local models (Ollama) for development and testing, then switch to cloud APIs for production!

