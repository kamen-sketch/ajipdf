import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/providers/document_provider.dart';
import '../../../../core/providers/subscription_provider.dart';
import '../widgets/editor_result.dart';

/// PDF Editor Screen - menangani operasi split, merge, compress, encrypt, watermark, dll.
class PDFEditorScreen extends ConsumerStatefulWidget {
  const PDFEditorScreen({
    super.key,
    this.operation,
  });

  final String? operation;

  @override
  ConsumerState<PDFEditorScreen> createState() => _PDFEditorScreenState();
}

class _PDFEditorScreenState extends ConsumerState<PDFEditorScreen> {
  bool _processing = false;
  String? _status;

  // Input untuk operasi tertentu
  final _passwordController = TextEditingController();
  final _watermarkController = TextEditingController(text: 'CONFIDENTIAL');
  final _rangeStartController = TextEditingController(text: '1');
  final _rangeEndController = TextEditingController(text: '1');

  List<PdfDocumentInfo> _mergeDocs = [];
  PdfDocumentInfo? _singleDoc;
  int _pageCount = 0;

  String get _op => widget.operation ?? 'view';

  @override
  void dispose() {
    _passwordController.dispose();
    _watermarkController.dispose();
    _rangeStartController.dispose();
    _rangeEndController.dispose();
    super.dispose();
  }

  ProFeature? get _requiredFeature {
    switch (_op) {
      case 'split':
        return ProFeature.split;
      case 'merge':
        return ProFeature.merge;
      case 'compress':
        return ProFeature.compress;
      case 'watermark':
        return ProFeature.watermark;
      case 'encrypt':
        return ProFeature.encrypt;
      case 'sign':
        return ProFeature.sign;
      default:
        return null;
    }
  }

  String get _title => switch (_op) {
        'split' => 'Split PDF',
        'merge' => 'Merge PDF',
        'sign' => 'Sign PDF',
        'compress' => 'Compress PDF',
        'watermark' => 'Add Watermark',
        'encrypt' => 'Lock PDF',
        'rotate' => 'Rotate Pages',
        'reorder' => 'Reorder Pages',
        _ => 'PDF Editor',
      };

