# Receipt Tracker - iOS Financial Management App

A comprehensive iOS application built with SwiftUI for tracking expenses through receipt scanning and providing intelligent financial insights.

## 🌟 Features

### 📸 Receipt Capture & OCR
- **Camera Integration**: Take photos of receipts directly in-app
- **Photo Library Support**: Import existing receipt images
- **Advanced OCR**: Uses Apple's Vision framework for text recognition
- **Smart Parsing**: Automatically extracts:
  - Merchant name
  - Date
  - Total amount
  - Line items with quantities and prices
  - Receipt details

### 💰 Expense Tracking
- **Multiple Categories**: 11 predefined expense categories including:
  - Food & Dining
  - Groceries
  - Transportation
  - Utilities
  - Entertainment
  - Shopping
  - Healthcare
  - Education
  - Travel
  - Housing
  - Other

### 📊 Analytics & Insights
- **Time-Based Views**: 
  - Weekly spending overview
  - Monthly analysis
  - Annual trends
- **Interactive Charts**: 
  - Spending trends over time
  - Category breakdown
  - Comparative analysis
- **Smart Insights**: AI-powered recommendations including:
  - High spending alerts
  - Category-specific insights
  - Small purchase accumulation warnings
  - Positive reinforcement for savings
  - Personalized recommendations

### 🎯 Dashboard
- Real-time spending summary
- Transaction count and averages
- Comparison with previous periods
- Visual trend charts
- Recent transactions list
- Category distribution

### 📋 Receipt Management
- Complete receipt history
- Advanced filtering by:
  - Category
  - Date range
  - Custom criteria
- Detailed receipt view with images
- Swipe-to-delete functionality
- Search and sort options

### ⚙️ Settings & Privacy
- Customizable currency support (USD, EUR, GBP, JPY)
- Monthly budget setting
- Notification preferences
- Data export (CSV, JSON)
- Complete data deletion option
- Privacy-focused design

## 🏗️ Architecture

### Technology Stack
- **Framework**: SwiftUI
- **Minimum iOS Version**: iOS 16.0+
- **Language**: Swift 5.9+
- **Persistence**: Core Data
- **OCR**: Vision Framework
- **Charts**: Swift Charts

### Project Structure
```
receipt/
├── ReceiptTrackerApp.swift          # App entry point
├── Models/
│   ├── Receipt.swift                # Data models
│   └── ReceiptDataModel.xcdatamodeld # Core Data schema
├── Views/
│   ├── ContentView.swift            # Main tab view
│   ├── DashboardView.swift          # Dashboard with analytics
│   ├── AddReceiptView.swift         # Receipt capture view
│   ├── ReceiptsListView.swift       # Receipt list with filters
│   ├── ReceiptDetailView.swift      # Detailed receipt view
│   ├── InsightsView.swift           # Financial insights
│   └── SettingsView.swift           # App settings
├── ViewModels/
│   ├── DashboardViewModel.swift     # Dashboard logic
│   ├── AddReceiptViewModel.swift    # Receipt processing logic
│   ├── ReceiptsListViewModel.swift  # List management
│   └── InsightsViewModel.swift      # Insights generation
├── Services/
│   ├── PersistenceController.swift  # Core Data management
│   ├── OCRService.swift             # OCR processing
│   └── AnalyticsService.swift       # Analytics engine
├── Utilities/
│   └── ImagePicker.swift            # Camera/photo picker wrapper
└── Info.plist                       # App configuration
```

### Design Patterns
- **MVVM**: Model-View-ViewModel architecture
- **Singleton**: Services (OCR, Analytics, Persistence)
- **Repository Pattern**: Data access through PersistenceController
- **Dependency Injection**: Environment objects and @StateObject

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 16.0+ device or simulator
- Apple Developer account (for device testing)

### Installation

1. **Clone or navigate to the project directory**:
```bash
cd /Users/dsuke/Projects/dev/receipt
```

2. **Open in Xcode**:
```bash
open -a Xcode .
```

3. **Create a new Xcode project**:
   - File → New → Project
   - Choose "App" template
   - Product Name: "ReceiptTracker"
   - Organization Identifier: "com.yourcompany.receipttracker"
   - Interface: SwiftUI
   - Language: Swift
   - Storage: Core Data
   - Copy all the files into your project

