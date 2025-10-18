# Setup Guide - Receipt Tracker iOS App

This guide will walk you through setting up the Receipt Tracker app in Xcode.

## 📋 Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- iOS 16.0+ device or simulator
- Basic knowledge of Swift and Xcode

## 🛠️ Setup Steps

### Step 1: Create New Xcode Project

1. Open Xcode
2. Select **File → New → Project**
3. Choose **iOS** → **App**
4. Configure your project:
   - **Product Name**: `ReceiptTracker`
   - **Team**: Select your development team
   - **Organization Identifier**: `com.yourname.receipttracker` (or your preferred identifier)
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - **Storage**: `Core Data` ✓ (Check this!)
   - **Include Tests**: Optional
5. Choose save location (suggest: `/Users/dsuke/Projects/dev/receipt`)
6. Click **Create**

### Step 2: Organize Project Structure

1. In Xcode's Project Navigator, create the following groups (folders):
   - Right-click on project → **New Group**
   - Create these groups:
     - `Models`
     - `Views`
     - `ViewModels`
     - `Services`
     - `Utilities`

### Step 3: Add Files to Project

#### Delete Default Files
1. Delete the default ContentView.swift (we'll replace it)
2. Delete the default Core Data model file (we'll replace it)

#### Add Model Files
1. Drag `Receipt.swift` into the `Models` group
2. Replace the default `.xcdatamodeld` file:
   - Delete the existing data model
   - Create new: **File → New → File → Core Data → Data Model**
   - Name it `ReceiptDataModel`
   - Open the visual editor and manually add entities, or
   - Replace the contents file with the provided XML

#### Add Service Files
Drag these files into the `Services` group:
- `PersistenceController.swift`
- `OCRService.swift`
- `AnalyticsService.swift`

#### Add View Files
Drag these files into the `Views` group:
- `ContentView.swift`
- `DashboardView.swift`
- `AddReceiptView.swift`
- `ReceiptsListView.swift`
- `ReceiptDetailView.swift`
- `InsightsView.swift`
- `SettingsView.swift`

#### Add ViewModel Files
Drag these files into the `ViewModels` group:
- `DashboardViewModel.swift`
- `AddReceiptViewModel.swift`
- `ReceiptsListViewModel.swift`
- `InsightsViewModel.swift`

#### Add Utility Files
Drag these files into the `Utilities` group:
- `ImagePicker.swift`

#### Replace App Entry Point
1. Replace the content of `ReceiptTrackerApp.swift` with the provided version
2. Make sure it's in the root of your project

### Step 4: Configure Core Data

1. Open `ReceiptDataModel.xcdatamodeld`
2. In the visual editor:

**Create Receipt Entity:**
- Click "+" to add entity, name it `Receipt`
- Add attributes:
  - `id` (UUID)
  - `date` (Date)
  - `merchantName` (String, Optional)
  - `totalAmount` (Double)
  - `category` (String, Optional)
  - `imageData` (Binary Data, Optional, Allow External Storage ✓)
  - `notes` (String, Optional)
  - `currency` (String, Default: "USD")
  - `createdAt` (Date)
  - `updatedAt` (Date)

**Create ReceiptItem Entity:**
- Add another entity, name it `ReceiptItem`
- Add attributes:
  - `id` (UUID)
  - `name` (String)
  - `price` (Double)
  - `quantity` (Integer 16)
  - `order` (Integer 16)

**Create Relationships:**
- In Receipt entity:
  - Add relationship `items` → Destination: `ReceiptItem`, To Many ✓, Delete Rule: Cascade
- In ReceiptItem entity:
  - Add relationship `receipt` → Destination: `Receipt`, Delete Rule: Nullify

### Step 5: Configure Info.plist

1. Open `Info.plist`
2. Add these privacy descriptions (or merge with existing):
   - **Privacy - Camera Usage Description**: 
     "We need access to your camera to take photos of receipts for expense tracking."
   - **Privacy - Photo Library Usage Description**: 
     "We need access to your photo library to select receipt images for expense tracking."
   - **Privacy - Photo Library Additions Usage Description**: 
     "We need permission to save receipt images to your photo library."

### Step 6: Update PersistenceController Reference

In `PersistenceController.swift`, verify the Core Data model name matches:
```swift
container = NSPersistentContainer(name: "ReceiptDataModel")
```

### Step 7: Build Settings

1. Select your project in the Navigator
2. Select your target
3. Under **General** tab:
   - Set **Minimum Deployments** to iOS 16.0
4. Under **Signing & Capabilities**:
   - Select your development team
   - Ensure automatic signing is enabled

### Step 8: Test Build

1. Select a simulator or connected device
2. Press **Cmd + B** to build
3. Fix any errors:
   - Check file paths
   - Verify all files are added to target
   - Check for typos in imports

### Step 9: Run the App

1. Press **Cmd + R** to run
2. Grant camera/photo library permissions when prompted
3. Test basic functionality:
   - View dashboard
   - Add a receipt
   - Check insights

## 🐛 Common Issues and Solutions

### Issue: "No such module 'CoreData'"
**Solution**: Ensure your project has Core Data selected in project settings.

### Issue: Core Data entities not found
**Solution**: 
1. Clean build folder (Cmd + Shift + K)
2. Rebuild (Cmd + B)
3. Check that the data model file is in the project target

### Issue: Camera not available in simulator
**Solution**: Test camera functionality on a real device. Simulator has limited camera support.

### Issue: "Cannot find 'PersistenceController' in scope"
**Solution**: 
1. Check that PersistenceController.swift is added to the target
2. Check file's Target Membership in File Inspector

### Issue: Charts not rendering
**Solution**: Charts require iOS 16+. Check deployment target.

### Issue: Preview crashes
**Solution**: 
1. Ensure preview uses preview persistence controller
2. Check that @Published properties are initialized
3. Try restarting Xcode

## 📱 Testing Checklist

- [ ] App launches without crashes
- [ ] Dashboard displays correctly
- [ ] Can access camera (on device)
- [ ] Can select from photo library
- [ ] OCR processes receipt image
- [ ] Can edit and save receipt
- [ ] Receipt appears in list
- [ ] Can filter receipts
- [ ] Can view receipt details
- [ ] Insights generate correctly
- [ ] Settings can be modified
- [ ] Can export data
- [ ] Dark mode works correctly

## 🚀 Next Steps

1. **Customize**: Modify categories, colors, and branding
2. **Enhance OCR**: Integrate with OpenAI or other LLM services
3. **Add Features**: Implement budget tracking, recurring expenses
4. **Cloud Sync**: Add iCloud support for backup
5. **Localization**: Add support for multiple languages
6. **Testing**: Add unit tests and UI tests

## 📚 Additional Resources

- [Apple Core Data Documentation](https://developer.apple.com/documentation/coredata)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Vision Framework Guide](https://developer.apple.com/documentation/vision)
- [Swift Charts Documentation](https://developer.apple.com/documentation/charts)

## 💡 Tips

- **Use Real Device**: OCR works much better on real devices
- **Good Lighting**: Take receipt photos in good lighting for best OCR results
- **Test Edge Cases**: Try various receipt formats and layouts
- **Backup Data**: During development, regularly export data
- **Version Control**: Use git to track changes

## 🆘 Need Help?

If you encounter issues:
1. Check error messages in Xcode console
2. Review this guide step-by-step
3. Verify all files are properly added to target
4. Clean and rebuild project
5. Restart Xcode if needed

---

**Happy Coding! 🎉**