  IconData get _icon => switch (_op) {
        'split' => Icons.call_split_rounded,
        'merge' => Icons.merge_type_rounded,
        'sign' => Icons.draw_rounded,
        'compress' => Icons.compress_rounded,
        'watermark' => Icons.branding_watermark_rounded,
        'encrypt' => Icons.lock_rounded,
        'rotate' => Icons.rotate_90_degrees_ccw_rounded,
        'reorder' => Icons.reorder_rounded,
        _ => Icons.edit_note_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);
    final feature = _requiredFeature;
    final available = feature == null ||
        ref.read(subscriptionProvider.notifier).isFeatureAvailable(feature);

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Icon(_icon, size: 56, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Center(
              child: Text(_title,
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            const SizedBox(height: 4),
            if (!sub.isPro && feature != null)
              Center(
                child: Text(
                  feature == ProFeature.split || feature == ProFeature.merge
                      ? 'Free: sisa kuota ${sub.splitMergeRemaining} operasi bulan ini'
                      : 'Fitur Pro',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),
            if (!available)
              _buildLockedNotice()
            else
              _buildOperationUI(),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLockedNotice() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, size: 40, color: Colors.amber),
            const SizedBox(height: 12),
            const Text(
              'Fitur ini membutuhkan langganan Pro atau kuota Free sudah habis.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/subscription'),
              child: const Text('Upgrade ke Pro'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationUI() {
    switch (_op) {
      case 'merge':
        return _buildMergeUI();
      case 'split':
        return _buildSplitUI();
      case 'compress':
      case 'encrypt':
      case 'watermark':
        return _buildSingleDocUI();
      default:
        return _buildSingleDocUI();
    }
  }

  // ---------- MERGE ----------
  Widget _buildMergeUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _processing ? null : _pickMergeDocs,
          icon: const Icon(Icons.add),
          label: const Text('Pilih beberapa PDF (min. 2)'),
        ),
        const SizedBox(height: 12),
        ..._mergeDocs.asMap().entries.map((e) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${e.key + 1}')),
                title: Text(e.value.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(e.value.readableSize),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _processing
                      ? null
                      : () => setState(() => _mergeDocs.removeAt(e.key)),
                ),
              ),
            )),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (_mergeDocs.length >= 2 && !_processing) ? _runMerge : null,
          icon: _processing
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.merge_type),
          label: const Text('Gabungkan PDF'),
        ),
      ],
    );
  }

  // ---------- SPLIT ----------
  Widget _buildSplitUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilePickerTile(),
        if (_singleDoc != null) ...[
          const SizedBox(height: 16),
          Text('Total halaman: $_pageCount'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rangeStartController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Dari halaman',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _rangeEndController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sampai halaman',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _processing ? null : _runSplit,
            icon: const Icon(Icons.call_split),
            label: const Text('Split PDF'),
          ),
        ],
      ],
    );
  }

  // ---------- SINGLE DOC (compress, encrypt, watermark) ----------
  Widget _buildSingleDocUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilePickerTile(),
        if (_singleDoc != null) ...[
          const SizedBox(height: 16),
          if (_op == 'encrypt')
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (4-128 karakter)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          if (_op == 'watermark')
            TextField(
              controller: _watermarkController,
              decoration: const InputDecoration(
                labelText: 'Teks watermark',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.branding_watermark),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _processing ? null : _runSingleOp,
            icon: _processing
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_icon),
            label: Text(_title),
          ),
        ],
      ],
    );
  }

  Widget _buildFilePickerTile() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf),
        title: Text(_singleDoc?.name ?? 'Pilih file PDF'),
        subtitle: _singleDoc != null ? Text(_singleDoc!.readableSize) : null,
        trailing: const Icon(Icons.folder_open),
        onTap: _processing ? null : _pickSingleDoc,
      ),
    );
  }

  // ---------- ACTIONS ----------
  Future<void> _pickSingleDoc() async {
    final doc = await ref.read(documentsProvider.notifier).pickPdf();
    if (doc == null) return;
    final bytes = await _bytesOf(doc);
    var pages = 0;
    if (bytes != null) {
      final pdf = PdfDocument(inputBytes: bytes);
      pages = pdf.pages.count;
      pdf.dispose();
    }
    setState(() {
      _singleDoc = doc;
      _pageCount = pages;
      _rangeEndController.text = '$pages';
      _status = null;
    });
  }

  Future<void> _pickMergeDocs() async {
    final docs = await ref.read(documentsProvider.notifier).pickMultiplePdf();
    if (docs.isEmpty) return;
    setState(() {
      _mergeDocs = [..._mergeDocs, ...docs];
      _status = null;
    });
  }

  Future<Uint8List?> _bytesOf(PdfDocumentInfo doc) async {
    if (doc.bytes != null) return doc.bytes;
    // Pada platform non-web, baca dari path tidak ditangani di sini karena
    // file_picker withData:true sudah menyediakan bytes.
    return null;
  }

  Future<void> _runMerge() async {
    setState(() {
      _processing = true;
      _status = null;
    });
    try {
      final merged = PdfDocument();
      // Hapus halaman kosong default yang dibuat otomatis jika ada.
      if (merged.pages.count > 0) {
        merged.pages.removeAt(0);
      }

      for (final d in _mergeDocs) {
        final bytes = await _bytesOf(d);
        if (bytes == null) continue;
        final src = PdfDocument(inputBytes: bytes);
        for (int i = 0; i < src.pages.count; i++) {
          final srcPage = src.pages[i];
          final template = srcPage.createTemplate();
          final newPage = merged.pages.insert(
            merged.pages.count,
            srcPage.size,
          );
          newPage.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            newPage.size,
          );
        }
        src.dispose();
      }

      final out = Uint8List.fromList(await merged.save());
      merged.dispose();
      _recordUsage();
      _showResult('merged.pdf', out);
    } catch (e) {
      setState(() => _status = 'Gagal merge: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _runSplit() async {
    setState(() {
      _processing = true;
      _status = null;
    });
    try {
      final bytes = await _bytesOf(_singleDoc!);
      if (bytes == null) throw 'File tidak punya data';
      final start = int.tryParse(_rangeStartController.text) ?? 1;
      final end = int.tryParse(_rangeEndController.text) ?? start;
      if (start < 1 || end > _pageCount || start > end) {
        throw 'Range halaman tidak valid (1-$_pageCount)';
      }

      final src = PdfDocument(inputBytes: bytes);
      final out = PdfDocument();
      // Hapus halaman kosong default jika ada.
      if (out.pages.count > 0) {
        out.pages.removeAt(0);
      }

      for (int i = start - 1; i <= end - 1; i++) {
        final srcPage = src.pages[i];
        final template = srcPage.createTemplate();
        final newPage = out.pages.insert(
          out.pages.count,
          srcPage.size,
        );
        newPage.graphics.drawPdfTemplate(
          template,
          const Offset(0, 0),
          newPage.size,
        );
      }

      final result = Uint8List.fromList(await out.save());
      src.dispose();
      out.dispose();
      _recordUsage();
      _showResult('split_${start}_$end.pdf', result);
    } catch (e) {
      setState(() => _status = 'Gagal split: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _runSingleOp() async {
    setState(() {
      _processing = true;
      _status = null;
    });
    try {
      final bytes = await _bytesOf(_singleDoc!);
      if (bytes == null) throw 'File tidak punya data';
      final pdf = PdfDocument(inputBytes: bytes);

      String outName = _singleDoc!.name;

      switch (_op) {
        case 'encrypt':
          final pw = _passwordController.text;
          if (pw.length < 4 || pw.length > 128) {
            throw 'Password harus 4-128 karakter';
          }
          pdf.security.userPassword = pw;
          pdf.security.ownerPassword = pw;
          pdf.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
          outName = 'locked_${_singleDoc!.name}';
          break;
        case 'watermark':
          _applyWatermark(pdf, _watermarkController.text);
          outName = 'watermarked_${_singleDoc!.name}';
          break;
        case 'compress':
          pdf.compressionLevel = PdfCompressionLevel.best;
          outName = 'compressed_${_singleDoc!.name}';
          break;
      }

      final out = Uint8List.fromList(await pdf.save());
      pdf.dispose();
      _showResult(outName, out);
    } catch (e) {
      setState(() => _status = 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _applyWatermark(PdfDocument pdf, String text) {
    for (var i = 0; i < pdf.pages.count; i++) {
      final page = pdf.pages[i];
      final gfx = page.graphics;
      gfx.save();
      gfx.setTransparency(0.15);
      gfx.translateTransform(page.size.width / 2, page.size.height / 2);
      gfx.rotateTransform(-45);
      gfx.drawString(
        text,
        PdfStandardFont(PdfFontFamily.helvetica, 48, style: PdfFontStyle.bold),
        brush: PdfBrushes.red,
        bounds: Rect.fromLTWH(-page.size.width / 2, 0, page.size.width, 60),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      gfx.restore();
    }
  }

  void _recordUsage() {
    ref.read(subscriptionProvider.notifier).recordSplitMergeUsage();
  }

  void _showResult(String fileName, Uint8List bytes) {
    setState(() => _status = 'Berhasil! Ukuran hasil: ${(bytes.length / 1024).toStringAsFixed(0)} KB');
    showDialog(
      context: context,
      builder: (_) => EditorResultDialog(fileName: fileName, bytes: bytes),
    );
  }
}
