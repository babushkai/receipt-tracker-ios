// iOS Swift Client for OCR Gateway API
// Add this to your iOS app to securely call the OCR service

import Foundation
import UIKit

/// OCR API Client - Secure connection to your backend gateway
class OCRClient {
    
    // MARK: - Configuration
    
    /// Your backend gateway URL (NOT the OCR server directly!)
    private let baseURL = "https://your-backend.com" // Change this to your domain
    
    /// API Key - Store securely! Use Keychain in production
    private let apiKey = "ios_app_key_123xyz" // Get from your secure storage
    
    // MARK: - Models
    
    struct OCRRequest: Codable {
        let image: String  // URL or base64
        let prompt: String?
    }
    
    struct BatchOCRRequest: Codable {
        let images: [String]
        let prompt: String?
    }
    
    struct OCRResponse: Codable {
        let success: Bool
        let text: String?
        let error: String?
        let usage: Usage?
        
        struct Usage: Codable {
            let requestsUsed: Int
            let dailyLimit: Int
            let tier: String
            
            enum CodingKeys: String, CodingKey {
                case requestsUsed = "requests_used"
                case dailyLimit = "daily_limit"
                case tier
            }
        }
    }
    
    struct BatchOCRResponse: Codable {
        let success: Bool
        let results: [Result]?
        let total: Int?
        let successful: Int?
        let error: String?
        let usage: OCRResponse.Usage?
        
        struct Result: Codable {
            let success: Bool
            let text: String?
            let length: Int?
            let error: String?
        }
    }
    
    // MARK: - Single Image OCR
    
    /// Perform OCR on a single image
    /// - Parameters:
    ///   - imageURL: URL of the image to process
    ///   - prompt: Optional custom prompt (default: "Extract all text.")
    ///   - completion: Completion handler with result
    func performOCR(imageURL: URL, 
                    prompt: String? = nil,
                    completion: @escaping (Result<OCRResponse, Error>) -> Void) {
        
        let request = OCRRequest(
            image: imageURL.absoluteString,
            prompt: prompt ?? "Extract all text from this document."
        )
        
        makeRequest(endpoint: "/api/v1/ocr", body: request, completion: completion)
    }
    
    /// Perform OCR on a local image
    /// - Parameters:
    ///   - image: UIImage to process
    ///   - prompt: Optional custom prompt
    ///   - completion: Completion handler with result
    func performOCR(image: UIImage,
                    prompt: String? = nil,
                    completion: @escaping (Result<OCRResponse, Error>) -> Void) {
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8),
              let base64String = imageData.base64EncodedString() as String? else {
            completion(.failure(NSError(domain: "OCRClient", code: -1, 
                                       userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])))
            return
        }
        
        let request = OCRRequest(
            image: base64String,
            prompt: prompt ?? "Extract all text from this document."
        )
        
        makeRequest(endpoint: "/api/v1/ocr", body: request, completion: completion)
    }
    
    // MARK: - Batch OCR
    
    /// Perform OCR on multiple images
    /// - Parameters:
    ///   - imageURLs: Array of image URLs
    ///   - prompt: Optional custom prompt
    ///   - completion: Completion handler with results
    func performBatchOCR(imageURLs: [URL],
                        prompt: String? = nil,
                        completion: @escaping (Result<BatchOCRResponse, Error>) -> Void) {
        
        let request = BatchOCRRequest(
            images: imageURLs.map { $0.absoluteString },
            prompt: prompt
        )
        
        makeRequest(endpoint: "/api/v1/ocr/batch", body: request, completion: completion)
    }
    
    // MARK: - Usage Stats
    
    struct UsageResponse: Codable {
        let success: Bool
        let usage: Usage?
        let error: String?
        
        struct Usage: Codable {
            let user: String
            let tier: String
            let requestsUsed: Int
            let dailyLimit: Int
            let requestsRemaining: Int
            
            enum CodingKeys: String, CodingKey {
                case user, tier
                case requestsUsed = "requests_used"
                case dailyLimit = "daily_limit"
                case requestsRemaining = "requests_remaining"
            }
        }
    }
    
    /// Get current usage statistics
    func getUsage(completion: @escaping (Result<UsageResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/v1/usage") else {
            completion(.failure(NSError(domain: "OCRClient", code: -1,
                                       userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "OCRClient", code: -1,
                                           userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let result = try JSONDecoder().decode(UsageResponse.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Private Helper Methods
    
    private func makeRequest<Request: Encodable, Response: Decodable>(
        endpoint: String,
        body: Request,
        completion: @escaping (Result<Response, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(NSError(domain: "OCRClient", code: -1,
                                       userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "OCRClient", code: -1,
                                           userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let result = try JSONDecoder().decode(Response.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - Usage Example

/*
// In your ViewController:

let ocrClient = OCRClient()

// Example 1: OCR from URL
let imageURL = URL(string: "https://example.com/receipt.jpg")!
ocrClient.performOCR(imageURL: imageURL) { result in
    DispatchQueue.main.async {
        switch result {
        case .success(let response):
            if response.success, let text = response.text {
                print("Extracted text: \(text)")
                print("Usage: \(response.usage?.requestsUsed ?? 0)/\(response.usage?.dailyLimit ?? 0)")
            } else {
                print("Error: \(response.error ?? "Unknown error")")
            }
        case .failure(let error):
            print("Network error: \(error.localizedDescription)")
        }
    }
}

// Example 2: OCR from UIImage (e.g., from camera or photo library)
if let image = UIImage(named: "receipt") {
    ocrClient.performOCR(image: image) { result in
        DispatchQueue.main.async {
            switch result {
            case .success(let response):
                if response.success, let text = response.text {
                    self.resultTextView.text = text
                }
            case .failure(let error):
                self.showAlert(error.localizedDescription)
            }
        }
    }
}

// Example 3: Batch OCR
let urls = [
    URL(string: "https://example.com/receipt1.jpg")!,
    URL(string: "https://example.com/receipt2.jpg")!
]
ocrClient.performBatchOCR(imageURLs: urls) { result in
    DispatchQueue.main.async {
        switch result {
        case .success(let response):
            if response.success, let results = response.results {
                for (index, result) in results.enumerated() {
                    print("Image \(index + 1): \(result.text ?? "No text")")
                }
            }
        case .failure(let error):
            print("Error: \(error)")
        }
    }
}

// Example 4: Check usage
ocrClient.getUsage { result in
    switch result {
    case .success(let response):
        if let usage = response.usage {
            print("Tier: \(usage.tier)")
            print("Used: \(usage.requestsUsed)/\(usage.dailyLimit)")
            print("Remaining: \(usage.requestsRemaining)")
        }
    case .failure(let error):
        print("Error: \(error)")
    }
}
*/

