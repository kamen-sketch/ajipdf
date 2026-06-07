import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Model dokumen PDF yang sedang/baru dibuka.
class PdfDocumentInfo {
  final String id; // Unique identifier for this document
  final String name;
  final String? path;
  final Uint8List? bytes;
  final int size;
  final DateTime lastOpened;

  PdfDocumentInfo({
    String? id,
    required this.name,
    this.path,
    this.bytes,
    required this.size,
    required this.lastOpened,
  }) : id = id ?? const Uuid().v4();

  String get readableSize {
    if (size <= 0) return '-';
    const units = ['B', 'KB', 'MB', 'GB'];
    var s = size.toDouble();
    var i = 0;
    while (s >= 1024 && i < units.length - 1) {
      s /= 1024;
      i++;
    }
    return '${s.toStringAsFixed(s < 10 && i > 0 ? 1 : 0)} ${units[i]}';
  }

  /// Copy with different id (for new instance)
  PdfDocumentInfo copyWithNewId() {
    return PdfDocumentInfo(
      name: name,
      path: path,
      bytes: bytes,
      size: size,
      lastOpened: lastOpened,
    );
  }

  /// Update bytes while keeping same id (for save operations)
  PdfDocumentInfo withBytes(Uint8List newBytes) {
    return PdfDocumentInfo(
      id: id,
      name: name,
      path: path,
      bytes: newBytes,
      size: newBytes.length,
      lastOpened: DateTime.now(),
    );
  }
}

/// State daftar dokumen (recent).
class DocumentsNotifier extends StateNotifier<List<PdfDocumentInfo>> {
  DocumentsNotifier() : super(const []);

  /// Buka dialog pemilih file PDF. Mengembalikan dokumen terpilih, atau null.
  Future<PdfDocumentInfo?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // diperlukan untuk web
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    // Di web, file.path getter akan throw exception, jadi jangan diakses.
    // Gunakan bytes saja untuk cross-platform.
    final doc = PdfDocumentInfo(
      name: file.name,
      path: kIsWeb ? null : file.path, // aman untuk web
      bytes: file.bytes,
      size: file.size,
      lastOpened: DateTime.now(),
    );

    addRecent(doc);
    return doc;
  }

  /// Pilih beberapa PDF sekaligus (untuk merge).
  Future<List<PdfDocumentInfo>> pickMultiplePdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return [];

    final docs = result.files
        .map((f) => PdfDocumentInfo(
              name: f.name,
              path: kIsWeb ? null : f.path, // aman untuk web
              bytes: f.bytes,
              size: f.size,
              lastOpened: DateTime.now(),
            ))
        .toList();

    for (final d in docs) {
      addRecent(d);
    }
    return docs;
  }

  /// Tambahkan ke daftar recent (paling baru di atas, max 20, tanpa duplikat id).
  void addRecent(PdfDocumentInfo doc) {
    final updated = [
      doc,
      // Hapus duplikat berdasarkan ID (bukan nama) agar bytes yang benar ikut tersimpan
      ...state.where((d) => d.id != doc.id),
    ];
    state = updated.take(20).toList();
  }

  /// Update bytes dokumen yang sudah ada di recent list berdasarkan id.
  void updateBytes(String id, Uint8List newBytes) {
    state = state.map((d) {
      if (d.id != id) return d;
      return d.withBytes(newBytes);
    }).toList();
  }

  void clear() => state = const [];
}

final documentsProvider =
    StateNotifierProvider<DocumentsNotifier, List<PdfDocumentInfo>>((ref) {
  return DocumentsNotifier();
});

/// Dokumen yang sedang aktif dibuka di viewer/editor.
final activeDocumentProvider = StateProvider<PdfDocumentInfo?>((ref) => null);
