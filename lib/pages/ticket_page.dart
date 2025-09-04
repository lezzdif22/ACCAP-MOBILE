import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../services/talkback_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../components/text_size.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  _TicketsPageState createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<QueryDocumentSnapshot>> getUserRequests() {
    User? user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    Stream<QuerySnapshot> medicationStream = _firestore
        .collection("medication_requests")
        .where("user", isEqualTo: user.email)
        .snapshots();

    Stream<QuerySnapshot> wheelchairStream = _firestore
        .collection("wheelchair_requests")
        .where("user", isEqualTo: user.email)
        .snapshots();

    Stream<QuerySnapshot> serviceStream = _firestore
        .collection("service_requests")
        .where("user", isEqualTo: user.email)
        .snapshots();

    return Rx.combineLatest3(
      medicationStream,
      wheelchairStream,
      serviceStream,
          (QuerySnapshot medication, QuerySnapshot wheelchair, QuerySnapshot service) {
        List<QueryDocumentSnapshot> allDocs = [
          ...medication.docs,
          ...wheelchair.docs,
          ...service.docs,
        ];


        allDocs.sort((a, b) {
          String status1 = a["status"] ?? "";
          String status2 = b["status"] ?? "";
          Timestamp? timestamp1 = a["timestamp"];
          Timestamp? timestamp2 = b["timestamp"];
          if (status1 == "Closed" && status2 != "Closed") return 1;
          if (status2 == "Closed" && status1 != "Closed") return -1;
          if (timestamp1 != null && timestamp2 != null) {
            return timestamp2.compareTo(timestamp1);
          }

          return 0;
        });

        return allDocs;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(title: Text("My Request", style: TextStyle(fontSize: fontSize),),
        backgroundColor: Color.fromARGB(255, 250, 250, 250),
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: getUserRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No Requests found."));
          }

          var requests = snapshot.data!;
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              var request = requests[index];
              Map<String, dynamic> data = request.data() as Map<String, dynamic>;
              String category = data["category"] ?? "Unknown";
              String status = data["status"] ?? "Pending";
              Color statusColor = status == "Open" ? Colors.green : Colors.red;

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: const Color.fromARGB(255, 250, 250, 250),
                child: ListTile(
                  title: Text("Request No. #${data["requestNumber"] ?? "N/A"}",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize-3)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Category: ${data["category"] ?? "Unknown"}",
                          style: TextStyle(color: Colors.grey[700], fontSize: fontSize-3)),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: fontSize-3),
                    ),
                  ),
                  onTap: () { HapticService.instance.buttonPress(); Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TicketDetailPage(request: request),
                    ),
                  ); },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TicketDetailPage extends StatefulWidget {
  final QueryDocumentSnapshot request;
  const TicketDetailPage({super.key, required this.request});

  @override
  _TicketDetailPageState createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late bool isOpen;

  @override
  void initState() {
    super.initState();
    isOpen = widget.request["status"] == "Open";
  }

  void addComment() async {
    if (_commentController.text.isNotEmpty && currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      String fullName = "Unknown User";
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String firstName = userData['firstName'] ?? "";
        String lastName = userData['lastName'] ?? "";
        fullName = "$firstName $lastName".trim();
      }

      await FirebaseFirestore.instance
          .collection(widget.request.reference.parent.id)
          .doc(widget.request.id)
          .collection("comments")
          .add({
        "text": _commentController.text,
        "timestamp": FieldValue.serverTimestamp(),
        "userFullName": fullName,
        "userEmail": currentUser!.email,
      });

  HapticService.instance.buttonPress();
  _commentController.clear();
    }
  }


  void updateRequestStatus(String newStatus) {
    FirebaseFirestore.instance
        .collection(widget.request.reference.parent.id)
        .doc(widget.request.id)
        .update({"status": newStatus});

    setState(() {
      isOpen = newStatus == "Open";
    });
  HapticService.instance.buttonPress();
  }

  @override
  Widget _buildDetailRow(String label, dynamic value) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 16, color: Colors.black),
          children: [
            TextSpan(text: "$label: ",
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: fontSize)),
            TextSpan(
                text: value ?? "N/A", style: TextStyle(fontSize: fontSize)),
          ],
        ),
      ),
    );
  }

  Future<String> getAdminUsername(String email) async {
    final doc = await FirebaseFirestore.instance.collection('admins').doc(email).get();
    if (doc.exists && doc.data() != null && doc.data()!.containsKey('username')) {
      return doc['username'];
    }
    return "Admin";
  }

  @override
  Widget build(BuildContext context) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;
    Map<String, dynamic> data = widget.request.data() as Map<String, dynamic>;
    String ticketOwnerEmail = data["user"] ?? "";

    if (currentUser?.email != ticketOwnerEmail) {
      return Scaffold(
        appBar: AppBar(title: Text("Unauthorized", style: TextStyle(fontSize: fontSize))),
        body: Center(child: Text("You do not have permission to view this Request.", style: TextStyle(fontSize: fontSize))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 48, 96),
        leading: Semantics(
          label: "Back button",
          hint: "Go back to previous page",
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color.fromARGB(255, 250, 250, 250),
            ),
            onPressed: () async {
              HapticService.instance.buttonPress();
              await TalkBackService.instance.speak("Going back from tickets");
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
      body: Container(
        color: const Color.fromARGB(255, 250, 250, 250),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Category: ${data["category"] ?? "N/A"}", style: TextStyle(fontSize: fontSize -2, fontWeight: FontWeight.bold)),
                    Text("Request No. #${data["requestNumber"] ?? "N/A"}", style: TextStyle(fontSize: fontSize -2)),
                    Text("Status: ${data["status"]}", style: TextStyle(fontSize: fontSize, color: isOpen ? Colors.green : Colors.red)),
                    const SizedBox(height: 10),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data.containsKey("medicine_image") && data["medicine_image"] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    data["medicine_image"],
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                                  ),
                                ),
                              ),
                            if (data["category"] == "Medication") ...[
                              _buildDetailRow("Medicine", data["medicineName"]),
                              _buildDetailRow("Service", data["pickupOrDelivery"]),
                              _buildDetailRow("Address", data["address"]),
                              _buildDetailRow("Date", data["date"]),
                              _buildDetailRow("Time", data["requestedTime"]),
                            ] else if (data["category"] == "Wheelchair") ...[
                              _buildDetailRow("Reason", data["reason"]),
                              _buildDetailRow("Location", data["location"]),
                              _buildDetailRow("Delivery Date", data["dateToDeliver"]),
                              _buildDetailRow("Delivery Time", data["deliveryTime"]),
                              _buildDetailRow("Pickup Date", data["dateToPickUp"]),
                              _buildDetailRow("Pickup Time", data["pickupTime"]),
                            ] else if (data["category"] == "Transportation Service") ...[
                              _buildDetailRow("Reason", data["reason"]),
                              _buildDetailRow("Pickup Location", data["pickup_location"]),
                              _buildDetailRow("Pickup Date", data["pickup_date"]),
                              _buildDetailRow("Pickup Time", data["pickup_time"]),
                              _buildDetailRow("Destination", data["destination"]),
                              _buildDetailRow("Needs Wheelchair", data["needsWheelchair"] == true ? "Yes" : "No"),
                              _buildDetailRow("Trip Type", data["tripType"]),
                            ] else ...[
                              _buildDetailRow("Category", data["category"]),
                              const Text("No additional details available.", style: TextStyle(fontSize: 16)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text("Comments", style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
                    StreamBuilder(
                      stream: FirebaseFirestore.instance
                          .collection(widget.request.reference.parent.id)
                          .doc(widget.request.id)
                          .collection("comments")
                          .orderBy("timestamp", descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                        var comments = snapshot.data!.docs;

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            var comment = comments[index];
                            bool isAdminComment = comment.data().containsKey("role") && comment["role"] == "admin";
                            String commenter = comment.data().containsKey("userFullName") ? comment["userFullName"] : (comment["role"] ?? "Admin");
                            var timestamp = comment["timestamp"]?.toDate();
                            String formattedTime = timestamp != null ? DateFormat.jm().format(timestamp) : "";
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isAdminComment
                                          ? (comment.data().containsKey("username") ? comment["username"] : "Admin")
                                          : commenter,
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: fontSize - 4),
                                      ),
                                      Text(
                                        formattedTime,
                                        style: TextStyle(fontSize: fontSize - 4, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(comment["text"] ?? "No content", style: TextStyle(fontSize: fontSize)),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 100), // Give room at the bottom so scroll isn't cut off
                  ],
                ),
              ),
            ),

            if (isOpen)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(labelText: "Add a comment"),
                          ),
                        ),
                        IconButton(
                          onPressed: addComment,
                          icon: const Icon(Icons.send, color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => updateRequestStatus("Closed"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text("Close Request", style: TextStyle(color: Colors.white, fontSize: fontSize)),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: Text(
                    "This Request is closed. Comments are disabled.",
                    style: TextStyle(fontSize: fontSize - 4, fontStyle: FontStyle.italic, color: Colors.red),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
