import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class EpsInitResult {
  final String redirectUrl;
  final String merchantTransactionId;

  EpsInitResult({required this.redirectUrl, required this.merchantTransactionId});
}

class EpsService {
  const EpsService();

  Future<EpsInitResult> initializePayment({
    required String pharmacyId,
    required String planId,
    String? couponCode,
  }) async {
    final platform = Platform.isAndroid ? 'android' : 'ios';
    
    final response = await http.post(
      Uri.parse('$apiBaseUrl/eps_initialize.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pharmacy_id': pharmacyId,
        'plan_id': planId,
        'platform': platform,
        'coupon_code': couponCode,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to initialize payment');
    }

    final data = jsonDecode(response.body);
    return EpsInitResult(
      redirectUrl: data['redirect_url'],
      merchantTransactionId: data['merchant_transaction_id'],
    );
  }

  Future<bool> verifyPayment(String merchantTransactionId) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/eps_verify.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'merchant_transaction_id': merchantTransactionId,
      }),
    );

    if (response.statusCode != 200) return false;
    
    final data = jsonDecode(response.body);
    return data['status'] == 'success';
  }

  Future<List<Map<String, dynamic>>> getPlans() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/get_plans.php'));
    if (response.statusCode != 200) throw Exception('Failed to load plans');
    
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['data']);
  }
}
