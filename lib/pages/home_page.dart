import 'package:firebase/pages/request_assistance_page.dart';
import 'package:firebase/pages/settings_page.dart';
import 'package:firebase/pages/ticket_page.dart';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'announcement_page.dart';
import 'notification_page.dart';
import 'tools_page.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/push_listener_service.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? userDetails;
  int _selectedIndex = 0;
  final GlobalKey<HomePageContentState> _homePageKey = GlobalKey<HomePageContentState>();

  @override
  void initState() {
    super.initState();
    fetchUserDetails();
    _initNotificationsAndListener();
  }

  Future<void> _initNotificationsAndListener() async {
    // Request Android 13+ notifications permission (no-op on older/other platforms)
    try {
      await Permission.notification.request();
    } catch (_) {}

    final user = _auth.currentUser;
    if (user != null) {
      await PushListenerService.instance.start(user.uid);
    }
  }

  Future<void> fetchUserDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection("users").doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          userDetails = userDoc.data() as Map<String, dynamic>;
        });
      }
    }
  }

  void goToSettings() {
    if (userDetails != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SettingsPage(userDetails: userDetails!),
        ),
      );
    }
  }

  void goToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserNotificationsPage(),
      ),
    );
  }

  final List<Widget> _pages = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pages.isEmpty) {
      _pages.add(HomePageContent(key: _homePageKey));
      _pages.add(UserToolsPage());
      _pages.add(UserAnnouncementPage());
      _pages.add(TicketsPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(
        toolbarHeight: 70,
        flexibleSpace: Container(
          width: double.infinity,
          height: 70,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Color.fromARGB(255, 0, 48, 96),
                width: 60.0, // Border thickness
              ),
            ),
          ),
        ),
        backgroundColor: Color.fromARGB(255, 0, 48, 96),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "ACCAP",
          textAlign: TextAlign.center,
          style: TextStyle(
            letterSpacing: 5.0,
            fontFamily: "Inter",
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 250, 250, 250),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticService.instance.selection();
              goToNotifications();
            },
            icon: const Icon(Icons.notifications, size: 30),
          ),
          IconButton(
            onPressed: () {
              HapticService.instance.selection();
              goToSettings();
            },
            icon: const Icon(Icons.settings, size: 30),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        backgroundColor: const Color.fromARGB(255, 250, 250, 250),
        onTap: (index) {
          HapticService.instance.selection();
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black54,
        selectedIconTheme: IconThemeData(size: 26),
        unselectedIconTheme: IconThemeData(size: 22),
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 9),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_people),
            label: 'Assistance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_circle),
            label: 'Tools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.announcement),
            label: 'Announcements',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_num),
            label: 'My Requests',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    PushListenerService.instance.stop();
    super.dispose();
  }
}