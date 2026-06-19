import 'dart:convert';

import 'package:restaurantwaiter/domain/models/table_layout.dart';
import 'package:restaurantwaiter/domain/repositories/table_layout_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local (shared_preferences) implementation of [TableLayoutRepository].
///
/// The layout is stored as JSON under a per-branch key. To later move this to
/// the backend, only this class needs to change.
class TableLayoutRepositoryImpl implements TableLayoutRepository {
  static const String _keyPrefix = 'table_layout_';

  String _keyFor(String branchId) => '$_keyPrefix$branchId';

  @override
  Future<TableLayout> loadLayout({required String branchId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(branchId));
    if (raw == null || raw.isEmpty) {
      return TableLayout(branchId: branchId, elements: []);
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TableLayout.fromJson(json);
    } catch (_) {
      return TableLayout(branchId: branchId, elements: []);
    }
  }

  @override
  Future<void> saveLayout(TableLayout layout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyFor(layout.branchId),
      jsonEncode(layout.toJson()),
    );
  }
}
