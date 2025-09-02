import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/haptic_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  String? errorMessage;

  void resetPassword() async {
    setState(() {
      errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent!")),
      );
  HapticService.instance.heavyImpactWithVibration();
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
  HapticService.instance.vibratePattern([0, 60, 40, 60]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 48, 96),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Image(
                image: AssetImage('assets/ACCAP_LOGO.png'),
                width: 150,
                height: 150,
              ),
              Stack(
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
              const Text(
                "Accesibility-Centered Community\nApplication for PWD",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Enter your email to reset password",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: "Email",
                  labelStyle: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:Color.fromARGB(255, 0, 48, 96),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: resetPassword,
                  child: const Text("Reset Password", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}