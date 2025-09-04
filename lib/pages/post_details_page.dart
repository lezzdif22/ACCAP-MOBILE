import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../services/talkback_service.dart';
import '../components/talkback_longpress.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';

import '../components/text_size.dart';
class PostDetailsPage extends StatefulWidget {
  final DocumentSnapshot post;

  const PostDetailsPage({super.key, required this.post});

  @override
  _PostDetailsPageState createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _charCount = 0;
  final int _maxChars = 250;
  String? userCategory;
  Map<String, bool> receivedStatus = {};
  Map<String, bool> attendStatus = {};
  int _currentImagePage = 0;
  final PageController _imagePageController = PageController();
  Future<List<String>>? _imageUrlsFuture;

  @override
  void initState() {
    super.initState();
    fetchUserCategory();
    loadStatuses();
    _commentController.addListener(_updateCharCount);
    // Prepare imageUrls future after widget.post is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final postData = widget.post.data() as Map<String, dynamic>?;
      List<String> imageUrls = [];
      if (postData != null) {
        if (postData.containsKey('imageUrls') && postData['imageUrls'] is List) {
          imageUrls = List<String>.from(postData['imageUrls'].whereType<String>());
        } else if (postData.containsKey('imageUrl')) {
          if (postData['imageUrl'] is String) {
            imageUrls = [postData['imageUrl']];
          } else if (postData['imageUrl'] is List) {
            imageUrls = List<String>.from(postData['imageUrl'].whereType<String>());
          }
        }
      }
      setState(() {
        _imageUrlsFuture = _getImageUrls(imageUrls);
      });
    });
  }

  @override
  void dispose() {
    _commentController.removeListener(_updateCharCount);
    _commentController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  void _updateCharCount() {
    setState(() {
      _charCount = _commentController.text.length;
    });
  }

  Future<void> fetchUserCategory() async {
    String? userId = _auth.currentUser?.uid;
    DocumentSnapshot userDoc =
    await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
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

    setState(() {
      receivedStatus = newReceivedStatus;
      attendStatus = newAttendStatus;
    });
  }

  Future<void> uploadResume(String postId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null) {
      String fileName = result.files.single.name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Uploaded: $fileName")),
      );

      await _firestore.collection('jobApplications').add({
        'postId': postId,
        'user': _auth.currentUser?.email,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File upload canceled.")),
      );
    }
  }


  @override
  Widget _buildActionButton(String postType, String postId) {
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
          backgroundColor: (attendStatus[postId] ?? false) ? Colors.grey : Colors.blue,
        ),
        child: Text((attendStatus[postId] ?? false) ? "Attending ✔" : "Attend"),
      );
    } else if (postType == 'Job Offering') {
      return ElevatedButton(
        onPressed: () async {
          HapticService.instance.buttonPress();
          await uploadResume(postId);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
        ),
        child: const Text("Apply"),
      );
    } else {
      return ElevatedButton(
        onPressed: (receivedStatus[postId] ?? false)
            ? null
            : () async {
          HapticService.instance.buttonPress();
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
          backgroundColor: (receivedStatus[postId] ?? false) ? Colors.grey : Colors.blue,
        ),
        child: Text((receivedStatus[postId] ?? false) ? "Received ✔" : "Received"),
      );
    }
  }

Future<List<String>> _getImageUrls(List<String> imageUrls) async {
  List<String> urls = [];
  for (var imageUrl in imageUrls) {
    try {
      if (imageUrl.startsWith("gs://")) {
        final ref = FirebaseStorage.instance.refFromURL(imageUrl);
        urls.add(await ref.getDownloadURL());
      } else {
        urls.add(imageUrl);
      }
    } catch (e) {
      print("Error fetching image URL: $e");
    }
  }
  return urls;
}

