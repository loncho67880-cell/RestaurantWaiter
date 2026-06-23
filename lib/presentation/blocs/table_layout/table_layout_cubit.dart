import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/utils/guid_utils.dart';
import 'package:restaurantwaiter/domain/models/table_layout.dart';
import 'package:restaurantwaiter/domain/repositories/table_layout_repository.dart';

import 'table_layout_state.dart';

class TableLayoutCubit extends Cubit<TableLayoutState> {
  final TableLayoutRepository repository;
  final String branchId;
  final String accessToken;

  static const double _canvas = 1000.0;

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
        floorCount: _floorCountFrom(layout.tables, layout.elements),
        dirty: false,
      ));
    } catch (_) {
      emit(state.copyWith(status: TableLayoutStatus.error));
    }
  }

  void selectFloor(int floor) => emit(state.copyWith(selectedFloor: floor));

  void addFloor() {
    final next = state.floorCount + 1;
    emit(state.copyWith(floorCount: next, selectedFloor: next));
  }

  void addElement(LayoutElementType type, String defaultLabel) {
    if (type == LayoutElementType.table) {
      _addTable();
      return;
    }

    final element = LayoutElement(
      id: generateGuidV4(),
      type: type,
      label: defaultLabel,
      floor: state.selectedFloor,
      x: 24,
      y: 24,
    );
    emit(state.copyWith(
      elements: [...state.elements, element],
      dirty: true,
    ));
  }

  void _addTable() {
    final table = LayoutTable(
      tableId: generateGuidV4(),
      layoutElementId: generateGuidV4(),
      tableNumber: _nextTableNumber(),
      floor: state.selectedFloor,
      x: 24,
      y: 24,
      isPending: true,
    );
    emit(state.copyWith(
      tables: [...state.tables, table],
      dirty: true,
    ));
  }

  void moveElement(String id, double dx, double dy) {
    final tableIndex = state.tables.indexWhere((t) => t.tableId == id);
    if (tableIndex >= 0) {
      final table = state.tables[tableIndex];
      final tables = [...state.tables];
      tables[tableIndex] = table.copyWith(
        x: (table.x + dx).clamp(0.0, _canvas),
        y: (table.y + dy).clamp(0.0, _canvas),
      );
      emit(state.copyWith(tables: tables, dirty: true));
      return;
    }

    final elements = state.elements.map((e) {
      if (e.id != id) return e;
      return e.copyWith(
        x: (e.x + dx).clamp(0.0, double.infinity),
        y: (e.y + dy).clamp(0.0, double.infinity),
      );
    }).toList();
    emit(state.copyWith(elements: elements, dirty: true));
  }

  void renameElement(String id, String label) {
    final elements = state.elements
        .map((e) => e.id == id ? e.copyWith(label: label) : e)
        .toList();
    emit(state.copyWith(elements: elements, dirty: true));
  }

  void updateTable(String id, {int? tableNumber, int? capacity}) {
    final tableIndex = state.tables.indexWhere((t) => t.tableId == id);
    if (tableIndex < 0) return;

    final tables = [...state.tables];
    tables[tableIndex] = tables[tableIndex].copyWith(
      tableNumber: tableNumber,
      capacity: capacity,
    );
    emit(state.copyWith(tables: tables, dirty: true));
  }

  void removeElement(String id) {
    final table = state.tables.where((t) => t.tableId == id).firstOrNull;
    if (table != null) {
      if (!table.isPending) return;
      emit(state.copyWith(
        tables: state.tables.where((t) => t.tableId != id).toList(),
        dirty: true,
      ));
      return;
    }

    emit(state.copyWith(
      elements: state.elements.where((e) => e.id != id).toList(),
      dirty: true,
    ));
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

  int _nextTableNumber() {
    if (state.tables.isEmpty) return 1;
    return state.tables
            .map((t) => t.tableNumber)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  int _floorCountFrom(List<LayoutTable> tables, List<LayoutElement> elements) {
    final floors = [
      ...tables.map((t) => t.floor),
      ...elements.map((e) => e.floor),
      1,
    ];
    return floors.reduce((a, b) => a > b ? a : b);
  }
}
