import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'admin_ticket_page.dart';

class AdminNotificationsPage extends StatelessWidget {
  const AdminNotificationsPage({super.key});

  Stream<List<QueryDocumentSnapshot>> _fetchRecentNotifications() {
    Stream<QuerySnapshot> medicationStream = FirebaseFirestore.instance
        .collection("medication_requests")
        .orderBy("timestamp", descending: true)
        .limit(5)
        .snapshots();

    Stream<QuerySnapshot> wheelchairStream = FirebaseFirestore.instance
        .collection("wheelchair_requests")
        .orderBy("timestamp", descending: true)
        .limit(5)
        .snapshots();

    Stream<QuerySnapshot> serviceStream = FirebaseFirestore.instance
        .collection("service_requests")
        .orderBy("timestamp", descending: true)
        .limit(5)
        .snapshots();

    Stream<QuerySnapshot> commentNotificationStream = FirebaseFirestore.instance
        .collection("notifications")
        .orderBy("timestamp", descending: true)
        .limit(5)
        .snapshots();

    return Rx.combineLatest4(
      medicationStream,
      wheelchairStream,
      serviceStream,
      commentNotificationStream,
      (
        QuerySnapshot medication,
        QuerySnapshot wheelchair,
        QuerySnapshot service,
        QuerySnapshot comments,
      ) {
        List<QueryDocumentSnapshot> allNotifications = [
          ...medication.docs,
          ...wheelchair.docs,
          ...service.docs,
          ...comments.docs,
        ];

        allNotifications.sort((a, b) {
          Timestamp timeA = a["timestamp"] ?? Timestamp(0, 0);
          Timestamp timeB = b["timestamp"] ?? Timestamp(0, 0);
          return timeB.compareTo(timeA);
        });

        return allNotifications.take(10).toList();
      },
    );
  }

  void _navigateToTicket(BuildContext context, String ticketNumber) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    List<String> collections = [
      "medication_requests",
      "wheelchair_requests",
      "service_requests"
    ];

    for (String collection in collections) {
      var querySnapshot = await firestore
          .collection(collection)
          .where("ticketNumber", isEqualTo: ticketNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var ticketDoc = querySnapshot.docs.first;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketDetailPage(request: ticketDoc),
          ),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Ticket #$ticketNumber not found!")),
    );
  }

  Future<void> _deleteNotification(
    BuildContext context,
    QueryDocumentSnapshot doc,
    String collectionName,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(doc.id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notification deleted.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Notifications")),
      body: StreamBuilder(
        stream: _fetchRecentNotifications(),
        builder: (context, AsyncSnapshot<List<QueryDocumentSnapshot>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No recent notifications."));
          }

          var notifications = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var doc = notifications[index];
              var data = doc.data() as Map<String, dynamic>;
              String collectionName = doc.reference.parent.id;

              bool isTicket = data.containsKey('ticketNumber');
              bool isComment = data.containsKey('type') && (data['type'] == 'reply' || data['type'] == 'comment');
              bool isSOS = data.containsKey('type') && data['type'] == 'sos';

              String formattedTime = data['timestamp'] is Timestamp
                  ? DateFormat('MMM dd, yyyy – hh:mm a').format(data['timestamp'].toDate())
                  : "Unknown Time";

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isTicket) ...[
                              Text(
                                'Ticket No. #${data['ticketNumber'] ?? "Unknown"}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Text("📅 $formattedTime", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 5),
                              Text("📂 Category: ${data['category'] ?? "No Category"}", style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 3),
                              Text("📧 User: ${data['user'] ?? "No Email"}", style: const TextStyle(fontSize: 12)),
                            ] else if (isSOS) ...[
                              Text(
                                '🚨 Emergency Alert',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "👤 User: ${data['userFullName'] ?? 'Unknown'}", // This will display the full name of the user who made the SOS request
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 5),
                              Text("📅 $formattedTime", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 5),
                              Text("🔔 Message: ${data['message'] ?? 'No message provided'}"),
                            ] else if (isComment) ...[
  const Text(
    '🗨️ New Comment/Reply',
    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  ),
  const SizedBox(height: 5),
  Text("🧑 From: ${data['commentedBy'] ?? data['repliedBy'] ?? "Unknown"}"),
  const SizedBox(height: 5),
  Text("💬 \"${data['comment'] ?? "No comment"}\""),
  const SizedBox(height: 5),
  Text("📅 $formattedTime", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Delete Notification"),
                              content: const Text("Are you sure you want to delete this notification?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteNotification(context, doc, collectionName);
                                  },
                                  child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
