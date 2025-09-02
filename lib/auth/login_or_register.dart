import 'package:firebase/pages/login_page.dart';
import 'package:firebase/pages/register_page.dart';
import 'package:firebase/pages/personalDetails_page.dart';
import 'package:flutter/material.dart';

class LoginOrRegister extends StatefulWidget {
  const LoginOrRegister({super.key});

  @override
  State<LoginOrRegister> createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  bool showLoginPage = true;
  Map<String, dynamic>? personalDetails;

  void togglePages() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  void goToRegister(Map<String, dynamic> details) {
    setState(() {
      personalDetails = details;
      showLoginPage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      return LoginPage(onTap: togglePages);
    } else if (personalDetails == null) {
      return PersonalDetailsPage(onNext: goToRegister);
    } else {
      return RegisterPage(personalDetails: personalDetails!, onTap: togglePages);
    }
  }
}
