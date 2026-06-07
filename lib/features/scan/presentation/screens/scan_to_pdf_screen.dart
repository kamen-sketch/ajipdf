import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../pdf_editor/presentation/widgets/editor_result.dart';

/// Model satu halaman gambar hasil scan/foto.
class _ScanPage {
  _ScanPage({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

/// Scan to PDF — pilih beberapa foto dari galeri atau kamera untuk dijadikan PDF.
class ScanToPdfScreen extends ConsumerStatefulWidget {
  const ScanToPdfScreen({super.key});

  @override
  ConsumerState<ScanToPdfScreen> createState() => _ScanToPdfScreenState();
}

class _ScanToPdfScreenState extends ConsumerState<ScanToPdfScreen> {
  List<_ScanPage> _pages = [];
  bool _processing = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan to PDF'),
        actions: [
          if (_pages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Hapus semua',
              onPressed: () => setState(() {
                _pages = [];
                _status = null;
              }),
            ),
        ],
      ),
      body: _pages.isEmpty ? _buildEmpty() : _buildPageList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _processing ? null : _pickImages,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.document_scanner_outlined,
                size: 72, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text('Scan to PDF', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Pilih foto dari galeri atau ambil foto baru.\n'
              'Atur urutan halaman, lalu konversi menjadi satu file PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Pilih dari Galeri'),
            ),
            const SizedBox(height: 12),
            if (!kIsWeb)
              OutlinedButton.icon(
                onPressed: _captureFromCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Ambil Foto'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageList() {
    return Column(
      children: [
        // Header info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.primaryColor.withValues(alpha: 0.05),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text('${_pages.length} halaman — drag untuk ubah urutan',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.primaryColor)),
              const Spacer(),
              TextButton.icon(
                onPressed: _processing ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate, size: 16),
                label: const Text('Tambah', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        // Reorderable list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _pages.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _pages.removeAt(oldIndex);
                _pages.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final page = _pages[index];
              return Card(
                key: ValueKey('scan_${index}_${page.name}'),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      page.bytes,
                      width: 48,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text('Halaman ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(page.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.drag_handle, color: Colors.grey),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _processing
                            ? null
                            : () => setState(() => _pages.removeAt(index)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Status
        if (_status != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(_status!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
          ),
        // Convert button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    (_pages.isNotEmpty && !_processing) ? _convertToPdf : null,
                icon: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf),
                label: Text('Buat PDF (${_pages.length} halaman)'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============ ACTIONS ============

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final newPages = <_ScanPage>[];
      for (final file in result.files) {
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          newPages.add(_ScanPage(
            name: file.name,
            bytes: file.bytes!,
          ));
        }
      }
      if (newPages.isNotEmpty) {
        setState(() {
          _pages = [..._pages, ...newPages];
          _status = null;
        });
      }
    } catch (e) {
      setState(() => _status = 'Gagal memilih gambar: $e');
    }
  }

  Future<void> _captureFromCamera() async {
    // Di web tidak bisa pakai kamera langsung, buka file picker image saja
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        setState(() {
          _pages.add(_ScanPage(name: file.name, bytes: file.bytes!));
          _status = null;
        });
      }
    } catch (e) {
      setState(() => _status = 'Gagal mengambil foto: $e');
    }
  }

  Future<void> _convertToPdf() async {
    if (_pages.isEmpty) return;
    setState(() {
      _processing = true;
      _status = 'Mengonversi ${_pages.length} gambar ke PDF…';
    });
    try {
      final pdf = PdfDocument();
      pdf.pageSettings.margins.all = 0;
      // Hapus halaman default
      while (pdf.pages.count > 0) {
        pdf.pages.removeAt(0);
      }

      for (int i = 0; i < _pages.length; i++) {
        final imgBytes = _pages[i].bytes;
        final image = PdfBitmap(imgBytes);

        // Ukur halaman berdasar dimensi gambar, max A4 landscape/portrait
        double imgW = image.width.toDouble();
        double imgH = image.height.toDouble();

        // Skala ke max A4 (595 x 842 points) jaga aspect ratio
        const maxW = 595.0;
        const maxH = 842.0;
        double scale = 1.0;
        if (imgW > maxW || imgH > maxH) {
          scale = (maxW / imgW).clamp(0, 1);
          if (imgH * scale > maxH) {
            scale = (maxH / imgH).clamp(0, 1);
          }
        }
        final pageW = imgW * scale;
        final pageH = imgH * scale;

        pdf.pageSettings.size = Size(pageW, pageH);
        final page = pdf.pages.add();
        page.graphics.drawImage(
          image,
          Rect.fromLTWH(0, 0, pageW, pageH),
        );
      }

      final result = Uint8List.fromList(await pdf.save());
      pdf.dispose();

      setState(() => _status =
          'Berhasil! ${(result.length / 1024).toStringAsFixed(0)} KB');

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => EditorResultDialog(
            fileName: 'scanned_${_pages.length}_pages.pdf',
            bytes: result,
          ),
        );
      }
    } catch (e) {
      setState(() => _status = 'Gagal konversi: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}
