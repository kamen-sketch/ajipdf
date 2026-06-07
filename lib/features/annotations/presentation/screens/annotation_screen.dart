import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/document_provider.dart';

/// Annotation Screen — Panduan & shortcut ke fitur anotasi.
///
/// Perbedaan dengan Viewer:
/// - **Viewer**: Membaca PDF + markup inline (highlight, underline, dll.)
/// - **Annotate**: Panduan cara anotasi + tips + shortcut langsung ke mode
///   markup tanpa harus membuka PDF manual dulu.
///
/// Anotasi sebenarnya dilakukan di PDF Viewer sebagai overlay (ISO 32000).
class AnnotationScreen extends ConsumerWidget {
  const AnnotationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(activeDocumentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Annotate PDF')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(Icons.edit_note_rounded,
                size: 64, color: AppTheme.primaryColor),
            const SizedBox(height: 12),
            Text(
              'Anotasi langsung di PDF',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pilih teks di halaman PDF, lalu gunakan tombol markup untuk '
              'menambahkan highlight, underline, atau strikethrough. '
              'Anotasi tersimpan dalam PDF (ISO 32000) — terbaca di semua reader.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Quick start buttons
            if (doc != null) ...[
              Card(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                child: ListTile(
                  leading:
                      const Icon(Icons.menu_book, color: AppTheme.primaryColor),
                  title: Text('Annotate: ${doc.name}',
                      overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Buka di Viewer & mulai markup'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push('/viewer'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: () => _openAndAnnotate(context, ref),
              icon: const Icon(Icons.folder_open),
              label: Text(doc == null
                  ? 'Pilih PDF untuk di-annotate'
                  : 'Buka PDF lain'),
            ),

            const SizedBox(height: 32),

            // Guide / tips
            Text('Cara pakai:',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildStep('1', 'Buka PDF di viewer',
                'Klik tombol di atas atau buka dari dokumen.'),
            _buildStep(
                '2', 'Pilih teks', 'Tekan & seret untuk memilih kata/kalimat.'),
            _buildStep('3', 'Pilih markup',
                'Tekan ikon ✏️ di toolbar — highlight, underline, strikethrough.'),
            _buildStep('4', 'Simpan',
                'Tekan ikon 💾 — anotasi tersimpan di PDF & bisa di-download.'),

            const SizedBox(height: 24),

            // Annotation types info
            Text('Jenis anotasi:',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(Icons.highlight, 'Highlight', Colors.yellow.shade700,
                    isFree: true),
                _buildChip(Icons.format_underlined, 'Underline', Colors.blue),
                _buildChip(
                    Icons.format_strikethrough, 'Strikethrough', Colors.red),
                _buildChip(Icons.gesture, 'Squiggly', Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '🟡 Highlight gratis  •  Lainnya memerlukan Pro',
              style: TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primaryColor,
              child: Text(num,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color,
      {bool isFree = false}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      side: isFree ? BorderSide(color: color) : BorderSide.none,
      backgroundColor: color.withValues(alpha: 0.1),
    );
  }

  Future<void> _openAndAnnotate(BuildContext context, WidgetRef ref) async {
    final doc = await ref.read(documentsProvider.notifier).pickPdf();
    if (doc == null) return;
    ref.read(activeDocumentProvider.notifier).state = doc;
    if (context.mounted) context.push('/viewer');
  }
}
