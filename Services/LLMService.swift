//
//  LLMService.swift
//  ReceiptTracker
//
//  Optional LLM service for enhanced OCR parsing
//  Supports OpenAI, Anthropic Claude, or any OpenAI-compatible API
//

import Foundation

struct LLMConfig {
    let apiKey: String
    let apiEndpoint: String
    let model: String
    
    static let openAI = LLMConfig(
        apiKey: "", // Add your API key here or load from environment
        apiEndpoint: "https://api.openai.com/v1/chat/completions",
        model: "gpt-4o-mini"
    )
    
    static let anthropic = LLMConfig(
        apiKey: "", // Add your API key here
        apiEndpoint: "https://api.anthropic.com/v1/messages",
        model: "claude-sonnet-4-5-20250929"
    )
}

struct ParsedReceiptData: Codable {
    let merchantName: String?
    let date: String? // ISO8601 format
    let totalAmount: Double?
    let currency: String?
    let category: String?
    let items: [ParsedItem]?
    let taxAmount: Double?
    let subtotal: Double?
    let paymentMethod: String?
    
    struct ParsedItem: Codable {
        let name: String
        let quantity: Int
        let price: Double
        let unitPrice: Double?
    }
}

class LLMService {
    static let shared = LLMService()
    
    private init() {}
    
    // MARK: - Main Method
    func enhanceOCR(rawText: String, config: LLMConfig) async throws -> ParsedReceiptData {
        print("\n🤖 ========== LLM ENHANCEMENT STARTED ==========")
        
        guard !config.apiKey.isEmpty else {
            print("❌ API Key is empty!")
            throw LLMError.missingAPIKey
        }
        
        print("📡 API Endpoint: \(config.apiEndpoint)")
        print("🤖 Model: \(config.model)")
        print("🔑 API Key: \(String(config.apiKey.prefix(8)))...")
        print("📝 Raw Text Length: \(rawText.count) characters")
        
        let prompt = buildPrompt(rawText: rawText)
        
        if config.apiEndpoint.contains("anthropic") {
            print("🧠 Using Anthropic Claude API")
            return try await callAnthropic(prompt: prompt, config: config)
        } else {
            print("🧠 Using OpenAI API")
            return try await callOpenAI(prompt: prompt, config: config)
        }
    }
    
