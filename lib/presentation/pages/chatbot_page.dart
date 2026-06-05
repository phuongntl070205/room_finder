import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/booking_model.dart';
import '../../data/services/chatbot_service.dart';

class ChatbotPage extends StatefulWidget {
  final String chatId;
  final String listingId;
  final String listingTitle;
  final String landlordId;
  final String landlordName;

  const ChatbotPage({
    super.key,
    required this.chatId,
    required this.listingId,
    required this.listingTitle,
    required this.landlordId,
    required this.landlordName,
  });

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final _service = ChatbotService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatbotMessage>[];
  List<String> _slots = [];
  ConversationState _state = const ConversationState();
  BookingModel? _booking;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _slots = await _service.getAvailableSlots(widget.landlordId);
    final response = _service.generateResponse(
      userMessage: '',
      state: _state,
      availableSlots: _slots,
      listingTitle: widget.listingTitle,
      landlordName: widget.landlordName,
    );
    setState(() {
      _messages.add(ChatbotMessage(
        content: response.message,
        isBot: true,
        quickReplies: response.quickReplies,
      ));
      _state = _state.copyWith(step: response.nextStep);
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    _controller.clear();

    setState(() {
      _messages.add(ChatbotMessage(content: text, isBot: false));
      _isLoading = true;
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 600));

    final response = _service.generateResponse(
      userMessage: text,
      state: _state,
      availableSlots: _slots,
      listingTitle: widget.listingTitle,
      landlordName: widget.landlordName,
    );

    // Cập nhật state hội thoại
    ConversationState newState = _state.copyWith(step: response.nextStep);
    if (response.data != null) {
      if (response.data!['slot'] != null) newState = newState.copyWith(selectedSlot: response.data!['slot'] as String);
      if (response.data!['date'] != null) newState = newState.copyWith(selectedDate: response.data!['date'] as String);
      if (response.data!['dateTime'] != null) {
        newState = newState.copyWith(selectedDateTime: DateTime.tryParse(response.data!['dateTime'] as String));
      }
      if (response.data!.containsKey('note')) newState = newState.copyWith(note: response.data!['note'] as String?);
    }

    // Tạo booking nếu xác nhận
    BookingModel? newBooking;
    if (response.shouldCreateBooking) {
      try {
        final scheduledTime = newState.selectedDateTime ?? DateTime.now().add(const Duration(days: 1));
        newBooking = await _service.createBooking(
          listingId: widget.listingId,
          listingTitle: widget.listingTitle,
          landlordId: widget.landlordId,
          chatId: widget.chatId,
          scheduledTime: scheduledTime,
          note: newState.note,
        );
      } catch (_) {}
    }

    setState(() {
      _state = newState;
      _booking = newBooking ?? _booking;
      _messages.add(ChatbotMessage(
        content: response.message,
        isBot: true,
        quickReplies: response.nextStep != ConversationStep.done ? response.quickReplies : null,
        booking: newBooking,
      ));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue[100],
              child: const Icon(Icons.smart_toy, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trợ lý đặt lịch', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('Tự động', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          if (_booking != null)
            IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: _showBookingDetail,
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner phòng
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue[50],
            child: Row(
              children: [
                const Icon(Icons.home, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.listingTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text('Chủ: ${widget.landlordName}',
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return _buildTypingIndicator();
                return _buildBubble(_messages[index]);
              },
            ),
          ),

          // Quick replies
          if (_messages.isNotEmpty && _messages.last.quickReplies != null && !_isLoading)
            _buildQuickReplies(_messages.last.quickReplies!),

          // Input
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatbotMessage msg) {
    final isBot = msg.isBot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isBot) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              child: const Icon(Icons.smart_toy, color: Colors.blue, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isBot ? Colors.white : Colors.blue[600],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isBot ? Radius.zero : const Radius.circular(16),
                      bottomRight: isBot ? const Radius.circular(16) : Radius.zero,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(color: isBot ? Colors.black87 : Colors.white, fontSize: 14),
                  ),
                ),
                if (msg.booking != null) ...[
                  const SizedBox(height: 6),
                  _buildBookingCard(msg.booking!),
                ],
                const SizedBox(height: 2),
                Text(DateFormat('HH:mm').format(msg.time),
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    final color = booking.status == BookingStatus.confirmed
        ? Colors.green
        : booking.status == BookingStatus.cancelled
        ? Colors.red
        : Colors.orange;
    final statusText = booking.status == BookingStatus.confirmed
        ? '✅ Đã xác nhận'
        : booking.status == BookingStatus.cancelled
        ? '❌ Đã hủy'
        : '⏳ Chờ xác nhận';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.calendar_today, size: 14, color: color),
            const SizedBox(width: 6),
            Text(DateFormat('EEEE, dd/MM/yyyy', 'vi').format(booking.scheduledTime),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(DateFormat('HH:mm').format(booking.scheduledTime),
                style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ]),
          if (booking.note?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.note, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(child: Text(booking.note!, style: TextStyle(color: Colors.grey[700], fontSize: 13))),
            ]),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(statusText, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue[100],
            child: const Icon(Icons.smart_toy, color: Colors.blue, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _dot(), const SizedBox(width: 4), _dot(), const SizedBox(width: 4), _dot(),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _dot() => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(color: Colors.blue[300], shape: BoxShape.circle),
  );

  Widget _buildQuickReplies(List<String> replies) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: replies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ActionChip(
          label: Text(replies[i], style: const TextStyle(fontSize: 13)),
          backgroundColor: Colors.blue[50],
          side: BorderSide(color: Colors.blue[200]!),
          onPressed: () => _send(replies[i]),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              enabled: _state.step != ConversationStep.done,
              decoration: InputDecoration(
                hintText: _state.step == ConversationStep.done ? 'Đã hoàn tất' : 'Nhập tin nhắn...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _isLoading || _state.step == ConversationStep.done ? Colors.grey : Colors.blue,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _isLoading || _state.step == ConversationStep.done
                  ? null
                  : () => _send(_controller.text),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingDetail() {
    final b = _booking;
    if (b == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chi tiết lịch hẹn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildBookingCard(b),
            const SizedBox(height: 16),
            if (b.status == BookingStatus.pending)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _service.updateBookingStatus(b.id, BookingStatus.cancelled);
                    setState(() => _booking = b.copyWith(status: BookingStatus.cancelled));
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('Hủy lịch hẹn', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}