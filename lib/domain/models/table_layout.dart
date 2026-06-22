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
    orElse: () => LayoutElementType.table,
  );
}

/// A single positioned element on the salon canvas.
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

  LayoutElement copyWith({String? label, int? floor, double? x, double? y}) =>
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
        x: ((json['x'] ?? json['X']) as num).toDouble(),
        y: ((json['y'] ?? json['Y']) as num).toDouble(),
      );
}

/// A table entry within the layout (from backend).
class LayoutTable {
  final String tableId;
  final int tableNumber;
  final int floor;
  final int capacity;
  final double positionX;
  final double positionY;
  final String shape;

  const LayoutTable({
    required this.tableId,
    required this.tableNumber,
    required this.floor,
    required this.capacity,
    required this.positionX,
    required this.positionY,
    required this.shape,
  });

  factory LayoutTable.fromJson(Map<String, dynamic> json) => LayoutTable(
        tableId: (json['tableId'] ?? json['TableId'])?.toString() ?? '',
        tableNumber:
            (json['tableNumber'] ?? json['TableNumber'] as num?)?.toInt() ?? 0,
        floor: (json['floor'] ?? json['Floor'] as num?)?.toInt() ?? 1,
        capacity:
            (json['capacity'] ?? json['Capacity'] as num?)?.toInt() ?? 0,
        positionX:
            ((json['positionX'] ?? json['PositionX']) as num).toDouble(),
        positionY:
            ((json['positionY'] ?? json['PositionY']) as num).toDouble(),
        shape: (json['shape'] ?? json['Shape']) as String? ?? 'circle',
      );

  Map<String, dynamic> toJson() => {
        'tableId': tableId,
        'floor': floor,
        'positionX': positionX,
        'positionY': positionY,
        'shape': shape,
      };

  LayoutElement toElement() => LayoutElement(
        id: tableId,
        type: LayoutElementType.table,
        label: '$tableNumber',
        floor: floor,
        x: positionX * 1000,
        y: positionY * 1000,
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

  /// Flat list: tables converted to LayoutElement + decorative elements.
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
        .toList();
    return TableLayout(
      branchId: json['branchId'] as String? ?? '',
      tables: tableList,
      elements: elementList,
    );
  }

  /// Legacy constructor used by SharedPreferences fallback (elements-only JSON).
  static TableLayout fromLegacyJson(String branchId, List<dynamic> elements) =>
      TableLayout(
        branchId: branchId,
        tables: const [],
        elements: elements
            .map((e) => LayoutElement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
