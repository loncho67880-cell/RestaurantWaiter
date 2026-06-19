/// Kinds of elements the waiter can place on the salon canvas.
enum LayoutElementType { table, entrance, restroom, bar, kitchen }

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
  double x;
  double y;

  LayoutElement({
    required this.id,
    required this.type,
    required this.label,
    required this.x,
    required this.y,
  });

  bool get isTable => type == LayoutElementType.table;

  LayoutElement copyWith({String? label, double? x, double? y}) => LayoutElement(
        id: id,
        type: type,
        label: label ?? this.label,
        x: x ?? this.x,
        y: y ?? this.y,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'label': label,
        'x': x,
        'y': y,
      };

  factory LayoutElement.fromJson(Map<String, dynamic> json) => LayoutElement(
        id: json['id'] as String,
        type: _typeFromString(json['type'] as String?),
        label: json['label'] as String? ?? '',
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );
}

/// The full salon layout for a branch.
class TableLayout {
  final String branchId;
  final List<LayoutElement> elements;

  const TableLayout({
    required this.branchId,
    required this.elements,
  });

  Map<String, dynamic> toJson() => {
        'branchId': branchId,
        'elements': elements.map((e) => e.toJson()).toList(),
      };

  factory TableLayout.fromJson(Map<String, dynamic> json) => TableLayout(
        branchId: json['branchId'] as String? ?? '',
        elements: (json['elements'] as List<dynamic>? ?? [])
            .map((e) => LayoutElement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
