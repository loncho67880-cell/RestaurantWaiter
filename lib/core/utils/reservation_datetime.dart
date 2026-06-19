/// Formats a local reservation date/time as UTC for API requests.
String formatApiReservationDate(DateTime value) {
  return value.toUtc().toIso8601String();
}

/// Parses reservation dates from the API into local time.
///
/// If the API includes an explicit timezone (`Z` or `-05:00`), convert it to
/// the device local time. If it sends a SQL/local DateTime without timezone,
/// keep that wall-clock time as-is.
DateTime parseApiReservationDate(String value) {
  final trimmed = value.trim();
  final parsed = DateTime.parse(trimmed);

  if (_hasExplicitTimezone(trimmed)) {
    return parsed.toLocal();
  }

  return parsed;
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

bool _hasExplicitTimezone(String value) {
  final normalized = value.toUpperCase();
  if (normalized.endsWith('Z')) return true;

  final timePart = normalized.contains('T')
      ? normalized.split('T').last
      : normalized.split(' ').last;
  return RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(timePart);
}
