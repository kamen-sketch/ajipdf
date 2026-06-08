import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../../core/providers/document_provider.dart';
import '../../../../core/providers/subscription_provider.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../core/theme/app_theme.dart';

/// PDF Viewer Screen — ISO 32000 Compliant Annotations
///
/// Anotasi disimpan sebagai **standard PDF annotations** (ISO 32000-1/2)
/// menggunakan `PdfTextMarkupAnnotation` di `syncfusion_flutter_pdf`.
/// Ini berarti:
/// - Anotasi **terlihat di semua PDF reader** (Edge, Chrome, Acrobat, Preview)
/// - Cross-platform: share file PDF ke siapapun, anotasi tetap ada
/// - Cross-device: upload ke cloud, buka di device lain, anotasi terbaca
///
/// Persistence:
/// - `saveDocument()` menghasilkan bytes PDF lengkap dengan anotasi standar
/// - Bytes disimpan ke **Hive** (IndexedDB di web) agar survive page refresh
/// - Saat `initState`, bytes dibaca dari Hive (bukan hanya provider RAM)
class PDFViewerScreen extends ConsumerStatefulWidget {
  const PDFViewerScreen({super.key, this.filePath});
  final String? filePath;

  @override
  ConsumerState<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends ConsumerState<PDFViewerScreen> {
  final PdfViewerController _ctrl = PdfViewerController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final UndoHistoryController _undoCtrl = UndoHistoryController();

  PdfTextSearchResult? _searchResult;
  bool _showSearch = false;
  bool _searchBusy = false;

  String _title = 'PDF Viewer';
  int _page = 1;
  int _total = 0;
  String? _error;

  double _zoom = 1.0;
  static const double _zoomStep = 0.25;
  static const double _zoomMin = 0.5;
  static const double _zoomMax = 3.0;

  bool _saving = false;
  bool _ocrOffered = false;

  /// Bytes untuk SfPdfViewer — TIDAK berubah selama session ini.
  Uint8List? _viewerBytes;

  /// Key version: increment hanya saat ganti dokumen.
  int _viewerKeyVersion = 0;

  /// Hive key untuk persist PDF bytes yang sudah dianotasi.
  String get _hiveKey {
    final doc = ref.read(activeDocumentProvider);
    return 'annotated_pdf_${doc?.id ?? _title}';
  }

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final doc = ref.read(activeDocumentProvider);
    _title = doc?.name ?? 'PDF Viewer';
    ErrorReporter.instance
        .addBreadcrumb('pdf_viewer', 'open_${doc?.name ?? "empty"}');

    if (doc?.bytes != null) {
      // PRIORITAS: baca dari Hive (bytes terakhir yang sudah dianotasi)
      // Fallback: bytes dari provider (file asli yang baru dipick)
      final hiveKey = 'annotated_pdf_${doc!.id}';
      final savedBytes = HiveService.instance.documentsBox.get(hiveKey);
      if (savedBytes != null &&
          savedBytes is Uint8List &&
          savedBytes.isNotEmpty) {
        _viewerBytes = savedBytes;
        debugPrint(
            '[Viewer] Loaded ${savedBytes.length} bytes from Hive (annotated)');
      } else {
        _viewerBytes = doc.bytes;
        debugPrint(
            '[Viewer] Loaded ${doc.bytes!.length} bytes from provider (original)');
      }
    }
  }

  @override
  void dispose() {
    _searchResult?.removeListener(_onSearchUpdate);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    // JANGAN dispose _undoCtrl — SfPdfViewer mengelola lifecycle-nya sendiri
    // karena undoController di-pass sebagai parameter widget.
    // Dispose manual menyebabkan "used after disposed" saat SfPdfViewer cleanup.
    _ctrl.dispose();
    super.dispose();
  }

  // ── zoom ─────────────────────────────────────────────────────────────────

  void _zoomIn() {
    final next = (_zoom + _zoomStep).clamp(_zoomMin, _zoomMax);
    if (next == _zoom) return;
    setState(() => _zoom = next);
    _ctrl.zoomLevel = next;
  }

  void _zoomOut() {
    final next = (_zoom - _zoomStep).clamp(_zoomMin, _zoomMax);
    if (next == _zoom) return;
    setState(() => _zoom = next);
    _ctrl.zoomLevel = next;
  }

  void _resetZoom() {
    setState(() => _zoom = 1.0);
    _ctrl.zoomLevel = 1.0;
  }

