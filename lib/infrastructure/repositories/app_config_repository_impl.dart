import 'package:dio/dio.dart';
import 'package:restaurantwaiter/domain/models/app_config_bundle.dart';
import 'package:restaurantwaiter/domain/repositories/app_config_repository.dart';

class AppConfigRepositoryImpl implements AppConfigRepository {
  final Dio dio;

  AppConfigRepositoryImpl({required this.dio});

  @override
  Future<AppConfigBundle> loadAppConfig({
    required String restaurantId,
    required String lang,
    String appType = 'waiter',
  }) async {
    final response = await dio.get(
      '/api/app-config',
      queryParameters: {
        'restaurantId': restaurantId,
        'lang': lang,
        'appType': appType,
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception('Invalid app-config response.');
    }

    return AppConfigBundle.fromJson(Map<String, dynamic>.from(data));
  }
}
