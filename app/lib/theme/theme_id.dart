final class ThemeId {
  const ThemeId(this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is ThemeId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
