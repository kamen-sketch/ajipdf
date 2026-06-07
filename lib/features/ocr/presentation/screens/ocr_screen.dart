import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as spdf;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show AnchorElement, document;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/subscription_provider.dart';
import '../../../../core/providers/document_provider.dart';
import '../../../../core/services/ocr_service.dart';

/// OCR Screen — extract text dari scanned PDF/gambar
/// Cross-platform: tesseract.js di web, google_mlkit di native
class OCRScreen extends ConsumerStatefulWidget {
  const OCRScreen({super.key});

  @override
  ConsumerState<OCRScreen> createState() => _OCRScreenState();
}

class _OCRScreenState extends ConsumerState<OCRScreen> {
  String _selectedLang = 'eng';
  bool _isProcessing = false;
  double _progress = 0;
  String? _extractedText;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _quoteIndex = 0;

  /// Motivational quotes shown during OCR processing
  static const _quotes = [
    '"The only way to do great work is to love what you do." — Steve Jobs',
    '"Innovation distinguishes between a leader and a follower." — Steve Jobs',
    '"Patience is bitter, but its fruit is sweet." — Aristotle',
    '"The best time to plant a tree was 20 years ago. The second best time is now." — Chinese Proverb',
    '"Technology is best when it brings people together." — Matt Mullenweg',
    '"Any sufficiently advanced technology is indistinguishable from magic." — Arthur C. Clarke',
    '"The future belongs to those who believe in the beauty of their dreams." — Eleanor Roosevelt',
    '"Success is not final, failure is not fatal: it is the courage to continue that counts." — Winston Churchill',
    '"Strive not to be a success, but rather to be of value." — Albert Einstein',
    '"The only limit to our realization of tomorrow is our doubts of today." — Franklin D. Roosevelt',
    '"In the middle of every difficulty lies opportunity." — Albert Einstein',
    '"It does not matter how slowly you go as long as you do not stop." — Confucius',
    '"What we know is a drop, what we don\'t know is an ocean." — Isaac Newton',
    '"Turn your wounds into wisdom." — Oprah Winfrey',
    '"The greatest glory in living lies not in never falling, but in rising every time we fall." — Nelson Mandela',
  ];

  final _languages = [
    ('eng', 'English', Icons.language),
    ('ind', 'Indonesian', Icons.language),
    ('chi_sim', 'Chinese (中文)', Icons.translate),
    ('jpn', 'Japanese (日本語)', Icons.translate),
    ('kor', 'Korean (한국어)', Icons.translate),
    ('ara', 'Arabic (العربية)', Icons.translate),
    ('fra', 'French', Icons.language),
    ('deu', 'German', Icons.language),
    ('spa', 'Spanish', Icons.language),
  ];

  late final OcrService _ocrService;
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    _ocrService = OcrService();
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startQuoteRotation() {
    _quoteTimer?.cancel();
    _quoteTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isProcessing) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() => _quoteIndex = (_quoteIndex + 1) % _quotes.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(isProProvider);
    final doc = ref.watch(activeDocumentProvider);

