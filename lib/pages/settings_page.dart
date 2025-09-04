import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase/pages/profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/haptic_service.dart';
import '../services/talkback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/text_size.dart';
import 'login_page.dart';
// ...existing code...

class SettingsPage extends StatelessWidget {
  final Map<String, dynamic> userDetails;

  const SettingsPage({super.key, required this.userDetails});
  @override
  Widget build(BuildContext context) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(title: const Text(
        "SETTINGS",
        style: TextStyle(
          color: Color.fromARGB(255, 250, 250, 250),
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 5.0,
        ),
       ),
        toolbarHeight: 70,
        flexibleSpace: Container(
          width: double.infinity,
          height: 70,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Color.fromARGB(255, 0, 48, 96),
                width: 60.0,
              ),
            ),
          ),
        ),
        backgroundColor: Color.fromARGB(255, 0, 48, 96),
        centerTitle: true,
        leading: Semantics(
          label: "Back button",
          hint: "Go back to previous page",
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 250, 250, 250), size: 30),
            onPressed: () async {
              HapticService.instance.buttonPress();
              await TalkBackService.instance.speak("Going back from settings");
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: ListView(
        children: [
          Semantics(
            label: "Account Details",
            hint: "View and edit your account information",
            child: ListTile(
              leading: Icon(Icons.person),
              title: Text('Account Details',style: TextStyle(fontSize: fontSize),),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () {
                HapticService.instance.buttonPress();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AccountSettingsPage()),
                );
              },
            ),
          ),
          Semantics(
            label: "Profile",
            hint: "View and edit your profile information",
            child: ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text('Profile', style: TextStyle(fontSize: fontSize)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                HapticService.instance.buttonPress();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(userDetails: userDetails),
                  ),
                );
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.format_size),
            title: Text('Personalization',style: TextStyle(fontSize: fontSize),),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              HapticService.instance.buttonPress();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PersonalizationSettingsPage()),
              );
            },
          ),
          // Haptics toggle moved to Personalization (keeps settings page simpler)
          // Haptics test removed — use Haptics toggle above
        ],
      ),
    );
  }
}


