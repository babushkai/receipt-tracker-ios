# Quick Start - Receipt Tracker

## 🚀 5-Minute Setup

I've opened Xcode for you. Follow these steps to get the app running:

### Step 1: Create the Xcode Project (2 minutes)

1. In Xcode, click **"Create New Project"** (or File → New → Project)
2. Select **iOS** → **App** → **Next**
3. Fill in:
   - **Product Name**: `ReceiptTracker`
   - **Team**: Select your team (or leave as "None" for simulator only)
   - **Organization Identifier**: `com.yourname.receipttracker`
   - **Interface**: `SwiftUI` ✓
   - **Language**: `Swift` ✓
   - **Storage**: `Core Data` ✓ ← **IMPORTANT! Check this box!**
4. **Save Location**: Choose `/Users/dsuke/Projects/dev/receipt/ReceiptTracker`
5. Click **Create**

### Step 2: Replace the Files (1 minute)

The project will create some default files. Let's replace them with our code:

1. **Delete these default files** in Xcode (Right-click → Delete → Move to Trash):
   - `ContentView.swift` (we'll use our version)
   - The `.xcdatamodeld` file (we'll use our version)

2. **Add our files**:
   - Drag ALL the files from `/Users/dsuke/Projects/dev/receipt/` into the Xcode project
   - When prompted, select:
     - ✓ Copy items if needed
     - ✓ Create groups
     - ✓ Add to target: ReceiptTracker

### Step 3: Configure Info.plist (30 seconds)

1. Click on `Info.plist` in Xcode
2. The privacy descriptions should already be there (we created them)
3. If not, add:
   - **Privacy - Camera Usage Description**
   - **Privacy - Photo Library Usage Description**

### Step 4: Build and Run! (1 minute)

1. Select **iPhone 15 Pro** (or any simulator) from the device menu
2. Press **⌘ + R** (or click the Play button)
3. Wait for it to build...
4. The app will launch! 🎉

## ✅ What You'll See

The app will open with 5 tabs:
- **Dashboard**: Spending overview with charts
- **Receipts**: List of all receipts  
- **Add (+)**: Take photos or upload receipts
- **Insights**: Financial recommendations
- **Settings**: App configuration

## 📸 Testing the App

1. **Tap the "+" tab**
2. **Choose "Take Photo"** or **"Choose from Library"**
3. If using simulator, you can drag an image file onto the simulator
4. The OCR will process the receipt (this uses Apple Vision framework)
5. Edit the detected fields
6. **Tap "Save Receipt"**
7. View it in the Dashboard and Receipts tabs!

## 💡 Quick Tips

- **Use a real device** for best OCR results (camera works better than simulator)
- **Good lighting** makes OCR more accurate
- **Sample receipts**: Take a photo of any receipt to test
- The app stores everything locally - no internet required!

## 🐛 If Something Goes Wrong

### Error: "No such module 'CoreData'"
- Make sure you checked **"Core Data"** when creating the project
- Clean Build Folder: Shift + ⌘ + K, then rebuild

### Error: Files not found
- Make sure you dragged all files into the Xcode project
- Check that files are in the correct groups (Models, Views, etc.)

### Camera doesn't work
- Grant camera permission when prompted
- Camera only works on real devices, not simulator
- For simulator, use "Choose from Library" instead

### Build errors
- Check the error message
- Often it's a missing file or incorrect target membership
- Try: Clean Build Folder (Shift + ⌘ + K) then rebuild

## 🎯 Next Steps

Once you have it running:

1. **Add some receipts** to see the analytics
2. **Check out the Insights** tab (needs a few receipts first)
3. **Explore the code** - it's well-commented!
4. **Customize categories** in `Models/Receipt.swift`
5. **Add LLM integration** following `LLM_INTEGRATION_GUIDE.md`

## 📁 Project Structure After Setup

```
ReceiptTracker/
├── ReceiptTracker.xcodeproj     ← Xcode project file
└── ReceiptTracker/              ← App source
    ├── ReceiptTrackerApp.swift
    ├── Models/
    ├── Views/
    ├── ViewModels/
    ├── Services/
    ├── Utilities/
    ├── Assets.xcassets
    └── Info.plist
```

## 🎬 Ready to Start?

1. Xcode should already be open
2. Follow Step 1 above to create the project
3. You'll be running the app in 5 minutes!

---

**Need help?** Check `README.md` for detailed documentation or `SETUP_GUIDE.md` for troubleshooting.

