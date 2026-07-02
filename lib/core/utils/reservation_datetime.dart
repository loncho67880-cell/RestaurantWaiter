// Keep in sync with restaurant_customer_core/lib/core/utils/reservation_datetime.dart.

/// Formats a local reservation date/time as UTC for API requests.
String formatApiReservationDate(DateTime value) {
  return value.toUtc().toIso8601String();
}

/// Parses reservation dates from the API into local time.
///
/// The API stores timestamps in UTC (PostgreSQL). Values with an explicit
/// timezone (`Z` or `-05:00`) are converted to local time. Naive strings
/// without a timezone are treated as UTC wall-clock time.
DateTime parseApiReservationDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return DateTime.now();

  final parsed = DateTime.parse(trimmed);

  if (_hasExplicitTimezone(trimmed)) {
    return parsed.toLocal();
  }

  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  ).toLocal();
}

/// Formats a reservation date/time for display in the user's locale.
String formatReservationDateTime(DateTime dateTime, String locale) {
  final local = dateTime.toLocal();
  final months = locale == 'es'
      ? [
          'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
          'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
        ]
      : [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year} — $h:$m';
}

/// Formats only the time portion of a reservation for short hints.
String formatReservationTime(DateTime dateTime, String locale) {
  final local = dateTime.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

bool _hasExplicitTimezone(String value) {
  final normalized = value.toUpperCase();
  if (normalized.endsWith('Z')) return true;

  final timePart = normalized.contains('T')
      ? normalized.split('T').last
      : normalized.split(' ').last;
  return RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(timePart);
}
