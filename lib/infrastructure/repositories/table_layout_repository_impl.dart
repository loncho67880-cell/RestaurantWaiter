import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurantwaiter/domain/models/table_layout.dart';
import 'package:restaurantwaiter/domain/repositories/table_layout_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saves and loads the branch layout using the backend API.
/// Falls back to SharedPreferences when the backend is unreachable.
class TableLayoutRepositoryImpl implements TableLayoutRepository {
  final Dio dio;

  static const String _keyPrefix = 'table_layout_';

  TableLayoutRepositoryImpl({required this.dio});

  String _keyFor(String branchId) => '$_keyPrefix$branchId';

  @override
  Future<TableLayout> loadLayout({
    required String branchId,
    required String accessToken,
  }) async {
    try {
      final response = await dio.get(
        '/api/layout/$branchId',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      // Backend stores element coords as 0-1 relative values.
      // Convert to the 1000px pixel canvas used by the organizer.
      final layout = _parseBackendLayout(response.data as Map<String, dynamic>);
      await _cacheLocally(branchId, layout);
      return layout;
    } catch (e, stack) {
      debugPrint('[Layout] loadLayout from API failed: $e\n$stack');
      return _loadFromCache(branchId);
    }
  }

  static const double _canvas = 1000.0;

  TableLayout _parseBackendLayout(Map<String, dynamic> json) {
    final raw = TableLayout.fromJson(json);
    // Convert decorative elements from 0-1 to pixel coords.
    final elements = raw.elements.map((e) => LayoutElement(
          id: e.id,
          type: e.type,
          label: e.label,
          floor: e.floor,
          x: e.x * _canvas,
          y: e.y * _canvas,
        )).toList();
    return TableLayout(branchId: raw.branchId, tables: raw.tables, elements: elements);
  }

  @override
  Future<void> saveLayout(
    TableLayout layout, {
    required String accessToken,
  }) async {
    final payload = _buildSavePayload(layout);
    try {
      await dio.put(
        '/api/layout/${layout.branchId}',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } catch (e, stack) {
      debugPrint('[Layout] saveLayout to API failed: $e\n$stack');
    }
    // Always persist locally so the canvas survives offline sessions.
    await _cacheLocally(layout.branchId, layout);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> _buildSavePayload(TableLayout layout) {
    final canvas = 1000.0; // pixel canvas size used by the editor

    final tables = layout.tables.map((t) {
      final element = layout.allElements
          .where((e) => e.id == t.tableId)
          .cast<LayoutElement?>()
          .firstOrNull;
      return {
        'tableId': t.tableId,
        'floor': element?.floor ?? t.floor,
        'positionX': (element != null ? element.x / canvas : t.positionX)
            .clamp(0.0, 1.0),
        'positionY': (element != null ? element.y / canvas : t.positionY)
            .clamp(0.0, 1.0),
        'shape': t.shape,
      };
    }).toList();

    final elements = layout.elements.map((e) => {
          'id': e.id.isNotEmpty ? e.id : null,
          'type': e.type.name,
          'label': e.label,
          'floor': e.floor,
          'x': (e.x / canvas).clamp(0.0, 1.0),
          'y': (e.y / canvas).clamp(0.0, 1.0),
        }).toList();

    return {'tables': tables, 'elements': elements};
  }

  Future<void> _cacheLocally(String branchId, TableLayout layout) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFor(branchId), jsonEncode(layout.toJson()));
    } catch (e) {
      debugPrint('[Layout] local cache write failed: $e');
    }
  }

  Future<TableLayout> _loadFromCache(String branchId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(branchId));
      if (raw == null || raw.isEmpty) {
        return TableLayout(branchId: branchId, elements: const []);
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;

      // Support old format that only had an 'elements' list at root
      if (!json.containsKey('tables') && json.containsKey('elements')) {
        return TableLayout.fromLegacyJson(
            branchId, json['elements'] as List<dynamic>);
      }
      return TableLayout.fromJson(json);
    } catch (_) {
      return TableLayout(branchId: branchId, elements: const []);
    }
  }
}
