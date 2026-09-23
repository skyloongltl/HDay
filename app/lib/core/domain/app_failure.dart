enum FailureCode {
  validation,
  duplicate,
  notFound,
  conflict,
  persistence,
  unavailable,
}

final class AppFailure implements Exception {
  const AppFailure(this.code, {this.detail});

  final FailureCode code;
  final String? detail;

  @override
  String toString() => detail == null
      ? 'AppFailure(${code.name})'
      : 'AppFailure(${code.name}, $detail)';
}
