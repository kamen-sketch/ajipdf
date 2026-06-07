# PDF Viewer Performance Optimization & Feature Activation Plan

**Current Issue**: 77-page PDF takes ~20 seconds to load in browser  
**Target**: < 3 seconds load time  
**Gap**: ~6-7x improvement needed

---

## Phase 1: Quick Wins (1-2 days)

### 1.1 Enable Hardware Acceleration
- SfPdfViewer already supports GPU rendering
- Ensure `enableTextSelection: true` doesn't disable acceleration
- Test on different browsers (Chrome, Firefox, Safari)

**Action**: Run performance profiling in browser DevTools to identify bottleneck

### 1.2 Add Loading State Indicator
```dart
// Show indeterminate progress while PDF loads
if (_totalPages == 0 && !_showSearchBar) {
  return Scaffold(
    appBar: ...,
    body: const Center(child: CircularProgressIndicator()),
  );
}
```

**Action**: Implement in `_buildBody` method  
**Impact**: User perceives faster loading with feedback

---

## Phase 2: Lazy Loading Implementation (3-5 days)

### 2.1 Chunk-Based Page Loading
**Requirement** (AC 6): "Loading halaman secara bertahap dengan maksimal 20 halaman per batch"

```dart
class PDFViewerEngine {
  static const int batchSize = 20;
  final List<int> _cachedPages = [];
  
  Future<void> loadPageBatch(int startPage, int endPage) async {
    // Load pages startPage to min(endPage, startPage+batchSize)
    // Cache in memory with LRU eviction
  }
  
  // Called when user scrolls near page boundary
  void onViewportChange(int firstVisiblePage, int lastVisiblePage) {
    final nextBatch = firstVisiblePage + (batchSize * 2);
    if (!_cachedPages.contains(nextBatch)) {
      loadPageBatch(nextBatch, nextBatch + batchSize);
    }
  }
}
```

### 2.2 Implement Page Caching Strategy
- LRU (Least Recently Used) cache with max 50 pages
- Preload next/previous pages on scroll
- Evict pages outside viewport + buffer zone

**Files to create**:
- `lib/core/services/pdf_cache_service.dart` - LRU cache management
- `lib/core/services/pdf_renderer_service.dart` - Background rendering

---

## Phase 3: Background Rendering (3-5 days)

### 3.1 Offload to Isolate
```dart
// main.dart or service init
import 'dart:isolate';

class PDFRenderService {
  late SendPort _renderPort;
  
  Future<void> init() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_renderIsolate, receivePort.sendPort);
    _renderPort = await receivePort.first;
  }
  
  static void _renderIsolate(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    
    receivePort.listen((message) {
      // Render pages in background without blocking UI
      final renderedBytes = _renderPage(message);
      sendPort.send(renderedBytes);
    });
  }
  
  Future<Uint8List> renderPageInBackground(int pageNum) async {
    return await _renderIsolateRecv.first;
  }
}
```

**Benefit**: Search operations won't freeze UI on web

---

## Phase 4: Async Search (2-3 days)

### 4.1 Non-Blocking Search
```dart
void _performSearch(String text) async {
  setState(() => _searchInProgress = true);
  
  // On web, search still blocks but with UI feedback
  // On mobile, run in Isolate
  if (kIsWeb) {
    final result = _pdfController.searchText(text);
    _searchResult = result;
    setState(() => _searchInProgress = false);
  } else {
    // Run search in background Isolate
    final result = await compute(_searchInIsolate, {
      'controller': _pdfController,
      'text': text,
    });
    _searchResult = result;
    setState(() => _searchInProgress = false);
  }
}
```

---

## Phase 5: Missing UI Features (2-3 days each)

### 5.1 Thumbnail Panel
```dart
// Create new widget: lib/features/pdf_viewer/presentation/widgets/thumbnail_panel.dart
class ThumbnailPanel extends ConsumerWidget {
  final int totalPages;
  final int currentPage;
  final ValueChanged<int> onPageTap;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 100,
      child: ListView.builder(
        itemCount: totalPages,
        itemBuilder: (ctx, i) {
          final pageNum = i + 1;
          return GestureDetector(
            onTap: () => onPageTap(pageNum),
            child: ThumbnailTile(
              pageNum: pageNum,
              isSelected: pageNum == currentPage,
              size: Size(80, 100),
            ),
          );
        },
      ),
    );
  }
}
```

**Requirement** (AC 8): "Panel thumbnail yang menampilkan hingga 20 thumbnail halaman"

**Implementation**:
- Add `ThumbnailPanel` to right side of PDFViewerScreen
- Lazy load thumbnails (max 20 visible at once)
- Cache generated thumbnails

### 5.2 Fullscreen Mode
```dart
// Add to PDFViewerScreen
class _PDFViewerScreenState extends ConsumerState<PDFViewerScreen> {
  bool _isFullscreen = false;
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _isFullscreen ? _exitFullscreen : null,
      child: _isFullscreen ? _buildFullscreenView() : _buildNormalView(),
    );
  }
  
  Widget _buildFullscreenView() {
    return GestureDetector(
      onTap: () => setState(() => _isFullscreen = false),
      child: Container(
        color: Colors.black,
        child: SfPdfViewer.memory(
          active.bytes!,
          // ... full screen config
        ),
      ),
    );
  }
}
```

