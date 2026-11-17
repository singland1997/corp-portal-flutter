/// Strict API boundary: missing/invalid values must not turn into fabricated zeroes.
Map<String, dynamic> jsonObject(dynamic value) {
  if (value is! Map<String, dynamic>) throw const FormatException('Expected object');
  return value;
}

List<T> jsonList<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) throw const FormatException('Expected list');
  return List.unmodifiable(value.map((item) => parse(jsonObject(item))));
}

extension JsonRead on Map<String, dynamic> {
  String string(String key) {
    final value = this[key];
    if (value is! String) throw FormatException('Expected string: $key');
    return value;
  }

  String? optionalString(String key) => this[key] == null ? null : string(key);
  double number(String key) {
    final value = this[key];
    if (value is! num || !value.isFinite) throw FormatException('Expected number: $key');
    return value.toDouble();
  }

  double? optionalNumber(String key) => this[key] == null ? null : number(key);
  bool boolean(String key) {
    final value = this[key];
    if (value is! bool) throw FormatException('Expected boolean: $key');
    return value;
  }

  String enumString(String key, Set<String> allowed) {
    final value = string(key);
    if (!allowed.contains(value)) throw FormatException('Invalid value: $key');
    return value;
  }

  String? optionalStatus(String key) => this[key] == null
      ? null
      : enumString(key, {'active', 'inactive', 'suspended', 'pending', 'failed', 'terminated'});
}
