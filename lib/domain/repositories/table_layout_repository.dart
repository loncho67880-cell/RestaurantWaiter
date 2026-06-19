import '../models/table_layout.dart';

/// Abstraction over salon-layout persistence. Currently backed by local
/// storage (shared_preferences); can later be swapped for a backend
/// implementation without touching the presentation layer.
abstract class TableLayoutRepository {
  Future<TableLayout> loadLayout({required String branchId});

  Future<void> saveLayout(TableLayout layout);
}
