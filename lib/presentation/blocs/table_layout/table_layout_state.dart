import 'package:equatable/equatable.dart';
import 'package:restaurantwaiter/domain/models/table_layout.dart';

enum TableLayoutStatus { loading, ready, error }

class TableLayoutState extends Equatable {
  final TableLayoutStatus status;
  final String branchId;
  final List<LayoutTable> tables;
  final List<LayoutElement> elements;
  final int selectedFloor;
  final bool saving;
  final bool dirty;

  const TableLayoutState({
    this.status = TableLayoutStatus.loading,
    this.branchId = '',
    this.tables = const [],
    this.elements = const [],
    this.selectedFloor = 1,
    this.saving = false,
    this.dirty = false,
  });

  List<LayoutElement> get allElements => [
        ...tables.map((t) => t.toElement()),
        ...elements,
      ];

  List<LayoutElement> get floorElements =>
      allElements.where((e) => e.floor == selectedFloor).toList();

  /// Elements placed by the waiter on the canvas (excludes backend tables).
  List<LayoutElement> get canvasElements =>
      elements.where((e) => e.floor == selectedFloor).toList();

  TableLayoutState copyWith({
    TableLayoutStatus? status,
    String? branchId,
    List<LayoutTable>? tables,
    List<LayoutElement>? elements,
    int? selectedFloor,
    bool? saving,
    bool? dirty,
  }) {
    return TableLayoutState(
      status: status ?? this.status,
      branchId: branchId ?? this.branchId,
      tables: tables ?? this.tables,
      elements: elements ?? this.elements,
      selectedFloor: selectedFloor ?? this.selectedFloor,
      saving: saving ?? this.saving,
      dirty: dirty ?? this.dirty,
    );
  }

  @override
  List<Object?> get props => [
        status,
        branchId,
        elements.map((e) => '${e.id}:${e.x}:${e.y}:${e.label}:${e.floor}').join('|'),
        tables
            .map((t) =>
                '${t.tableId}:${t.positionX}:${t.positionY}:${t.floor}')
            .join('|'),
        selectedFloor,
        saving,
        dirty,
      ];
}
