import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/hive_service.dart';
import 'core/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (ignore error if file missing in dev)
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  // Initialize Hive
  await Hive.initFlutter();
  await HiveService.instance.init();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: PDFEnterpriseSuiteApp(),
    ),
  );
}

class PDFEnterpriseSuiteApp extends ConsumerWidget {
  const PDFEnterpriseSuiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final personalization = ref.watch(appPersonalizationProvider);
    final scheme = personalization.colorScheme;
    final themeMode = personalization.themeMode;

    return MaterialApp.router(
      title: 'PDF Enterprise Suite',
      debugShowCheckedModeBanner: false,

      // Theme dari color scheme yang dipilih user
      theme: AppTheme.lightThemeFrom(scheme),
      darkTheme: AppTheme.darkThemeFrom(scheme),
      themeMode: themeMode,

      // Router configuration
      routerConfig: router,
    );
  }
}
