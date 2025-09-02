import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class AdminTicketPage extends StatefulWidget {
  const AdminTicketPage({super.key});

  @override
  _AdminTicketPageState createState() => _AdminTicketPageState();
}

class _AdminTicketPageState extends State<AdminTicketPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String selectedCategory = "Medication";
  String selectedStatus = "All";
  TextEditingController searchController = TextEditingController();

  Stream<List<QueryDocumentSnapshot>> getAllRequests() {
    Stream<QuerySnapshot> medicationStream = _firestore.collection("medication_requests").snapshots();
    Stream<QuerySnapshot> wheelchairStream = _firestore.collection("wheelchair_requests").snapshots();
    Stream<QuerySnapshot> serviceStream = _firestore.collection("service_requests").snapshots();

    return Rx.combineLatest3(
      medicationStream,
      wheelchairStream,
      serviceStream,
          (QuerySnapshot medication, QuerySnapshot wheelchair, QuerySnapshot service) {
        return [...medication.docs, ...wheelchair.docs, ...service.docs];
      },
    );
  }

 @override
Widget build(BuildContext context) {
  final searchController = TextEditingController();
  final screenWidth = MediaQuery.of(context).size.width;
  final isSmallScreen = screenWidth < 600;

  return Scaffold(
    backgroundColor: const Color.fromRGBO(255, 255, 255, 1.0),
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Admin Tickets", style: TextStyle(color: Colors.black)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: "Search Ticket No.",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ],
                )
              :Padding(
  padding: const EdgeInsets.all(12.0),
  child: Builder(
    builder: (context) {
      final screenWidth = MediaQuery.of(context).size.width;
      final bool isSmall = screenWidth < 600;

      if (isSmall) {
        return Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text("Search Ticket"),
            onPressed: () {
              final TextEditingController popupController = TextEditingController();

              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Search Ticket No."),
                    content: TextField(
                      controller: popupController,
                      decoration: InputDecoration(
                        hintText: "Enter Ticket No.",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          searchController.text = popupController.text;
                          setState(() {}); // Apply the filter
                          Navigator.pop(context);
                        },
                        child: const Text("Search"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      } else {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Admin Tickets",
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              width: 250,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: "Search Ticket No.",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
          ],
        );
      }
    },
  ),
);



        },
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: const BorderSide(color: Colors.black, width: 1),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  bool isNarrow = constraints.maxWidth < 600;
                  return isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButton<String>(
                              value: selectedCategory,
                              onChanged: (newCategory) {
                                setState(() {
                                  selectedCategory = newCategory!;
                                });
                              },
                              items: ["Medication", "Wheelchair", "Transportation Service"]
                                  .map<DropdownMenuItem<String>>((String category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            _buildStatusFilters(),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            DropdownButton<String>(
                              value: selectedCategory,
                              onChanged: (newCategory) {
                                setState(() {
                                  selectedCategory = newCategory!;
                                });
                              },
                              items: ["Medication", "Wheelchair", "Transportation Service"]
                                  .map<DropdownMenuItem<String>>((String category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                            ),
                            _buildStatusFilters(),
                          ],
                        );
                },
              ),
              const SizedBox(height: 12),

              if (!isSmallScreen)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: const Color.fromARGB(217, 217, 217, 217),
                  child: Row(
                    children: const [
                      Expanded(flex: 2, child: Center(child: Text("Ticket Number", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Date Created", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 3, child: Center(child: Text("User", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Category", style: TextStyle(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),

              Expanded(
                child: StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: getAllRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No tickets found."));
                    }

                    var requests = snapshot.data!;
                    String searchText = searchController.text.trim();

                    if (searchText.isNotEmpty) {
                      requests = requests.where((request) {
                        var data = request.data() as Map<String, dynamic>;
                        String ticketNumber = data["ticketNumber"]?.toString() ?? "";
                        return ticketNumber.contains(searchText);
                      }).toList();
                    }

                    requests = requests.where((request) {
                      var data = request.data() as Map<String, dynamic>;
                      return data["category"] == selectedCategory;
                    }).toList();

                    if (selectedStatus != "All") {
                      requests = requests.where((request) {
                        var data = request.data() as Map<String, dynamic>;
                        return data["status"] == selectedStatus;
                      }).toList();
                    }

                    requests.sort((a, b) {
                      var dataA = a.data() as Map<String, dynamic>;
                      var dataB = b.data() as Map<String, dynamic>;

                      String statusA = dataA["status"] ?? "Pending";
                      String statusB = dataB["status"] ?? "Pending";

                      int ticketNumberA = int.tryParse(dataA["ticketNumber"].toString()) ?? 0;
                      int ticketNumberB = int.tryParse(dataB["ticketNumber"].toString()) ?? 0;

                      if (statusA == "Closed" && statusB != "Closed") return 1;
                      if (statusA != "Closed" && statusB == "Closed") return -1;

                      return ticketNumberB.compareTo(ticketNumberA);
                    });

                    return ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        var request = requests[index];
                        Map<String, dynamic> data = request.data() as Map<String, dynamic>;
                        String ticketNumber = data["ticketNumber"]?.toString() ?? "N/A";
                        String created = data['timestamp'] is Timestamp
                            ? DateFormat('MMM dd, yyyy').format(data['timestamp'].toDate())
                            : "Unknown Time";
                        String user = data["name"] ?? "N/A";
                        String category = data["category"] ?? "Unknown";
                        String status = data["status"] ?? "Pending";

                        Color statusColor;
                        if (status == "Open") {
                          statusColor = Colors.green;
                        } else if (status == "Closed") {
                          statusColor = Colors.red;
                        } else {
                          statusColor = Colors.orange;
                        }

                        return isSmallScreen
                            ? Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  title: Text("Ticket No. #$ticketNumber"),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Created: $created"),
                                      Text("User: $user"),
                                      Text("Category: $category"),
                                      Text("Status: $status"),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TicketDetailPage(request: request),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 1),
                                    child: Container(
                                      height: 45,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: InkWell(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TicketDetailPage(request: request),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            _verticalDivider(),
                                            Expanded(flex: 2, child: Center(child: Text("Ticket No. #$ticketNumber"))),
                                            _verticalDivider(),
                                            Expanded(flex: 2, child: Center(child: Text(created))),
                                            _verticalDivider(),
                                            Expanded(flex: 3, child: Center(child: Text(user))),
                                            _verticalDivider(),
                                            Expanded(flex: 2, child: Center(child: Text(category))),
                                            _verticalDivider(),
                                            Expanded(
                                              flex: 2,
                                              child: Center(
                                                child: Container(
                                                  width: 70,
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: statusColor),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    status,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Divider(color: Colors.grey, thickness: 1, height: 0.5),
                                ],
                              );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    ),
  );
}
Widget _buildStatusFilters() {
  return Wrap(
    spacing: 8.0,
    runSpacing: 8.0,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Text(
        "Filter by Status:",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      _buildRadioButton("All"),
      _buildRadioButton("Open"),
      _buildRadioButton("Closed"),
    ],
  );
}


  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 45,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildRadioButton(String label) {
    return Row(
      children: [
        Radio<String>(
          value: label,
          groupValue: selectedStatus,
          onChanged: (String? value) {
            setState(() {
              selectedStatus = value!;
            });
          },
        ),
        Text(label),
      ],
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
  late bool isOpen;

  @override
  void initState() {
    super.initState();
    isOpen = widget.request["status"] == "Open";
  }

  void addComment() {
    if (_commentController.text.isNotEmpty) {
      FirebaseFirestore.instance
          .collection(widget.request.reference.parent.id)
          .doc(widget.request.id)
          .collection("comments")
          .add({
        "text": _commentController.text,
        "timestamp": FieldValue.serverTimestamp(),
        "role": "admin",
      });
      _commentController.clear();
    }
  }

  void updateTicketStatus(String newStatus) {
    FirebaseFirestore.instance
        .collection(widget.request.reference.parent.id)
        .doc(widget.request.id)
        .update({"status": newStatus});

    setState(() {
      isOpen = newStatus == "Open";
    });
  }

  @override
  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 16, color: Colors.black),
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value ?? "N/A"),
          ],
        ),
      ),
    );
    
  }
  @override
