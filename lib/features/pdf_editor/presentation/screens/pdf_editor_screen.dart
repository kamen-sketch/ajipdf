import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/providers/document_provider.dart';
import '../../../../core/providers/subscription_provider.dart';
import '../../../../core/services/pdf_compress_service.dart';
import '../../../../core/services/error_reporter.dart';
import '../widgets/editor_result.dart';
import '../widgets/multi_result_dialog.dart';

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
  final _passwordConfirmController = TextEditingController();
  final _watermarkController = TextEditingController(text: 'CONFIDENTIAL');
  final _rangeStartController = TextEditingController(text: '1');
  final _rangeEndController = TextEditingController(text: '1');

  List<PdfDocumentInfo> _mergeDocs = [];
  PdfDocumentInfo? _singleDoc;
  int _pageCount = 0;
  CompressLevel _compressLevel = CompressLevel.medium;
  bool _splitEachPage = false;
  Color _watermarkColor = Colors.red;

  String get _op => widget.operation ?? 'view';

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordConfirmController.dispose();
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
    // Redirect sign to dedicated signature screen
    if (_op == 'sign') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.replace('/signature');
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Sign PDF')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Redirect rotate/reorder to dedicated screen
    if (_op == 'rotate' || _op == 'reorder') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.replace('/rotate-reorder');
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Rotate & Reorder')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
            if (!available) _buildLockedNotice() else _buildOperationUI(),
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
        if (_mergeDocs.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Drag untuk ubah urutan:',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _mergeDocs.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _mergeDocs.removeAt(oldIndex);
              _mergeDocs.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final doc = _mergeDocs[index];
            return Card(
              key: ValueKey('merge_${index}_${doc.name}'),
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(doc.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(doc.readableSize),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.drag_handle, color: Colors.grey),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _processing
                          ? null
                          : () => setState(() => _mergeDocs.removeAt(index)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed:
              (_mergeDocs.length >= 2 && !_processing) ? _runMerge : null,
          icon: _processing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _splitEachPage,
            title: const Text('Pisah setiap halaman jadi file terpisah'),
            subtitle: const Text('Menghasilkan banyak PDF (1 halaman per file)',
                style: TextStyle(fontSize: 12)),
            onChanged:
                _processing ? null : (v) => setState(() => _splitEachPage = v),
          ),
          if (!_splitEachPage) ...[
            const SizedBox(height: 8),
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
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _processing ? null : _runSplit,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.call_split),
            label: Text(_splitEachPage ? 'Pisah Semua Halaman' : 'Split PDF'),
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
          if (_op == 'encrypt') ...[
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (4-128 karakter)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordConfirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
          if (_op == 'watermark') ...[
            TextField(
              controller: _watermarkController,
              decoration: const InputDecoration(
                labelText: 'Teks watermark (max 100 karakter)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.branding_watermark),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Warna watermark:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                Colors.red,
                Colors.blue,
                Colors.grey,
                Colors.black,
                Colors.green,
                Colors.orange,
                Colors.purple,
              ]
                  .map((c) => GestureDetector(
                        onTap: _processing
                            ? null
                            : () => setState(() => _watermarkColor = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _watermarkColor == c
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: _watermarkColor == c
                                ? [
                                    BoxShadow(
                                        color: c.withValues(alpha: 0.5),
                                        blurRadius: 6)
                                  ]
                                : null,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (_op == 'compress') ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Tingkat kompresi:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            ...CompressLevel.values.map(
              (lvl) => RadioListTile<CompressLevel>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: lvl,
                groupValue: _compressLevel,
                title: Text(lvl.label),
                onChanged: _processing
                    ? null
                    : (v) => setState(() => _compressLevel = v!),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kompresi maksimal mengubah halaman menjadi gambar — '
              'cocok untuk dokumen hasil scan.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _processing ? null : _runSingleOp,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
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
      // Clear input fields for new document
      _passwordController.clear();
      _passwordConfirmController.clear();
      _watermarkController.text = 'CONFIDENTIAL';
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
    ErrorReporter.instance.addBreadcrumb('pdf_editor', 'merge_start');
    setState(() {
      _processing = true;
      _status = null;
    });
    try {
      if (_mergeDocs.length < 2) {
        throw 'Minimal 2 dokumen diperlukan untuk merge';
      }

      // Validasi semua docs punya bytes
      for (int i = 0; i < _mergeDocs.length; i++) {
        final bytes = await _bytesOf(_mergeDocs[i]);
        if (bytes == null || bytes.isEmpty) {
          throw 'File "${_mergeDocs[i].name}" tidak memiliki data. Pilih ulang file.';
        }
      }

      // Pendekatan robust: gunakan dokumen pertama sebagai base,
      // lalu append halaman dari dokumen lainnya
      final firstBytes = await _bytesOf(_mergeDocs[0]);
      final merged = PdfDocument(inputBytes: firstBytes!);

      for (int d = 1; d < _mergeDocs.length; d++) {
        final bytes = await _bytesOf(_mergeDocs[d]);
        if (bytes == null) continue;
        final src = PdfDocument(inputBytes: bytes);

        for (int i = 0; i < src.pages.count; i++) {
          final srcPage = src.pages[i];
          // Buat halaman baru dengan ukuran source page
          final newPage = merged.pages.insert(merged.pages.count, srcPage.size);

          // Copy content via template
          try {
            final template = srcPage.createTemplate();
            newPage.graphics.drawPdfTemplate(
              template,
              const Offset(0, 0),
              srcPage.size,
            );
          } catch (_) {
            debugPrint(
                '[Merge] Warning: gagal copy page ${i + 1} dari ${_mergeDocs[d].name}');
          }
        }
        src.dispose();
      }

      final out = Uint8List.fromList(await merged.save());
      merged.dispose();
      _recordUsage();
      _showResult('merged.pdf', out);
    } catch (e, st) {
      debugPrint('[Merge] Error: $e\n$st');
      setState(() => _status = 'Gagal merge: $e');
      ErrorReporter.instance.reportError(e, st,
          screen: 'pdf_editor', action: 'merge', severity: 'high');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _runSplit() async {
    ErrorReporter.instance.addBreadcrumb('pdf_editor',
        'split_start_pages_${_rangeStartController.text}-${_rangeEndController.text}');
    setState(() {
      _processing = true;
      _status = null;
    });
    try {
      if (_pageCount <= 0) {
        throw 'PDF tidak memiliki halaman atau belum dimuat';
      }

      final bytes = await _bytesOf(_singleDoc!);
      if (bytes == null) throw 'File tidak punya data';

      final baseName = _singleDoc!.name
          .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

      if (_splitEachPage) {
        // Hasilkan satu file PDF per halaman.
        final files = <ResultFile>[];
        for (int i = 0; i < _pageCount; i++) {
          final pageBytes = await _extractPages(bytes, i, i);
          files.add(ResultFile(
            fileName: '${baseName}_page_${i + 1}.pdf',
            bytes: pageBytes,
          ));
        }
        _recordUsage();
        setState(() => _status = 'Berhasil dipecah jadi ${files.length} file');
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => MultiResultDialog(files: files),
          );
        }
        return;
      }

      final start = int.tryParse(_rangeStartController.text) ?? 1;
      final end = int.tryParse(_rangeEndController.text) ?? start;

      if (start < 1) throw 'Halaman awal harus >= 1';
      if (end > _pageCount) {
        throw 'Halaman akhir melebihi total halaman ($_pageCount)';
      }
      if (start > end) {
        throw 'Halaman awal tidak boleh lebih besar dari halaman akhir';
      }

      // Bangun dokumen baru hanya berisi halaman [start..end] dengan
      // mengimpor halaman via template (andal di web, tidak sekadar hide).
      final result = _extractPages(bytes, start - 1, end - 1);
      _recordUsage();
      _showResult('${baseName}_${start}_$end.pdf', await result);
    } catch (e, st) {
      debugPrint('Split error: $e\n$st');
      setState(() => _status = 'Gagal split: $e');
      ErrorReporter.instance.reportError(e, st,
          screen: 'pdf_editor', action: 'split', severity: 'high');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// Ekstrak halaman [startIndex..endIndex] (0-based, inklusif) menjadi PDF baru.
  /// Bangun dokumen kosong baru, copy tiap halaman via template → ukuran file
  /// hanya mengandung resource yang benar-benar dipakai halaman tersebut.
  Future<Uint8List> _extractPages(
      Uint8List source, int startIndex, int endIndex) async {
    final src = PdfDocument(inputBytes: source);
    final out = PdfDocument();
    // PdfDocument() punya 1 halaman default — hapus.
    out.pageSettings.margins.all = 0;
    // Hapus halaman default
    while (out.pages.count > 0) {
      out.pages.removeAt(0);
    }

    for (int i = startIndex; i <= endIndex && i < src.pages.count; i++) {
      final srcPage = src.pages[i];
      final template = srcPage.createTemplate();
      // Tambah halaman baru dengan ukuran sama
      out.pageSettings.size = srcPage.size;
      final newPage = out.pages.add();
      newPage.graphics
          .drawPdfTemplate(template, const Offset(0, 0), srcPage.size);
    }

    final bytes = Uint8List.fromList(await out.save());
    src.dispose();
    out.dispose();
    return bytes;
  }

  Future<void> _runSingleOp() async {
    setState(() {
      _processing = true;
      _status = null;
    });
    try {
      final bytes = await _bytesOf(_singleDoc!);
      if (bytes == null) throw 'File tidak punya data';

      // Compress ditangani terpisah karena memakai rasterisasi async.
      if (_op == 'compress') {
        setState(() => _status = 'Mengompres… (merender halaman)');
        final result = await PdfCompressService.compress(
          bytes,
          level: _compressLevel,
        );
        final outName = 'compressed_${_singleDoc!.name}';
        if (result.compressedSize >= result.originalSize) {
          setState(() => _status =
              'PDF sudah optimal — tidak ada pengurangan ukuran berarti.');
        } else {
          setState(() => _status =
              'Berhasil! ${(result.originalSize / 1024).toStringAsFixed(0)} KB → '
                  '${(result.compressedSize / 1024).toStringAsFixed(0)} KB '
                  '(hemat ${result.savedPercent})');
        }
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) =>
                EditorResultDialog(fileName: outName, bytes: result.bytes),
          );
        }
        return;
      }

      final pdf = PdfDocument(inputBytes: bytes);
      String outName = _singleDoc!.name;

      switch (_op) {
        case 'encrypt':
          final pw = _passwordController.text;
          final pwConfirm = _passwordConfirmController.text;

          if (pw.isEmpty || pwConfirm.isEmpty) {
            throw 'Password dan konfirmasi tidak boleh kosong';
          }
          if (pw != pwConfirm) {
            throw 'Password tidak cocok';
          }
          if (pw.length < 4 || pw.length > 128) {
            throw 'Password harus 4-128 karakter';
          }

          final security = pdf.security;
          // AES-256 (revisi 6) bisa lambat/tidak kompatibel di web build.
          // RC4 128-bit lebih ringan dan didukung semua reader umum.
          security.algorithm = PdfEncryptionAlgorithm.rc4x128Bit;
          security.userPassword = pw;
          security.ownerPassword = pw;
          outName = 'locked_${_singleDoc!.name}';
          break;
        case 'watermark':
          final watermarkText = _watermarkController.text.trim();
          if (watermarkText.isEmpty) {
            throw 'Teks watermark tidak boleh kosong';
          }
          if (watermarkText.length > 100) {
            throw 'Teks watermark maksimal 100 karakter (saat ini: ${watermarkText.length})';
          }
          _applyWatermark(pdf, watermarkText);
          outName = 'watermarked_${_singleDoc!.name}';
          break;
      }

      final out = Uint8List.fromList(await pdf.save());
      pdf.dispose();
      _showResult(outName, out);
    } catch (e) {
      setState(() => _status = 'Gagal: $e');
      ErrorReporter.instance.reportError(e, StackTrace.current,
          screen: 'pdf_editor', action: _op, severity: 'medium');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _applyWatermark(PdfDocument pdf, String text) {
    // Konversi Flutter Color ke PdfColor
    final pdfColor = PdfColor(
      _watermarkColor.red,
      _watermarkColor.green,
      _watermarkColor.blue,
    );
    final brush = PdfSolidBrush(pdfColor);

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
        brush: brush,
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
    setState(() => _status =
        'Berhasil! Ukuran hasil: ${(bytes.length / 1024).toStringAsFixed(0)} KB');
    showDialog(
      context: context,
      builder: (_) => EditorResultDialog(fileName: fileName, bytes: bytes),
    );
  }
}