    // MARK: - OpenAI Integration
    private func callOpenAI(prompt: String, config: LLMConfig) async throws -> ParsedReceiptData {
        guard let url = URL(string: config.apiEndpoint) else {
            throw LLMError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a receipt parsing assistant. Extract structured data from receipt text and return ONLY valid JSON."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.1,
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LLMError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse OpenAI response
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = openAIResponse.choices.first?.message.content else {
            throw LLMError.noContent
        }
        
        // Parse the JSON content
        guard let contentData = content.data(using: .utf8) else {
            throw LLMError.invalidJSON
        }
        
        return try JSONDecoder().decode(ParsedReceiptData.self, from: contentData)
    }
    
    // MARK: - Anthropic Integration
    private func callAnthropic(prompt: String, config: LLMConfig) async throws -> ParsedReceiptData {
        print("📤 Sending request to Anthropic API...")
        
        guard let url = URL(string: config.apiEndpoint) else {
            print("❌ Invalid URL: \(config.apiEndpoint)")
            throw LLMError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("⏳ Waiting for API response...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response")
            throw LLMError.invalidResponse
        }
        
        print("📥 Received response with status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            // Try to parse error message from response
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorDict["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("❌ API Error (\(httpResponse.statusCode)): \(message)")
            } else {
                print("❌ API Error: Status code \(httpResponse.statusCode)")
            }
            throw LLMError.apiError(statusCode: httpResponse.statusCode)
        }
        
        print("✅ API call successful, parsing response...")
        
        // Parse Anthropic response
        let anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let content = anthropicResponse.content.first?.text else {
            print("❌ No content in response")
            throw LLMError.noContent
        }
        
        print("📄 Received content (\(content.count) characters)")
        
        // Extract JSON from markdown code block if present
        let jsonContent = extractJSON(from: content)
        
        guard let contentData = jsonContent.data(using: .utf8) else {
            print("❌ Failed to convert content to data")
            throw LLMError.invalidJSON
        }
        
        print("🔍 Parsing structured receipt data...")
        print("📝 JSON to parse: \(jsonContent)")
        
        do {
            let parsedData = try JSONDecoder().decode(ParsedReceiptData.self, from: contentData)
            print("✅ Successfully parsed receipt data!")
            print("🏪 Merchant: \(parsedData.merchantName ?? "unknown")")
            print("💰 Total: $\(parsedData.totalAmount ?? 0)")
            print("🤖 ========== LLM ENHANCEMENT COMPLETE ==========\n")
            return parsedData
        } catch {
            print("❌ JSON parsing error: \(error)")
            print("📝 Failed to parse this JSON:")
            print(jsonContent)
            throw LLMError.invalidJSON
        }
    }
    
    // MARK: - Helper Methods
    private func buildPrompt(rawText: String) -> String {
        return """
        Parse the following receipt text and extract structured information.
        Return the result as a JSON object with the following structure:
        
        {
          "merchantName": "Store name",
          "date": "YYYY-MM-DD",
          "totalAmount": 0.00,
          "currency": "USD",
          "category": "One of: Food & Dining, Groceries, Transportation, Utilities, Entertainment, Shopping, Healthcare, Education, Travel, Housing, Other",
          "items": [
            {
              "name": "Item name",
              "quantity": 1,
              "price": 0.00,
              "unitPrice": 0.00
            }
          ],
          "taxAmount": 0.00,
          "subtotal": 0.00,
          "paymentMethod": "Cash/Card/etc"
        }
        
        Receipt text:
        \(rawText)
        
        Return ONLY the JSON object, no additional text or explanation.
        If a field cannot be determined, use null.
        """
    }
    
    private func extractJSON(from text: String) -> String {
        // Remove markdown code blocks if present
        let pattern = "```(?:json)?\\s*([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Response Models
private struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}

private struct AnthropicResponse: Codable {
    let content: [Content]
    
    struct Content: Codable {
        let text: String
    }
}

// MARK: - Errors
enum LLMError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case noContent
    case invalidJSON
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is missing. Please configure your LLM API key."
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let statusCode):
            return "API error with status code: \(statusCode)"
        case .noContent:
            return "No content in API response"
        case .invalidJSON:
            return "Could not parse JSON response"
        }
    }
}

// MARK: - Integration with OCRService
import UIKit

extension OCRService {
    func processReceiptWithLLM(image: UIImage, llmConfig: LLMConfig) async throws -> OCRResult {
        // Step 1: Extract text using Vision
        let extractedText = try await extractText(from: image)
        
        // Step 2: Enhance with LLM
        let llmResult = try await LLMService.shared.enhanceOCR(
            rawText: extractedText,
            config: llmConfig
        )
        
        // Step 3: Convert LLM result to OCRResult
        let date = parseDate(llmResult.date)
        let items: [ReceiptItemData] = (llmResult.items ?? []).map { item in
            ReceiptItemData(
                name: item.name,
                price: item.unitPrice ?? item.price,
                quantity: item.quantity
            )
        }
        
        // Determine category
        let category = determineCategory(llmResult.category)
        
        return OCRResult(
            merchantName: llmResult.merchantName,
            date: date,
            totalAmount: llmResult.totalAmount,
            items: items,
            rawText: extractedText,
            confidence: 0.95 // Higher confidence with LLM
        )
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    private func determineCategory(_ categoryString: String?) -> ExpenseCategory {
        guard let categoryString = categoryString else { return .other }
        return ExpenseCategory.allCases.first { $0.rawValue == categoryString } ?? .other
    }
}

