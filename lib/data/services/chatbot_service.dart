import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';

enum ChatbotIntent {
  greeting,
  wantToBook,
  selectSlot,
  addNote,
  confirm,
  cancel,
  unknown,
}

class ChatbotMessage {
  final String content;
  final bool isBot;
  final DateTime time;
  final List<String>? quickReplies;
  final BookingModel? booking;

  ChatbotMessage({
    required this.content,
    required this.isBot,
    DateTime? time,
    this.quickReplies,
    this.booking,
  }) : time = time ?? DateTime.now();
}

class ChatbotService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  ChatbotIntent detectIntent(String message) {
    final text = message.toLowerCase().trim();
    if (text.contains('hủy') || text.contains('thôi') || text.contains('không muốn')) return ChatbotIntent.cancel;
    if (text.contains('xác nhận') || text.contains('đồng ý') || text.contains('ok') || text.contains('được') || text.contains('chốt')) return ChatbotIntent.confirm;
    if (text.contains('xin chào') || text.contains('hello') || text.contains('chào') || text.contains('hi')) return ChatbotIntent.greeting;
    if (text.contains('xem phòng') || text.contains('đặt lịch') || text.contains('muốn xem')) return ChatbotIntent.wantToBook;
    if (_extractSlotFromText(text) != null) return ChatbotIntent.selectSlot;
    return ChatbotIntent.unknown;
  }

  String? _extractSlotFromText(String text) {
    final patterns = [RegExp(r'(\d{1,2})[h:]'), RegExp(r'sáng'), RegExp(r'chiều'), RegExp(r'tối')];
    for (final p in patterns) { if (p.hasMatch(text)) return text; }
    return null;
  }

  String? matchSlotFromMessage(String message, List<String> slots) {
    final text = message.toLowerCase();
    for (final slot in slots) {
      final s = slot.toLowerCase();
      final m = RegExp(r'(\d{1,2})').firstMatch(s);
      if (m != null && text.contains(m.group(0)!)) return slot;
      if (text.contains('sáng') && s.contains('sáng')) return slot;
      if (text.contains('chiều') && s.contains('chiều')) return slot;
      if (text.contains('tối') && s.contains('tối')) return slot;
    }
    return null;
  }

  DateTime? extractDateFromMessage(String message) {
    final text = message.toLowerCase();
    final now = DateTime.now();
    if (text.contains('hôm nay')) return now;
    if (text.contains('ngày mai') || text.contains('mai')) return now.add(const Duration(days: 1));
    if (text.contains('ngày kia')) return now.add(const Duration(days: 2));
    if (text.contains('cuối tuần') || text.contains('thứ 7')) {
      final d = 6 - now.weekday;
      return now.add(Duration(days: d <= 0 ? 7 : d));
    }
    final match = RegExp(r'(\d{1,2})[/\-](\d{1,2})').firstMatch(text);
    if (match != null) {
      final day = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      if (day != null && month != null) return DateTime(now.year, month, day);
    }
    return null;
  }

  ChatbotResponse generateResponse({
    required String userMessage,
    required ConversationState state,
    required List<String> availableSlots,
    required String listingTitle,
    required String landlordName,
  }) {
    final intent = detectIntent(userMessage);
    switch (state.step) {
      case ConversationStep.initial:
        return _handleInitial(availableSlots, listingTitle, landlordName);
      case ConversationStep.waitingForTime:
        return _handleTimeSelection(userMessage, intent, availableSlots, state);
      case ConversationStep.waitingForDate:
        return _handleDateSelection(userMessage, intent, state);
      case ConversationStep.waitingForNote:
        return _handleNoteInput(userMessage, state);
      case ConversationStep.waitingForConfirm:
        return _handleConfirmation(userMessage, intent);
      case ConversationStep.done:
        return ChatbotResponse(
          message: 'Lịch hẹn đã được đặt! Xem lại ở biểu tượng 📅 phía trên.',
          nextStep: ConversationStep.done,
        );
    }
  }

  ChatbotResponse _handleInitial(List<String> slots, String title, String landlord) {
    final slotsText = slots.isEmpty ? 'linh hoạt theo yêu cầu' : slots.join('\n• ');
    return ChatbotResponse(
      message: 'Tôi sẽ giúp bạn đặt lịch xem phòng "$title" của $landlord 🏠\n\nCác khung giờ trống:\n• $slotsText\n\nBạn muốn xem vào buổi nào?',
      quickReplies: slots.isNotEmpty ? slots.take(3).toList() : ['Sáng', 'Chiều', 'Tối'],
      nextStep: ConversationStep.waitingForTime,
    );
  }

  ChatbotResponse _handleTimeSelection(String message, ChatbotIntent intent, List<String> slots, ConversationState state) {
    if (intent == ChatbotIntent.cancel) {
      return ChatbotResponse(message: 'Đã hủy. Nhắn lại bất cứ lúc nào nhé!', nextStep: ConversationStep.initial);
    }
    final slot = matchSlotFromMessage(message, slots) ?? message.trim();
    return ChatbotResponse(
      message: 'Bạn chọn "$slot".\n\nBạn muốn đến vào ngày nào?',
      quickReplies: ['Hôm nay', 'Ngày mai', 'Cuối tuần'],
      nextStep: ConversationStep.waitingForDate,
      data: {'slot': slot},
    );
  }

  ChatbotResponse _handleDateSelection(String message, ChatbotIntent intent, ConversationState state) {
    if (intent == ChatbotIntent.cancel) {
      return ChatbotResponse(message: 'Đã hủy. Nhắn lại bất cứ lúc nào nhé!', nextStep: ConversationStep.initial);
    }
    final date = extractDateFromMessage(message);
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : message.trim();
    return ChatbotResponse(
      message: 'Ngày $dateStr, giờ ${state.selectedSlot ?? ""}.\n\nBạn có ghi chú gì thêm không?',
      quickReplies: ['Không có ghi chú', 'Tôi đi một mình', 'Tôi đi cùng bạn'],
      nextStep: ConversationStep.waitingForNote,
      data: {'date': dateStr, 'dateTime': date?.toIso8601String()},
    );
  }

  ChatbotResponse _handleNoteInput(String message, ConversationState state) {
    final note = message.toLowerCase().contains('không') || message.toLowerCase().contains('ko') ? null : message.trim();
    final summary = '📅 ${state.selectedDate ?? ""}\n⏰ ${state.selectedSlot ?? ""}\n${note != null ? "📝 $note\n" : ""}\nXác nhận đặt lịch không?';
    return ChatbotResponse(
      message: summary,
      quickReplies: ['✅ Xác nhận', '❌ Hủy'],
      nextStep: ConversationStep.waitingForConfirm,
      data: {'note': note},
    );
  }

  ChatbotResponse _handleConfirmation(String message, ChatbotIntent intent) {
    if (intent == ChatbotIntent.cancel || message.toLowerCase().contains('hủy')) {
      return ChatbotResponse(message: 'Đã hủy yêu cầu. Nhắn lại bất cứ lúc nào nhé!', nextStep: ConversationStep.initial);
    }
    return ChatbotResponse(
      message: '✅ Đã gửi yêu cầu đặt lịch!\n\nChủ trọ sẽ xác nhận sớm. Bạn sẽ thấy trạng thái cập nhật ở đây.',
      nextStep: ConversationStep.done,
      shouldCreateBooking: true,
    );
  }

  Future<BookingModel> createBooking({
    required String listingId,
    required String listingTitle,
    required String landlordId,
    required String chatId,
    required DateTime scheduledTime,
    String? note,
  }) async {
    final tenantId = _auth.currentUser?.uid ?? '';
    final ref = _firestore.collection('bookings').doc();
    final booking = BookingModel(
      id: ref.id,
      listingId: listingId,
      listingTitle: listingTitle,
      tenantId: tenantId,
      landlordId: landlordId,
      chatId: chatId,
      scheduledTime: scheduledTime,
      status: BookingStatus.pending,
      note: note,
      createdAt: DateTime.now(),
    );
    await ref.set(booking.toMap());
    return booking;
  }

  Future<List<String>> getAvailableSlots(String landlordId) async {
    try {
      final doc = await _firestore.collection('users').doc(landlordId).collection('availability').doc('slots').get();
      if (!doc.exists) return _defaultSlots();
      return List<String>.from((doc.data() as Map<String, dynamic>)['slots'] ?? _defaultSlots());
    } catch (_) {
      return _defaultSlots();
    }
  }

  Future<void> updateBookingStatus(String bookingId, BookingStatus status) async {
    await _firestore.collection('bookings').doc(bookingId).update({'status': status.name});
  }

  List<String> _defaultSlots() => ['Sáng: 8:00 - 10:00', 'Sáng: 10:00 - 12:00', 'Chiều: 14:00 - 16:00', 'Chiều: 16:00 - 18:00'];
}

enum ConversationStep { initial, waitingForTime, waitingForDate, waitingForNote, waitingForConfirm, done }

class ConversationState {
  final ConversationStep step;
  final String? selectedSlot;
  final String? selectedDate;
  final DateTime? selectedDateTime;
  final String? note;

  const ConversationState({
    this.step = ConversationStep.initial,
    this.selectedSlot,
    this.selectedDate,
    this.selectedDateTime,
    this.note,
  });

  ConversationState copyWith({
    ConversationStep? step,
    String? selectedSlot,
    String? selectedDate,
    DateTime? selectedDateTime,
    String? note,
  }) {
    return ConversationState(
      step: step ?? this.step,
      selectedSlot: selectedSlot ?? this.selectedSlot,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedDateTime: selectedDateTime ?? this.selectedDateTime,
      note: note ?? this.note,
    );
  }
}

class ChatbotResponse {
  final String message;
  final List<String>? quickReplies;
  final ConversationStep nextStep;
  final Map<String, dynamic>? data;
  final bool shouldCreateBooking;

  ChatbotResponse({
    required this.message,
    this.quickReplies,
    required this.nextStep,
    this.data,
    this.shouldCreateBooking = false,
  });
}