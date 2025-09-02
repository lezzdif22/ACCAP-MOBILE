import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../services/haptic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../components/text_size.dart';
import 'add_alarm_page.dart';
import 'edit_alarm_page.dart';
import 'alarm_screen.dart';
import 'dart:io';

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  _ReminderPageState createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  List<Map<String, dynamic>> reminders = [];
  FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadReminders();
    _startReminderChecker();
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings("app_icon");
    final InitializationSettings settings = InitializationSettings(android: androidSettings);
    notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null) {
          final parts = response.payload!.split('_');
          if (parts.length >= 2) {
            final action = parts[0];
            final index = int.tryParse(parts[1]);
            
            if (index != null && index >= 0 && index < reminders.length) {
              if (action == 'STOP') {
                setState(() {
                  reminders[index]["active"] = false;
                });
                _stopVibration();
                _saveReminders();
              } else if (action == 'SNOOZE') {
                _handleSnooze(index);
              }
            }
          }
        }
      },
    );
  }

  Future<void> _showNotification(String reminderName, int index, {String? ringtone}) async {
    final soundName = (ringtone ?? 'default').toLowerCase().replaceAll('.mp3', '');
    final channelId = "reminder_channel_$soundName";
    final channelName = "Reminder for $soundName";
    final sound = RawResourceAndroidNotificationSound(soundName);

    final alarm = reminders[index];
    final bool hasSnooze = alarm['snooze'] ?? false;
    final int snoozeDuration = alarm['snooze_duration'] ?? 5;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: "Reminder Alerts with $soundName",
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: sound,
      enableVibration: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'STOP_ACTION',
          'Stop Alarm',
          cancelNotification: true,
        ),
        if (hasSnooze)
          AndroidNotificationAction(
            'SNOOZE_ACTION',
            'Snooze ${snoozeDuration}m',
            cancelNotification: true,
          ),
      ],
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      index,
      "Reminder!",
      "$reminderName is due!",
      notificationDetails,
      payload: 'STOP_$index',
    );
  }

  Future<void> _saveReminders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("reminders", jsonEncode(reminders));
  }

  Future<void> _loadReminders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedReminders = prefs.getString("reminders");

    setState(() {
      reminders = List<Map<String, dynamic>>.from(jsonDecode(savedReminders ?? '[]')).map((reminder) {
        if (reminder["type"] == "Medication") {
          return {
            "name": reminder["name"] ?? "Alarm",
            "type": "Medication",
            "time": reminder["time"] ?? "00:00",
            "repeat": reminder["repeat"] ?? "No Repeat",
            "custom_time": reminder["custom_time"] ?? 60,
            "stop_condition": reminder["stop_condition"] ?? "Normal",
            "dnd_start": reminder["dnd_start"] ?? "",
            "dnd_end": reminder["dnd_end"] ?? "",
            "ringtone": reminder["ringtone"] ?? "Default",
            "snooze": reminder["snooze"] ?? false,
            "snooze_duration": reminder["snooze_duration"] ?? 5,
            "image_path": reminder["image_path"],
            "active": reminder["active"] ?? true,
          };
        } else {
          return {
            "name": reminder["name"] ?? "Alarm",
            "type": "Standard",
            "time": reminder["time"] ?? "00:00",
            "ringtone": reminder["ringtone"] ?? "Default",
            "snooze": reminder["snooze"] ?? false,
            "snooze_duration": reminder["snooze_duration"] ?? 5,
            "image_path": reminder["image_path"],
            "active": reminder["active"] ?? true,
          };
        }
      }).toList();
    });
  }

  void _toggleReminder(int index) {
    setState(() {
      reminders[index]["active"] = !reminders[index]["active"];
    });
    _saveReminders();
  }

  void _removeReminder(int index) {
    setState(() {
      reminders.removeAt(index);
    });
    _saveReminders();
  }

  void _startReminderChecker() {
    _reminderTimer = Timer.periodic(Duration(seconds: 60), (timer) {
      if (!mounted) return;
      DateTime now = DateTime.now();
      String currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      
      for (int i = 0; i < reminders.length; i++) {
        if (reminders[i]["active"] && reminders[i]["time"] == currentTime) {
          _triggerReminder(i);
        }
      }
    });
  }

  Timer? _vibrationTimer;

  void _triggerReminder(int index) {
    if (!mounted) return;

    final alarm = reminders[index];
    final type = alarm["type"];

    String name = alarm["name"] ?? "Reminder";
    String currentTime = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    if (type == "Medication") {
      String? dndStart = alarm["dnd_start"];
      String? dndEnd = alarm["dnd_end"];

      if (_isWithinDND(dndStart, dndEnd, currentTime)) {
        print("Skipping reminder '$name' due to DND mode.");
        return;
      }

        if (alarm["stop_condition"] == "No Stop (24hr)") {
          _startInfiniteVibration();
        } else {
          HapticService.instance.vibrate(1000);
      }

      // Handle repeat
      String repeatInterval = (reminders[index]["repeat"] as String?) ?? "No Repeat";
      int hoursToAdd = 0;
      int minutesToAdd = 0;

      switch (repeatInterval) {
        case "1 Hour":
          hoursToAdd = 1;
          break;
        case "2 Hours":
          hoursToAdd = 2;
          break;
        case "3 Hours":
          hoursToAdd = 3;
          break;
        case "4 Hours":
          hoursToAdd = 4;
          break;
        case "Custom Time":
          int customMinutes = alarm["custom_time"] ?? 60;
          hoursToAdd = customMinutes ~/ 60;
          minutesToAdd = customMinutes % 60;
          break;
        case "No Repeat":
        default:
          setState(() {
            reminders[index]["active"] = false;
          });
          _stopVibration();
          break;
      }

      // If there's a repeat, update time
      if (repeatInterval != "No Repeat") {
        DateTime newTime = DateTime.now().add(Duration(hours: hoursToAdd, minutes: minutesToAdd));
        String updatedTime = "${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}";
        setState(() {
          reminders[index]["time"] = updatedTime;
        });
      }
    } else {
      // Standard Alarm
        HapticService.instance.vibrate(1000);
    }

    // Show the alarm screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AlarmScreen(
          alarmName: name,
          ringtone: alarm["ringtone"] ?? "Default",
          hasSnooze: alarm["snooze"] ?? false,
          snoozeDuration: alarm["snooze_duration"] ?? 5,
          imagePath: alarm["image_path"],
          onStop: () {
            setState(() {
              reminders[index]["active"] = false;
            });
            _stopVibration();
            _saveReminders();
          },
          onSnooze: () => _handleSnooze(index),
        ),
      ),
    );

    _showNotification(name, index, ringtone: alarm["ringtone"]);
    _saveReminders();
  }

  // Function to start infinite vibration for "No Stop (24hr)"
  void _startInfiniteVibration() {
    _vibrationTimer?.cancel(); // Cancel any existing vibration loop
    _vibrationTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      // Use HapticService to vibrate consistently; service checks for vibrator availability
      HapticService.instance.vibrate(1000);
    });

    // Stop after 24 hours
    Future.delayed(Duration(hours: 24), () {
      _stopVibration();
    });
  }

  // Function to stop vibration manually or when alarm is deactivated
  void _stopVibration() {
    print("Stopping vibration...");
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  HapticService.instance.cancel();
  }

  bool _isWithinDND(String? dndStart, String? dndEnd, String currentTime) {
    // Early exit if null or empty
    if (dndStart == null || dndStart.isEmpty || dndEnd == null || dndEnd.isEmpty) {
      return false;
    }

    try {
      DateTime now = DateTime.now();

      List<String> startParts = dndStart.split(":");
      List<String> endParts = dndEnd.split(":");
      List<String> currentParts = currentTime.split(":");

      if (startParts.length != 2 || endParts.length != 2 || currentParts.length != 2) {
        return false;
      }

      DateTime dndStartTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );

      DateTime dndEndTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      );

      DateTime currentDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(currentParts[0]),
        int.parse(currentParts[1]),
      );

      if (dndStartTime.isBefore(dndEndTime)) {
        // Normal DND window
        return currentDateTime.isAfter(dndStartTime) && currentDateTime.isBefore(dndEndTime);
      } else {
        // DND spans over midnight
        return currentDateTime.isAfter(dndStartTime) || currentDateTime.isBefore(dndEndTime);
      }
    } catch (e) {
      print("DND time parsing error: $e");
      return false;
    }
  }

  Future<void> _navigateToAddAlarmPage() async {
    final newAlarm = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddAlarmPage()),
    );

    if (newAlarm == null) return;

    setState(() {
      if (newAlarm["type"] == "Standard") {
        reminders.add({
          "name": newAlarm["label"] ?? "Alarm",
          "type": "Standard",
          "time": newAlarm["time"],
          "ringtone": newAlarm["ringtone"] ?? "Default",
          "snooze": newAlarm["snooze"] ?? false,
          "snooze_duration": newAlarm["snooze_duration"] ?? 5,
          "image_path": newAlarm["image_path"],
          "active": true,
        });
      } else {
        reminders.add({
          "name": newAlarm["label"] ?? "Alarm",
          "type": "Medication",
          "time": newAlarm["time"],
          "repeat": newAlarm["repeat"] ?? "No Repeat",
          "custom_time": newAlarm["custom_time"] ?? 60,
          "stop_condition": newAlarm["stop_condition"] ?? "Normal",
          "dnd_start": newAlarm["dnd_start"] ?? "",
          "dnd_end": newAlarm["dnd_end"] ?? "",
          "ringtone": newAlarm["ringtone"] ?? "Default",
          "snooze": newAlarm["snooze"] ?? false,
          "snooze_duration": newAlarm["snooze_duration"] ?? 5,
          "image_path": newAlarm["image_path"],
          "active": true,
        });
      }
    });

    _saveReminders();
  }

  Future<void> _navigateToEditAlarmPage(int index) async {
    final originalAlarm = reminders[index];

    final editedAlarm = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAlarmPage(alarm: originalAlarm),
      ),
    );

    if (editedAlarm == null) return;

    setState(() {
      reminders[index] = {
        "id": editedAlarm["id"] ?? originalAlarm["id"], // Safer
        "type": editedAlarm["type"] ?? originalAlarm["type"] ?? "Standard",
        "name": editedAlarm["label"] ?? originalAlarm["label"] ?? "Alarm", // FIXED here
        "time": editedAlarm["time"] ?? originalAlarm["time"],
        "repeat": editedAlarm["repeat"] ?? originalAlarm["repeat"] ?? "No Repeat",
        "custom_time": editedAlarm["custom_time"] ?? originalAlarm["custom_time"] ?? 60,
        "stop_condition": editedAlarm["stop_condition"] ?? originalAlarm["stop_condition"] ?? "Normal",
        "dnd_start": editedAlarm["dnd_start"] ?? originalAlarm["dnd_start"],
        "dnd_end": editedAlarm["dnd_end"] ?? originalAlarm["dnd_end"],
        "ringtone": editedAlarm["ringtone"] ?? originalAlarm["ringtone"] ?? "Default",
        "snooze": editedAlarm["snooze"] ?? originalAlarm["snooze"] ?? false,
        "active": editedAlarm["active"] ?? originalAlarm["active"] ?? true,
      };
    });

    _saveReminders();
  }

  void _handleSnooze(int alarmIndex) {
    if (alarmIndex >= 0 && alarmIndex < reminders.length) {
      final alarm = reminders[alarmIndex];
      final int snoozeDuration = alarm['snooze_duration'] ?? 5;
      
      // Calculate new time
      DateTime now = DateTime.now();
      DateTime snoozeTime = now.add(Duration(minutes: snoozeDuration));
      String newTime = "${snoozeTime.hour.toString().padLeft(2, '0')}:${snoozeTime.minute.toString().padLeft(2, '0')}";
      
      setState(() {
        reminders[alarmIndex]["time"] = newTime;
        reminders[alarmIndex]["active"] = true;
      });
      
      // Show new notification for snoozed alarm
      _showNotification(
        reminders[alarmIndex]["name"] ?? "Alarm",
        alarmIndex,
        ringtone: reminders[alarmIndex]["ringtone"],
      );
      
      _saveReminders();
      _stopVibration();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(
        title: Text("REMINDERS", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 250, 250, 250),
        actions: [
          IconButton(
            icon: Icon(Icons.add, size: 30),
            onPressed: _navigateToAddAlarmPage,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: reminders.length,
        itemBuilder: (context, index) {
          final imagePath = reminders[index]["image_path"];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: const Color.fromARGB(255, 250, 250, 250),
            child: ListTile(
              leading: imagePath != null
                  ? FutureBuilder<bool>(
                      future: File(imagePath).exists(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data == true) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(imagePath),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading image: $error');
                                return Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.error_outline, color: Colors.grey[600]),
                                );
                              },
                            ),
                          );
                        }
                        return Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.alarm, color: Colors.grey[600]),
                        );
                      },
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.alarm, color: Colors.grey[600]),
                    ),
              title: Text(
                reminders[index]["name"] ?? "Unnamed Alarm",
                style: TextStyle(fontSize: fontSize - 1 , fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Time: ${reminders[index]["time"]}",
                    style: TextStyle(fontSize: fontSize - 5, color: Colors.grey[700]),
                  ),
                  Text(
                    reminders[index]["type"] == 'Medication'
                        ? "Repeat: ${reminders[index]["repeat"]}"
                        : "Standard Alarm",
                    style: TextStyle(fontSize: fontSize - 8, color: Colors.grey[700]),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: reminders[index]["active"],
                    onChanged: (val) => _toggleReminder(index),
                  ),
                  PopupMenuButton<String>(
                    color: Colors.white,
                    onSelected: (String choice) {
                      if (choice == 'Edit') {
                        _navigateToEditAlarmPage(index);
                      } else if (choice == 'Delete') {
                        _removeReminder(index);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem(value: 'Edit', child: Text('Edit')),
                      PopupMenuItem(value: 'Delete', child: Text('Delete')),
                    ],
                    icon: Icon(Icons.more_vert),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
