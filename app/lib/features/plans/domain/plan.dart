final class Plan {
  Plan({
    required this.id,
    required String name,
    required this.enabled,
    required this.priority,
    required this.defaultOrder,
    required this.createdAt,
    required this.updatedAt,
  }) : name = name.trim() {
    _requireNonempty(id, 'id');
    _requireNonempty(this.name, 'name');
    if (defaultOrder < 0) {
      throw ArgumentError.value(
        defaultOrder,
        'defaultOrder',
        'Must not be negative.',
      );
    }
    _requireUtc(createdAt, 'createdAt');
    _requireUtc(updatedAt, 'updatedAt');
  }

  final String id;
  final String name;
  final bool enabled;
  final int priority;
  final int defaultOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
}

void _requireNonempty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, name, 'Must use UTC.');
  }
}