@override
Widget build(BuildContext context) {
  final textSizeProvider = Provider.of<TextSizeProvider>(context);
  final fontSize = textSizeProvider.fontSize;
  String postId = widget.post.id;
  String postType = widget.post['type'];

  Map<String, dynamic>? postData = widget.post.data() as Map<String, dynamic>?;
  List<String> imageUrls = [];
  if (postData != null) {
    if (postData.containsKey('imageUrls') && postData['imageUrls'] is List) {
      imageUrls = List<String>.from(postData['imageUrls'].whereType<String>());
    } else if (postData.containsKey('imageUrl')) {
      if (postData['imageUrl'] is String) {
        imageUrls = [postData['imageUrl']];
      } else if (postData['imageUrl'] is List) {
        imageUrls = List<String>.from(postData['imageUrl'].whereType<String>());
      }
    }
  }

  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 250, 250, 250),
    appBar: AppBar(
      backgroundColor: const Color.fromARGB(255, 0, 48, 96),
      leading: Semantics(
        label: "Back button",
        hint: "Go back to posts list",
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color.fromARGB(255, 250, 250, 250),
          ),
          onPressed: () async {
            HapticService.instance.buttonPress();
            await TalkBackService.instance.speak("Going back to posts list");
            Navigator.of(context).pop();
          },
        ),
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Display Images if available
                if (_imageUrlsFuture != null)
                  FutureBuilder<List<String>>(
                    future: _imageUrlsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[200],
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 300,
                                child: PageView.builder(
                                  controller: _imagePageController,
                                  itemCount: snapshot.data!.length,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentImagePage = index;
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Image.network(
                                        snapshot.data![index],
                                        fit: BoxFit.contain,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(child: CircularProgressIndicator());
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Center(
                                              child: Icon(Icons.broken_image, size: 50, color: Colors.grey));
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (snapshot.data!.length > 1)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      snapshot.data!.length,
                                      (index) => Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: index == _currentImagePage ? Colors.blue : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TalkBackLongPress(
                        text: "Post title: ${widget.post['title']}",
                        child: Text(
                          widget.post['title'],
                          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TalkBackLongPress(
                        text: "Post content: ${widget.post['content']}",
                        child: Text(widget.post['content'], style: TextStyle(fontSize: fontSize)),
                      ),
                      const SizedBox(height: 20),
                      if (postType == 'Seminar' || postType == 'Job Offering')
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: _buildActionButton(postType, postId),
                        ),
                      const Divider(),
                      SizedBox(
                        height: 300,
                        child: _buildCommentSection(postId),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
              top: 4,
            ),
            child: _buildCommentInput(postId),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildCommentSection(String postId) {
    return Container(
      color: const Color.fromARGB(255, 250, 250, 250),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _firestore
                  .collection('announcements')
                  .doc(postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, commentSnapshot) {
                if (!commentSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var comments = commentSnapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    var comment = comments[index];
                    String formattedDate = comment['timestamp'] != null
                        ? DateFormat("MMM d, y • h:mma").format(comment['timestamp'].toDate())
                        : "Unknown Time";

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: const Color.fromARGB(255, 250, 250, 250),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      comment['user'] ?? "Anonymous",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TalkBackLongPress(
                                  text: "Comment by ${comment['user'] ?? "Anonymous"}: ${comment['comment'] ?? "No Comment"}",
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      comment['comment'] ?? "No Comment",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      await TalkBackService.instance.speak("Reply to comment");
                                      _showReplyDialog(postId, comment.id);
                                    },
                                    icon: const Icon(Icons.reply, size: 16, color: Colors.blue),
                                    label: const Text(
                                      "Reply",
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: const Size(10, 30),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        StreamBuilder(
                          stream: _firestore
                              .collection('announcements')
                              .doc(postId)
                              .collection('comments')
                              .doc(comment.id)
                              .collection('replies')
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                          builder: (context, replySnapshot) {
                            if (!replySnapshot.hasData) return const SizedBox.shrink();
                            var replies = replySnapshot.data!.docs;

                            return Padding(
                              padding: const EdgeInsets.only(left: 24.0, top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: replies.map((reply) {
                                  String author = reply['author'] ?? 'Anonymous';
                                  String content = reply['text'] ?? 'No Reply';
                                  String replyDate = reply['timestamp'] != null
                                      ? DateFormat("MMM d, y • h:mma").format(reply['timestamp'].toDate())
                                      : "Unknown Time";

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "$author (Reply)",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.blueAccent,
                                              ),
                                            ),
                                            Text(
                                              replyDate,
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          content,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  void _showReplyDialog(String postId, String commentId) {
    TextEditingController replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 250, 250, 250),
          title: const Text("Reply to Comment"),
          content: TextField(
            controller: replyController,
            decoration: const InputDecoration(hintText: "Write a reply..."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                HapticService.instance.buttonPress();
                addReply(postId, commentId, replyController.text);
                Navigator.pop(context);
              },
              child: const Text("Reply"),
            ),
          ],
        );
      },
    );
  }

  void addReply(String postId, String commentId, String replyText) async {
    if (replyText.trim().isEmpty) return;

    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Get user's first name from Firestore
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    String userName = "Anonymous";
    String firstName = "Anonymous";
    if (userDoc.exists) {
      firstName = userDoc['firstName'] ?? "Anonymous";
      String lastName = userDoc['lastName'] ?? "";
      userName = "$firstName $lastName".trim();
    }

    // Add the reply
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .add({
      'text': replyText.trim(),
      'timestamp': Timestamp.now(),
      'author': userName,
    });

    // Fetch post data to get the owner and title
    final postDoc = await FirebaseFirestore.instance
        .collection('announcements')
        .doc(postId)
        .get();
    final postData = postDoc.data();
    final postOwner = postData?['adminEmail'] ?? '';
    final postTitle = postData?['title'] ?? '';

    // Add notification if the replier is not the post owner
    if (postOwner != currentUser.email) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'reply',
        'to': postOwner,
        'from': currentUser.email,
        'postId': postId,
        'message': '$firstName replied on this post: \'$postTitle\'',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
  }


Widget _buildCommentInput(String postId) {
  bool isOverLimit = _charCount > _maxChars;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    margin: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Color.fromARGB(255, 255, 255, 255),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            const Icon(Icons.comment, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                label: "Comment text field",
                hint: "Write a comment here",
                child: TextField(
                  controller: _commentController,
                  maxLength: _maxChars,
                  decoration: const InputDecoration(
                    hintText: "Write a comment...",
                    counterText: "",
                    isDense: true,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: isOverLimit ? null : () async { 
                HapticService.instance.buttonPress(); 
                await TalkBackService.instance.speak("Sending comment");
                _addComment(postId); 
              },
              icon: Icon(
                Icons.send_rounded,
                color: isOverLimit ? Colors.grey : Colors.blue,
              ),
              tooltip: 'Send',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "$_charCount / $_maxChars",
          style: TextStyle(
            fontSize: 12,
            color: isOverLimit ? Colors.red : Colors.grey,
            fontWeight: isOverLimit ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}


 Future<void> _addComment(String postId) async {
  if (_commentController.text.trim().isEmpty || _charCount > _maxChars) return;

  User? user = _auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You must be logged in to comment.")),
    );
    return;
  }

  DocumentSnapshot userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  String userName = "Anonymous";

  if (userDoc.exists) {
    String firstName = userDoc['firstName'] ?? "";
    String lastName = userDoc['lastName'] ?? "";
    userName = "$firstName $lastName".trim();

    // 🔔 Send notification to admin
    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'comment',
      'postId': postId,
      'message': '$firstName commented on this post: \'${widget.post['title']}\'',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  } else {
    // 🔔 Send notification to admin (fallback)
    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'comment',
      'postId': postId,
      'message': 'Anonymous commented on this post',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  // Save the comment to the announcement post
  await FirebaseFirestore.instance
      .collection('announcements')
      .doc(postId)
      .collection('comments')
      .add({
    'user': userName,
    'comment': _commentController.text.trim(),
    'timestamp': FieldValue.serverTimestamp(),
  });

  _commentController.clear();
}
}
