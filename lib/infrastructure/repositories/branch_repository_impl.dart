import 'package:dio/dio.dart';
import 'package:restaurantwaiter/domain/models/branch.dart';
import 'package:restaurantwaiter/domain/repositories/branch_repository.dart';

class BranchRepositoryImpl implements BranchRepository {
  final Dio _dio;

  BranchRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<List<Branch>> getBranches({
    required String restaurantId,
  }) async {
    final response = await _dio.get(
      '/api/branches',
      queryParameters: {'restaurantId': restaurantId},
    );
    final data = response.data as List<dynamic>;
    return data
        .map((e) => Branch.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
