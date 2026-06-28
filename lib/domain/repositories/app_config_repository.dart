import 'package:restaurantwaiter/domain/models/app_config_bundle.dart';

abstract class AppConfigRepository {
  Future<AppConfigBundle> loadAppConfig({
    required String restaurantId,
    required String lang,
    String appType = 'waiter',
  });
}
