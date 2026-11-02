class ApiProblem implements Exception {
  const ApiProblem({
    required this.status,
    required this.code,
    required this.title,
    this.fieldErrors = const [],
  });

  final int status;
  final String code;
  final String title;
  final List<String> fieldErrors;

  bool get isNetwork => status == 0;
  bool get isValidation => status == 400;
  bool get isDenied => status == 403;
  bool get isUnauthenticated => status == 401;

  String get message {
    if (isNetwork) {
      return "We couldn't reach Softxu. Check your connection and try again.";
    }
    return [title, ...fieldErrors].where((line) => line.isNotEmpty).join(' ');
  }
}
