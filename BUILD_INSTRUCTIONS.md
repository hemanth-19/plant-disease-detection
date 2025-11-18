# 📱 Mobile App Build Instructions

## 🚀 Easiest Method: GitHub Actions (Recommended)

Since you don't have Android SDK locally and iOS requires Apple Developer account, use GitHub Actions to build automatically in the cloud.

### Step 1: Push to GitHub

```bash
cd /Users/hemanth/flutter_application_1

# Add all files
git add .

# Commit
git commit -m "Initial commit - Plant Disease Detection App"

# Create GitHub repository and push
# Go to github.com and create new repository named "plant-disease-detection"
git remote add origin https://github.com/YOUR_USERNAME/plant-disease-detection.git
git branch -M main
git push -u origin main
```

### Step 2: Download Built Apps

1. Go to your GitHub repository
2. Click on "Actions" tab
3. Wait for build to complete (~10-15 minutes)
4. Download artifacts:
   - `plant-disease-detection.apk` (Android)
   - `plant-disease-detection.ipa` (iOS)

### Step 3: Install on Devices

**Android APK:**
1. Transfer APK to Android device
2. Enable "Install from Unknown Sources" in Settings
3. Open APK file and install

**iOS IPA:**
1. Requires Apple Developer account ($99/year)
2. Use Xcode to sign and install
3. Or use services like Diawi/TestFlight for distribution

---

## 🔧 Alternative: Local Build (Requires Setup)

### Android APK (Requires Android SDK)

**Install Android SDK:**
```bash
# Open Android Studio (already installed)
# Go to: Preferences > Appearance & Behavior > System Settings > Android SDK
# Install: Android SDK Platform 34, Android SDK Build-Tools 34

# Set environment variables
export ANDROID_HOME=~/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools

# Accept licenses
flutter doctor --android-licenses

# Build APK
flutter build apk --release
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

### iOS IPA (Requires Apple Developer Account)

**Setup:**
1. Open Xcode: `open ios/Runner.xcworkspace`
2. Sign in with Apple ID
3. Select Development Team
4. Set unique Bundle ID

**Build:**
```bash
flutter build ios --release
```

**Create IPA:**
1. Open Xcode
2. Product > Archive
3. Distribute App > Ad Hoc/App Store

---

## 📦 Quick Build Commands

```bash
# Web (Already deployed)
flutter build web
firebase deploy --only hosting

# Android APK
flutter build apk --release

# iOS (no codesign for testing)
flutter build ios --release --no-codesign

# iOS (with codesign for distribution)
flutter build ios --release
```

---

## 🌐 Current Deployment Status

✅ **Web App**: https://plant-disease-demo-a7a8a.web.app  
⏳ **Android APK**: Use GitHub Actions  
⏳ **iOS IPA**: Use GitHub Actions or Xcode

---

## 📞 Need Help?

**Android SDK Issues:**
- Install Android Studio
- Configure SDK in Preferences
- Run `flutter doctor` to verify

**iOS Code Signing Issues:**
- Need Apple Developer account ($99/year)
- Or use GitHub Actions for unsigned builds
- Or test on iOS Simulator

**GitHub Actions:**
- Builds automatically on push
- No local setup required
- Download from Actions artifacts