import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_service.dart';

/// Error reporter that tracks user journey and sends error reports to backend.
class ErrorReporter {
  static final ErrorReporter instance = ErrorReporter._();
  ErrorReporter._();

  final List<Map<String, String>> _breadcrumbs = [];

  /// Add a breadcrumb to the journey log. Max 20, FIFO.
  void addBreadcrumb(String screen, String action) {
    _breadcrumbs.add({
      'screen': screen,
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_breadcrumbs.length > 20) {
      _breadcrumbs.removeAt(0);
    }
  }

  /// Report an error to the backend. Silent fail — never crashes the app.
  Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    String? screen,
    String? action,
    String severity = 'medium',
  }) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final appVersion = await _getAppVersion();

      final payload = {
        'errorMessage': error.toString(),
        'stackTrace': stackTrace?.toString(),
        'screen': screen,
        'action': action,
        'severity': severity,
        'reproductionSteps':
            _breadcrumbs.map((b) => '${b['screen']} → ${b['action']}').toList(),
        'deviceInfo': {
          ...deviceInfo,
          'appVersion': appVersion,
        },
        'context': {
          'journey': List<Map<String, String>>.from(_breadcrumbs),
          'timestamp': DateTime.now().toIso8601String(),
        },
      };

      await ApiService.instance.post('/errors/report', data: payload);
    } catch (_) {
      // Silent fail — error reporter must never crash the app
    }
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();

      if (kIsWeb) {
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        return {
          'platform': 'web',
          'browser': webInfo.browserName.name,
          'userAgent': webInfo.userAgent ?? '',
        };
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        return {
          'platform': 'android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'version': androidInfo.version.release,
          'sdk': androidInfo.version.sdkInt.toString(),
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        return {
          'platform': 'ios',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemVersion': iosInfo.systemVersion,
        };
      }
    } catch (_) {
      // Silent fail
    }
    return {'platform': 'unknown'};
  }

  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }
}
