import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurantwaiter/core/auth/auth_token_provider.dart';

Dio createDioClient(String baseUrl, {AuthTokenProvider? tokenProvider}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'User-Agent': 'RestaurantWaiter/1.0',
      },
    ),
  );

  _configureNativeHttpClient(dio);
  if (tokenProvider != null) {
    dio.interceptors.add(AuthInterceptor(tokenProvider));
  }
  dio.interceptors.add(RetryInterceptor(dio));

  return dio;
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenProvider);

  final AuthTokenProvider _tokenProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider.token;
    if (token != null &&
        token.isNotEmpty &&
        !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

void _configureNativeHttpClient(Dio dio) {
  if (!Platform.isAndroid && !Platform.isIOS) return;

  final adapter = IOHttpClientAdapter();
  adapter.createHttpClient = () {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    client.connectionTimeout = const Duration(seconds: 30);
    client.idleTimeout = const Duration(seconds: 15);
    return client;
  };
  dio.httpClientAdapter = adapter;
}

Future<void> warmUpApiConnection(Dio dio) async {
  try {
    await dio.head<void>(
      '/',
      options: Options(
        validateStatus: (_) => true,
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
  } catch (_) {
    // Best effort: retries on real requests handle remaining tunnel flakiness.
  }
}

bool isTransientNetworkError(DioException error) {
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.connectionError) {
    return true;
  }

  final status = error.response?.statusCode;
  if (status == 502 || status == 503 || status == 504) return true;

  final details = '${error.message ?? ''} ${error.error ?? ''}'.toLowerCase();
  if (error.type == DioExceptionType.unknown) {
    return details.contains('connection closed') ||
        details.contains('connection reset') ||
        details.contains('broken pipe') ||
        details.contains('socket') ||
        details.contains('handshake') ||
        details.contains('failed host lookup') ||
        details.contains('network is unreachable');
  }

  return false;
}

class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 4});

  final Dio _dio;
  final int maxRetries;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;

    if (retryCount < maxRetries && isTransientNetworkError(err)) {
      err.requestOptions.extra['retryCount'] = retryCount + 1;
      final delayMs = 700 * (1 << retryCount);
      await Future<void>.delayed(
        Duration(milliseconds: delayMs.clamp(700, 5000)),
      );

      try {
        final response = await _dio.fetch<dynamic>(err.requestOptions);
        return handler.resolve(response);
      } on DioException catch (retryError) {
        if (kDebugMode) {
          debugPrint(
            '[DioRetry] retry ${retryCount + 1}/$maxRetries failed: ${retryError.response?.statusCode ?? retryError.message}',
          );
        }
        return onError(retryError, handler);
      }
    }

    handler.next(err);
  }
}