class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _auth = FirebaseAuth.instance;
  String _email = '';
  String _fullName = '';
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() => _email = user.email ?? '');

      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userData.exists) {
        setState(() {
          _fullName = '${userData['firstName']} ${userData['middleName']} ${userData['lastName']}'
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ');
        });
      }
    }
  }

  void signOut(BuildContext context) async {
    bool? confirmLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 250, 250, 250),
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage(onTap: () {})),
                      (route) => false,
                );
              }
            },
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage(onTap: () {})),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(
        title: const Text(
        "",
        style: TextStyle(
          color: Color.fromARGB(255, 250, 250, 250),
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 5.0,
          ),
        ),
        toolbarHeight: 70,
        flexibleSpace: Container(
          width: double.infinity,
          height: 70,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Color.fromARGB(255, 0, 48, 96),
                width: 60.0,
              ),
            ),
          ),
        ),
        backgroundColor: Color.fromARGB(255, 0, 48, 96),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () async { 
            HapticService.instance.buttonPress(); 
            await TalkBackService.instance.speak("Going back from account settings");
            Navigator.pop(context); 
          },
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          Text(
            'My Account',
            style: TextStyle(
              color: Colors.grey,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          ListTile(
            title: Text(
              _fullName,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(),
          Text(
            'Account Info',
            style: TextStyle(
              color: Colors.grey,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          ListTile(
            title: Text('Email: $_email', style: TextStyle(fontSize: fontSize - 2,),),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChangeEmailPage(),
              ),
            ),
          ),
          Divider(),
          Text(
            'Security Info',
            style: TextStyle(
              color: Colors.grey,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          ListTile(
            title: Text('Password', style: TextStyle(fontSize: fontSize,),),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChangePasswordPage(),
              ),
            ),
          ),
          Divider(),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => signOut(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 0, 48, 96), // Button background color
              foregroundColor: Colors.white, // Text (and icon) color
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white), // Ensures text is white
            ),
          ),
        ],
      ),
    );
  }
}

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  _ChangeEmailPageState createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  String _currentPassword = '';
  String _newEmail = '';
  bool _isLoading = false;
  bool _showPassword = false;

  Future<void> _updateEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = _auth.currentUser;
        if (user != null) {
          await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(
              email: user.email!,
              password: _currentPassword,
            ),
          );
          await user.updateEmail(_newEmail);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Email updated successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update email: ${e.toString()}')),
        );
      }
      setState(() => _isLoading = false);
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
                width: 60.0,
              ),
            ),
          ),
        ),
        backgroundColor: Color.fromARGB(255, 0, 48, 96),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () async { 
            HapticService.instance.buttonPress(); 
            await TalkBackService.instance.speak("Going back from change email");
            Navigator.pop(context); 
          },
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                ),
                obscureText: !_showPassword,
                validator: (value) =>
                value?.isEmpty ?? true ? 'Please enter current password' : null,
                onChanged: (value) => _currentPassword = value,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'New Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                value?.isEmpty ?? true ? 'Please enter new email' : null,
                onChanged: (value) => _newEmail = value,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _updateEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text(
                  'Update Email',
                  style: TextStyle(color: Colors.white),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  String _currentPassword = '';
  String _newPassword = '';
  bool _isLoading = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
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

  String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Please enter new password';
    if (!hasUppercase) return 'Must have at least one uppercase letter';
    if (!hasLowercase) return 'Must have at least one lowercase letter';
    if (!hasNumber) return 'Must have at least one number';
    if (!hasSpecialChar) return 'Must have at least one special character';
    if (!hasMinLength) return 'Must be at least 8 characters';
    return null;
  }

  Future<void> _updatePassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = _auth.currentUser;
        if (user != null) {
          await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(
              email: user.email!,
              password: _currentPassword,
            ),
          );
          await user.updatePassword(_newPassword);
          HapticService.instance.heavyImpactWithVibration();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Password updated successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        HapticService.instance.vibratePattern([0, 60, 40, 60]);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update password: ${e.toString()}')),
        );
      }
      setState(() => _isLoading = false);
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
                width: 60.0,
              ),
            ),
          ),
        ),
        backgroundColor: Color.fromARGB(255, 0, 48, 96),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () async { 
            HapticService.instance.buttonPress(); 
            await TalkBackService.instance.speak("Going back from change password");
            Navigator.pop(context); 
          },
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showCurrentPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _showCurrentPassword = !_showCurrentPassword;
                      });
                    },
                  ),
                ),
                obscureText: !_showCurrentPassword,
                validator: (value) =>
                value?.isEmpty ?? true ? 'Please enter current password' : null,
                onChanged: (value) => _currentPassword = value,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'New Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showNewPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _showNewPassword = !_showNewPassword;
                      });
                    },
                  ),
                ),
                obscureText: !_showNewPassword,
                validator: passwordValidator, // <-- This applies the requirements
                onChanged: (value) {
                  _newPassword = value;
                  validatePassword(value); // <-- This updates the checklist colors
                },
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    "Password Requirements:",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 5),
                  Text('• At least one uppercase letter',
                      style: TextStyle(color: hasUppercase ? Colors.green : Colors.red)),
                  Text('• At least one lowercase letter',
                      style: TextStyle(color: hasLowercase ? Colors.green : Colors.red)),
                  Text('• At least one number',
                      style: TextStyle(color: hasNumber ? Colors.green : Colors.red)),
                  Text('• At least one special character',
                      style: TextStyle(color: hasSpecialChar ? Colors.green : Colors.red)),
                  Text('• At least 8 characters',
                      style: TextStyle(color: hasMinLength ? Colors.green : Colors.red)),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _showConfirmPassword = !_showConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: !_showConfirmPassword,
                validator: (value) =>
                value != _newPassword ? 'Passwords do not match' : null,
                onChanged: (value) {},
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text(
                  'Update Password',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PersonalizationSettingsPage extends StatefulWidget {
  const PersonalizationSettingsPage({super.key});

  @override
  State<PersonalizationSettingsPage> createState() => _PersonalizationSettingsPageState();
}

enum TextSize { normal, large, larger }

class _PersonalizationSettingsPageState extends State<PersonalizationSettingsPage> {
  bool _hapticsOn = false;
  bool _talkBackOn = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final haptics = prefs.getBool('haptics_enabled');
    final talkback = prefs.getBool('talkback_enabled');
    setState(() {
      _hapticsOn = haptics ?? true;
      _talkBackOn = talkback ?? false;
    });
    // ensure HapticService state matches
    await HapticService.instance.setEnabled(_hapticsOn);
  }

  @override
  Widget build(BuildContext context) {
    final textProvider = Provider.of<TextSizeProvider>(context);
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(
        title: const Text(
          "PERSONALIZATION",
          style: TextStyle(
            color: Color.fromARGB(255, 250, 250, 250),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 5.0,
          ),
        ),
        toolbarHeight: 70,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Color.fromARGB(255, 0, 48, 96),
                width: 60.0,
              ),
            ),
          ),
        ),
        backgroundColor: Color.fromARGB(255, 0, 48, 96),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () async { 
            HapticService.instance.buttonPress(); 
            await TalkBackService.instance.speak("Going back from personalization settings");
            Navigator.pop(context); 
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'INTERFACE STYLE',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: textProvider.sliderValue,
              min: 0,
              max: 2,
              divisions: 2,
              activeColor: Color.fromARGB(255, 30, 136, 229),
              inactiveColor: Color.fromARGB(255, 200, 200, 200),
              onChanged: (value) => textProvider.updateFromSlider(value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTextSizeLabel('Normal', textProvider.textSize == TextSize.normal),
                _buildTextSizeLabel('Large', textProvider.textSize == TextSize.large),
                _buildTextSizeLabel('Larger', textProvider.textSize == TextSize.larger),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Preview Text: This is an example.',
              style: TextStyle(fontSize: textProvider.fontSize),
            ),
            const SizedBox(height: 24),
            // Haptics Switch
            Semantics(
              label: _hapticsOn ? "Haptics enabled" : "Haptics disabled",
              hint: "Toggle haptic feedback on or off",
              child: SwitchListTile(
                title: const Text('Haptics'),
                value: _hapticsOn,
                onChanged: (value) async {
                  await HapticService.instance.setEnabled(value);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('haptics_enabled', value);
                  setState(() {
                    _hapticsOn = value;
                  });
                },
                activeColor: Color.fromARGB(255, 0, 48, 96),
              ),
            ),
            // TalkBack Switch
            Semantics(
              label: _talkBackOn ? "TalkBack enabled" : "TalkBack disabled",
              hint: "Toggle accessibility screen reader on or off",
              child: SwitchListTile(
                title: const Text('TalkBack'),
                value: _talkBackOn,
                onChanged: (value) async {
                  await TalkBackService.instance.setEnabled(value);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('talkback_enabled', value);
                  setState(() {
                    _talkBackOn = value;
                  });
                },
                activeColor: Color.fromARGB(255, 0, 48, 96),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                      'textSize': textProvider.textSize.toString().split('.').last,
                      // Optionally save haptics/talkback state as well
                      // 'hapticsOn': _hapticsOn,
                      // 'talkBackOn': _talkBackOn,
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 48, 96),
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Save Preference',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextSizeLabel(String label, bool isSelected) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.blue : Colors.black,
      ),
    );
  }
}
