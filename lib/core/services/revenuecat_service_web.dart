import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;

import 'revenuecat_service.dart';

/// Configure RevenueCat — synchronous JS call returning JSON string.
Future<bool> rcConfigureImpl(String apiKey, String appUserId) async {
  try {
    final result = js.context.callMethod('rcConfigure', [apiKey, appUserId]);
    final map = jsonDecode(result as String) as Map<String, dynamic>;
    return map['success'] == true;
  } catch (_) {
    return false;
  }
}

/// Purchase — panggil JS async via injeksi script + DOM event (pola sama OCR).
Future<PurchaseResult> rcPurchaseImpl(String packageId) async {
  final jsonStr = await _callJsAsync(
    'rcPurchase(${jsonEncode(packageId)})',
    'rc_purchase_done',
    'rcPurchaseResult',
  );
  return _parse(jsonStr);
}

/// Get customer info.
Future<PurchaseResult> rcGetCustomerInfoImpl() async {
  final jsonStr = await _callJsAsync(
    'rcGetCustomerInfo()',
    'rc_customer_done',
    'rcCustomerResult',
  );
  return _parse(jsonStr);
}

PurchaseResult _parse(String jsonStr) {
  try {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (map['success'] != true) {
      return PurchaseResult(success: false, error: map['error']?.toString());
    }
    return PurchaseResult(
      success: true,
      customerId: map['customerId']?.toString(),
      activeEntitlements: (map['activeEntitlements'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      productId: map['productId']?.toString(),
    );
  } catch (e) {
    return PurchaseResult(success: false, error: 'Parse error: $e');
  }
}

/// Memanggil fungsi JS yang return Promise<String> via injeksi script + event.
Future<String> _callJsAsync(
    String jsCall, String eventName, String datasetKey) {
  final completer = Completer<String>();
  final scriptId = 'rc_${DateTime.now().microsecondsSinceEpoch}';

  final script = html.ScriptElement()
    ..id = scriptId
    ..text = '''
      (async function() {
        try {
          const result = await window.$jsCall;
          document.body.dataset.$datasetKey = result;
        } catch(e) {
          document.body.dataset.$datasetKey = JSON.stringify({success:false,error:e.toString()});
        }
        window.dispatchEvent(new Event('$eventName'));
      })();
    ''';

  late html.EventListener listener;
  listener = (event) {
    html.window.removeEventListener(eventName, listener);
    final result = html.document.body?.dataset[datasetKey] ??
        '{"success":false,"error":"no result"}';
    html.document.body?.dataset.remove(datasetKey);
    html.document.getElementById(scriptId)?.remove();
    if (!completer.isCompleted) completer.complete(result);
  };
  html.window.addEventListener(eventName, listener);
  html.document.body!.append(script);

  // Timeout 5 menit (purchase popup butuh interaksi user).
  Future.delayed(const Duration(seconds: 300), () {
    if (!completer.isCompleted) {
      html.window.removeEventListener(eventName, listener);
      html.document.getElementById(scriptId)?.remove();
      completer.complete('{"success":false,"error":"Timeout"}');
    }
  });

  return completer.future;
}