4. **Configure the project**:
   - Set deployment target to iOS 16.0+
   - Add required frameworks:
     - Vision.framework
     - CoreData.framework
     - Charts (built-in with iOS 16+)

5. **Build and run**:
   - Select your target device or simulator
   - Press Cmd+R to build and run

### Required Permissions

The app requires the following permissions (already configured in Info.plist):
- **Camera Access**: To take photos of receipts
- **Photo Library Access**: To import existing receipt images

## 💡 Usage Guide

### Adding a Receipt
1. Tap the "+" tab at the bottom
2. Choose "Take Photo" or "Choose from Library"
3. Capture or select your receipt image
4. Review the automatically extracted information
5. Edit any fields as needed
6. Select the appropriate category
7. Add optional notes
8. Tap "Save Receipt"

### Viewing Insights
1. Navigate to the "Insights" tab
2. Review personalized recommendations
3. Each insight includes:
   - Impact level (High/Medium/Low)
   - Detailed description
   - Actionable recommendations

### Filtering Receipts
1. Go to "Receipts" tab
2. Tap the filter icon (top right)
3. Select category and/or date range
4. Tap "Done" to apply filters
5. Clear filters by tapping "Clear All Filters"

### Exporting Data
1. Go to "Settings" tab
2. Tap "Export Data"
3. Choose format (CSV or JSON)
4. Share via any supported method

## 🔧 Customization

### Adding New Categories
Edit `ExpenseCategory` enum in `Models/Receipt.swift`:
```swift
case newCategory = "New Category"
```

Add icon and color:
```swift
var icon: String {
    case .newCategory: return "icon.name"
}

var color: String {
    case .newCategory: return "colorName"
}
```

### Modifying Insights Logic
Edit `AnalyticsService.swift` in the `generateInsights` method to add custom insights logic.

### LLM Integration
To integrate with OpenAI or other LLM providers:
1. Add API key to your configuration
2. Implement the `enhanceWithLLM` method in `OCRService.swift`
3. Create API client for your chosen provider

Example OpenAI integration:
```swift
func enhanceWithLLM(ocrResult: OCRResult, apiKey: String) async throws -> OCRResult {
    // Configure OpenAI API request
    // Send receipt text for enhanced parsing
    // Parse JSON response
    // Return enhanced OCR result
}
```

## 🔐 Privacy & Security

- **Local Storage**: All data stored locally using Core Data
- **No Cloud Sync**: Complete privacy by default
- **Image Storage**: Receipt images stored securely in app sandbox
- **Data Export**: User has full control over their data
- **Deletion**: Complete data removal option available

## 🎨 UI/UX Features

- **Modern Design**: Clean, iOS-native interface
- **Dark Mode**: Full support for dark mode
- **Animations**: Smooth transitions and interactions
- **Accessibility**: VoiceOver support
- **Responsive**: Works on all iPhone and iPad sizes
- **Pull-to-Refresh**: Update data with pull gesture

## 🐛 Known Limitations

1. **OCR Accuracy**: Recognition quality depends on:
   - Image quality and lighting
   - Receipt clarity and format
   - Language (optimized for English)

2. **Currency**: Currently supports major currencies but exchange rates not included

3. **Backup**: No automatic backup (consider implementing iCloud sync)

4. **Multi-User**: Single user per device

## 🔄 Future Enhancements

- [ ] iCloud sync for cross-device access
- [ ] Budget tracking with alerts
- [ ] Recurring expense detection
- [ ] Tax category tagging
- [ ] Receipt sharing
- [ ] Multi-currency conversion
- [ ] Widget support
- [ ] Apple Watch companion app
- [ ] Siri Shortcuts integration
- [ ] Advanced ML for better categorization

## 📱 System Requirements

- iOS 16.0 or later
- iPhone or iPad
- Camera (for photo capture)
- ~50MB storage space

## 📄 License

This project is provided as-is for educational and personal use.

## 🤝 Contributing

This is a personal project, but suggestions and improvements are welcome!

## 📞 Support

For issues or questions:
1. Check the documentation above
2. Review the code comments
3. Test on a real device (OCR works better than simulator)

## 🙏 Acknowledgments

- Apple Vision framework for OCR capabilities
- SwiftUI and Swift Charts for modern UI
- Core Data for reliable data persistence

---

**Built with ❤️ using Swift and SwiftUI**

