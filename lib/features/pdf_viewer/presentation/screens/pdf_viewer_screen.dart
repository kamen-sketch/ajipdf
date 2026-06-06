import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers/document_provider.dart';

/// PDF Viewer Screen - menampilkan dokumen PDF dengan zoom, scroll, dan navigasi halaman.
class PDFViewerScreen extends ConsumerStatefulWidget {
  const PDFViewerScreen({
    super.key,
    this.filePath,
  });

  final String? filePath;

  @override
  ConsumerState<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends ConsumerState<PDFViewerScreen> {
  PdfController? _controller;
  String? _error;
  String _title = 'PDF Viewer';
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  void _loadDocument() {
    try {
      final active = ref.read(activeDocumentProvider);

      Future<PdfDocument> future;
      if (active?.bytes != null) {
        _title = active!.name;
        future = PdfDocument.openData(active.bytes!);
      } else if (active?.path != null) {
        _title = active!.name;
        future = PdfDocument.openFile(active.path!);
      } else if (widget.filePath != null && widget.filePath!.isNotEmpty) {
        _title = widget.filePath!.split(RegExp(r'[/\\]')).last;
        future = PdfDocument.openFile(widget.filePath!);
      } else {
        setState(() => _error = 'no_document');
        return;
      }

      _controller = PdfController(document: future);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _pickAndLoad() async {
    final doc = await ref.read(documentsProvider.notifier).pickPdf();
    if (doc == null) return;
    ref.read(activeDocumentProvider.notifier).state = doc;
    setState(() {
      _error = null;
      _controller?.dispose();
      _controller = null;
      _currentPage = 1;
      _totalPages = 0;
    });
    _loadDocument();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_controller != null) ...[
            IconButton(
              tooltip: 'Halaman sebelumnya',
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: () => _controller?.previousPage(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
              ),
            ),
            IconButton(
              tooltip: 'Halaman berikutnya',
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => _controller?.nextPage(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Buka PDF lain',
            onPressed: _pickAndLoad,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Bagikan',
            onPressed: _shareDocument,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _controller != null && _totalPages > 0
          ? _buildPageIndicator()
          : null,
    );
  }

  Widget _buildBody() {
    if (_error == 'no_document') {
      return _buildEmptyState();
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Gagal membuka PDF:\n$_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _pickAndLoad,
                icon: const Icon(Icons.folder_open),
                label: const Text('Pilih PDF lain'),
              ),
            ],
          ),
        ),
      );
    }
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PdfView(
      controller: _controller!,
      scrollDirection: Axis.vertical,
      onDocumentLoaded: (doc) {
        setState(() => _totalPages = doc.pagesCount);
      },
      onPageChanged: (page) {
        setState(() => _currentPage = page);
      },
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        pageLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) => Center(child: Text(error.toString())),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf_rounded, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Belum ada dokumen dipilih',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Pilih file PDF dari perangkat untuk mulai membaca',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pickAndLoad,
            icon: const Icon(Icons.folder_open),
            label: const Text('Pilih PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return BottomAppBar(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Halaman $_currentPage dari $_totalPages',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _shareDocument() async {
    final active = ref.read(activeDocumentProvider);
    if (active?.path != null) {
      await Share.shareXFiles([XFile(active!.path!)], text: active.name);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berbagi file hanya tersedia di perangkat mobile/desktop.')),
      );
    }
  }
}
