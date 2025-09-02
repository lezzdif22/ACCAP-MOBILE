import 'package:firebase/components/text_field.dart';
import 'package:firebase/pages/home_page.dart';
import 'package:firebase/pages/personalDetails_page.dart';
import 'package:firebase/pages/verification.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'forgotpassword_page.dart';
import 'package:url_launcher/url_launcher.dart';
class LoginPage extends StatefulWidget {
  final Function()? onTap;
  final bool showVerificationMessage;
  const LoginPage({super.key, required this.onTap, this.showVerificationMessage = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailTextController = TextEditingController();
  final passwordTextController = TextEditingController();
  String? emailError;
  String? passwordError;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    if (widget.showVerificationMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verify your email'),
            content: const Text('A verification email has been sent. Please verify your email before logging in.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
    else {
      // fallback: check prefs in case navigation didn't pass the flag
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final prefs = await SharedPreferences.getInstance();
        final showFlag = prefs.getBool('show_verification_message') ?? false;
        if (showFlag && mounted) {
          await prefs.remove('show_verification_message');
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Verify your email'),
              content: const Text('A verification email has been sent. Please verify your email before logging in.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
              ],
            ),
          );
        }
      });
    }
  }

  void signIn() async {
    setState(() {
      emailError = null;
      passwordError = null;
    });

    try {
      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailTextController.text.trim(),
        password: passwordTextController.text.trim(),
      );

      // Check if user doc requires verification (new accounts set 'mustVerify': true).
      User? signedInUser = userCredential.user;
      if (signedInUser != null) {
        try {
          final userDocRef = FirebaseFirestore.instance.collection('users').doc(signedInUser.uid);
          final userDocSnap = await userDocRef.get();
          final mustVerify = userDocSnap.exists && userDocSnap.data() != null ? (userDocSnap.data()!['mustVerify'] == true) : false;

          if (mustVerify && !signedInUser.emailVerified) {
            // Prompt to resend verification or cancel
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Email not verified'),
                content: const Text('Your email address is not verified. Would you like us to resend the verification email?'),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      try {
                        await signedInUser.sendEmailVerification();
                      } catch (e) {
                        print('Failed to resend verification: $e');
                      }
                      if (!mounted) return;
                      showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Verification Sent'), content: const Text('A verification email has been sent. Please check your inbox.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
                    },
                    child: const Text('Resend'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
            return;
          }
        } catch (e) {
          print('Error checking mustVerify flag: $e');
        }
      }

      String userEmail = emailTextController.text.trim();

      DocumentSnapshot adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(userEmail)
          .get();

   if (adminDoc.exists) {
      final url = Uri.parse('https://authenticationtest-d4ad2.web.app/#/login');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
      return;
   }


      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        if (!mounted) return;
        HapticService.instance.heavyImpactWithVibration();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserHomePage()),
        );
      } else {
        setState(() {
          emailError = "User role not found.";
        });
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase Error Code: ${e.code}");

      if (!mounted) return;
      setState(() {
        if (e.code == 'invalid-email') {
          emailError = "This email is not formatted correctly or not registered.";
          passwordError = null;
        } else if (e.code == 'user-not-found') {
          emailError = "This email is not registered.";
          passwordError = null;
        } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          emailError = "Email or password is incorrect.";
          passwordError = "";
          HapticService.instance.vibratePattern([0, 60, 40, 60]);
        } else if (e.code == 'missing-password') {
          emailError = null;
          passwordError = "Please enter your password";
          HapticService.instance.vibratePattern([0, 60, 40, 60]);
        } else {
          emailError = "Authentication failed. Please check your credentials.";
          passwordError = "";
          HapticService.instance.vibratePattern([0, 60, 40, 60]);
        }
      });
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            "email": user.email,
            "firstName": user.displayName != null ? user.displayName!.split(" ")[0] : "",
            "lastName": user.displayName != null && user.displayName!.split(" ").length > 1
                ? user.displayName!.split(" ")[1]
                : "",
            "profilePic": user.photoURL,
            "createdAt": Timestamp.now(),
            "role": "user",
          });

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => PersonalDetailsPage()),
          );
        } else {

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => PersonalDetailsPage()),
          );
        }
      }
    } catch (e) {
      print("Google Sign-In Error: $e");
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                           //Stack
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
                        ]
                      ),
                      Text(
                        "Accesibility-Centered Community\nApplication for PWD",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: "Inter",
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Color.fromARGB(255, 0, 0, 0)),
                      ),
                      const SizedBox(height: 25),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Email", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      MyTextField(
                        controller: emailTextController,
                        hintText: 'Email',
                        obscureText: false,
                        errorText: emailError,
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Password", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      MyTextField(
                        controller: passwordTextController,
                        hintText: 'Password',
                        obscureText: !_isPasswordVisible,
                        errorText: passwordError,
                        onToggleVisibility: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Material(
                        borderRadius: BorderRadius.circular(8),
                        color: Color.fromARGB(255, 0, 48, 96),
                        child: SizedBox(
                          width: 190,
                          child: TextButton.icon(
                            onPressed: () {
                              HapticService.instance.lightImpact();
                              signIn();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                              backgroundColor: Colors.transparent,
                            ),
                            label: const Text(
                              'Sign in',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        text: TextSpan(
                          text: "Forgot your Password? ",
                          style: TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                              text: "Click here",
                              style: const TextStyle(
                                color: Color.fromARGB(255, 51, 102, 153),
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    HapticService.instance.selection();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => ForgotPasswordPage()),
                                    );
                                  },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Not a member?",
                              style: TextStyle(color: Colors.black)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                                HapticService.instance.selection();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          VerificationPage(onTap: () {  },)),
                                );
                              },
                            child: const Text(
                              "Register now",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 51, 102, 153),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}