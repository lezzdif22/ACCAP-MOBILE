import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/text_size.dart';
import '../services/haptic_service.dart';
import '../services/talkback_service.dart';
import 'stt_page.dart';
import 'alarm_page.dart';
import 'tts_page.dart';

class UserToolsPage extends StatefulWidget {
  const UserToolsPage({super.key});

  @override
  _UserToolsPageState createState() => _UserToolsPageState();
}

class _UserToolsPageState extends State<UserToolsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      body: Column(
        children: [
          Container(
            color: const Color.fromARGB(255, 250, 250, 250),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.black,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              onTap: (index) {
                HapticService.instance.buttonPress();
                final tabNames = ["Speech to Text", "Text to Speech", "Reminders"];
                if (index < tabNames.length) {
                  TalkBackService.instance.speak("${tabNames[index]} tab selected");
                }
              },
              tabs: [
                Tab(
                  child: Text(
                    "STT",
                    style: TextStyle(fontSize: fontSize - 6),
                  ),
                ),
                Tab(
                  child: Text(
                    "TTS",
                    style: TextStyle(fontSize: fontSize - 6),
                  ),
                ),
                Tab(
                  child: Text(
                    "Reminders",
                    style: TextStyle(fontSize: fontSize - 6),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                STTPage(),
                TTSPage(),
                ReminderPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}