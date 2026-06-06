class ModerationResult {
  final bool passed;
  final List<String> violations;
  final String message;
  final Map<String, dynamic> details;

  const ModerationResult({
    required this.passed,
    this.violations = const [],
    required this.message,
    this.details = const {},
  });

  factory ModerationResult.passed({
    String message = 'Nội dung hợp lệ.',
    Map<String, dynamic> details = const {},
  }) {
    return ModerationResult(
      passed: true,
      message: message,
      details: details,
    );
  }

  factory ModerationResult.rejected({
    required List<String> violations,
    required String message,
    Map<String, dynamic> details = const {},
  }) {
    return ModerationResult(
      passed: false,
      violations: violations,
      message: message,
      details: details,
    );
  }

  Map<String, dynamic> toMap() => {
        'passed': passed,
        'violations': violations,
        'message': message,
        'details': details,
      };

  factory ModerationResult.fromMap(Map<String, dynamic> map) {
    return ModerationResult(
      passed: map['passed'] == true,
      violations: List<String>.from(map['violations'] ?? []),
      message: map['message']?.toString() ?? '',
      details: Map<String, dynamic>.from(map['details'] ?? {}),
    );
  }
}
