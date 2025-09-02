import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'admin_ticket_page.dart';
import 'admin_user_lists_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final Function(int) updateIndex;
  final ScrollController scrollController;
  const AdminDashboardPage({super.key,required this.updateIndex,required this.scrollController});

  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _recentTickets = [];
  List<GlobalKey> _postKeys = [];
  Map<String, int> _disabilityCounts = {
    'Hearing Impairment': 0,
    'Visual Impairment': 0,
    'Speech Impairment': 0,
    'Mobility Impairment': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
    _loadUserCounts();
    _loadRecentTickets();
    _postKeys = List.generate(_announcements.length, (index) => GlobalKey());
  }

  void _navigateToTicket(BuildContext context, String ticketNumber) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    List<String> collections = ["medication_requests", "wheelchair_requests", "service_requests"];

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

  void _loadAnnouncements() {
    FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _announcements = snapshot.docs.map((doc) {
          var data = doc.data();
          var rawDate = data['timestamp'];

          DateTime parsedDate = (rawDate is Timestamp)
              ? rawDate.toDate()
              : DateTime.parse(rawDate);

          String formattedDate = DateFormat('MMMM dd, yyyy hh:mm a').format(parsedDate);

          return {
            'id': doc.id,
            'title': data['title'] ?? 'No Title',
            'type': data ['type'] ?? 'No Type',
            'content': data['content'] ?? 'No Details',
            'timestamp': formattedDate,
          };
        }).toList();
        _postKeys = List.generate(_announcements.length, (index) => GlobalKey());
      });
    });
  }

  void _loadUserCounts() {
    FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
      Map<String, int> tempCounts = {
        'Hearing Impairment': 0,
        'Visual Impairment': 0,
        'Speech Impairment': 0,
        'Mobility Impairment': 0,
      };

      for (var doc in snapshot.docs) {
        String? disabilityType = doc.data()['disabilityType'];
        if (disabilityType != null && tempCounts.containsKey(disabilityType)) {
          tempCounts[disabilityType] = (tempCounts[disabilityType] ?? 0) + 1;
        }
      }

      setState(() {
        _disabilityCounts = tempCounts;
      });
    });
  }

  void _loadRecentTickets() async {
    List<String> collections = ['medication_requests', 'wheelchair_requests', 'service_requests'];
    List<Map<String, dynamic>> allTickets = [];

    for (String collection in collections) {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String formattedTime = 'No Date Available';
        if (data['timestamp'] is Timestamp) {
          formattedTime = DateFormat('MMMM dd, yyyy hh:mm a').format(data['timestamp'].toDate());
        }

        allTickets.add({
          'ticket#': data['ticketNumber'] ?? 'No Message',
          'user': data['name'] ?? 'Unknown User',
          'timestamp': formattedTime,
          'type': collection.replaceAll('_', ' '),
        });
      }
    }

    allTickets.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    setState(() {
      _recentTickets = allTickets.take(5).toList();
    });
  }

 @override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 900;
  final cardWidth = isMobile ? screenWidth * 0.9 : screenWidth / 2 - 32;

  return Scaffold(
    backgroundColor: const Color.fromRGBO(255, 255, 255, 1.0),
    appBar: AppBar(
      title: const Text(
        'Admin Dashboard',
        style: TextStyle(color: Colors.black),
      ),
      backgroundColor: const Color.fromRGBO(255, 255, 255, 1.0),
      elevation: 0,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Center(
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            SizedBox(
              width: cardWidth,
              height: 400,
              child: _buildImageCard(),
            ),
            SizedBox(
              width: cardWidth,
              height: 400,
              child: _buildUserCountCard(),
            ),
            SizedBox(
              width: cardWidth,
              height: 400,
              child: _buildRecentTicketCard(context),
            ),
            SizedBox(
              width: cardWidth,
              height: 400,
              child: _buildAnnouncementsCard(context),
            ),
          ],
        ),
      ),
    ),
  );
}


  Widget _buildUserCountCard() {
    int totalUserCount = _disabilityCounts.values.fold(0, (sum, value) => sum + value);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: SizedBox(
        height: 200,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "User Count",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _disabilityCounts.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserListScreen(category: entry.key),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 1.0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: Color.fromARGB(255, 250, 250, 250),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.accessibility_new,
                                    color: Colors.blue,
                                    size: 25,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${entry.key}: ${entry.value}',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Total Users: $totalUserCount",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTicketCard(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;
  final titleFontSize = isMobile ? 16.0 : 20.0;
  final textFontSize = isMobile ? 11.0 : 12.0;
  final cardMaxHeight = MediaQuery.of(context).size.height * 0.4; // Limit height to avoid overflow

  return Container(
    constraints: BoxConstraints(
      maxHeight: cardMaxHeight, // Limit vertical size and enable scroll if needed
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.black, width: 2),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recent Tickets",
            style: TextStyle(
              color: Colors.black,
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _recentTickets.length > 5 ? 5 : _recentTickets.length,
              itemBuilder: (context, index) {
                final ticket = _recentTickets[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: GestureDetector(
                    onTap: () => _navigateToTicket(context, ticket['ticket#']),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 250, 250, 250),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ticket No. #${ticket['ticket#'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: textFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'User: ${ticket['user'] ?? 'Unknown'} | Category: ${ticket['type'] ?? 'Unknown'}',
                            style: TextStyle(
                              fontSize: textFontSize,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}



  Stream<List<QueryDocumentSnapshot>> _fetchRecentTickets() {
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

    return Rx.combineLatest3(
      medicationStream,
      wheelchairStream,
      serviceStream,
          (QuerySnapshot medication, QuerySnapshot wheelchair, QuerySnapshot service) {
        List<QueryDocumentSnapshot> allTickets = [
          ...medication.docs,
          ...wheelchair.docs,
          ...service.docs,
        ];

        allTickets.sort((a, b) {
          Timestamp timeA = a["timestamp"] ?? Timestamp(0, 0);
          Timestamp timeB = b["timestamp"] ?? Timestamp(0, 0);
          return timeB.compareTo(timeA);
        });

        return allTickets.take(5).toList();
      },
    );
  }

 Widget _buildAnnouncementsCard(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;
  final titleFontSize = isMobile ? 16.0 : 20.0;
  final textFontSize = isMobile ? 11.0 : 12.0;
  final maxCardHeight = screenHeight * 0.4;

  return Container(
    constraints: BoxConstraints(
      maxHeight: maxCardHeight,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.black, width: 2),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recent Announcements",
            style: TextStyle(
              color: Colors.black,
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _announcements.length > 5 ? 5 : _announcements.length,
              itemBuilder: (context, index) {
                final announcement = _announcements[index];
                return GestureDetector(
                  onTap: () {
                    widget.updateIndex(2); // Go to HomePage

                    final postKey = _postKeys[index];
                    final postContext = postKey.currentContext;

                    if (postContext != null) {
                      final position = postContext
                          .findRenderObject()!
                          .getTransformTo(null)
                          .getTranslation()
                          .y;

                      widget.scrollController.animateTo(
                        position,
                        duration: Duration(seconds: 1),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: Container(
                      key: _postKeys[index],
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 250, 250, 250),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            announcement['title'],
                            style: TextStyle(
                              fontSize: textFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${announcement['type']} • ${announcement['timestamp']}',
                            style: TextStyle(
                              fontSize: textFontSize,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildImageCard() {
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.black, width: 2),
    ),
    child: Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          'https://firebasestorage.googleapis.com/v0/b/authenticationtest-d4ad2.firebasestorage.app/o/dashboard%2FdashboardImage.jpg?alt=media&token=15d22627-3455-4748-84ae-39a3d49c736a',
          width: 800,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const CircularProgressIndicator();
          },
          errorBuilder: (context, error, stackTrace) {
            return const Text('Failed to load image');
          },
        ),
      ),
    ),
  );
}
}