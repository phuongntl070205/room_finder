import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  // Khởi tạo hoặc lấy cuộc hội thoại hiện có
  Future<String> getOrCreateChat(String otherId, {String? postId}) async {
    if (_currentUid == null) throw Exception('Chưa đăng nhập');

    List<String> ids = [_currentUid!, otherId];
    ids.sort();
    String chatId = ids.join('_');

    final chatDoc = await _db.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await _db.collection('chats').doc(chatId).set({
        'participants': ids,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        if (postId != null && postId.isNotEmpty) 'postId': postId,
        'unreadCount': {
          _currentUid!: 0,
          otherId: 0,
        },
      });
    } else if (postId != null && postId.isNotEmpty) {
      await _db.collection('chats').doc(chatId).set({
        'postId': postId,
      }, SetOptions(merge: true));
    }
    return chatId;
  }

  // Gửi tin nhắn thực tế
  Future<void> sendMessage(String chatId, String text) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final String currentUid = currentUser.uid;
    final chatRef = _db.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data();
    final participants = List<String>.from(chatData?['participants'] ?? []);
    String? receiverId;
    for (final id in participants) {
      if (id != currentUid) {
        receiverId = id;
        break;
      }
    }

    final batch = _db.batch();

    // 1. Thêm tin nhắn vào sub-collection
    DocumentReference msgRef =
        _db.collection('chats').doc(chatId).collection('messages').doc();
    batch.set(msgRef, {
      'senderId': currentUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Cập nhật thông tin cuộc hội thoại
    final updateData = <String, dynamic>{
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUid,
    };
    if (receiverId != null) {
      updateData['unreadCount.$receiverId'] = FieldValue.increment(1);
      updateData['unreadCount.$currentUid'] = 0;
    }
    batch.update(chatRef, updateData);

    await batch.commit();

    // 3. Gửi thông báo cho người nhận
    try {
      if (receiverId == null) return;

      final senderDoc = await _db.collection('users').doc(currentUid).get();
      final senderName = senderDoc.data()?['displayName'] ?? 'Ai đó';

      print(
          'DEBUG: Sending message notification to $receiverId from $senderName');

      await _db
          .collection('users')
          .doc(receiverId)
          .collection('notifications')
          .add({
        'title': 'Tin nhắn mới từ $senderName',
        'body': text,
        'type': 'message',
        'chatId': chatId,
        'senderId': currentUid,
        if (chatData?['postId'] != null) 'postId': chatData?['postId'],
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('DEBUG: Notification added successfully');
    } catch (e) {
      print('DEBUG ERROR sending message notification: $e');
    }
  }
}
