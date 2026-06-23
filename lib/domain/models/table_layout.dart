/// Kinds of elements the waiter can place on the salon canvas.
enum LayoutElementType {
  table,
  entrance,
  exit,
  reception,
  bar,
  kitchen,
  restroom,
  stairs,
  elevator,
  counter,
}

LayoutElementType _typeFromString(String? value) {
  return LayoutElementType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => LayoutElementType.entrance,
  );
}

/// A decorative/structural element on the salon canvas (never type = table).
class LayoutElement {
  final String id;
  final LayoutElementType type;
  final String label;
  final int floor;
  double x;
  double y;

  LayoutElement({
    required this.id,
    required this.type,
    required this.label,
    this.floor = 1,
    required this.x,
    required this.y,
  });

  bool get isTable => type == LayoutElementType.table;

  LayoutElement copyWith({
    String? label,
    int? floor,
    double? x,
    double? y,
  }) =>
      LayoutElement(
        id: id,
        type: type,
        label: label ?? this.label,
        floor: floor ?? this.floor,
        x: x ?? this.x,
        y: y ?? this.y,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'label': label,
        'floor': floor,
        'x': x,
        'y': y,
      };

  factory LayoutElement.fromJson(Map<String, dynamic> json) => LayoutElement(
        id: (json['id'] ?? json['Id'])?.toString() ?? '',
        type: _typeFromString((json['type'] ?? json['Type']) as String?),
        label: (json['label'] ?? json['Label']) as String? ?? '',
        floor: (json['floor'] ?? json['Floor'] as num?)?.toInt() ?? 1,
        x: ((json['x'] ?? json['X']) as num?)?.toDouble() ?? 0,
        y: ((json['y'] ?? json['Y']) as num?)?.toDouble() ?? 0,
      );
}

/// Business table data; canvas position/shape live on the linked layout element.
class LayoutTable {
  final String tableId;
  final String layoutElementId;
  final int tableNumber;
  final int floor;
  final int capacity;
  double x;
  double y;
  final String shape;
  final bool isPending;

  LayoutTable({
    required this.tableId,
    required this.layoutElementId,
    required this.tableNumber,
    required this.floor,
    this.capacity = 4,
    required this.x,
    required this.y,
    this.shape = 'circle',
    this.isPending = false,
  });

  factory LayoutTable.fromJson(Map<String, dynamic> json) => LayoutTable(
        tableId: (json['tableId'] ?? json['TableId'])?.toString() ?? '',
        layoutElementId:
            (json['layoutElementId'] ?? json['LayoutElementId'])?.toString() ??
                '',
        tableNumber:
            (json['tableNumber'] ?? json['TableNumber'] as num?)?.toInt() ?? 0,
        floor: (json['floor'] ?? json['Floor'] as num?)?.toInt() ?? 1,
        capacity:
            (json['capacity'] ?? json['Capacity'] as num?)?.toInt() ?? 4,
        x: ((json['x'] ??
                    json['positionX'] ??
                    json['PositionX']) as num?)
                ?.toDouble() ??
            0,
        y: ((json['y'] ??
                    json['positionY'] ??
                    json['PositionY']) as num?)
                ?.toDouble() ??
            0,
        shape: (json['shape'] ?? json['Shape']) as String? ?? 'circle',
        isPending: json['isPending'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'tableId': tableId,
        'layoutElementId': layoutElementId,
        'tableNumber': tableNumber,
        'floor': floor,
        'capacity': capacity,
        'x': x,
        'y': y,
        'shape': shape,
        'isPending': isPending,
      };

  LayoutTable copyWith({
    String? layoutElementId,
    int? tableNumber,
    int? floor,
    int? capacity,
    double? x,
    double? y,
    String? shape,
    bool? isPending,
  }) =>
      LayoutTable(
        tableId: tableId,
        layoutElementId: layoutElementId ?? this.layoutElementId,
        tableNumber: tableNumber ?? this.tableNumber,
        floor: floor ?? this.floor,
        capacity: capacity ?? this.capacity,
        x: x ?? this.x,
        y: y ?? this.y,
        shape: shape ?? this.shape,
        isPending: isPending ?? this.isPending,
      );

  /// Canvas representation for the organizer (position/shape from layout element).
  LayoutElement toElement() => LayoutElement(
        id: tableId,
        type: LayoutElementType.table,
        label: '$tableNumber',
        floor: floor,
        x: x,
        y: y,
      );
}

/// The full salon layout for a branch.
class TableLayout {
  final String branchId;
  final List<LayoutTable> tables;
  final List<LayoutElement> elements;

  const TableLayout({
    required this.branchId,
    this.tables = const [],
    required this.elements,
  });

  List<LayoutElement> get allElements => [
        ...tables.map((t) => t.toElement()),
        ...elements,
      ];

  Map<String, dynamic> toJson() => {
        'branchId': branchId,
        'tables': tables.map((t) => t.toJson()).toList(),
        'elements': elements.map((e) => e.toJson()).toList(),
      };

  factory TableLayout.fromJson(Map<String, dynamic> json) {
    final tableList = (json['tables'] as List<dynamic>? ?? [])
        .map((e) => LayoutTable.fromJson(e as Map<String, dynamic>))
        .toList();
    final elementList = (json['elements'] as List<dynamic>? ?? [])
        .map((e) => LayoutElement.fromJson(e as Map<String, dynamic>))
        .where((e) => !e.isTable)
        .toList();
    return TableLayout(
      branchId: json['branchId'] as String? ?? '',
      tables: tableList,
      elements: elementList,
    );
  }

  /// Legacy cache: elements-only JSON; table-type rows become [LayoutTable].
  static TableLayout fromLegacyJson(String branchId, List<dynamic> elements) {
    final tables = <LayoutTable>[];
    final decor = <LayoutElement>[];

    for (final raw in elements) {
      final e = LayoutElement.fromJson(raw as Map<String, dynamic>);
      if (e.isTable) {
        tables.add(LayoutTable(
          tableId: e.id,
          layoutElementId: e.id,
          tableNumber: int.tryParse(e.label) ?? tables.length + 1,
          floor: e.floor,
          x: e.x,
          y: e.y,
          isPending: true,
        ));
      } else {
        decor.add(e);
      }
    }

    return TableLayout(branchId: branchId, tables: tables, elements: decor);
  }
}
