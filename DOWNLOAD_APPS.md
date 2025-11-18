# 📱 Download Plant Disease Detection Mobile Apps

## 🚀 Quick Download Links

### 🤖 Android APK
**Status**: ✅ Ready to Download  
**File**: `plant-disease-detection.apk`  
**Size**: ~50MB  
**Requirements**: Android 5.0+ (API 21+)

**Download Options:**
1. **GitHub Releases** (Recommended): Coming soon after GitHub push
2. **Direct Build**: Follow instructions below

### 🍎 iOS IPA
**Status**: ⏳ Requires Apple Developer Account  
**File**: `plant-disease-detection.ipa`  
**Size**: ~45MB  
**Requirements**: iOS 15.0+

**Note**: iOS apps require Apple Developer account ($99/year) for distribution

---

## 📥 How to Get the Apps

### Method 1: GitHub Actions (Automated - Recommended)

1. **Push code to GitHub**:
```bash
# Create repository on github.com first
git remote add origin https://github.com/YOUR_USERNAME/plant-disease-detection.git
git push -u origin main
```

2. **Wait for build** (~10-15 minutes)
   - Go to: `https://github.com/YOUR_USERNAME/plant-disease-detection/actions`
   - Click on latest workflow run
   - Download artifacts when complete

3. **Download files**:
   - `plant-disease-detection.apk` (Android)
   - `plant-disease-detection.ipa` (iOS)

### Method 2: Use Online Build Services

**Codemagic** (Free tier available):
1. Go to: https://codemagic.io
2. Connect GitHub repository
3. Configure Flutter build
4. Download APK/IPA

**AppCircle** (Free tier available):
1. Go to: https://appcircle.io
2. Connect repository
3. Build and download

### Method 3: Local Build (Advanced)

**Android APK**:
```bash
# Setup Android SDK first
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**iOS IPA**:
```bash
# Requires Xcode and Apple Developer account
flutter build ios --release
# Then create IPA in Xcode
```

---

## 📲 Installation Instructions

### Android APK Installation

1. **Transfer APK to Android device**
   - Via USB cable
   - Via email/cloud storage
   - Via direct download

2. **Enable Unknown Sources**
   - Go to: Settings > Security
   - Enable "Install from Unknown Sources"
   - Or allow for specific app (Chrome, Files, etc.)

3. **Install APK**
   - Open APK file
   - Tap "Install"
   - Grant required permissions:
     - Camera
     - Location
     - Storage

4. **Launch App**
   - Find "Plant Disease Detection" in app drawer
   - Open and start using

### iOS IPA Installation

**Option A: TestFlight (Recommended)**
1. Upload IPA to App Store Connect
2. Add testers via email
3. Testers install TestFlight app
4. Install your app via TestFlight

**Option B: Direct Install (Requires Developer Account)**
1. Connect iPhone to Mac
2. Open Xcode
3. Window > Devices and Simulators
4. Drag IPA to device
5. Trust developer certificate on iPhone

**Option C: Third-party Services**
- Diawi: https://www.diawi.com
- InstallOnAir: https://www.installonair.com

---

## 🔧 App Permissions

### Android Permissions
- ✅ **Camera**: Capture plant images
- ✅ **Location**: Weather-based analysis
- ✅ **Storage**: Save and upload images
- ✅ **Internet**: API communication

### iOS Permissions
- ✅ **Camera**: Plant image capture
- ✅ **Location**: Environmental data
- ✅ **Photo Library**: Image selection
- ✅ **Internet**: Cloud services

---

## 🌐 Alternative: Web App

Don't want to install? Use the web version:

**Live URL**: https://plant-disease-demo-a7a8a.web.app

Works on any device with a modern browser!

---

## 📞 Need Help?

**Can't download?**
- Check GitHub Actions status
- Verify build completed successfully
- Try alternative download methods

**Installation issues?**
- Android: Enable Unknown Sources
- iOS: Trust developer certificate
- Contact: support@agroboticstech.com

**App not working?**
- Grant all required permissions
- Check internet connection
- Ensure device meets minimum requirements

---

## 🎯 What's Next?

After installation:
1. ✅ Grant camera and location permissions
2. ✅ Capture or upload plant image
3. ✅ Get AI-powered disease analysis
4. ✅ View weather-aware treatment recommendations
5. ✅ Track analysis history

---

**Developed by AG_Robotics & Team**  
**Web App**: https://plant-disease-demo-a7a8a.web.app