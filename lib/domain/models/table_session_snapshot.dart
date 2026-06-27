import 'table_session_participant.dart';

class TableSessionSnapshot {
  final String sessionId;
  final List<TableSessionParticipant> participants;
  final bool allParticipantsConfirmed;
  final bool canFinalizeTable;

  const TableSessionSnapshot({
    required this.sessionId,
    required this.participants,
    this.allParticipantsConfirmed = false,
    this.canFinalizeTable = false,
  });

  factory TableSessionSnapshot.fromJson(Map<String, dynamic> json) {
    final sessionId = (json['sessionId'] ??
            json['SessionId'] ??
            json['reservationId'] ??
            json['ReservationId'])
        ?.toString();

    final rawParticipants = json['participants'] ?? json['Participants'];
    final participants = rawParticipants is List
        ? rawParticipants
            .whereType<Map>()
            .map(
              (e) => TableSessionParticipant.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList()
        : const <TableSessionParticipant>[];

    return TableSessionSnapshot(
      sessionId: sessionId ?? '',
      participants: participants,
      allParticipantsConfirmed: json['allParticipantsConfirmed'] == true ||
          json['AllParticipantsConfirmed'] == true,
      canFinalizeTable:
          json['canFinalizeTable'] == true || json['CanFinalizeTable'] == true,
    );
  }
}
