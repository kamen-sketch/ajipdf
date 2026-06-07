import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/services/pdf_raster_service.dart';
import 'editor_result.dart';

/// Layar pratinjau hasil edit PDF (mis. rotate/reorder) sebelum diunduh.
/// Merender halaman dengan pdf.js/pdfx agar user melihat hasil dulu.
class PreviewResultScreen extends StatefulWidget {
  const PreviewResultScreen({
    super.key,
    required this.fileName,
    required this.bytes,
    this.title = 'Pratinjau Hasil',
  });

  final String fileName;
  final Uint8List bytes;
  final String title;

  @override
  State<PreviewResultScreen> createState() => _PreviewResultScreenState();
}

class _PreviewResultScreenState extends State<PreviewResultScreen> {
  int _page = 1;
  int _total = 1;
  Uint8List? _png;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    try {
      final pdf = PdfDocument(inputBytes: widget.bytes);
      _total = pdf.pages.count;
      pdf.dispose();
    } catch (_) {}
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rp =
          await PdfRasterService.renderPage(widget.bytes, _page, scale: 1.5);
      setState(() {
        _png = rp.imageBytes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              'Pratinjau tidak tersedia.\n$_error\n\n'
                              'Anda tetap bisa mengunduh hasilnya.',
                              textAlign: TextAlign.center),
                        ),
                      )
                    : InteractiveViewer(
                        maxScale: 4,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: _png != null
                                ? Image.memory(_png!)
                                : const SizedBox(),
                          ),
                        ),
                      ),
          ),
          if (_total > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _load();
                          }
                        : null,
                  ),
                  Text('$_page / $_total'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _page < _total
                        ? () {
                            setState(() => _page++);
                            _load();
                          }
                        : null,
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Kembali & Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => EditorResultDialog(
                            fileName: widget.fileName,
                            bytes: widget.bytes,
                          ),
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Simpan / Unduh'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
