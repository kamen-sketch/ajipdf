import 'package:dio/dio.dart';

import 'hive_service.dart';

/// Singleton HTTP service using Dio for all API communication.
class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  static const String baseUrl = 'http://localhost:3000/api';

  late final Dio _dio;

  /// Initialize Dio with base options, interceptors, and timeout.
  void init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = token;
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          handler.next(response);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Clear token on unauthorized
            _clearToken();
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Get current JWT token from local storage.
  String? get token => HiveService.instance.getPreference<String>('auth_token');

  /// Save or clear JWT token.
  Future<void> setToken(String? t) async {
    if (t == null) {
      await HiveService.instance.savePreference('auth_token', null);
    } else {
      await HiveService.instance.savePreference('auth_token', t);
    }
  }

  void _clearToken() {
    HiveService.instance.savePreference('auth_token', null);
  }

  /// HTTP GET request.
  Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    return _dio.get(path, queryParameters: params);
  }

  /// HTTP POST request.
  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  /// HTTP PUT request.
  Future<Response> put(String path, {dynamic data}) async {
    return _dio.put(path, data: data);
  }

  /// HTTP DELETE request.
  Future<Response> delete(String path) async {
    return _dio.delete(path);
  }
}
