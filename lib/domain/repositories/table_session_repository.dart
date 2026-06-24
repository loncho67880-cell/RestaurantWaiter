import '../models/reservation_item.dart';
import '../models/table_session_participant.dart';

abstract class TableSessionRepository {
  Future<List<TableSessionParticipant>> getParticipants({
    required String sessionId,
    required String accessToken,
  });

  Future<List<TableSessionParticipant>> updateParticipantItems({
    required String sessionId,
    required String customerId,
    required List<ReservationItem> items,
    required String accessToken,
  });

  Future<List<TableSessionParticipant>> confirmParticipant({
    required String sessionId,
    required String customerId,
    required String accessToken,
  });
}
