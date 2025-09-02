
import 'package:firebase/widget/FullCommentDialog.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_notifications_page.dart';
import 'admin_dashboard_page.dart';
import 'admin_ticket_page.dart';
import 'AdminCreatePostDialog.dart';
import 'login_page.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:excel/excel.dart' as ex;


class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'General', 'Seminar', 'Job Offering'];
  bool _isSidebarExpanded = false;
  Map<String, dynamic>? userDetails;
  String? adminEmail;
  bool isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = 0;
  List<GlobalKey> _postKeys = [];


  @override
  void initState() {
    super.initState();
    fetchUserDetails();
  }

  void _updateIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> fetchUserDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
      await _firestore.collection("admins").doc(user.email).get();
      if (userDoc.exists) {
        setState(() {
          userDetails = userDoc.data() as Map<String, dynamic>?;
          adminEmail = user.email;
          isLoading = false;
        });
      } else {
        setState(() {
          adminEmail = null;
          isLoading = false;
        });
      }
    } else {
      setState(() => isLoading = false);
    }
  }
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return "${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  void signOut(BuildContext context) async {
    bool? confirmLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                // Navigate directly to LoginPage after sign-out
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage(onTap: null)),
                );
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage(onTap: null)),
        );
      }
    }
  }
final Map<String, bool> _replyVisibilityMap = {};

