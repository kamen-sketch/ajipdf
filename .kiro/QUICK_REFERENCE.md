# PDF Enterprise Suite - Quick Reference Guide

## 🚀 Build & Run

### Build for Web
```bash
flutter clean
flutter pub get
flutter build web --no-tree-shake-icons
```

### Run on Web (Dev)
```bash
flutter run -d chrome
```

### Run on Mobile
```bash
flutter run -d android    # Android emulator
flutter run -d ios        # iOS simulator
```

---

## 🧪 Testing

### Unit Tests
```bash
flutter test test/features/pdf_viewer/pdf_viewer_test.dart
```

### All Tests
```bash
flutter test
```

### Performance Test
```bash
flutter run -d chrome --profile
```

---

## 🐛 Common Issues & Fixes

### Issue: "PDF doesn't load in viewer"
**Cause**: Document provider returning null bytes  
**Fix**: Ensure file picker is setting `withData: true`

### Issue: "Annotations disappear when renaming PDF"
**Cause**: Old code keyed by document name (not ID)  
**Fix**: Now uses unique UUID per document - restart app

### Issue: "Split gives confusing error message"
**Cause**: Page count was 0 (PDF not loaded)  
**Fix**: New validation checks `_pageCount > 0` first

### Issue: "Can lock PDF with mismatched password"
**Cause**: No confirmation field  
**Fix**: Now requires password confirmation - must match

### Issue: "Search blocks UI"
**Cause**: SfPdfViewer.searchText() runs on main thread  
**Fix**: In progress - will use Isolate for mobile

---

## 📂 File Structure

```
lib/
├── core/
│   ├── providers/
│   │   ├── document_provider.dart       ← PDF document state
│   │   ├── annotation_provider.dart     ← Annotations storage
│   │   ├── subscription_provider.dart   ← Pro/Free gating
│   │   ├── auth_provider.dart
│   │   └── ...
│   ├── services/
│   │   ├── hive_service.dart           ← Local storage
│   │   └── ...
│   └── theme/
│       └── app_theme.dart
├── features/
│   ├── pdf_viewer/
│   │   └── presentation/
│   │       └── screens/
│   │           └── pdf_viewer_screen.dart ← MAIN VIEWER
│   ├── pdf_editor/
│   │   └── presentation/
│   │       └── screens/
│   │           ├── pdf_editor_screen.dart  ← Split/merge/compress/encrypt
│   │           └── rotate_reorder_screen.dart
│   ├── annotations/
│   ├── signature/
│   ├── ocr/
│   └── ...
└── main.dart
```

---

## 🎯 Feature Checklist

### Free Tier Features
- [x] View PDF (zoom, scroll, search)
- [x] Highlight text
- [x] Sticky notes
- [x] Split PDF (10/month limit)
- [x] Merge PDF (10/month limit)
- [x] Rotate/reorder pages
- [x] Share document
- [x] Dark mode

### Pro Tier Features
- [x] Underline text
- [x] Strikethrough text
- [x] Drawing annotation
- [x] Stamp annotation
- [x] Unlimited split/merge
- [x] Compress PDF (3 levels)
- [x] Encrypt PDF (AES-256)
- [x] Watermark (text/image)
- [x] Digital signature (draw/upload/text)

### Not Yet Implemented
- [ ] OCR (engine available, not in viewer UI)
- [ ] Thumbnails panel
- [ ] Fullscreen mode
- [ ] Bookmarks UI
- [ ] Google Drive sync
- [ ] iCloud sync
- [ ] Shareable links

---

## 🔑 Key Classes & Methods

### PdfDocumentInfo (document_provider.dart)
```dart
class PdfDocumentInfo {
  final String id;              // Unique UUID
  final String name;            // File name
  final String? path;           // File path (null on web)
  final Uint8List? bytes;       // File bytes
  final int size;               // File size in bytes
  final DateTime lastOpened;    // Access time
}
```

### AnnotationModel (annotation_provider.dart)
```dart
class AnnotationModel {
  final String id;              // Unique annotation ID
  final String documentId;      // Document UUID (NOT name!)
  final AnnotationType type;    // highlight, text, etc.
  final int pageIndex;          // 0-based page number
  final double x, y;            // Position on page
  final double width, height;   // Size
  final String? text;           // For text annotations
  final Color color;            // RGB color
  final double opacity;         // 0.0 to 1.0
  final DateTime createdAt;     // Creation time
  final DateTime updatedAt;     // Last modified time
}
```

### Pro Features Check
```dart
final isPro = ref.read(isProProvider);
if (!isPro && requiresPro) {
  showDialog(...);  // Show upgrade prompt
}
```

### Annotation Limits
```dart
Free tier: 50 annotations per document, max highlight + text
Pro tier:  500 annotations per document, all types
```

---

## 🛠️ Important Provider Usage

### Access Active Document
```dart
final active = ref.watch(activeDocumentProvider);
```

### Get Annotations for Active Document
```dart
final annotations = ref.watch(activeDocumentAnnotationsProvider);
```

### Add Annotation
```dart
final result = ref.read(annotationProvider.notifier).addAnnotation(
  AnnotationModel(
    id: 'unique-id',
    type: AnnotationType.highlight,
    documentId: doc.id,  // Use doc.id, not doc.name!
    pageIndex: 0,
    x: 100, y: 200,
    width: 50, height: 20,
    color: Colors.yellow,
    opacity: 1.0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
);
if (result != null) {
  print('Error: $result');  // Limit exceeded or Pro-only
}
```