**Action**: Add fullscreen button to AppBar actions

### 5.3 Document Metadata Display
```dart
// Add info dialog
void _showDocumentInfo() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Document Info'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow('Title', _pdfController.document?.title ?? 'N/A'),
          _InfoRow('Pages', '$_totalPages'),
          _InfoRow('Size', activeDoc.readableSize),
          _InfoRow('Created', activeDoc.lastOpened.toString()),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ),
  );
}
```

### 5.4 Bookmark Management UI
```dart
// Add bookmark creation/management
Future<void> _toggleBookmark() async {
  final page = _currentPage;
  final bookmarks = _bookmarks ?? [];
  
  if (bookmarks.contains(page)) {
    bookmarks.remove(page);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmark removed')),
    );
  } else {
    bookmarks.add(page);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmark added')),
    );
  }
  
  // Save to Hive
  await HiveService.instance.bookmarksBox.put('bookmarks_${activeDoc.id}', bookmarks);
}
```

**Action**: Add bookmark star button to AppBar

---

## Phase 6: Feature Activation Checklist

### All Base Features Working ✅
- [x] PDF viewing with zoom/scroll
- [x] Text search with navigation
- [x] Highlight/underline/strikethrough markup
- [x] PDF split (range-based)
- [x] PDF merge (multi-select)
- [x] PDF compress (3 levels)
- [x] PDF encrypt with password
- [x] PDF watermark with text
- [x] Rotate and reorder pages
- [x] Digital signature (draw, upload, text)
- [x] Annotation management (Hive storage)
- [x] Subscription gating for Pro features
- [x] Dark mode support

### Need UI/UX Completion
- [ ] Bookmarks - functional but no visual UI
- [ ] Thumbnails - not implemented
- [ ] Fullscreen - not implemented
- [ ] Document metadata - not shown
- [ ] OCR - engine missing from viewer integration

### Need Backend Integration
- [ ] Cloud sync (Google Drive/iCloud) - Phase 10 task
- [ ] Shareable links (7-day validity) - Phase 11 task
- [ ] Annotation export to PDF - Phase 11 task

---

## Phase 7: Performance Profiling (1-2 days)

### Use Browser DevTools
```
1. Open Chrome DevTools (F12)
2. Go to Performance tab
3. Click record
4. Open 77-page PDF
5. Analyze:
   - Initial parse time
   - Rendering time per page
   - Memory usage growth
   - JS interop overhead
```

### Measure Against Targets
| Operation | Target | Current | Status |
|-----------|--------|---------|--------|
| Load <50 pages | <1s | ~20s | ❌ Need opt |
| 60fps scroll | 60fps | Unknown | ⚠️ Test |
| Zoom render | <100ms | Unknown | ⚠️ Test |
| Search time | Async | Blocking | ❌ Need opt |

---

## Phase 8: Testing Strategy

### Unit Tests (Existing)
```bash
flutter test test/features/pdf_viewer/pdf_viewer_test.dart
```

### Widget Tests (New)
```dart
testWidgets('PDF viewer renders and displays page count', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  expect(find.byType(PDFViewerScreen), findsOneWidget);
  expect(find.text('Page 1 of 77'), findsOneWidget);
});
```

### Integration Tests (New)
```dart
// integration_test/pdf_viewer_flow_test.dart
void main() {
  testWidgets('User can open, search, and annotate PDF', (WidgetTester tester) async {
    // Full user workflow test
  });
}
```

### Performance Tests (New)
```bash
flutter run -d chrome --profile
```

---

## Implementation Priority

**High Priority** (1-2 weeks):
1. Quick wins - Loading indicator + profiling
2. Lazy page loading implementation
3. Background Isolate for search

**Medium Priority** (2-3 weeks):
4. Thumbnail panel UI
5. Fullscreen mode
6. Document metadata display

**Low Priority** (next sprint):
7. Bookmark UI (functionality exists)
8. OCR integration
9. Cloud sync (requires Phase 10 completion)

---

## Resource Requirements

- **Time**: ~4-6 weeks for full optimization + features
- **Skills**: Flutter web performance, PDF rendering, async Dart
- **Tools**: Browser DevTools, Flutter DevTools, Dartpad performance analyzer

---

## Success Metrics

- [ ] PDF load time < 3 seconds (77 pages, 20MB)
- [ ] 60fps scroll maintained (RAM > 4GB)
- [ ] Zoom render < 100ms
- [ ] 95% test coverage for new code
- [ ] Zero performance regressions on main branch

---

## Next Steps

1. **Today**: Gather performance baseline with browser profiling
2. **This week**: Implement lazy loading + background Isolate
3. **Next week**: Add thumbnail panel + fullscreen mode
4. **Week 3**: Performance optimization sprint
5. **Week 4**: Full QA testing and release

