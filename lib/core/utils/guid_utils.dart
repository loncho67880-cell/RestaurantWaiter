import 'dart:math';

final _guidV4 = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Generates an RFC-4122 v4 UUID string accepted by the .NET backend.
String generateGuidV4() {
  final random = Random();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int index) => bytes[index].toRadixString(16).padLeft(2, '0');

  return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
      '${hex(4)}${hex(5)}-'
      '${hex(6)}${hex(7)}-'
      '${hex(8)}${hex(9)}-'
      '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
}

/// Returns [id] when it is a valid GUID, otherwise `null` for new records.
String? guidForApi(String id) => _guidV4.hasMatch(id) ? id : null;