Widget _buildCommentSection(String postId, String commentId, Map<String, dynamic> commentData) {
  TextEditingController replyController = TextEditingController();

  // Initialize if not already
  _replyVisibilityMap.putIfAbsent(commentId, () => false);

  return StatefulBuilder(
    builder: (context, setState) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${commentData['user'] ?? 'Anonymous'}: ${commentData['comment']}",
              style: const TextStyle(fontSize: 14),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _replyVisibilityMap[commentId] = !_replyVisibilityMap[commentId]!;
                });
              },
              child: const Text("Reply", style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 4),
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
                      padding: const EdgeInsets.only(left: 16.0, top: 4),
                      child: Text(
                        "↳ ${reply['author'] ?? 'Anonymous'}: ${reply['text']}",
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            if (_replyVisibilityMap[commentId] == true)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: replyController,
                      decoration: const InputDecoration(hintText: "Write a reply..."),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
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
                          'author': 'Admin',
                        });
                        replyController.clear();
                        setState(() {
                          _replyVisibilityMap[commentId] = false;
                        });
                      }
                    },
                  )
                ],
              ),
          ],
        ),
      );
    },
  );
}


  void _showAcknowledgedDialog(String postId) async {
    var snapshot = await FirebaseFirestore.instance
        .collection("notifications")
        .where("postId", isEqualTo: postId)
        .where("action", isEqualTo: "received")
        .get();

    List<List<String>> acknowledgedData = [
      ['User', 'Action']
    ];

    for (var doc in snapshot.docs) {
      var data = doc.data();
      acknowledgedData.add([
        data['user'] ?? 'Unknown',
        data['action'] ?? 'N/A',
      ]);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Acknowledged Users'),
          backgroundColor: const Color(0xFFFAFAFA), // Set background color to ARGB(255, 250, 250, 250)
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              children: snapshot.docs.map((doc) {
                var data = doc.data();
                return ListTile(
                  title: Text(data['user'] ?? 'Unknown'),
                  subtitle: Text(data['action'] ?? 'No action'),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                var excel = ex.Excel.createExcel();
                var sheet = excel['Acknowledged Users'];

                for (var row in acknowledgedData) {
                  sheet.appendRow(row.cast<ex.CellValue?>());
                }

                final bytes = excel.encode();
                if (bytes == null) return;

                final blob = html.Blob([Uint8List.fromList(bytes)]);
                final url = html.Url.createObjectUrlFromBlob(blob);
                final anchor = html.AnchorElement(href: url)
                  ..setAttribute("download", "Acknowledged_Users.xlsx")
                  ..click();
                html.Url.revokeObjectUrl(url);
              },
              child: const Text('Download Excel'),
            ),
          ],
        );
      },
    );
  }

  void _showAttendeesDialog(String postId) async {
    var snapshot = await FirebaseFirestore.instance
        .collection("notifications")
        .where("postId", isEqualTo: postId)
        .where("action", isEqualTo: "attended")
        .get();

    // Prepare data for Excel
    List<List<String>> attendeesData = [
      ['User', 'Action']
    ];

    for (var doc in snapshot.docs) {
      var data = doc.data();
      attendeesData.add([
        data['user'] ?? 'Unknown',
        data['action'] ?? 'N/A',
      ]);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Attendees'),
          backgroundColor: const Color(0xFFFAFAFA), // Set background color to ARGB(255, 250, 250, 250)
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              children: snapshot.docs.map((doc) {
                var data = doc.data();
                return ListTile(
                  title: Text(data['user'] ?? 'Unknown'),
                  subtitle: Text(data['action'] ?? 'No email'),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                // Create Excel
                var excel = ex.Excel.createExcel();
                var sheet = excel['Attendees'];

                for (var row in attendeesData) {
                  sheet.appendRow(row.cast<ex.CellValue?>());
                }

                final bytes = excel.encode();
                if (bytes == null) return;

                final blob = html.Blob([Uint8List.fromList(bytes)]);
                final url = html.Url.createObjectUrlFromBlob(blob);
                final anchor = html.AnchorElement(href: url)
                  ..setAttribute("download", "Seminar Attendees.xlsx")
                  ..click();
                html.Url.revokeObjectUrl(url);
              },
              child: const Text('Download Excel'),
            ),
          ],
        );
      },
    );
  }

  void _showApplicantsDialog(String postId) async {
    var snapshot = await FirebaseFirestore.instance
        .collection('jobApplications')
        .where('postId', isEqualTo: postId)
        .get();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Job Applicants'),
          backgroundColor: const Color(0xFFFAFAFA), // Set background color to ARGB(255, 250, 250, 250)
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              children: snapshot.docs.map((doc) {
                var data = doc.data();
                String resumeUrl = data['resumeUrl'] ?? 'No resume URL';
                String userEmail = data['user'] ?? 'Unknown';

                return ListTile(
                  title: Text(userEmail),
                  subtitle: Text(resumeUrl),
                  trailing: IconButton(
                    icon: const Icon(Icons.picture_as_pdf),
                    onPressed: () {
                      _openResumeInNewTab(resumeUrl);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }

  void _openResumeInNewTab(String resumeUrl) async {
    if (await canLaunch(resumeUrl)) {
      await launch(resumeUrl);
    } else {
      print('Could not open resume URL: $resumeUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 30, 136, 229),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "ACCAP",
          style: TextStyle(
            letterSpacing: 2.0,
            fontSize: 50,
            fontWeight: FontWeight.w900,
            color: Color.fromARGB(255, 255, 255, 255),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.menu,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isSidebarExpanded = !_isSidebarExpanded;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            tooltip: "Notifications",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminNotificationsPage()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isSidebarExpanded ? 250 : 60,
            color: const Color.fromRGBO(255, 255, 255, 1.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildNavItem(Icons.dashboard, "  Dashboard", 0),
                _buildNavItem(Icons.confirmation_num, "  Tickets", 1),
                _buildNavItem(Icons.post_add, "  Make a Post", 2),
                const Spacer(),
                _buildNavItem(Icons.logout, "  Logout", -1),
              ],
            ),
          ),
          Container(width: 2, color: Colors.grey[300]),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                AdminDashboardPage(
                  updateIndex: _updateIndex,
                  scrollController: _scrollController,
                ),
                AdminTicketPage(),
                _buildHomePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: _isSidebarExpanded
          ? Text(label,
          style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)))
          : null,
      selected: _currentIndex == index,
      onTap: () {
        if (index == -1) {
          signOut(context);
        } else {
          setState(() {
            _currentIndex = index;
          });
        }
      },
      horizontalTitleGap: 0,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

 Widget _buildHomePage() {
  final screenWidth = MediaQuery.of(context).size.width;
  
  return Container(
    color: Color.fromARGB(255, 250, 250, 250),  // Background color
    child: Column(
      children: [
        // 🔹 Filter Chips
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 10),
          child: Wrap(
            spacing: 10,
            children: ['All', 'General', 'Seminar', 'Job Offering'].map((filter) {
              final isSelected = _selectedFilter == filter;
              return ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                selectedColor: const Color(0xFF0F3060),
                backgroundColor: Colors.grey[200],
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
              );
            }).toList(),
          ),
        ),

        // 🔹 Create Post Box
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 12),
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: SizedBox(
                    width: screenWidth * 0.8, // Set width based on screen size
                    child: AdminPostDialogContent(),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(25),
                color: Colors.white,
              ),
              child: Row(
                children: const [
                  Icon(Icons.edit, color: Colors.grey),
                  SizedBox(width: 10),
                  Text(
                    "Create post",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder(
            stream: _firestore
                .collection('announcements')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              var posts = snapshot.data?.docs ?? [];

              // 🔹 Apply local filter instead of Firestore query
              if (_selectedFilter != 'All') {
                posts = posts.where((post) {
                  final data = post.data();
                  return data['type'] == _selectedFilter;
                }).toList();
              }

              if (posts.isEmpty) {
                return const Center(child: Text("No announcements posted yet."));
              }

              _postKeys = List.generate(posts.length, (index) => GlobalKey());

              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  var post = posts[index];
                  var data = post.data();
                  return Card(
                    key: _postKeys[index], // Assign the GlobalKey to the post
                    elevation: 2,
                    margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: const Color(0xFFFAFAFA), // Set background color to ARGB(255, 250, 250, 250)
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Post header
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFF0F3060),
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("ACCAP Admin", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(_formatTimestamp(data['timestamp']),
                                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        child: SizedBox(
                                          width: screenWidth * 0.8, // Set width based on screen size
                                          child: AdminPostDialogContent(
                                            postId: post.id,
                                            initialData: data,
                                          ),
                                        ),
                                      ),
                                    );
                                  } else if (value == 'delete') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("Delete Post"),
                                        content: const Text("Are you sure you want to delete this post?"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await FirebaseFirestore.instance.collection('announcements').doc(post.id).delete();
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text("Edit")),
                                  const PopupMenuItem(value: 'delete', child: Text("Delete")),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Title
                          if ((data['title'] ?? '').isNotEmpty)
                            Text(
                              data['title'],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F3060)),
                            ),
                          const SizedBox(height: 8),

                          // Description
                          if ((data['content'] ?? '').isNotEmpty)
                            Text(data['content'], style: const TextStyle(fontSize: 15)),
                          const SizedBox(height: 12),

                          // Images
                          if (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
                            Center(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center, // ensures even multiple images are centered
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
                                    }).toList().cast<Widget>();
                                  } else {
                                    return <Widget>[];
                                  }
                                })(),
                              ),
                            ),

                          const SizedBox(height: 12),
                SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.start, // Align to the left side
    children: [
      // View Comments Button (Left)
      TextButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: SizedBox(
                width: screenWidth * 0.8, // Set width based on screen size
                child: FullCommentDialog(postId: post.id),
              ),
            ),
          );
        },
        icon: const Icon(Icons.comment),
        label: const Text("View Comments"),
      ),
      
      // Right-aligned buttons
      Row(
        mainAxisSize: MainAxisSize.min,  // Ensure that the Row does not occupy extra space
        children: [
          if (data['type'] == 'Job Offering')
            TextButton.icon(
              onPressed: () => _showApplicantsDialog(post.id),
              icon: const Icon(Icons.work),
              label: const Text("View Applicants"),
            ),
          if (data['type'] == 'Seminar')
            TextButton.icon(
              onPressed: () => _showAttendeesDialog(post.id),
              icon: const Icon(Icons.people),
              label: const Text("View Attendees"),
            ),
          if (data['type'] == 'General')
            TextButton.icon(
              onPressed: () => _showAcknowledgedDialog(post.id),
              icon: const Icon(Icons.check_circle),
              label: const Text("View Acknowledged"),
            ),
        ],
      ),
    ],
  ),
),
          
                            /// Optional preview comments
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('announcements')
                                  .doc(post.id)
                                  .collection('comments')
                                  .orderBy('timestamp', descending: true)
                                  .snapshots(),
                              builder: (context, commentSnapshot) {
                                if (!commentSnapshot.hasData) return const SizedBox();

                                final comments = commentSnapshot.data!.docs;
                                final displayComments = (data['imageUrl'] == null || data['imageUrl'].isEmpty)
                                    ? comments.take(3).toList()
                                    : comments;

                                return Column(
                                  children: displayComments.map((commentDoc) {
                                    var commentData = commentDoc.data() as Map<String, dynamic>;
                                    return _buildCommentSection(post.id, commentDoc.id, commentData);
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
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
}