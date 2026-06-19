import 'package:equatable/equatable.dart';
import 'package:restaurantwaiter/domain/models/table_layout.dart';

enum TableLayoutStatus { loading, ready, error }

class TableLayoutState extends Equatable {
  final TableLayoutStatus status;
  final String branchId;
  final List<LayoutElement> elements;
  final bool saving;
  final bool dirty;

  const TableLayoutState({
    this.status = TableLayoutStatus.loading,
    this.branchId = '',
    this.elements = const [],
    this.saving = false,
    this.dirty = false,
  });

  TableLayoutState copyWith({
    TableLayoutStatus? status,
    String? branchId,
    List<LayoutElement>? elements,
    bool? saving,
    bool? dirty,
  }) {
    return TableLayoutState(
      status: status ?? this.status,
      branchId: branchId ?? this.branchId,
      elements: elements ?? this.elements,
      saving: saving ?? this.saving,
      dirty: dirty ?? this.dirty,
    );
  }

  @override
  List<Object?> get props => [
        status,
        branchId,
        elements.map((e) => '${e.id}:${e.x}:${e.y}:${e.label}').join('|'),
        saving,
        dirty,
      ];
}
