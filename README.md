# PDF Enterprise Suite

A comprehensive PDF management application for iOS, Android, and Web built with Flutter.

## Features

### Core Features
- 📖 **PDF Viewer** - Fast, smooth PDF viewing with zoom and navigation
- ✂️ **Split PDF** - Split documents by page range or chunk size
- 🔗 **Merge PDF** - Combine multiple PDFs into one document
- 🔄 **Rotate/Reorder** - Rotate and rearrange pages
- 🗜️ **Compress PDF** - Reduce file size with quality preservation
- 🔒 **Lock/Encrypt** - Password protect PDFs with AES-256
- 💧 **Watermark** - Add text or image watermarks
- ✍️ **Digital Signature** - Sign documents with custom signatures
- 📝 **Annotations** - Highlight, text, drawing, and stamp annotations
- 🔍 **OCR** - Convert scanned documents to searchable text

### Cloud & Sync
- ☁️ **Google Drive** - Sync with Google Drive
- 📱 **iCloud** - Sync across Apple devices
- 🔗 **Share & Export** - Share via apps or generate links

### Subscription
- 🆓 **Free Tier** - Basic features with limits
- 💎 **Pro Tier** - Unlimited features without ads

## Project Structure

```
lib/
├── core/
│   ├── router/          # App routing configuration
│   ├── theme/           # App theme and styling
│   ├── providers/       # Global providers
│   └── services/        # Core services (Hive, etc.)
├── features/
│   ├── auth/            # Authentication feature
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── dashboard/       # Dashboard feature
│   ├── pdf_viewer/      # PDF viewing
│   ├── pdf_editor/      # PDF editing operations
│   ├── subscription/    # Subscription management
│   └── settings/        # App settings
└── main.dart
```

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Dart SDK 3.0+
- Android Studio / VS Code
- Xcode (for iOS development)

### Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/pdf-enterprise-suite.git
cd pdf-enterprise-suite
```

2. Install dependencies
```bash
flutter pub get
```

3. Generate code (for Hive adapters, etc.)
```bash
flutter packages pub run build_runner build
```

4. Configure environment
- Copy `.env.dev` to `.env` for development
- Add your Firebase configuration
- Add RevenueCat API keys

5. Run the app
```bash
flutter run
```

## Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Navigation**: go_router
- **Local Storage**: Hive
- **PDF Rendering**: pdfx, syncfusion_flutter_pdfviewer
- **PDF Editing**: syncfusion_flutter_pdf
- **OCR**: google_mlkit_text_recognition
- **Authentication**: Firebase Auth
- **Database**: Cloud Firestore
- **Storage**: Firebase Storage
- **In-App Purchase**: RevenueCat

## Configuration

### Firebase Setup
1. Create a Firebase project
2. Add iOS, Android, and Web apps
3. Enable Authentication (Email, Google, Apple)
4. Create Firestore database
5. Enable Cloud Storage
6. Download configuration files:
   - iOS: `GoogleService-Info.plist`
   - Android: `google-services.json`
   - Web: Add config to `.env`

### RevenueCat Setup
1. Create RevenueCat account
2. Create app and configure products
3. Add subscription products in App Store Connect and Google Play Console
4. Copy API keys to `.env`

## Build & Deploy

### Build for Production

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## License

This project is proprietary software. All rights reserved.

## Support

For support, email support@pdfenterprisesuite.com
