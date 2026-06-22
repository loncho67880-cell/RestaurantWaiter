import '../models/table_layout.dart';

/// Abstraction over salon-layout persistence (backend + local cache).
abstract class TableLayoutRepository {
  Future<TableLayout> loadLayout({
    required String branchId,
    required String accessToken,
  });

  Future<void> saveLayout(
    TableLayout layout, {
    required String accessToken,
  });
}
