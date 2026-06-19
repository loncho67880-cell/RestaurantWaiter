import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/table_layout.dart';
import 'package:restaurantwaiter/domain/repositories/table_layout_repository.dart';

import 'table_layout_state.dart';

class TableLayoutCubit extends Cubit<TableLayoutState> {
  final TableLayoutRepository repository;
  final String branchId;

  TableLayoutCubit({
    required this.repository,
    required this.branchId,
  }) : super(const TableLayoutState());

  Future<void> load() async {
    emit(state.copyWith(status: TableLayoutStatus.loading));
    try {
      final layout = await repository.loadLayout(branchId: branchId);
      emit(state.copyWith(
        status: TableLayoutStatus.ready,
        branchId: branchId,
        elements: layout.elements,
        dirty: false,
      ));
    } catch (_) {
      emit(state.copyWith(status: TableLayoutStatus.error));
    }
  }

  void addElement(LayoutElementType type, String defaultLabel) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final label = type == LayoutElementType.table
        ? _nextTableLabel()
        : defaultLabel;
    final element = LayoutElement(
      id: id,
      type: type,
      label: label,
      x: 24,
      y: 24,
    );
    emit(state.copyWith(
      elements: [...state.elements, element],
      dirty: true,
    ));
  }

  void moveElement(String id, double dx, double dy) {
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

  Future<bool> save() async {
    emit(state.copyWith(saving: true));
    try {
      await repository.saveLayout(
        TableLayout(branchId: branchId, elements: state.elements),
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
