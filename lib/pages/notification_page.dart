import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../services/talkback_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:async/async.dart';
import 'post_details_page.dart';


class UserNotificationsPage extends StatefulWidget {
  const UserNotificationsPage({super.key});

  @override
  State<UserNotificationsPage> createState() => _UserNotificationsPageState();
}

class _UserNotificationsPageState extends State<UserNotificationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Set<String> dismissedNotifications = {};

  @override
  void initState() {
    super.initState();

  }

Future<List<Map<String, dynamic>>> _fetchAdminPostsNotifications() async {
  final snapshot = await _firestore
      .collection('announcements')
      .orderBy('timestamp', descending: true)
      .get();

  return snapshot.docs.map((doc) {
    final data = doc.data();
    return {
      ...data,
      'type': 'admin_post',
      'id': doc.id,
      'timestamp': data['timestamp'], // ✅ Add this
    };
  }).toList();
}



Future<List<Map<String, dynamic>>> _fetchAdminRepliesToTickets() async {
  final userEmail = _auth.currentUser?.email;
  if (userEmail == null) return [];

  final List<String> ticketTypes = [
    'wheelchair_requests',
    'medication_requests',
    'service_requests'
  ];

  List<Map<String, dynamic>> adminReplies = [];

  for (String collectionName in ticketTypes) {
    final ticketSnapshot = await _firestore
        .collection(collectionName)
        .where('email', isEqualTo: userEmail)
        .get();

    for (var ticket in ticketSnapshot.docs) {
      final commentsSnapshot = await _firestore
          .collection(collectionName)
          .doc(ticket.id)
          .collection('comments')
          .where('role', isEqualTo: 'Admin')
          .orderBy('timestamp', descending: true)
          .get();

      for (var comment in commentsSnapshot.docs) {
        final commentData = comment.data();
        adminReplies.add({
          'type': 'admin_ticket_reply',
          'id': comment.id,
          'timestamp': commentData['timestamp'],
          'text': commentData['text'],
          'ticketType': collectionName.replaceAll('_requests', ''),
        });
      }
    }
  }

  return adminReplies;
}
 Stream<List<Map<String, dynamic>>> getNotifications() async* {
  final userId = _auth.currentUser?.uid;
  final userEmail = _auth.currentUser?.email;

  if (userEmail == null) {
    yield [];
    return;
  }

  final generalStream = _firestore
      .collection('notifications')
      .where('userId', whereIn: [userId, 'all_users'])
      .snapshots();

  final userNotifStream = _firestore
      .collection('user_notifications')
      .where('user', isEqualTo: userEmail)
      .snapshots();

  final personalStream = _firestore
      .collection("notifications")
      .doc(userEmail)
      .collection("user_requests")
      .orderBy("timestamp", descending: true)
      .snapshots();

  await for (final combined in StreamZip([
    generalStream,
    userNotifStream,
    personalStream,
  ])) {
   final manualAdminPosts = await _fetchAdminPostsNotifications();
final manualTicketReplies = await _fetchAdminRepliesToTickets();

final allNotifications = [
  ...combined[0].docs.map((doc) => {...doc.data(), 'id': doc.id}),
  ...combined[1].docs.map((doc) => {...doc.data(), 'id': doc.id}),
  ...combined[2].docs.map((doc) => {...doc.data(), 'id': doc.id}),
  ...manualAdminPosts,
  ...manualTicketReplies,
];



    allNotifications.sort((a, b) {
      final tsA = a['timestamp'] as Timestamp?;
      final tsB = b['timestamp'] as Timestamp?;
      return (tsB?.compareTo(tsA ?? Timestamp.now()) ?? 0);
    });

    yield allNotifications;
  }
}
  void _showEventPopup(String title, String message) {
  String displayMessage = message.trim().isEmpty || message == "No details available"
      ? "Your ticket has been sent"
      : message;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(displayMessage),
      actions: [
        TextButton(
          onPressed: () { HapticService.instance.buttonPress(); Navigator.pop(context); },
          child: const Text("Close"),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(
        title: const Text(
          "NOTIFICATIONS",
          style: TextStyle(
            color: Color.fromARGB(255, 250, 250, 250),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 5.0,
          ),
        ),
        toolbarHeight: 70,
        flexibleSpace: Container(
          width: double.infinity,
          height: 70,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Color.fromARGB(255, 0, 48, 96),
                width: 60.0,
              ),
            ),
          ),
        ),
        backgroundColor: Color.fromARGB(255, 0, 48, 96),
        centerTitle: true,
        leading: Semantics(
          label: "Back button",
          hint: "Go back to previous page",
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
            onPressed: () async {
              HapticService.instance.buttonPress();
              await TalkBackService.instance.speak("Going back from notifications");
              Navigator.pop(context);
            },
          ),
        ),
      ),
