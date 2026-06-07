// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:flutter/material.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Unit tests memverifikasi alur save/load annotation.
///
/// Test 10 mendokumentasikan BUG yang terjadi jika _viewerBytes tidak
/// diupdate dari provider saat session baru dibuka (initState).
///
/// Fix yang benar:
/// - _viewerBytes TIDAK berubah saat save (mencegah SfPdfViewer reload)
/// - _viewerBytes di-set dari provider saat initState (session baru = bytes terbaru)
/// - Provider selalu menyimpan bytes terbaru setelah setiap save
void main() {
  // ─── HELPERS ─────────────────────────────────────────────────────────────

  Uint8List makeTwoPagePdf() {
    final doc = PdfDocument();
    final p1 = doc.pages.add();
    p1.graphics.drawString(
        'Hello page one', PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(10, 10, 300, 20));
    final p2 = doc.pages.add();
    p2.graphics.drawString(
        'Hello page two', PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(10, 10, 300, 20));
    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  // Simulasi: SfPdfViewer load bytes → user highlight → saveDocument() → return new bytes
  // isDocumentSaved=false → load dari bytes yang diberikan
  Uint8List simulateViewerSaveDocument(
    Uint8List viewerBytes, // bytes yang di-load ke viewer (dari provider)
    List<Map<String, dynamic>> newAnnotations, // [{page, label}]
  ) {
    final doc = PdfDocument(inputBytes: viewerBytes);

    // _retrieveAnnotations() — baca semua anotasi dari semua halaman
    print('  [Viewer] Loading from bytes (${viewerBytes.length} bytes)');
    for (int i = 0; i < doc.pages.count; i++) {
      final count = doc.pages[i].annotations.count;
      if (count > 0) {
        print('    Page ${i + 1}: $count annotations');
        for (int j = 0; j < count; j++) {
          print('      - "${doc.pages[i].annotations[j].text}"');
        }
      }
    }

    // Tambah anotasi baru (user highlight di sesi ini)
    for (final ann in newAnnotations) {
      final page = doc.pages[ann['page'] as int];
      page.annotations.add(PdfTextMarkupAnnotation(
        const Rect.fromLTWH(50, 50, 100, 14),
        ann['label'] as String,
        PdfColor(255, 255, 0),
        textMarkupAnnotationType: PdfTextMarkupAnnotationType.highlight,
      ));
      print(
          '  [Viewer] Added: "${ann['label']}" to page ${(ann["page"] as int) + 1}');
    }

    // saveDocument() → _document.save()
    final savedBytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    print('  [Viewer] Saved ${savedBytes.length} bytes');
    return savedBytes;
  }

  List<String> readAllLabels(Uint8List bytes) {
    final doc = PdfDocument(inputBytes: bytes);
    final labels = <String>[];
    for (int i = 0; i < doc.pages.count; i++) {
      for (int j = 0; j < doc.pages[i].annotations.count; j++) {
        labels.add('P${i + 1}:${doc.pages[i].annotations[j].text}');
      }
    }
    doc.dispose();
    return labels;
  }

  int countPage(Uint8List bytes, int page0indexed) {
    final doc = PdfDocument(inputBytes: bytes);
    final c = doc.pages[page0indexed].annotations.count;
    doc.dispose();
    return c;
  }

  // ─── TESTS ───────────────────────────────────────────────────────────────

  group('PDF Annotation Persistence — Core', () {
    test('1. PDF awal tidak punya anotasi', () {
      final b = makeTwoPagePdf();
      expect(countPage(b, 0), 0);
      expect(countPage(b, 1), 0);
    });

    test('2. Save P1 → load → P1 tetap ada', () {
      final original = makeTwoPagePdf();
      final saved = simulateViewerSaveDocument(original, [
        {'page': 0, 'label': 'P1_A'}
      ]);
      expect(countPage(saved, 0), 1);
      expect(countPage(saved, 1), 0);
    });

    test('3. Save P1+P2 → load → keduanya ada', () {
      final original = makeTwoPagePdf();
      final saved = simulateViewerSaveDocument(original, [
        {'page': 0, 'label': 'P1_A'},
        {'page': 1, 'label': 'P2_A'},
      ]);
      expect(countPage(saved, 0), 1);
      expect(countPage(saved, 1), 1);
      expect(readAllLabels(saved), containsAll(['P1:P1_A', 'P2:P2_A']));
    });
  });

  group('PDF Annotation Persistence — Multi-Session (THE BUG)', () {
    test(
        '4. [S1+S2] S1: P1+P2 → save → '
        'S2 load providerBytes → tambah P2_new → S1_P1 harus tetap ada', () {
      print('\n=== SESSION 1 ===');
      final original = makeTwoPagePdf();

      // S1: viewer load original, user highlight P1 dan P2, lalu save
      // _viewerBytes = original (tidak berubah selama S1)
      // provider updated = savedAfterS1
      final savedAfterS1 = simulateViewerSaveDocument(original, [
        {'page': 0, 'label': 'S1_P1'},
        {'page': 1, 'label': 'S1_P2'},
      ]);

      print('\nAfter S1 save: ${readAllLabels(savedAfterS1)}');
      expect(countPage(savedAfterS1, 0), 1);
      expect(countPage(savedAfterS1, 1), 1);

      print('\n=== SESSION 2 ===');
      // S2: user close → open lagi
      // initState: _viewerBytes = provider bytes = savedAfterS1 ← INI KUNCINYA
      // viewer load dari savedAfterS1 → P1 dan P2 terbaca
      // user tambah P2_new → save
      final savedAfterS2 = simulateViewerSaveDocument(
          savedAfterS1, // ← _viewerBytes = savedAfterS1 (bukan original!)
          [
            {'page': 1, 'label': 'S2_P2'}
          ]);

      final labels = readAllLabels(savedAfterS2);
      print('\nAfter S2 save: $labels');

      expect(countPage(savedAfterS2, 0), 1,
          reason: 'S1_P1 harus TETAP ADA setelah S2 save!');
      expect(countPage(savedAfterS2, 1), 2, reason: 'S1_P2 + S2_P2 di page 2');
      expect(labels, containsAll(['P1:S1_P1', 'P2:S1_P2', 'P2:S2_P2']));
    });

    test(
        '5. [S1+S2+S3] 3 sesi berturut — '
        'semua anotasi semua sesi harus ada', () {
      print('\n=== SESSION 1 ===');
      final original = makeTwoPagePdf();
      final s1bytes = simulateViewerSaveDocument(original, [
        {'page': 0, 'label': 'S1_P1'},
        {'page': 1, 'label': 'S1_P2'},
      ]);

      print('\n=== SESSION 2 ===');
      // initState: _viewerBytes = s1bytes (provider)
      final s2bytes = simulateViewerSaveDocument(s1bytes, [
        {'page': 1, 'label': 'S2_P2'}
      ]);

      print('\n=== SESSION 3 ===');
      // initState: _viewerBytes = s2bytes (provider)
      final s3bytes = simulateViewerSaveDocument(s2bytes, [
        {'page': 1, 'label': 'S3_P2'}
      ]);

      final labels = readAllLabels(s3bytes);
      print('\nFinal labels: $labels');

      expect(countPage(s3bytes, 0), 1,
          reason: 'S1_P1 harus masih ada di page 1!');
      expect(countPage(s3bytes, 1), 3,
          reason: 'S1_P2 + S2_P2 + S3_P2 di page 2');
      expect(labels,
          containsAll(['P1:S1_P1', 'P2:S1_P2', 'P2:S2_P2', 'P2:S3_P2']));
    });

    test(
        '6. [BUG DOKUMENTASI] Jika _viewerBytes = bytes LAMA (bukan provider), '
        'maka S1_P1 hilang', () {
      // Ini mendokumentasikan bug yang terjadi jika kode salah:
      // _viewerBytes = originalBytes (lama), bukan savedAfterS1
      final original = makeTwoPagePdf();

      // S1 save
      final savedAfterS1 = simulateViewerSaveDocument(original, [
        {'page': 0, 'label': 'S1_P1'},
        {'page': 1, 'label': 'S1_P2'},
      ]);
      // savedAfterS1 tersimpan di provider ✓

      // BUG: _viewerBytes tidak di-update dari provider
      // → viewer load dari 'original' (bukan savedAfterS1)
      final buggyResult = simulateViewerSaveDocument(
          original, // ← BUG: seharusnya savedAfterS1
          [
            {'page': 1, 'label': 'S2_P2'}
          ]);

      final labels = readAllLabels(buggyResult);
      print('BUG result labels: $labels');

      // Verifikasi bug: S1_P1 dan S1_P2 hilang karena load dari bytes lama
      expect(countPage(buggyResult, 0), 0,
          reason: 'BUG confirmed: S1_P1 hilang karena load dari bytes lama');
      expect(labels, isNot(contains('P1:S1_P1')),
          reason: 'BUG: S1_P1 seharusnya ada tapi tidak ada');
    });

    test('7. [FIX VERIFICATION] Provider bytes harus selalu yang terbaru', () {
      // Simulasi state yang benar:
      // - providerBytes selalu diupdate setelah save
      // - initState selalu membaca dari providerBytes
      Uint8List providerBytes = makeTwoPagePdf();

      // Session 1
      print('\n=== SESSION 1 ===');
      final s1saved = simulateViewerSaveDocument(providerBytes, [
        {'page': 0, 'label': 'S1_P1'},
        {'page': 1, 'label': 'S1_P2'},
      ]);
      providerBytes =
          s1saved; // update provider ← ini yang terjadi di _saveDocument()

      // Session 2: initState menggunakan providerBytes yang sudah diupdate
      print('\n=== SESSION 2 ===');
      final s2viewerBytes =
          providerBytes; // ← initState: _viewerBytes = providerBytes
      final s2saved = simulateViewerSaveDocument(s2viewerBytes, [
        {'page': 1, 'label': 'S2_P2'}
      ]);
      providerBytes = s2saved; // update provider

      // Session 3: initState menggunakan providerBytes yang sudah diupdate
      print('\n=== SESSION 3 ===');
      final s3viewerBytes =
          providerBytes; // ← initState: _viewerBytes = providerBytes
      final s3saved = simulateViewerSaveDocument(s3viewerBytes, [
        {'page': 1, 'label': 'S3_P2'}
      ]);
      providerBytes = s3saved;

      final labels = readAllLabels(providerBytes);
      print('\nFinal provider labels: $labels');

      expect(countPage(providerBytes, 0), 1,
          reason: 'S1_P1 harus ada karena provider bytes selalu diupdate');
      expect(countPage(providerBytes, 1), 3);
      expect(
          labels, containsAll(['P1:S1_P1', 'P2:S1_P2', 'P2:S2_P2', 'P2:S3_P2']),
          reason: 'Semua anotasi dari semua sesi harus ada');
    });

    test('8. Save tanpa anotasi baru tidak menghapus anotasi lama', () {
      final original = makeTwoPagePdf();
      final s1saved = simulateViewerSaveDocument(original, [
        {'page': 0, 'label': 'P1_KEEP'},
        {'page': 1, 'label': 'P2_KEEP'},
      ]);

      // Session 2: open, tidak tambah anotasi baru, langsung save
      final s2saved = simulateViewerSaveDocument(s1saved, []);

      expect(countPage(s2saved, 0), 1,
          reason: 'P1_KEEP tidak boleh hilang setelah save tanpa edit');
      expect(countPage(s2saved, 1), 1,
          reason: 'P2_KEEP tidak boleh hilang setelah save tanpa edit');
    });
  });
}
