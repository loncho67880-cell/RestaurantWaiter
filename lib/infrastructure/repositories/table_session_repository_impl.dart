import 'package:dio/dio.dart';
import 'package:restaurantwaiter/domain/models/table_session_participant.dart';
import 'package:restaurantwaiter/domain/models/reservation_item.dart';
import 'package:restaurantwaiter/domain/repositories/table_session_repository.dart';

class TableSessionRepositoryImpl implements TableSessionRepository {
  final Dio _dio;

  TableSessionRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<List<TableSessionParticipant>> getParticipants({
    required String sessionId,
    required String accessToken,
  }) async {
    final response = await _dio.get(
      '/api/table-sessions/$sessionId',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return _parseParticipants(response.data);
  }

  @override
  Future<List<TableSessionParticipant>> updateParticipantItems({
    required String sessionId,
    required String customerId,
    required List<ReservationItem> items,
    required String accessToken,
  }) async {
    final response = await _dio.put(
      '/api/table-sessions/$sessionId/participants/$customerId/items',
      data: {'items': items.map((i) => i.toJson()).toList()},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return _parseParticipants(response.data);
  }

  @override
  Future<List<TableSessionParticipant>> confirmParticipant({
    required String sessionId,
    required String customerId,
    required String accessToken,
  }) async {
    final response = await _dio.put(
      '/api/table-sessions/$sessionId/participants/$customerId/confirm',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return _parseParticipants(response.data);
  }

  List<TableSessionParticipant> _parseParticipants(dynamic data) {
    if (data is! Map<String, dynamic>) return const [];
    final raw = data['participants'] ?? data['Participants'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => TableSessionParticipant.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }
}
