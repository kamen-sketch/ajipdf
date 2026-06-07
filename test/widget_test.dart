// Basic smoke test for PDF Enterprise Suite.
//
// The full app requires Hive and dotenv initialization, so this test focuses
// on verifying that the root widget can be instantiated within a ProviderScope.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pdf_enterprise_suite/main.dart';

void main() {
  testWidgets('App builds within ProviderScope', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PDFEnterpriseSuiteApp(),
      ),
    );

    // The root widget should be a MaterialApp (router-based).
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
