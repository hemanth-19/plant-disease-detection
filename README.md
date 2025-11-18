# Plant Disease Detection App
**Developed by AG_Robotics & Team**

## 📱 Mobile App Downloads

### 🤖 Android APK
- **Direct Download**: [Coming Soon - Build in Progress]
- **Requirements**: Android 5.0+ (API 21+)
- **Size**: ~50MB
- **Permissions**: Camera, Location, Storage

### 🍎 iOS App
- **App Store**: [Coming Soon - Under Review]
- **Requirements**: iOS 15.0+
- **Size**: ~45MB
- **Permissions**: Camera, Location, Photo Library

## 🌐 Web Application
**Live URL**: https://plant-disease-demo-a7a8a.web.app

## 🚀 Features
- **AI-Powered Disease Detection**: Real-time plant disease classification
- **Weather-Aware Analysis**: Environmental data integration
- **Camera & Upload**: Multiple image input methods
- **Cloud Storage**: Firebase-powered data management
- **Treatment Recommendations**: LLM-enhanced advisory system
- **Analysis History**: Complete tracking of all diagnoses

## 📋 How to Build Mobile Apps

### Prerequisites
- Flutter SDK 3.38.1+
- Android Studio (for Android builds)
- Xcode (for iOS builds)
- Firebase project setup

### Android Build
```bash
# Install dependencies
flutter pub get

# Build APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS Build
```bash
# Install dependencies
flutter pub get

# Build for iOS
flutter build ios --release --no-codesign

# For App Store: Use Xcode to archive and upload
```

### Automated Builds
This project includes GitHub Actions for automated building:
- Push to `main` branch triggers builds
- Download APK/IPA from Actions artifacts
- Supports both Android and iOS platforms

## 🛠️ Technical Stack
- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Firestore, Storage, Hosting)
- **AI/ML**: Custom disease classification API
- **Weather**: Open-Meteo API
- **Location**: Device GPS
- **Camera**: Native camera integration

## 📦 Dependencies
```yaml
dependencies:
  flutter: sdk
  firebase_core: ^4.2.1
  cloud_firestore: ^6.1.0
  camera: ^0.10.5+5
  image_picker: ^1.0.4
  geolocator: ^10.1.0
  permission_handler: ^11.0.1
  http: ^1.1.0
```

## 🔧 Setup Instructions

1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd flutter_application_1
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create Firebase project
   - Enable Firestore and Storage
   - Download configuration files
   - Update `firebase_options.dart`

4. **Run Application**
   ```bash
   # Web
   flutter run -d chrome
   
   # Android
   flutter run -d android
   
   # iOS
   flutter run -d ios
   ```

## 📱 App Permissions

### Android
- `CAMERA`: Image capture functionality
- `ACCESS_FINE_LOCATION`: Weather data and location tracking
- `READ_EXTERNAL_STORAGE`: Image upload from gallery
- `INTERNET`: API communication

### iOS
- `NSCameraUsageDescription`: Camera access for plant imaging
- `NSLocationWhenInUseUsageDescription`: Location for weather data
- `NSPhotoLibraryUsageDescription`: Photo library access

## 🌟 Key Features Detail

### AI Disease Detection
- **9 Disease Classes**: Including bacterial spot, early blight, late blight
- **Confidence Scoring**: Percentage-based reliability metrics
- **Severity Assessment**: Risk categorization (None/Low/Moderate/High)

### Weather Integration
- **Real-time Data**: Current temperature and humidity
- **Location-based**: GPS coordinate precision
- **Treatment Adaptation**: Climate-conscious recommendations

### Cloud Infrastructure
- **Real-time Sync**: Instant data synchronization
- **Scalable Storage**: Firebase cloud storage
- **Global CDN**: Worldwide content delivery

## 📊 Performance
- **Load Time**: <3 seconds initial load
- **Analysis Speed**: <5 seconds per image
- **Offline Support**: Basic functionality without internet
- **Cross-platform**: Web, Android, iOS compatibility

## 🔒 Security & Privacy
- **Data Encryption**: HTTPS/TLS communication
- **Firebase Security**: Server-side validation rules
- **Privacy-first**: Minimal data collection
- **User Control**: Data deletion capabilities

## 📞 Support
- **Technical Issues**: Create GitHub issue
- **Feature Requests**: Submit pull request
- **General Questions**: Contact development team

## 📄 License
This project is developed by AG_Robotics & Team for agricultural technology advancement.

---
**Live Application**: https://plant-disease-demo-a7a8a.web.app