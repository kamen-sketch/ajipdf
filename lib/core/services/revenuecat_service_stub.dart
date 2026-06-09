import 'revenuecat_service.dart';

Future<bool> rcConfigureImpl(String apiKey, String appUserId) async {
  return false;
}

Future<PurchaseResult> rcPurchaseImpl(String packageId) async {
  return PurchaseResult(
      success: false, error: 'Tidak didukung di platform ini');
}

Future<PurchaseResult> rcGetCustomerInfoImpl() async {
  return PurchaseResult(
      success: false, error: 'Tidak didukung di platform ini');
}