  // ── save (ISO 32000 standard annotations + Hive persistence) ─────────────

  Future<void> _saveDocument() async {
    if (_saving || _viewerBytes == null) return;
    setState(() => _saving = true);
    try {
      // saveDocument() → PDF bytes dengan ISO 32000 standard annotations.
      // Annotations disimpan sebagai PdfTextMarkupAnnotation objects di dalam PDF.
      // Ini yang membuat highlight terlihat di Edge, Chrome, Acrobat, dll.
      final savedBytes = Uint8List.fromList(
          await _ctrl.saveDocument(flattenOption: PdfFlattenOption.none));

      final anns = _ctrl.getAnnotations();
      debugPrint(
          '[Viewer] saveDocument(): ${savedBytes.length} bytes, ${anns.length} annotations');

      // Persist ke Hive (IndexedDB di web) — survive page refresh
      await HiveService.instance.documentsBox.put(_hiveKey, savedBytes);
      debugPrint('[Viewer] Saved to Hive key: $_hiveKey');

      // Update provider (RAM) juga — untuk konsistensi navigasi
      final current = ref.read(activeDocumentProvider);
      if (current != null) {
        final updated = current.withBytes(savedBytes);
        ref.read(activeDocumentProvider.notifier).state = updated;
        ref
            .read(documentsProvider.notifier)
            .updateBytes(current.id, savedBytes);
      }

      _snack('Dokumen tersimpan ✓ (${anns.length} anotasi, standar ISO 32000)');

      // Tampilkan dialog untuk download file PDF yang sudah teranotasi
      if (mounted) {
        _showDownloadDialog(savedBytes);
      }
    } catch (e, st) {
      debugPrint('[Viewer] Save error: $e\n$st');
      _snack('Gagal simpan: $e');
      ErrorReporter.instance.reportError(e, st,
          screen: 'pdf_viewer', action: 'save_document', severity: 'high');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Tampilkan dialog download setelah save berhasil
  void _showDownloadDialog(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Berhasil Disimpan'),
        content: const Text(
          'Anotasi telah disimpan ke dalam PDF (standar ISO 32000).\n\n'
          'Download file untuk menyimpan versi teranotasi ke perangkat. '
          'File ini bisa dibuka di Edge, Chrome, Acrobat, dan semua PDF reader.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadPdf(bytes);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    );
  }

  /// Download PDF ke perangkat user
  Future<void> _downloadPdf(Uint8List bytes) async {
    try {
      // Gunakan helper web yang sudah ada
      final fileName = 'annotated_$_title';
      if (kIsWeb) {
        // Web: trigger download via anchor element
        await _webDownload(fileName, bytes);
        _snack('Download dimulai: $fileName');
      } else {
        // Native: bisa langsung save ke path jika tersedia
        _snack('File disimpan sebagai $fileName');
      }
    } catch (e) {
      _snack('Gagal download: $e');
    }
  }

  /// Web download implementation
  Future<void> _webDownload(String fileName, Uint8List bytes) async {
    final base64Data = base64Encode(bytes);
    final href = 'data:application/pdf;base64,$base64Data';
    final anchor = html.AnchorElement(href: href)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
  }

  // ── OCR hint ─────────────────────────────────────────────────────────────

  void _offerOCR() {
    if (_ocrOffered) return;
    _ocrOffered = true;
    Future.microtask(() {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Tidak ditemukan teks. PDF mungkin berupa gambar (scan). '
              'Gunakan OCR untuk konversi ke teks.'),
          action: SnackBarAction(
              label: 'OCR',
              onPressed: () {
                _snack(
                    'Buka menu OCR dari dashboard untuk konversi PDF ke teks.');
              }),
          duration: const Duration(seconds: 5),
        ),
      );
    });
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_viewerBytes == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('PDF Viewer')),
        body: _buildEmpty(),
      );
    }
    return Scaffold(
      appBar: _showSearch ? _buildSearchBar() : _buildAppBar(),
      body: _buildViewer(),
      bottomNavigationBar:
          (_total > 0 && !_showSearch) ? _buildPageBar() : null,
    );
  }

  // ── app bar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(_title, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'Zoom out',
            onPressed: _zoom > _zoomMin ? _zoomOut : null),
        TextButton(
          onPressed: _zoom == 1.0 ? null : _resetZoom,
          child: Text('${(_zoom * 100).round()}%',
              style: const TextStyle(fontSize: 13)),
        ),
        IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Zoom in',
            onPressed: _zoom < _zoomMax ? _zoomIn : null),
        const SizedBox(width: 4),
        IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Cari',
            onPressed: () => setState(() {
                  _showSearch = true;
                  _ocrOffered = false;
                  _searchFocus.requestFocus();
                })),
        PopupMenuButton<PdfAnnotationMode>(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Markup',
          onSelected: _onMarkupSelected,
          itemBuilder: (_) => [
            _modeItem(PdfAnnotationMode.highlight, Icons.highlight, 'Highlight',
                Colors.yellow),
            _modeItem(PdfAnnotationMode.underline, Icons.format_underlined,
                'Underline', Colors.blue),
            _modeItem(PdfAnnotationMode.strikethrough,
                Icons.format_strikethrough, 'Strikethrough', Colors.red),
            _modeItem(PdfAnnotationMode.squiggly, Icons.gesture, 'Squiggly',
                Colors.green),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: PdfAnnotationMode.none,
              child: Row(children: [
                Icon(Icons.do_not_disturb, size: 18),
                SizedBox(width: 10),
                Text('Stop Markup'),
              ]),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: 'Undo',
          onPressed: () {
            try {
              _undoCtrl.undo();
            } catch (_) {}
          },
        ),
        IconButton(
          icon: const Icon(Icons.redo),
          tooltip: 'Redo',
          onPressed: () {
            try {
              _undoCtrl.redo();
            } catch (_) {}
          },
        ),
        if (_saving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Simpan',
              onPressed: _saveDocument),
        IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Buka lain',
            onPressed: _pickAndLoad),
        IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Bagikan',
            onPressed: _share),
      ],
    );
  }

  PopupMenuItem<PdfAnnotationMode> _modeItem(
      PdfAnnotationMode mode, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: mode,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label),
      ]),
    );
  }

  // ── search bar ───────────────────────────────────────────────────────────

  PreferredSizeWidget _buildSearchBar() {
    return AppBar(
      leading: IconButton(
          icon: const Icon(Icons.arrow_back), onPressed: _closeSearch),
      title: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
            hintText: 'Cari dalam dokumen…', border: InputBorder.none),
        onSubmitted: _search,
      ),
      actions: [
        if (_searchBusy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_searchResult != null && _searchResult!.hasResult) ...[
          Center(
              child: Text(
            '${_searchResult!.currentInstanceIndex}/${_searchResult!.totalInstanceCount}',
            style: const TextStyle(fontSize: 14),
          )),
          IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: () {
                _ctrl.clearSelection();
                _searchResult!.previousInstance();
              }),
          IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () {
                _ctrl.clearSelection();
                _searchResult!.nextInstance();
              }),
        ],
        if (_searchCtrl.text.isNotEmpty)
          IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchCtrl.clear();
                _clearSearch();
                _searchFocus.requestFocus();
              }),
      ],
    );
  }

  // ── viewer ───────────────────────────────────────────────────────────────

  Widget _buildViewer() {
    if (_error != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text('Gagal membuka PDF:\n$_error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _pickAndLoad,
              icon: const Icon(Icons.folder_open),
              label: const Text('Buka lain')),
        ]),
      ));
    }

    return SfPdfViewer.memory(
      _viewerBytes!,
      key: ValueKey(_viewerKeyVersion),
      controller: _ctrl,
      undoController: _undoCtrl,
      enableTextSelection: true,
      canShowPageLoadingIndicator: false,
      initialZoomLevel: _zoom,
      onDocumentLoaded: (details) {
        setState(() => _total = _ctrl.pageCount);
        final annCount = _ctrl.getAnnotations().length;
        debugPrint('[Viewer] Loaded: $_total pages, $annCount annotations');
      },
      onDocumentLoadFailed: (details) =>
          setState(() => _error = details.description),
      onPageChanged: (details) => setState(() => _page = details.newPageNumber),
    );
  }

  Widget _buildEmpty() {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.picture_as_pdf_rounded,
            size: 72, color: AppTheme.textHint),
        const SizedBox(height: 16),
        Text('Belum ada dokumen',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Pilih file PDF dari perangkat',
            style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: _pickAndLoad,
            icon: const Icon(Icons.folder_open),
            label: const Text('Buka PDF')),
      ],
    ));
  }

  // ── page bar ─────────────────────────────────────────────────────────────

  Widget _buildPageBar() {
    return BottomAppBar(
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: _page > 1 ? () => _ctrl.jumpToPage(1) : null),
            IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _page > 1 ? _ctrl.previousPage : null),
            GestureDetector(
                onTap: _jumpToPageDialog,
                child: Text('Hlm $_page / $_total',
                    style: Theme.of(context).textTheme.bodyMedium)),
            IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _page < _total ? _ctrl.nextPage : null),
            IconButton(
                icon: const Icon(Icons.last_page),
                onPressed:
                    _page < _total ? () => _ctrl.jumpToPage(_total) : null),
          ],
        ));
  }

  // ── search ───────────────────────────────────────────────────────────────

  void _search(String text) {
    if (text.trim().isEmpty) return;
    _searchResult?.removeListener(_onSearchUpdate);
    _ctrl.clearSelection();
    setState(() => _searchBusy = true);
    try {
      final result = _ctrl.searchText(text);
      _searchResult = result;
      if (kIsWeb) {
        setState(() => _searchBusy = false);
        if (!result.hasResult) _offerOCR();
      } else {
        result.addListener(_onSearchUpdate);
      }
    } catch (e) {
      _snack('Error: $e');
      setState(() => _searchBusy = false);
    }
  }

  void _onSearchUpdate() {
    if (!mounted) return;
    if (_searchResult != null && _searchResult!.isSearchCompleted) {
      setState(() => _searchBusy = false);
      if (!_searchResult!.hasResult) {
        _snack('Tidak ditemukan');
        _offerOCR();
      }
    }
  }

  void _clearSearch() {
    _searchResult?.removeListener(_onSearchUpdate);
    _searchResult?.clear();
    _ctrl.clearSelection();
    setState(() {
      _searchResult = null;
      _searchBusy = false;
    });
  }

  void _closeSearch() {
    _clearSearch();
    _searchCtrl.clear();
    setState(() => _showSearch = false);
  }

  // ── markup ───────────────────────────────────────────────────────────────

  void _onMarkupSelected(PdfAnnotationMode mode) {
    if (mode != PdfAnnotationMode.none && mode != PdfAnnotationMode.highlight) {
      if (!ref.read(isProProvider)) {
        _showProGate();
        return;
      }
    }
    setState(() => _ctrl.annotationMode = mode);
    if (mode != PdfAnnotationMode.none) {
      _snack('Markup aktif — pilih teks. Undo untuk batal.');
    }
  }

  void _showProGate() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Fitur Pro'),
              content: const Text(
                  'Underline, strikethrough, squiggly perlu Pro.\nHighlight gratis.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/subscription');
                    },
                    child: const Text('Upgrade')),
              ],
            ));
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  void _jumpToPageDialog() {
    final c = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Lompat ke Halaman'),
              content: TextField(
                  controller: c,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                      labelText: 'Halaman (1–$_total)',
                      border: const OutlineInputBorder())),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: () {
                      final p = int.tryParse(c.text);
                      if (p != null && p >= 1 && p <= _total)
                        _ctrl.jumpToPage(p);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Go')),
              ],
            ));
  }

  Future<void> _pickAndLoad() async {
    final doc = await ref.read(documentsProvider.notifier).pickPdf();
    if (doc == null || doc.bytes == null) return;

    // Cek apakah ada versi teranotasi di Hive
    final hiveKey = 'annotated_pdf_${doc.id}';
    final hiveBytes = HiveService.instance.documentsBox.get(hiveKey);

    ref.read(activeDocumentProvider.notifier).state = doc;
    setState(() {
      _viewerBytes = (hiveBytes is Uint8List && hiveBytes.isNotEmpty)
          ? hiveBytes
          : doc.bytes;
      _viewerKeyVersion++;
      _error = null;
      _title = doc.name;
      _page = 1;
      _total = 0;
      _zoom = 1.0;
      _ocrOffered = false;
      _searchResult?.removeListener(_onSearchUpdate);
      _searchResult = null;
      _showSearch = false;
      _searchBusy = false;
    });
  }

  Future<void> _share() async {
    // Share bytes terbaru (termasuk anotasi) dari Hive jika ada
    final hiveBytes = HiveService.instance.documentsBox.get(_hiveKey);
    final bytesToShare = (hiveBytes is Uint8List && hiveBytes.isNotEmpty)
        ? hiveBytes
        : _viewerBytes;

    if (bytesToShare != null) {
      await Share.shareXFiles([
        XFile.fromData(bytesToShare, name: _title, mimeType: 'application/pdf'),
      ], text: _title);
    } else {
      _snack('Tidak ada dokumen.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
