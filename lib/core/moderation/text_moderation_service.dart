import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'moderation_result.dart';

class TextModerationService {
  TextModerationService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  Future<ModerationResult> moderateListing({
    required String title,
    required String description,
    required String address,
  }) {
    final text = [
      'Tiêu đề: $title',
      'Mô tả: $description',
      'Địa chỉ: $address',
    ].join('\n');
    return moderateText(text, context: 'listing');
  }

  Future<ModerationResult> moderateComment(String text) {
    return moderateText(text, context: 'comment');
  }

  Future<ModerationResult> moderateText(
    String text, {
    required String context,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return ModerationResult.rejected(
        violations: const ['Nội dung không được để trống.'],
        message: 'Nội dung không được để trống.',
        details: {'context': context, 'source': 'client_validation'},
      );
    }

    final callable = _functions.httpsCallable('moderateText');
    final user = FirebaseAuth.instance.currentUser;
    final authToken = await user?.getIdToken(true);
    final response = await callable.call<Map<String, dynamic>>({
      'text': normalized,
      'context': context,
      if (authToken != null) 'authToken': authToken,
    });

    return ModerationResult.fromMap(
      Map<String, dynamic>.from(response.data),
    );
  }
}
