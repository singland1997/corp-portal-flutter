class ApiFailure implements Exception {
  const ApiFailure({required this.code, required this.message, this.status});
  final String code;
  final String message;
  final int? status;
  @override
  String toString() => 'ApiFailure($code, $status)';
}
