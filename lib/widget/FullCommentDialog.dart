import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FullCommentDialog extends StatefulWidget {
  final String postId;

  const FullCommentDialog({super.key, required this.postId});

  @override
  State<FullCommentDialog> createState() => _FullCommentDialogState();
}

class _FullCommentDialogState extends State<FullCommentDialog> {
  final TextEditingController _commentController = TextEditingController();

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'comment': _commentController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'user': 'Admin', // Change this to the actual user name if needed
    });

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('announcements').doc(widget.postId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var data = snapshot.data!.data() as Map<String, dynamic>;

        return Container(
          color: const Color.fromARGB(255, 250, 250, 250), // Background color
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((data['title'] ?? '').isNotEmpty)
                    Text(
                      data['title'],
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 8),

                  if ((data['content'] ?? '').isNotEmpty)
                    Text(data['content'], style: const TextStyle(fontSize: 16)),

                  const SizedBox(height: 12),

                  if (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
                    Center(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: (() {
                          final imageData = data['imageUrl'];
                          if (imageData is String) {
                            return [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageData,
                                  height: 150,
                                  width: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ];
                          } else if (imageData is List) {
                            return imageData.map<Widget>((url) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  height: 150,
                                  width: 150,
                                  fit: BoxFit.cover,
                                ),
                              );
                            }).toList();
                          } else {
                            return <Widget>[];
                          }
                        })(),
                      ),
                    ),

                  const Divider(height: 32),
                  const Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('announcements')
                        .doc(widget.postId)
                        .collection('comments')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, commentSnapshot) {
                      if (!commentSnapshot.hasData) return const CircularProgressIndicator();

                      return Column(
                        children: commentSnapshot.data!.docs.map((doc) {
                          var comment = doc.data() as Map<String, dynamic>;
                          var commentId = doc.id;
                          return _buildCommentSection(widget.postId, commentId, comment);
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: "Write a comment...",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _postComment,
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  final Map<String, bool> _replyVisibilityMap = {};

Widget _buildCommentSection(String postId, String commentId, Map<String, dynamic> commentData) {
  TextEditingController replyController = TextEditingController();

  // Initialize visibility state if not already present
  _replyVisibilityMap.putIfAbsent(commentId, () => false);

  return StatefulBuilder(
    builder: (context, setState) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person),
              title: Text("${commentData['user'] ?? 'Anonymous'}"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(commentData['comment'] ?? ''),
                  Text(
                    _formatTimestamp(commentData['timestamp']),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Delete Comment"),
                      content: const Text("Are you sure you want to delete this comment?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Delete", style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await FirebaseFirestore.instance
                        .collection('announcements')
                        .doc(postId)
                        .collection('comments')
                        .doc(commentId)
                        .delete();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Comment deleted")),
                    );
                  }
                },
              ),
            ),

            // Reply button
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _replyVisibilityMap[commentId] = !_replyVisibilityMap[commentId]!;
                  });
                },
                child: const Text("Reply", style: TextStyle(fontSize: 13)),
              ),
            ),

            // Replies
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .doc(postId)
                  .collection('comments')
                  .doc(commentId)
                  .collection('replies')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return Column(
                  children: snapshot.data!.docs.map((replyDoc) {
                    var reply = replyDoc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(left: 32.0, top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.reply, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "${reply['author'] ?? 'Anonymous'}: ${reply['text']}",
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            // Conditional Reply Field
            if (_replyVisibilityMap[commentId] == true)
              Padding(
                padding: const EdgeInsets.only(left: 32.0, top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        decoration: const InputDecoration(
                          hintText: "Write a reply...",
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, size: 20),
                      onPressed: () {
                        if (replyController.text.trim().isNotEmpty) {
                          FirebaseFirestore.instance
                              .collection('announcements')
                              .doc(postId)
                              .collection('comments')
                              .doc(commentId)
                              .collection('replies')
                              .add({
                            'text': replyController.text.trim(),
                            'timestamp': Timestamp.now(),
                            'author': 'Admin', // Change this to current user if needed
                          });
                          replyController.clear();
                          setState(() {
                            _replyVisibilityMap[commentId] = false;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}


  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return "${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}
