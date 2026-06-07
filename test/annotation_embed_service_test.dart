// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:flutter/material.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:pdf_enterprise_suite/core/services/annotation_embed_service.dart';

Uint8List _makePdf({int pages = 2}) {
  final doc = PdfDocument();
  for (int i = 0; i < pages; i++) {
    doc.pages.add().graphics.drawString(
          'Page ${i + 1}',
          PdfStandardFont(PdfFontFamily.helvetica, 12),
          bounds: const Rect.fromLTWH(10, 10, 200, 20),
        );
  }
  final b = doc.saveSync();
  doc.dispose();
  return Uint8List.fromList(b);
}

void main() {
  group('AnnotationEmbedService', () {
    test('1. PDF tanpa metadata → extract returns empty list', () {
      final pdf = _makePdf();
      final result = AnnotationEmbedService.extractAnnotations(pdf);
      expect(result, isEmpty);
    });

    test('2. Embed list kosong → extract returns empty list', () {
      final pdf = _makePdf();
      final embedded = AnnotationEmbedService.embedAnnotations(pdf, []);
      final result = AnnotationEmbedService.extractAnnotations(embedded);
      expect(result, isEmpty);
    });

    test('3. Embed 1 anotasi → extract → data identik', () {
      final pdf = _makePdf();
      final ann = {
        'id': 'abc-123',
        'type': 'highlight',
        'pageIndex': 0,
        'x': 10.0,
        'y': 10.0,
        'width': 100.0,
        'height': 14.0,
        'color': 0xFFFFFF00,
        'opacity': 1.0,
        'text': null,
        'documentId': 'doc-1',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'updatedAt': '2025-01-01T00:00:00.000Z',
      };

      final embedded = AnnotationEmbedService.embedAnnotations(pdf, [ann]);
      final result = AnnotationEmbedService.extractAnnotations(embedded);

      expect(result.length, 1);
      expect(result[0]['id'], 'abc-123');
      expect(result[0]['type'], 'highlight');
      expect(result[0]['pageIndex'], 0);
      expect(result[0]['documentId'], 'doc-1');
    });

    test('4. Embed 5 anotasi di berbagai halaman → extract semua ada', () {
      final pdf = _makePdf(pages: 3);
      final annotations = List.generate(
        5,
        (i) => {
          'id': 'id-$i',
          'type': i % 2 == 0 ? 'highlight' : 'underline',
          'pageIndex': i % 3,
          'x': 10.0 * i,
          'y': 10.0,
          'width': 80.0,
          'height': 14.0,
          'color': 0xFFFFFF00,
          'opacity': 0.8,
          'text': 'Note $i',
          'documentId': 'doc-multi',
          'createdAt': '2025-01-0${i + 1}T00:00:00.000Z',
          'updatedAt': '2025-01-0${i + 1}T00:00:00.000Z',
        },
      );

      final embedded =
          AnnotationEmbedService.embedAnnotations(pdf, annotations);
      final result = AnnotationEmbedService.extractAnnotations(embedded);

      expect(result.length, 5);
      for (int i = 0; i < 5; i++) {
        expect(result[i]['id'], 'id-$i');
        expect(result[i]['pageIndex'], i % 3);
      }
    });

    test('5. [SKENARIO BUG FIX] Multi-session — semua anotasi tetap ada', () {
      final pdf = _makePdf(pages: 2);

      // Session 1: tambah P1 dan P2
      final s1Annotations = [
        {
          'id': 'S1_P1',
          'type': 'highlight',
          'pageIndex': 0,
          'x': 10.0,
          'y': 10.0,
          'width': 100.0,
          'height': 14.0,
          'color': 0xFFFFFF00,
          'opacity': 1.0,
          'text': null,
          'documentId': 'doc-x',
          'createdAt': '2025-01-01T00:00:00.000Z',
          'updatedAt': '2025-01-01T00:00:00.000Z',
        },
        {
          'id': 'S1_P2',
          'type': 'highlight',
          'pageIndex': 1,
          'x': 10.0,
          'y': 10.0,
          'width': 100.0,
          'height': 14.0,
          'color': 0xFFFFFF00,
          'opacity': 1.0,
          'text': null,
          'documentId': 'doc-x',
          'createdAt': '2025-01-01T00:00:00.000Z',
          'updatedAt': '2025-01-01T00:00:00.000Z',
        },
      ];

      // Simpan ke PDF (seperti _saveDocument)
      var pdfWithAnnotations =
          AnnotationEmbedService.embedAnnotations(pdf, s1Annotations);

      // Verifikasi S1
      var extracted =
          AnnotationEmbedService.extractAnnotations(pdfWithAnnotations);
      print('After S1: ${extracted.map((e) => e["id"]).toList()}');
      expect(extracted.length, 2);
      expect(extracted.map((e) => e['id']), containsAll(['S1_P1', 'S1_P2']));

      // Session 2: load dari bytes S1, tambah S2_P2
      // (Ini simulasi: initState loads pdfWithAnnotations dari provider)
      final existingAnnotations =
          AnnotationEmbedService.extractAnnotations(pdfWithAnnotations);
      final s2NewAnnotation = {
        'id': 'S2_P2',
        'type': 'highlight',
        'pageIndex': 1,
        'x': 50.0,
        'y': 50.0,
        'width': 100.0,
        'height': 14.0,
        'color': 0xFFFF0000,
        'opacity': 1.0,
        'text': null,
        'documentId': 'doc-x',
        'createdAt': '2025-02-01T00:00:00.000Z',
        'updatedAt': '2025-02-01T00:00:00.000Z',
      };

      // Gabungkan: existing + new
      final s2AllAnnotations = [...existingAnnotations, s2NewAnnotation];
      pdfWithAnnotations = AnnotationEmbedService.embedAnnotations(
          pdfWithAnnotations, s2AllAnnotations);

      // Verifikasi S2
      extracted = AnnotationEmbedService.extractAnnotations(pdfWithAnnotations);
      print('After S2: ${extracted.map((e) => e["id"]).toList()}');

      expect(extracted.length, 3, reason: 'Harus 3: S1_P1 + S1_P2 + S2_P2');
      expect(extracted.map((e) => e['id']),
          containsAll(['S1_P1', 'S1_P2', 'S2_P2']),
          reason: 'S1_P1 di page 1 tidak boleh hilang!');

      // Session 3
      final existingS2 =
          AnnotationEmbedService.extractAnnotations(pdfWithAnnotations);
      final s3NewAnnotation = {
        'id': 'S3_P2',
        'type': 'underline',
        'pageIndex': 1,
        'x': 70.0,
        'y': 70.0,
        'width': 100.0,
        'height': 14.0,
        'color': 0xFF0000FF,
        'opacity': 1.0,
        'text': null,
        'documentId': 'doc-x',
        'createdAt': '2025-03-01T00:00:00.000Z',
        'updatedAt': '2025-03-01T00:00:00.000Z',
      };

      pdfWithAnnotations = AnnotationEmbedService.embedAnnotations(
          pdfWithAnnotations, [...existingS2, s3NewAnnotation]);

      extracted = AnnotationEmbedService.extractAnnotations(pdfWithAnnotations);
      print('After S3: ${extracted.map((e) => e["id"]).toList()}');

      expect(extracted.length, 4);
      expect(extracted.map((e) => e['id']),
          containsAll(['S1_P1', 'S1_P2', 'S2_P2', 'S3_P2']));
    });

    test('6. stripAnnotationMetadata → keywords bersih, PDF tetap valid', () {
      final pdf = _makePdf();
      final anns = [
        {'id': 'x', 'type': 'highlight', 'pageIndex': 0}
      ];
      final embedded = AnnotationEmbedService.embedAnnotations(pdf, anns);

      // Verifikasi embed berhasil
      expect(AnnotationEmbedService.extractAnnotations(embedded), isNotEmpty);

      // Strip metadata
      final stripped = AnnotationEmbedService.stripAnnotationMetadata(embedded);

      // Setelah strip: tidak ada metadata, PDF masih valid
      expect(AnnotationEmbedService.extractAnnotations(stripped), isEmpty);
      final doc = PdfDocument(inputBytes: stripped);
      expect(doc.pages.count, 2);
      doc.dispose();
    });

    test('7. Embed tidak merusak PDF — halaman count sama', () {
      final pdf = _makePdf(pages: 5);
      final anns = List.generate(3, (i) => {'id': 'ann-$i', 'pageIndex': i});
      final embedded = AnnotationEmbedService.embedAnnotations(pdf, anns);

      final doc = PdfDocument(inputBytes: embedded);
      expect(doc.pages.count, 5);
      doc.dispose();
    });

    test('8. Extract dari PDF yang tidak punya metadata tidak crash', () {
      // PDF dengan keywords biasa (bukan format kita)
      final doc = PdfDocument();
      doc.pages.add();
      doc.documentInformation.keywords = 'flutter pdf viewer app';
      final bytes = Uint8List.fromList(doc.saveSync());
      doc.dispose();

      final result = AnnotationEmbedService.extractAnnotations(bytes);
      expect(result, isEmpty);
    });

    test('9. Roundtrip: embed → extract → embed lagi → extract → data sama',
        () {
      final pdf = _makePdf();
      final original = [
        {
          'id': 'ann-1',
          'type': 'highlight',
          'pageIndex': 0,
          'color': 0xFFFFFF00
        },
        {
          'id': 'ann-2',
          'type': 'underline',
          'pageIndex': 1,
          'color': 0xFF0000FF
        },
      ];

      // Embed 3x roundtrip
      var bytes = AnnotationEmbedService.embedAnnotations(pdf, original);
      for (int i = 0; i < 3; i++) {
        final extracted = AnnotationEmbedService.extractAnnotations(bytes);
        bytes = AnnotationEmbedService.embedAnnotations(bytes, extracted);
      }

      final result = AnnotationEmbedService.extractAnnotations(bytes);
      expect(result.length, 2);
      expect(result[0]['id'], 'ann-1');
      expect(result[1]['id'], 'ann-2');
    });

    test('10. Data corrupt di keywords tidak crash', () {
      final doc = PdfDocument();
      doc.pages.add();
      doc.documentInformation.keywords =
          'AJIPDF_ANNOTATIONS_V1:!!!invalid_base64!!!';
      final bytes = Uint8List.fromList(doc.saveSync());
      doc.dispose();

      // Harus tidak crash
      final result = AnnotationEmbedService.extractAnnotations(bytes);
      expect(result, isEmpty);
    });
  });
}
