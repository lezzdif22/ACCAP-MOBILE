import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserListScreen extends StatelessWidget {
  final String category;

  const UserListScreen({super.key, required this.category});

  // Function to calculate age from birthdate
  int _calculateAge(DateTime birthdate) {
    final today = DateTime.now();
    int age = today.year - birthdate.year;
    if (today.month < birthdate.month || (today.month == birthdate.month && today.day < birthdate.day)) {
      age--;
    }
    return age;
  }

  Future<List<Map<String, String>>> _getUsersForCategory(String category) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('disabilityType', isEqualTo: category)
        .get();

    List<Map<String, String>> users = snapshot.docs.map((doc) {
      String firstName = doc['firstName'] ?? '';
      String middleName = doc['middleName'] ?? '';
      String lastName = doc['lastName'] ?? '';
      String contactNumber = doc['contactNumber'] ?? 'N/A';
      String email = doc['email'] ?? 'N/A';
      String address = doc['address'] ?? 'N/A';
      String birthdateString = doc['birthdate'] ?? '';  // Assuming the birthdate is a string

      // Parse birthdate string into DateTime
      DateTime birthdate = DateTime.parse(birthdateString);

      // Concatenate the full name
      String fullName = '$firstName $middleName $lastName'.trim();

      // Calculate age
      int age = _calculateAge(birthdate);

      // Format birthdate
      String birthdateFormatted = DateFormat('yyyy-MM-dd').format(birthdate);

      return {
        'fullName': fullName,
        'birthdate': birthdateFormatted,
        'age': age.toString(),
        'address': address,
        'contactNumber': contactNumber,
        'email': email,
      };
    }).toList();

    return users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: FutureBuilder<List<Map<String, String>>>(  // Fetch users data
        future: _getUsersForCategory(category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No users found in this category.'));
          } else {
            List<Map<String, String>> users = snapshot.data!;
            int totalUsers = users.length; // Calculate the total user count

            return SingleChildScrollView(
              child: Center(  // Center the table within the body
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Total user count display
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text(
                          'Total Users in $category: $totalUsers',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Table(
                        border: TableBorder.all(color: Colors.black, width: 1),
                        columnWidths: {
                          0: FixedColumnWidth(250),  // Wider name column
                          1: FixedColumnWidth(150),
                          2: FixedColumnWidth(80),
                          3: FixedColumnWidth(250),
                          4: FixedColumnWidth(200),
                          5: FixedColumnWidth(250),
                        },
                        children: [
                          // Header Row
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey[300]),
                            children: [
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Birthdate', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Age', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Address', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                          // User Rows
                          ...users.map((user) {
                            return TableRow(
                              children: [
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(user['fullName'] ?? 'N/A'),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(user['birthdate'] ?? 'N/A'),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(user['age'] ?? 'N/A'),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(user['address'] ?? 'N/A'),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(user['contactNumber'] ?? 'N/A'),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(user['email'] ?? 'N/A'),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}