import 'package:firebase/components/text_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase/pages/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'personalDetails_page.dart';

class RegisterPage extends StatefulWidget {
  final Map<String, dynamic> personalDetails;
  final Function()? onTap;

  const RegisterPage({super.key, required this.personalDetails, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailTextController = TextEditingController();
  final passwordTextController = TextEditingController();
  final confirmPasswordTextController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;
  bool hasMinLength = false;
  void validatePassword(String password) {
    setState(() {
      hasUppercase = password.contains(RegExp(r'[A-Z]'));
      hasLowercase = password.contains(RegExp(r'[a-z]'));
      hasNumber = password.contains(RegExp(r'[0-9]'));
      hasSpecialChar = password.contains(RegExp(r'[!@#\$&*~]'));
      hasMinLength = password.length >= 8;
    });
  }

  void signUp() async {
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    if (passwordTextController.text != confirmPasswordTextController.text) {
      Navigator.pop(context);
      displayMessage("Passwords don't match!");
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailTextController.text.trim(),
        password: passwordTextController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': emailTextController.text.trim(),
        'role': 'user',
  ...widget.personalDetails,
  'mustVerify': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send verification email then sign the user out so they can't be used before verification
      final user = userCredential.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }

      // Mark that we should show the verification message on the login page.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_verification_message', true);

      await FirebaseAuth.instance.signOut();
  // small delay to allow auth state listeners to process sign-out
  await Future.delayed(const Duration(milliseconds: 600));

  // clear controllers to avoid accidental reuse
  emailTextController.clear();
  passwordTextController.clear();
  confirmPasswordTextController.clear();

      if (context.mounted) {
        Navigator.pop(context);

        HapticService.instance.heavyImpactWithVibration();

        // Navigate to login page and show verification message there
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage(onTap: () {}, showVerificationMessage: true)),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
  HapticService.instance.vibratePattern([0, 60, 40, 60]);
  displayMessage("Error: ${e.message}");
    } catch (e) {
      Navigator.pop(context);
  HapticService.instance.vibratePattern([0, 60, 40, 60]);
  displayMessage("Unexpected error: $e");
    }
  }

  void displayMessage(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(title: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 48, 96),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () {
            Navigator.pop(context);
              MaterialPageRoute(
                builder: (context) => PersonalDetailsPage(
                  onNext: (data) {},
                  initialData: widget.personalDetails,
                ),
              );
          },
        ),
      ),
      backgroundColor: Color.fromARGB(255, 250, 250, 250),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Image(
                  image: AssetImage('assets/ACCAP_LOGO.png'),
                  width: 150,
                  height: 150,
                ),
              ),
              Center(
                child: Stack(
                  children: [
                    Text(
                      "ACCAP",
                      style: TextStyle(
                        letterSpacing: 3.0,
                        fontFamily: "Inter",
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Color.fromARGB(255, 28, 113, 166),
                      ),
                    ),
                    Text(
                      "ACCAP",
                      style: TextStyle(
                        letterSpacing: 3.0,
                        fontFamily: "Inter",
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 2
                          ..color = Color.fromARGB(255, 28, 113, 166),
                      ),
                    ),
                    Text(
                      "ACCAP",
                      style: TextStyle(
                        letterSpacing: 3.0,
                        fontFamily: "Inter",
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Color.fromARGB(255, 28, 113, 166),
                      ),
                    ),
                  ],
                ),
              ),
              const Center(
                child: Text(
                  "Accessibility-Centered Community\nApplication for PWD",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "Inter",
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              MyTextField(
                controller: emailTextController,
                hintText: 'Email',
                obscureText: false,
              ),
              const SizedBox(height: 10),
              MyTextField(
                controller: passwordTextController,
                hintText: 'Password',
                obscureText: !_isPasswordVisible,
                onChanged: (value) => validatePassword(value),
                onToggleVisibility: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              const SizedBox(height: 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Password Requirements:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '• At least one uppercase letter',
                    style: TextStyle(color: hasUppercase ? Colors.green : Colors.red),
                  ),
                  Text(
                    '• At least one lowercase letter',
                    style: TextStyle(color: hasLowercase ? Colors.green : Colors.red),
                  ),
                  Text(
                    '• At least one number',
                    style: TextStyle(color: hasNumber ? Colors.green : Colors.red),
                  ),
                  Text(
                    '• At least one special character',
                    style: TextStyle(color: hasSpecialChar ? Colors.green : Colors.red),
                  ),
                  Text(
                    '• At least 8 characters',
                    style: TextStyle(color: hasMinLength ? Colors.green : Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              MyTextField(
                controller: confirmPasswordTextController,
                hintText: 'Confirm Password',
                obscureText: !_isConfirmPasswordVisible,
                onToggleVisibility: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
              const SizedBox(height: 20),
              Center(
                child: Material(
                  borderRadius: BorderRadius.circular(8),
                  color: Color.fromARGB(255, 0, 48, 96),
                  child: SizedBox(
                    width: 200,
                    child: TextButton.icon(
                      onPressed: signUp,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        backgroundColor: Colors.transparent,
                      ),
                      label: const Text(
                        'Sign Up',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}