### Check Usage Count
```dart
final usage = ref.read(usageProvider);
print('Used: ${usage.splitMergeCount} / 10 this month');
```

---

## 🧪 Test Data

### Sample PDF for Testing
```dart
// Create minimal valid PDF (from pdf_viewer_test.dart)
Uint8List _createMinimalPdf() { ... }
```

### Test Documents
- Small: <1 MB, single page
- Medium: 5-10 MB, 10-20 pages
- Large: 20+ MB, 50+ pages (like the 77-page test case)

---

## 📊 Performance Targets

| Operation | Target | Current | Notes |
|-----------|--------|---------|-------|
| PDF load (50 pages) | <1s | ~20s | Needs lazy loading |
| Scroll (60fps) | 60fps | Unknown | Use DevTools |
| Zoom (100ms) | <100ms | Unknown | Use DevTools |
| Search | Async | Blocking web | Phase 3 todo |
| Annotation save | <100ms | <10ms | ✅ Good |
| Encryption | <5s | Unknown | Depends on size |

---

## 🔐 Security Best Practices

### Password Handling
```dart
// GOOD: Confirm password before encryption
if (pw != pwConfirm) throw 'Mismatch';

// GOOD: Validate length
if (pw.length < 4 || pw.length > 128) throw 'Invalid length';

// BAD: Don't echo passwords in logs
print('Password: $password');  // NEVER do this!
```

### Input Validation
```dart
// GOOD: Trim and validate
final text = controller.text.trim();
if (text.isEmpty) throw 'Empty input';
if (text.length > maxLength) throw 'Too long';

// BAD: Trust user input
final text = controller.text;  // Could have spaces, nulls, etc.
```

---

## 📱 Platform-Specific Notes

### iOS
- Requires `NSPhotoLibraryUsageDescription` in Info.plist
- Keychain used for secure token storage
- FileProvider for document access

### Android
- Requires `READ_EXTERNAL_STORAGE` permission
- Keystore for secure token storage
- ContentProvider for document access

### Web
- No file.path available (always null)
- Must use bytes for all operations
- IndexedDB for local storage (Hive)

---

## 🚨 Error Handling Patterns

### Try-Catch with Specific Errors
```dart
try {
  // Operation
} catch (e) {
  if (e is FileNotFoundException) {
    // Handle missing file
  } else if (e is PermissionDeniedException) {
    // Handle permission denied
  } else {
    // Generic error
    setState(() => _status = 'Error: $e');
  }
}
```

### User-Facing Error Messages
```dart
// GOOD: Specific and actionable
'Halaman awal harus >= 1'
'Password harus 4-128 karakter'
'Teks watermark maksimal 100 karakter'

// BAD: Generic
'Error occurred'
'Invalid input'
'Failed'
```

---

## 📝 Git Workflow

### Check Status
```bash
git status
```

### See Changes
```bash
git diff lib/features/pdf_viewer/presentation/screens/pdf_viewer_screen.dart
```

### Stage Changes
```bash
git add lib/core/providers/document_provider.dart
git add lib/core/providers/annotation_provider.dart
git add lib/features/pdf_viewer/presentation/screens/pdf_viewer_screen.dart
git add lib/features/pdf_editor/presentation/screens/pdf_editor_screen.dart
```

### Commit
```bash
git commit -m "Fix: critical PDF viewer bugs - null safety, password confirmation, annotation persistence"
```

### Push New Branch
```bash
git push -u origin bugfix/pdf-viewer-critical-fixes
```

---

## 🔍 Debugging Tips

### Enable Debug Prints
```dart
debugPrint('Message: $value');  // Shows in DevTools console
```

### Use Riverpod DevTools
```bash
# Add to pubspec.yaml dev_dependencies
riverpod_generator: ^2.3.9

# Then use Provider.autoDispose for testing
```

### Browser DevTools (Web)
```
F12 → Console → See debugPrint outputs
F12 → Performance → Record PDF loading
F12 → Application → IndexedDB (Hive storage)
```

### Flutter DevTools
```bash
flutter pub global activate devtools
devtools
# Ctrl+Click the link in console output
```

---

## 📚 Documentation References

- **FIXES_AND_IMPROVEMENTS.md** - All bug fixes with code examples
- **PERFORMANCE_OPTIMIZATION_PLAN.md** - Optimization roadmap
- **SESSION_SUMMARY.md** - Complete session overview
- **requirements.md** - Feature requirements by tier
- **design.md** - Architecture and UI design
- **tasks.md** - Implementation tasks and phases

---

## ✅ Before Deploying

- [ ] Run all tests: `flutter test`
- [ ] Check builds:
  - [ ] `flutter build web --no-tree-shake-icons`
  - [ ] `flutter build apk` (or ipa for iOS)
- [ ] Manual QA on each platform
- [ ] Performance profiling with DevTools
- [ ] Code review completed
- [ ] Commit message is clear
- [ ] No secrets in code
- [ ] No debug prints left

---

**Last Updated**: June 6, 2026  
**Last Editor**: Kiro  
**Version**: 1.0

