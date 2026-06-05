import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../presentation/pages/post_deep_link_page.dart';

class DeepLinkService {
  static const String scheme = 'roomfinder';
  static const String host = 'roomfinder';
  static const String listingPath = 'listing';

  static Uri postUri(String postId) {
    return Uri(
      scheme: scheme,
      host: host,
      pathSegments: [listingPath, postId],
    );
  }

  static String? extractPostIdFromText(String text) {
    final match = RegExp(r'roomfinder://[^\s]+').firstMatch(text);
    if (match == null) return null;
    return postIdFromUri(Uri.tryParse(match.group(0)!));
  }

  static String? postIdFromRouteName(String? routeName) {
    if (routeName == null || routeName.isEmpty || routeName == '/') {
      return null;
    }

    final uri = Uri.tryParse(routeName);
    if (uri == null) return null;

    return _postIdFromSegments(uri.pathSegments);
  }

  static String? postIdFromUri(Uri? uri) {
    if (uri == null) return null;

    if (uri.scheme == scheme) {
      if (uri.host == host) {
        return _postIdFromSegments(uri.pathSegments);
      }

      // Backward compatible with old links: roomfinder://listing/{postId}
      if (uri.host == listingPath && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
    }

    if (!uri.hasScheme) {
      return _postIdFromSegments(uri.pathSegments);
    }

    return null;
  }

  static Future<void> openPost(BuildContext context, String postId) async {
    if (postId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDeepLinkPage(postId: postId)),
    );
  }

  static Future<bool> postExists(String postId) async {
    final doc = await FirebaseFirestore.instance
        .collection('listings')
        .doc(postId)
        .get();
    return doc.exists;
  }

  static String? _postIdFromSegments(List<String> segments) {
    if (segments.length >= 2 && segments.first == listingPath) {
      return segments[1];
    }

    // Flutter can drop the host part for custom schemes. This keeps
    // roomfinder://listing/{postId} usable when the initial route is /{postId}.
    if (segments.length == 1 && segments.first.isNotEmpty) {
      return segments.first;
    }

    return null;
  }
}