Widget build(BuildContext context) {
  Map<String, dynamic> data = widget.request.data() as Map<String, dynamic>;

  return Scaffold(
    backgroundColor: const Color.fromRGBO(255, 255, 255, 1.0),
    appBar: AppBar(
      backgroundColor: const Color.fromRGBO(255, 255, 255, 1.0),
    ),
    body: SingleChildScrollView( // Wrap the entire body in a SingleChildScrollView
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double screenWidth = constraints.maxWidth;
            double containerWidth = screenWidth > 1400 ? 1350 : screenWidth * 0.95;
            double commentCardWidth = screenWidth > 400 ? 350 : screenWidth * 0.9;
            double imageWidth = screenWidth > 600 ? 200 : screenWidth * 0.4;

            return Center(
              child: Container(
                width: containerWidth,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 5,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Ticket No.: #${data["ticketNumber"] ?? "N/A"}",
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text("Name: ${data["name"] ?? "N/A"}", style: const TextStyle(fontSize: 18)),
                              Text("(${data["user"] ?? "N/A"})", style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              Text("Category: ${data["category"] ?? "N/A"}", style: const TextStyle(fontSize: 20)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOpen ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  data["status"] ?? "Pending",
                                  style: TextStyle(
                                    color: isOpen ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            spacing: 20,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (data["category"] == "Medication") ...[
                                    _buildDetailRow("Medicine", data["medicineName"]),
                                    _buildDetailRow("Service", data["pickupOrDelivery"]),
                                    _buildDetailRow("Address", data["address"]),
                                    _buildDetailRow("Date", data["date"]),
                                    _buildDetailRow("Time", data["requestedTime"]),
                                  ]
                                  else if (data["category"] == "Wheelchair") ...[
                                    _buildDetailRow("Reason", data["reason"]),
                                    _buildDetailRow("Location", data["location"]),
                                    _buildDetailRow("Delivery Date", data["dateToDeliver"]),
                                    _buildDetailRow("Delivery Time", data["deliveryTime"]),
                                    _buildDetailRow("Pickup Date", data["dateToPickUp"]),
                                    _buildDetailRow("Pickup Time", data["pickupTime"]),
                                  ]
                                  else if (data["category"] == "Transportation Service") ...[
                                    _buildDetailRow("Needs Wheelchair", data["needsWheelchair"] == true ? "Yes" : "No"),
                                    _buildDetailRow("Reason", data["reason"]),
                                    _buildDetailRow("Pickup Address", data["address"]),
                                    _buildDetailRow("Pickup Date", data["pickup_date"]),
                                    _buildDetailRow("Pickup Time", data["pickup_time"]),
                                    _buildDetailRow("Trip Type", data["tripType"]),
                                  ]
                                ],
                              ),
                              if (data.containsKey("medicine_image") && data["medicine_image"] != null)
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: true,
                                      builder: (BuildContext context) {
                                        return Dialog(
                                          backgroundColor: Colors.transparent,
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: Image.network(
                                                  data["medicine_image"],
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                                                ),
                                              ),
                                              Positioned(
                                                top: 20,
                                                right: 20,
                                                child: IconButton(
                                                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      data["medicine_image"],
                                      width: imageWidth,
                                      height: imageWidth,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: StreamBuilder(
                            stream: FirebaseFirestore.instance
                                .collection(widget.request.reference.parent.id)
                                .doc(widget.request.id)
                                .collection("comments")
                                .orderBy("timestamp", descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const CircularProgressIndicator();
                              var comments = snapshot.data!.docs;
                              return ListView.builder(
                                itemCount: comments.length,
                                itemBuilder: (context, index) {
                                  var comment = comments[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: SizedBox(
                                      width: commentCardWidth,
                                      child: Card(
                                        color: Color.fromARGB(255, 250, 250, 250),
                                        elevation: 5,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: ListTile(
                                          title: Text(
                                            comment.data().containsKey("userFullName")
                                                ? comment["userFullName"]
                                                : (comment.data().containsKey("role") && comment["role"] == "admin"
                                                    ? "Admin"
                                                    : "User"),
                                          ),
                                          subtitle: Text(comment["text"] ?? "No content"),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Add a Comment'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: _commentController,
                                          decoration: const InputDecoration(labelText: "Add a comment"),
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: IconButton(
                                            onPressed: () {
                                              addComment();
                                              Navigator.of(context).pop();
                                            },
                                            icon: const Icon(Icons.send, color: Colors.blue),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Make a Comment', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

}