body: StreamBuilder<List<Map<String, dynamic>>>(

        stream: getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

          var notifications = snapshot.data!
      .where((notif) => !dismissedNotifications.contains(notif['id']))
      .where((notif) => notif['type'] != 'sos')
          .toList();

          if (notifications.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

     return ListView.builder(
  itemCount: notifications.length,
  itemBuilder: (context, index) {
    var notification = notifications[index];
    String docId = notification['id'] ?? index.toString();

    String requestText = notification['request'] ?? notification['message'] ?? 'your request';
    String message = notification['message'] ?? 'No details available';
    String status = notification['status'] ?? '';
    String adminComment = notification['admin_comment'] ?? '';
    String reason = notification['reason'] ?? 'No reason provided';

    IconData icon = Icons.notifications_active;
    Color iconColor = Colors.blue;
    String title = notification['title'] ?? 'Notification';
    String formattedMessage = '';

    if (notification['type'] == 'admin_post') {
      icon = Icons.campaign;
      iconColor = Colors.blueAccent;
      title = 'New Announcement';
      formattedMessage = 'A new announcement titled "${notification['title']}" has been posted.';
    } else if (notification['type'] == 'admin_reply') {
      icon = Icons.comment;
      iconColor = Colors.amber;
      title = 'Admin Replied to Your Comment';
      formattedMessage =
          "Admin replied to your comment on '${notification['relatedAnnouncement']}':\n\n\"${notification['text']}\"";
    } else if (notification['type'] == 'admin_ticket_reply') {
      icon = Icons.chat;
      iconColor = Colors.deepPurple;
      title = 'Admin Replied to Your Ticket';
      formattedMessage = "Admin commented on your ${notification['ticketType']} ticket:\n\n\"${notification['text']}\"";
    } else {
      // Old logic fallback
      if (status == "accepted") {
        icon = Icons.check_circle;
        iconColor = Colors.green;
        title = "Request Accepted";
        formattedMessage = "Your request '$requestText' has been accepted.\n\nReason: $reason";
      } else if (status == "denied") {
        icon = Icons.cancel;
        iconColor = Colors.red;
        title = "Request Denied";
        formattedMessage = "Your request '$requestText' has been denied.\n\nReason: $reason";
      } else {
        icon = Icons.notifications;
        iconColor = Colors.grey;
        formattedMessage = message.trim().isEmpty || message == "No details available"
            ? "Your ticket has been sent.\n\nReason: $reason"
            : "$message\n\nReason: $reason";
      }

      if (adminComment.isNotEmpty) {
        formattedMessage += "\n\nAdmin Comment: $adminComment";
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: 3,
      color: const Color.fromARGB(255, 250, 250, 250),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(formattedMessage),
        trailing: Text(
          _formatTimestamp(notification['timestamp']),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        onTap: () async {
          if (notification['type'] == 'admin_post') {
            // Fetch the post document using the id from notification
            final doc = await FirebaseFirestore.instance
                .collection('announcements')
                .doc(notification['id'])
                .get();
            if (doc.exists) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailsPage(post: doc),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Announcement not found.')),
              );
            }
          } else {
            _showEventPopup(title, formattedMessage);
          }
        },
      ),
    );
  },
);

        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      return "${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
    return "Unknown";
  }
}