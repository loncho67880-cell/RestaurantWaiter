import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/table_layout.dart';
import 'package:restaurantwaiter/domain/repositories/table_layout_repository.dart';

import 'table_layout_state.dart';

class TableLayoutCubit extends Cubit<TableLayoutState> {
  final TableLayoutRepository repository;
  final String branchId;
  final String accessToken;

  TableLayoutCubit({
    required this.repository,
    required this.branchId,
    required this.accessToken,
  }) : super(const TableLayoutState());

  Future<void> load() async {
    emit(state.copyWith(status: TableLayoutStatus.loading));
    try {
      final layout = await repository.loadLayout(
        branchId: branchId,
        accessToken: accessToken,
      );
      emit(state.copyWith(
        status: TableLayoutStatus.ready,
        branchId: branchId,
        tables: layout.tables,
        elements: layout.elements,
        dirty: false,
      ));
    } catch (_) {
      emit(state.copyWith(status: TableLayoutStatus.error));
    }
  }

  void selectFloor(int floor) => emit(state.copyWith(selectedFloor: floor));

  void addElement(LayoutElementType type, String defaultLabel) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final label = type == LayoutElementType.table
        ? _nextTableLabel()
        : defaultLabel;
    final element = LayoutElement(
      id: id,
      type: type,
      label: label,
      floor: state.selectedFloor,
      x: 24,
      y: 24,
    );
    emit(state.copyWith(
      elements: [...state.elements, element],
      dirty: true,
    ));
  }

  void moveElement(String id, double dx, double dy) {
    // Check tables first
    final tableMatch = state.tables.where((t) => t.tableId == id).cast<LayoutTable?>().firstOrNull;
    if (tableMatch != null) {
      final canvas = 1000.0;
      final updated = state.allElements.map((e) {
        if (e.id != id) return e;
        final nx = (e.x + dx).clamp(0.0, canvas);
        final ny = (e.y + dy).clamp(0.0, canvas);
        return e.copyWith(x: nx, y: ny);
      }).toList();
      // Re-split back into tables+elements
      _emitFromAllElements(updated);
      return;
    }
    final elements = state.elements.map((e) {
      if (e.id != id) return e;
      final nx = (e.x + dx).clamp(0.0, double.infinity);
      final ny = (e.y + dy).clamp(0.0, double.infinity);
      return e.copyWith(x: nx, y: ny);
    }).toList();
    emit(state.copyWith(elements: elements, dirty: true));
  }

  void renameElement(String id, String label) {
    final elements = state.elements
        .map((e) => e.id == id ? e.copyWith(label: label) : e)
        .toList();
    emit(state.copyWith(elements: elements, dirty: true));
  }

  void removeElement(String id) {
    final elements = state.elements.where((e) => e.id != id).toList();
    emit(state.copyWith(elements: elements, dirty: true));
  }

  void _emitFromAllElements(List<LayoutElement> all) {
    final tableIds = {for (final t in state.tables) t.tableId};
    final tableElements = all.where((e) => tableIds.contains(e.id)).toList();
    final decorElements = all.where((e) => !tableIds.contains(e.id)).toList();

    final updatedTables = state.tables.map((t) {
      final match = tableElements.where((e) => e.id == t.tableId).cast<LayoutElement?>().firstOrNull;
      if (match == null) return t;
      return LayoutTable(
        tableId: t.tableId,
        tableNumber: t.tableNumber,
        floor: match.floor,
        capacity: t.capacity,
        positionX: match.x / 1000,
        positionY: match.y / 1000,
        shape: t.shape,
      );
    }).toList();

    emit(state.copyWith(tables: updatedTables, elements: decorElements, dirty: true));
  }

  Future<bool> save() async {
    emit(state.copyWith(saving: true));
    try {
      await repository.saveLayout(
        TableLayout(
          branchId: branchId,
          tables: state.tables,
          elements: state.elements,
        ),
        accessToken: accessToken,
      );
      emit(state.copyWith(saving: false, dirty: false));
      return true;
    } catch (_) {
      emit(state.copyWith(saving: false));
      return false;
    }
  }

  String _nextTableLabel() {
    final tableCount =
        state.elements.where((e) => e.isTable).length;
    return '${tableCount + 1}';
  }
}
