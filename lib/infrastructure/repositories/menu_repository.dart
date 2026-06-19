import 'package:dio/dio.dart';
import '../../domain/models/category_menu.dart';

class MenuRepository {
  final Dio dio;

  MenuRepository({required this.dio});

  Future<List<CategoryMenu>> loadCategories(
    String localeCode,
    String restaurantId,
    String branchId,
    String accessToken,
  ) async {
    try {
      final response = await dio.get(
        '/api/catalog',
        queryParameters: {
          'lang': localeCode,
          'restaurantId': restaurantId,
          'branchId': branchId,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> categories = data is Map<String, dynamic>
            ? data['categories'] as List<dynamic>
            : data as List<dynamic>;

        return categories
            .map((e) => CategoryMenu.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw Exception(
        'Error del servidor: ${response.statusCode} - ${response.data}',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      throw Exception(
        'Error de conexión: Verifica apiBaseUrl en appsettings y que el BFF esté encendido. '
        '${status != null ? 'HTTP $status' : e.message}${body != null ? ' - $body' : ''}',
      );
    }
  }
}
