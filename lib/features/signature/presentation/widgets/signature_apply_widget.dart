import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/providers/document_provider.dart';
import '../../../../core/services/pdf_raster_service.dart';
import '../../../pdf_editor/presentation/widgets/editor_result.dart';

/// Widget untuk menempel tanda tangan ke PDF dengan posisi visual (drag).
class SignatureApplyWidget extends ConsumerStatefulWidget {
  const SignatureApplyWidget({
    super.key,
    required this.document,
    required this.signatureData,
  });

  final PdfDocumentInfo document;
  final Uint8List signatureData;

  @override
  ConsumerState<SignatureApplyWidget> createState() =>
      _SignatureApplyWidgetState();
}

class _SignatureApplyWidgetState extends ConsumerState<SignatureApplyWidget> {
  int _selectedPage = 1;
  int _totalPages = 1;

  // Posisi & ukuran signature dalam koordinat halaman (PDF points, origin kiri-atas).
  Offset _posPt = const Offset(50, 50);
  double _sigWidthPt = 160;
  double _sigHeightPt = 64;
  double _opacity = 1.0;

  bool _processing = false;
  bool _loadingPreview = true;

  // Preview halaman (raster) + ukuran halaman dalam points.
  Uint8List? _pagePng;
  double _pagePtWidth = 595; // default A4
  double _pagePtHeight = 842;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final bytes = widget.document.bytes;
    if (bytes == null) {
      setState(() => _loadingPreview = false);
      return;
    }
    try {
      final pdf = PdfDocument(inputBytes: bytes);
      _totalPages = pdf.pages.count;
      pdf.dispose();
    } catch (_) {}
    await _loadPreview();
  }

  Future<void> _loadPreview() async {
    final bytes = widget.document.bytes;
    if (bytes == null) return;
    setState(() => _loadingPreview = true);
    try {
      final page =
          await PdfRasterService.renderPage(bytes, _selectedPage, scale: 1.0);
      setState(() {
        _pagePng = page.imageBytes;
        _pagePtWidth = page.pointWidth;
        _pagePtHeight = page.pointHeight;
        _loadingPreview = false;
      });
    } catch (e) {
      // Fallback: tetap izinkan apply tanpa preview.
      setState(() => _loadingPreview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tempel Tanda Tangan'),
        actions: [
          if (_totalPages > 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('Hlm $_selectedPage/$_totalPages'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_totalPages > 1) _buildPageNav(),
          Expanded(child: _buildPreviewArea()),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildPageNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _selectedPage > 1
                ? () {
                    setState(() => _selectedPage--);
                    _loadPreview();
                  }
                : null,
          ),
          Text('Halaman $_selectedPage'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _selectedPage < _totalPages
                ? () {
                    setState(() => _selectedPage++);
                    _loadPreview();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_loadingPreview) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Hitung skala tampilan agar halaman muat di area, jaga aspect ratio.
        final maxW = constraints.maxWidth - 24;
        final maxH = constraints.maxHeight - 24;
        final pageAspect = _pagePtWidth / _pagePtHeight;
        double dispW = maxW;
        double dispH = dispW / pageAspect;
        if (dispH > maxH) {
          dispH = maxH;
          dispW = dispH * pageAspect;
        }
        final scale = dispW / _pagePtWidth; // points -> display px

        return Center(
          child: Container(
            width: dispW,
            height: dispH,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              color: Colors.white,
            ),
            child: Stack(
              children: [
                // Page image
                if (_pagePng != null)
                  Positioned.fill(
                    child: Image.memory(_pagePng!, fit: BoxFit.fill),
                  )
                else
                  const Center(child: Text('Preview tidak tersedia')),
                // Draggable signature
                Positioned(
                  left: _posPt.dx * scale,
                  top: _posPt.dy * scale,
                  child: GestureDetector(
                    onPanUpdate: (d) {
                      setState(() {
                        final nx = _posPt.dx + d.delta.dx / scale;
                        final ny = _posPt.dy + d.delta.dy / scale;
                        _posPt = Offset(
                          nx.clamp(0, _pagePtWidth - _sigWidthPt),
                          ny.clamp(0, _pagePtHeight - _sigHeightPt),
                        );
                      });
                    },
                    child: Opacity(
                      opacity: _opacity,
                      child: Container(
                        width: _sigWidthPt * scale,
                        height: _sigHeightPt * scale,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 1.2),
                        ),
                        child: Image.memory(widget.signatureData,
                            fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Seret tanda tangan untuk mengatur posisi',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          Row(
            children: [
              const SizedBox(width: 60, child: Text('Lebar')),
              Expanded(
                child: Slider(
                  value: _sigWidthPt,
                  min: 60,
                  max: _pagePtWidth,
                  onChanged: (v) => setState(() {
                    _sigWidthPt = v;
                    if (_posPt.dx + _sigWidthPt > _pagePtWidth) {
                      _posPt = Offset(
                          (_pagePtWidth - _sigWidthPt).clamp(0, _pagePtWidth),
                          _posPt.dy);
                    }
                  }),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 60, child: Text('Tinggi')),
              Expanded(
                child: Slider(
                  value: _sigHeightPt,
                  min: 30,
                  max: _pagePtHeight / 2,
                  onChanged: (v) => setState(() {
                    _sigHeightPt = v;
                    if (_posPt.dy + _sigHeightPt > _pagePtHeight) {
                      _posPt = Offset(
                          _posPt.dx,
                          (_pagePtHeight - _sigHeightPt)
                              .clamp(0, _pagePtHeight));
                    }
                  }),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 60, child: Text('Opasitas')),
              Expanded(
                child: Slider(
                  value: _opacity,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (v) => setState(() => _opacity = v),
                ),
              ),
              Text('${(_opacity * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _processing ? null : _applySignature,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: const Text('Tempel Tanda Tangan'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applySignature() async {
    setState(() => _processing = true);
    try {
      final bytes = widget.document.bytes;
      if (bytes == null) throw Exception('Dokumen tidak punya data');

      final pdf = PdfDocument(inputBytes: bytes);
      final pageIndex = _selectedPage - 1;
      final page = pdf.pages[pageIndex];

      // Konversi koordinat preview (berdasarkan ukuran points yang dirender)
      // ke koordinat halaman aktual. Origin Syncfusion = kiri-atas (sama).
      final actualSize = page.getClientSize();
      final sx = actualSize.width / _pagePtWidth;
      final sy = actualSize.height / _pagePtHeight;

      final rect = Rect.fromLTWH(
        _posPt.dx * sx,
        _posPt.dy * sy,
        _sigWidthPt * sx,
        _sigHeightPt * sy,
      );

      final sigImage = PdfBitmap(widget.signatureData);
      final gfx = page.graphics;
      gfx.save();
      gfx.setTransparency(_opacity);
      gfx.drawImage(sigImage, rect);
      gfx.restore();

      final result = Uint8List.fromList(await pdf.save());
      pdf.dispose();

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => EditorResultDialog(
            fileName: 'signed_${widget.document.name}',
            bytes: result,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menempel tanda tangan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}
