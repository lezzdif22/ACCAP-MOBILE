import 'package:firebase/pages/post_details_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../components/text_size.dart';
import '../services/haptic_service.dart';
import '../services/talkback_service.dart';

class UserAnnouncementPage extends StatefulWidget {
  const UserAnnouncementPage({super.key});

  @override
  State<UserAnnouncementPage> createState() => _UserAnnouncementPageState();
}

class _UserAnnouncementPageState extends State<UserAnnouncementPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, TextEditingController> _commentControllers = {};
  String? userCategory;
  Map<String, bool> receivedStatus = {};
  Map<String, bool> attendStatus = {};
  late TabController _tabController;
  bool _isDisposed = false; // ✅ Added to prevent calling setState after dispose

  @override
  void initState() {
    super.initState();
    fetchUserCategory();
    loadStatuses();
    _tabController = TabController(length: 3, vsync: this);
  }
   @override
  void dispose() {
    _isDisposed = true; // ✅ Mark the state as disposed
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchUserCategory() async {
    String? userId = _auth.currentUser?.uid;
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists && mounted && !_isDisposed) {
      setState(() {
        userCategory = userDoc['disabilityType'] ?? 'All';
      });
    }
  }

    void loadStatuses() async {
    String? userEmail = _auth.currentUser?.email;

    var announcements = await _firestore.collection('announcements').get();
    Map<String, bool> newReceivedStatus = {};
    Map<String, bool> newAttendStatus = {};

    for (var post in announcements.docs) {
      String postId = post.id;

      QuerySnapshot receivedQuery = await _firestore
          .collection('notifications')
          .where('postId', isEqualTo: postId)
          .where('user', isEqualTo: userEmail)
          .where('action', isEqualTo: 'received')
          .get();

      QuerySnapshot attendedQuery = await _firestore
          .collection('notifications')
          .where('postId', isEqualTo: postId)
          .where('user', isEqualTo: userEmail)
          .where('action', isEqualTo: 'attended')
          .get();

      newReceivedStatus[postId] = receivedQuery.docs.isNotEmpty;
      newAttendStatus[postId] = attendedQuery.docs.isNotEmpty;
    }

    if (mounted && !_isDisposed) {
      setState(() {
        receivedStatus = newReceivedStatus;
        attendStatus = newAttendStatus;
      });
    }
  }

  void addComment(String postId) async {
    String commentText = _commentControllers[postId]?.text.trim() ?? '';

    if (commentText.isEmpty) return;

    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(user.uid).get();
    String fullName = userDoc.exists
        ? "${userDoc['firstName']} ${userDoc['lastName']}"
        : "Unknown User";

    await _firestore
        .collection('announcements')
        .doc(postId)
        .collection('comments')
        .add({
      'userFullName': fullName,
      'comment': commentText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted && !_isDisposed) {
      setState(() {
        _commentControllers[postId]?.clear();
      });
    }
  }


  Widget _buildActionButton(String postType, String postId) {
    Color buttonColor = const Color.fromARGB(255, 5, 92, 157);

    if (postType == 'Seminar') {
      return ElevatedButton(
        onPressed: (attendStatus[postId] ?? false)
            ? null
            : () async {
          HapticService.instance.buttonPress();
          await _firestore.collection('notifications').add({
            'postId': postId,
            'user': _auth.currentUser?.email,
            'timestamp': FieldValue.serverTimestamp(),
            'action': 'attended',
          });

          setState(() {
            attendStatus[postId] = true;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: (attendStatus[postId] ?? false) ? Colors.grey : buttonColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        child: Text(
          (attendStatus[postId] ?? false) ? "Attending ✔" : "Attend",
          style: const TextStyle(color: Colors.white),
        ),
      );
    } else if (postType == 'Job Offering') {
      return ElevatedButton(
        onPressed: (attendStatus[postId] ?? false)
            ? null
            : () async {
          await applyForJob(postId);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: (attendStatus[postId] ?? false) ? Colors.grey : buttonColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        child: Text(
          (attendStatus[postId] ?? false) ? "Applied ✔" : "Apply",
          style: const TextStyle(color: Colors.white),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: (receivedStatus[postId] ?? false)
            ? null
            : () async {
          await _firestore.collection('notifications').add({
            'postId': postId,
            'user': _auth.currentUser?.email,
            'timestamp': FieldValue.serverTimestamp(),
            'action': 'received',
          });

          setState(() {
            receivedStatus[postId] = true;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: (receivedStatus[postId] ?? false) ? Colors.grey : buttonColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        child: Text(
          (receivedStatus[postId] ?? false) ? "Received ✔" : "Received",
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
  }

  Future<void> applyForJob(String postId) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
    String? resumeUrl = userDoc.exists ? userDoc['resumeUrl'] : null;

    await _firestore.collection('jobApplications').add({
      'postId': postId,
      'user': user.email,
      'resumeUrl': resumeUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('announcements').doc(postId).update({
      'appliedBy': FieldValue.arrayUnion([user.email]),
    });

    setState(() {
      attendStatus[postId] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Applied successfully with your resume.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;
    return DefaultTabController(
      length: 3,
        child: Scaffold(
          body: userCategory == null
              ? const Center(child: CircularProgressIndicator())
              : Container(
            color: const Color.fromARGB(255, 250, 250, 250), // Set background color
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.black, // Selected tab text color
                  unselectedLabelColor: Colors.grey, // Unselected tab text color
                  indicatorColor: Colors.black, // Selected tab underline color
                  onTap: (index) {
                    HapticService.instance.buttonPress();
                    final tabNames = ["General announcements", "Seminar announcements", "Job offer announcements"];
                    if (index < tabNames.length) {
                      TalkBackService.instance.speak("${tabNames[index]} tab selected");
                    }
                  },
                  tabs: [
                    Tab(
                      child: Text(
                      "General",
                      style: TextStyle(fontSize: fontSize - 6),
                     ),
                    ),
                    Tab(
                      child: Text(
                      "Seminar",
                      style: TextStyle(fontSize: fontSize - 6),
                      ),
                    ),
                    Tab(child: Text(
                      "Job Offers",
                      style: TextStyle(fontSize: fontSize - 6),
                     ),
                    ),
                  ],
                ),
                Expanded(
                  child: StreamBuilder(
                    stream: _firestore.collection('announcements').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var posts = snapshot.data!.docs;
                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFilteredList(posts, "General"),
                          _buildFilteredList(posts, "Seminar"),
                          _buildFilteredList(posts, "Job Offering"),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        )
    );
  }

  Widget _buildFilteredList(List<QueryDocumentSnapshot> posts, String? type) {
    var filteredPosts = type == null
        ? posts
        : posts.where((post) => post['type'] == type).toList();

    return ListView.builder(
      itemCount: filteredPosts.length,
      itemBuilder: (context, index) {
        var post = filteredPosts[index];
        return _buildPostCard(post);
      },
    );
  }

  Widget _buildPostCard(QueryDocumentSnapshot post) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;
    String postId = post.id;
    String type = post['type'];
    List filters = post['filters'] ?? [];

    if (filters.isNotEmpty && !filters.contains("All") && !filters.contains(userCategory)) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(10),
      color: const Color.fromARGB(255, 250, 250, 250),  // Set background color
      child: InkWell(
        onTap: () { HapticService.instance.buttonPress(); Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailsPage(post: post),
            ),
          ); },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post['title'], style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
              Text(post['content'], style: TextStyle(fontSize: fontSize)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionButton(type, postId),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentSection(String postId) {
  return Column(
    children: [
      StreamBuilder(
        stream: _firestore
            .collection('announcements')
            .doc(postId)
            .collection('comments')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, commentSnapshot) {
          if (!commentSnapshot.hasData) return const SizedBox.shrink();
          var comments = commentSnapshot.data!.docs;

          return Column(
            children: comments.map((comment) {
              String formattedDate = comment['timestamp'] != null
                  ? DateFormat("MMMM d, y, h:mma").format(comment['timestamp'].toDate())
                  : "Unknown Time";

              List<dynamic> replies = comment.data().containsKey('replies')
                  ? comment['replies']
                  : [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(comment['user'] ?? "Unknown User",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(comment['comment'] ?? "No Comment"),
                    trailing: Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),

                  if (replies.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(left: 40.0),
    child: Column(
      children: replies.map((reply) {
        String replyText = reply.containsKey('comment') ? reply['comment'] : "No Reply";
        String replyUser = reply.containsKey('user') ? reply['user'] : "Admin";
        String replyDate = reply.containsKey('timestamp') ? reply['timestamp'] : "Unknown Time";

        return ListTile(
          title: Text(
            replyUser,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          subtitle: Text(replyText),
          trailing: Text(replyDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            }).toList(),
          );
        },
      ),
    ],
   );
  }
}