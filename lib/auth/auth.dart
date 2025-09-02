import 'package:firebase/auth/login_or_register.dart';
import 'package:firebase/pages/home_page.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  User? _user;
  String? _role;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _getUserRole(user);
      } else {
        setState(() {
          _user = null;
          _role = null;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _getUserRole(User user) async {
    final email = user.email ?? '';
    final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(email).get();
    // users collection stores docs by uid
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    bool mustVerify = false;

    if (userDoc.exists && userDoc.data() != null) {
      mustVerify = userDoc.data()!['mustVerify'] == true;
    }

    if (mounted) {
      setState(() {
        _user = user;

        if (adminDoc.exists && adminDoc.data()?['role'] == 'admin') {
          _role = "admin";
        } else if (userDoc.exists && userDoc.data()?['role'] == 'user') {
          _role = "user";
        } else {
          _role = null;
        }
        _isLoading = false;
      });

      // Delay slightly to let UI settle before navigation decisions
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted) return;

        // Only auto-navigate to the user's home when not admin
        if (_role != "admin") {
          // If this account requires verification but email isn't verified, sign out and return to auth
          if (mustVerify && !(user.emailVerified)) {
            try {
              await FirebaseAuth.instance.signOut();
            } catch (e) {
              print('Error signing out unverified user: $e');
            }
            if (mounted) {
              setState(() {
                _user = null;
                _role = null;
              });
            }
            return;
          }

          // otherwise navigate to user home
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserHomePage()),
            );
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _user == null ? const LoginOrRegister() : Container();
  }
}