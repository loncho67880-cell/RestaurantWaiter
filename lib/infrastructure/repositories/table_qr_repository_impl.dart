import 'package:dio/dio.dart';
import 'package:restaurantwaiter/domain/models/table_qr_token.dart';
import 'package:restaurantwaiter/domain/repositories/table_qr_repository.dart';

class TableQrRepositoryImpl implements TableQrRepository {
  final Dio dio;

  TableQrRepositoryImpl({required this.dio});

  @override
  Future<List<TableQrToken>> getBranchTokens({
    required String branchId,
    required String accessToken,
  }) async {
    final response = await dio.post(
      '/api/table-qr/branch/$branchId/tokens',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );

    final list = response.data as List<dynamic>;
    return list
        .map((e) => TableQrToken.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
