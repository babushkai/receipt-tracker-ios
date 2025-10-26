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
    private let deepseekServerURLKey = "deepseekServerURL"
    
    // Published properties
    @Published var deepseekServerURL: String {
        didSet {
            defaults.set(deepseekServerURL, forKey: deepseekServerURLKey)
        }
    }
    
    private init() {
        // Server URL - defaults to localhost
        self.deepseekServerURL = defaults.string(forKey: deepseekServerURLKey) ?? "http://localhost:5003"
    }
}