    if (!isPro) {
      return Scaffold(
        appBar: AppBar(title: const Text('OCR')),
        body: _buildLockedNotice(context),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR - Text Recognition'),
        actions: [
          if (_extractedText != null)
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: 'Copy all',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _extractedText!));
                _snack('Text copied to clipboard');
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.document_scanner, color: AppTheme.primaryColor),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'OCR mengekstrak teks dari PDF/gambar yang di-scan.\n'
                      'Powered by Tesseract (web) / ML Kit (mobile).\n'
                      'Hasilnya bisa di-copy atau di-search.',
                      style:
                          TextStyle(color: AppTheme.primaryColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Language selector
            const Text('Bahasa OCR:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _languages.map((l) {
                final selected = _selectedLang == l.$1;
                return ChoiceChip(
                  avatar: Icon(l.$3,
                      size: 14, color: selected ? Colors.white : null),
                  label: Text(l.$2,
                      style: TextStyle(
                          fontSize: 12, color: selected ? Colors.white : null)),
                  selected: selected,
                  selectedColor: AppTheme.primaryColor,
                  onSelected: (_) => setState(() => _selectedLang = l.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Document selector
            const Text('Dokumen:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf,
                    color: AppTheme.primaryColor),
                title: Text(doc?.name ?? 'Belum ada dokumen'),
                subtitle: doc != null ? Text(doc.readableSize) : null,
                trailing: const Icon(Icons.folder_open),
                onTap: _isProcessing ? null : _pickDocument,
              ),
            ),
            const SizedBox(height: 20),

            // Process button
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: (doc == null || _isProcessing) ? null : _runOCR,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.document_scanner),
                label: Text(_isProcessing
                    ? 'Processing... ${(_progress * 100).round()}%'
                    : 'Extract Text (OCR)'),
              ),
            ),

            // Progress + motivational quotes
            if (_isProcessing) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Container(
                  key: ValueKey(_quoteIndex),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.format_quote,
                          color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _quotes[_quoteIndex % _quotes.length],
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'OCR sedang memproses... Proses ini bisa memakan waktu beberapa menit tergantung jumlah halaman.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppTheme.errorColor),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: AppTheme.errorColor))),
                ]),
              ),
            ],

            // Results
            if (_extractedText != null) ...[
              const SizedBox(height: 20),
              Row(children: [
                const Text('Hasil Ekstraksi:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _extractedText!));
                    _snack('Copied');
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Cari dalam teks...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 400),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _extractedText!,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_searchQuery.allMatches(_extractedText!.toLowerCase()).length} matches',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              // Overlay button — embed text ke PDF sebagai invisible text layer
              FilledButton.icon(
                onPressed: _isProcessing ? null : _overlayTextToPdf,
                icon: const Icon(Icons.layers),
                label: const Text('Overlay ke PDF (Buat Searchable)'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Overlay menambahkan invisible text layer di atas halaman PDF, '
                'sehingga PDF bisa di-search dan di-copy tanpa mengubah tampilan.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLockedNotice(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.document_scanner, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text('OCR — Fitur Pro',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Upgrade ke Pro untuk mengekstrak teks dari PDF/gambar scan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/subscription'),
              icon: const Icon(Icons.workspace_premium),
              label: const Text('Upgrade to Pro'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocument() async {
    final doc = await ref.read(documentsProvider.notifier).pickPdf();
    if (doc != null) {
      ref.read(activeDocumentProvider.notifier).state = doc;
      setState(() {
        _extractedText = null;
        _error = null;
      });
    }
  }

  Future<void> _runOCR() async {
    final doc = ref.read(activeDocumentProvider);
    if (doc?.bytes == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _extractedText = null;
      _error = null;
      _quoteIndex = 0;
    });

    // Start quote rotation timer
    _startQuoteRotation();

    try {
      final pdfBytes = doc!.bytes!;
      setState(() => _progress = 0.1);

      // OCR service handles everything:
      // Web: PDF bytes → pdf.js render → canvas PNG → tesseract.js → text
      // Native: PDF bytes → render page → ML Kit → text
      final result =
          await _ocrService.recognizeFromBytes(pdfBytes, lang: _selectedLang);

      setState(() => _progress = 1.0);

      if (result.success) {
        setState(() {
          _extractedText = result.text.isEmpty
              ? 'Tidak ditemukan teks. Pastikan PDF berisi konten scan dengan resolusi min 150 DPI.'
              : result.text;
        });
      } else {
        setState(() => _error = result.error ?? 'OCR gagal.');
      }
    } catch (e) {
      setState(() => _error = 'OCR error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Overlay extracted text ke PDF sebagai invisible text layer
  /// Ini membuat PDF searchable tanpa mengubah visual
  Future<void> _overlayTextToPdf() async {
    final doc = ref.read(activeDocumentProvider);
    if (doc?.bytes == null || _extractedText == null) return;

    setState(() => _isProcessing = true);

    try {
      final pdfBytes = doc!.bytes!;
      final pdf = spdf.PdfDocument(inputBytes: pdfBytes);

      // Split extracted text per page (our OCR output format: --- Page N ---)
      final pageTexts = _splitTextByPages(_extractedText!);

      for (int i = 0; i < pdf.pages.count && i < pageTexts.length; i++) {
        final page = pdf.pages[i];
        final text = pageTexts[i];
        if (text.trim().isEmpty) continue;

        // Add invisible text layer — transparent font drawn on top of page
        // This makes the PDF searchable without changing visual appearance
        final graphics = page.graphics;
        graphics.save();
        graphics.setTransparency(0.01); // Nearly invisible

        // Draw text in small font covering the page area
        final font = spdf.PdfStandardFont(spdf.PdfFontFamily.helvetica, 1);
        final brush =
            spdf.PdfSolidBrush(spdf.PdfColor(0, 0, 0, 0)); // Transparent

        // Split text into lines and position them
        final lines = text.split('\n');
        final lineHeight = page.size.height / (lines.length + 1);

        for (int l = 0; l < lines.length; l++) {
          if (lines[l].trim().isEmpty) continue;
          graphics.drawString(
            lines[l],
            font,
            brush: brush,
            bounds:
                Rect.fromLTWH(0, l * lineHeight, page.size.width, lineHeight),
          );
        }

        graphics.restore();
      }

      // Save PDF with text overlay
      final outputBytes = Uint8List.fromList(pdf.saveSync());
      pdf.dispose();

      // Update document in provider
      final updated = doc.withBytes(outputBytes);
      ref.read(activeDocumentProvider.notifier).state = updated;
      ref.read(documentsProvider.notifier).updateBytes(doc.id, outputBytes);

      _snack(
          'PDF sekarang searchable! (${pageTexts.length} halaman di-overlay)');

      // Offer download
      if (mounted && kIsWeb) {
        _showOverlayDownloadDialog(outputBytes, doc.name);
      }
    } catch (e) {
      _snack('Gagal overlay: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Split OCR text by page markers (--- Page N ---)
  List<String> _splitTextByPages(String fullText) {
    final pages = <String>[];
    final sections = fullText.split(RegExp(r'---\s*Page\s+\d+\s*---'));
    for (final section in sections) {
      if (section.trim().isNotEmpty) {
        pages.add(section.trim());
      }
    }
    // If no page markers found, treat as single page
    if (pages.isEmpty) pages.add(fullText);
    return pages;
  }

  void _showOverlayDownloadDialog(Uint8List bytes, String originalName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('OCR Overlay Selesai'),
        content: const Text(
          'PDF sekarang bisa di-search. Download file untuk menyimpan versi searchable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadOverlayedPdf(bytes, 'searchable_$originalName');
            },
            icon: const Icon(Icons.download),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadOverlayedPdf(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      final base64Data = base64Encode(bytes);
      final href = 'data:application/pdf;base64,$base64Data';
      final anchor = html.AnchorElement(href: href)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
    }
    _snack('Download dimulai: $fileName');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
