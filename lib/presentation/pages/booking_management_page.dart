import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingManagementPage extends StatelessWidget {
  const BookingManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Quản lý lịch hẹn")),
      body: StreamBuilder<QuerySnapshot>(
        // Lọc theo landlordId để chủ trọ chỉ thấy lịch hẹn của họ
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('landlordId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Chưa có lịch hẹn nào"));
          }

          final bookings = snapshot.data!.docs;

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              var data = bookings[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'pending';

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text("Người thuê: ${data['userName']}"),
                  subtitle: Text("Thời gian: ${data['date']} - ${data['timeSlot']}\nPhòng: ${data['listingTitle']}"),
                  trailing: status == 'pending'
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => _updateStatus(bookings[index].id, 'confirmed')),
                      IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _updateStatus(bookings[index].id, 'rejected')),
                    ],
                  )
                      : Chip(
                    label: Text(status.toUpperCase()),
                    backgroundColor: status == 'confirmed' ? Colors.green[100] : Colors.red[100],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _updateStatus(String docId, String status) {
    FirebaseFirestore.instance.collection('bookings').doc(docId).update({'status': status});
  }
}