import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AddAlarmPage extends StatefulWidget {
  const AddAlarmPage({super.key});

  @override
  _AddAlarmPageState createState() => _AddAlarmPageState();
}

class _AddAlarmPageState extends State<AddAlarmPage> {
  int _selectedHour = 0;
  int _selectedMinute = 0;
  bool _snoozeEnabled = false;
  int _snoozeDuration = 5; // Default 5 minutes
  String _label = "Alarm";
  String _ringtone = "Default";
  String _repeatInterval = "No Repeat";
  bool _noStop = false;
  TimeOfDay? _customEndTime;
  TimeOfDay? _dndStartTime;
  TimeOfDay? _dndEndTime;
  int _customRepeatMinutes = 60;
  String _alarmType = "Standard"; // Standard or Medication
  File? _alarmImage;
  final ImagePicker _picker = ImagePicker();

  List<int> hours = List.generate(24, (index) => index);
  List<int> minutes = List.generate(60, (index) => index);
  final List<String> repeatOptions = [
    "No Repeat", "1 Hour", "2 Hours", "3 Hours", "4 Hours", "Custom Time"
  ];
  final List<String> alarmTypes = ["Standard", "Medication"];
  final List<int> snoozeDurations = [5, 10, 15, 20, 30]; // Snooze duration options in minutes
final List<Map<String, String>> preloadedRingtones = [
  {
    "name": "Loud",
    "path": "assets/ringtones/ringtone_1.mp3",
    "raw": "ringtone_1",
  },
  {
    "name": "Galaxy Waves",
    "path": "assets/ringtones/ringtone_2.mp3",
    "raw": "ringtone_2",
  },
  {
    "name": "Morning Sun",
    "path": "assets/ringtones/ringtone_3.mp3",
    "raw": "ringtone_3",
  },
];


String getSelectedRingtoneName() {
  final match = preloadedRingtones.firstWhere(
    (r) => r['raw'] == _ringtone,
    orElse: () => {"name": "Default"},
  );
  return match['name']!;
}

void _pickRingtone() {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text("Select Ringtone"),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: preloadedRingtones.map((ringtone) {
            return ListTile(
              title: Text(ringtone['name']!),
              onTap: () {
                setState(() {
                  // Save the raw name so it can be used by the notification later
                  _ringtone = ringtone['raw']!;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      );
    },
  );
}

  void _editLabel() {
    TextEditingController labelController = TextEditingController(text: _label);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Label"),
        content: TextField(controller: labelController, decoration: InputDecoration(labelText: "Alarm Label")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          TextButton(
            onPressed: () {
              setState(() => _label = labelController.text);
              Navigator.pop(context);
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, Function(TimeOfDay) onSelected) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color.fromARGB(255, 255, 255, 250),
              dialBackgroundColor: Color.fromARGB(255, 0, 48, 96),
              dialHandColor: Colors.black,
              hourMinuteColor: Color.fromARGB(255, 250, 250, 250),
              hourMinuteTextColor: Color.fromARGB(255, 0, 48, 96),
              hourMinuteTextStyle: const TextStyle(
                color: Color.fromARGB(255, 0, 48, 96),
                fontSize: 24,
              ),
              dialTextColor: Colors.white,
              dayPeriodColor: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.black
                  : Colors.white),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.white
                  : Colors.black),
              entryModeIconColor: Colors.black,
              helpTextStyle: const TextStyle(color: Colors.black),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => onSelected(picked));
  }

  Future<String?> _copyImageToLocalStorage(String sourcePath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'alarm_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destinationPath = path.join(directory.path, fileName);
      
      // Copy the file
      await File(sourcePath).copy(destinationPath);
      print('Image copied to: $destinationPath');
      return destinationPath;
    } catch (e) {
      print('Error copying image: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        final localPath = await _copyImageToLocalStorage(image.path);
        if (localPath != null) {
          setState(() {
            _alarmImage = File(localPath);
          });
          print('Image saved to local storage: $localPath');
        }
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

void _saveAlarm() {
  int alarmId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

  // Set fallback values for Medication alarms
  final isMedication = _alarmType == "Medication";
  final safeRepeat = isMedication ? (_repeatInterval.isNotEmpty ? _repeatInterval : "No Repeat") : "No Repeat";
  final safeCustomTime = (isMedication && _repeatInterval == "Custom Time") ? _customRepeatMinutes : 60;
  final safeStopCondition = isMedication
      ? (_noStop ? "No Stop (24hr)" : _customEndTime?.format(context) ?? "Normal")
      : "Normal";
 final safeDndStart = isMedication && _dndStartTime != null 
    ? _dndStartTime!.format(context) 
    : null;
final safeDndEnd = isMedication && _dndEndTime != null 
    ? _dndEndTime!.format(context) 
    : null;

  // Ensure we have a valid image path
  String? imagePath = _alarmImage?.path;
  if (imagePath != null) {
    print('Saving alarm with image path: $imagePath');
  }

  Map<String, dynamic> newAlarm = {
    "id": alarmId,
    "type": _alarmType,
    "time": "${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}",
    "label": _label,
    "ringtone": _ringtone.isNotEmpty ? _ringtone : "Default",
    "repeat": safeRepeat,
    "custom_time": safeCustomTime,
    "stop_condition": safeStopCondition,
    "dnd_start": safeDndStart,
    "dnd_end": safeDndEnd,
    "snooze": _snoozeEnabled,
    "snooze_duration": _snoozeDuration,
    "image_path": imagePath,
    "active": true,
  };

  Navigator.pop(context, newAlarm);
}

  Widget _buildTimePicker() {
    return SizedBox(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPicker(hours, (value) => setState(() => _selectedHour = value), _selectedHour),
          Text(":", style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold)),
          _buildPicker(minutes, (value) => setState(() => _selectedMinute = value), _selectedMinute),
        ],
      ),
    );
  }

  Widget _buildPicker(List<int> values, Function(int) onSelected, int selectedValue) {
    return SizedBox(
      width: 100,
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(initialItem: selectedValue),
        itemExtent: 50,
        onSelectedItemChanged: onSelected,
        children: values.map((value) => Center(child: Text(value.toString().padLeft(2, '0'), style: TextStyle(fontSize: 24)))).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(
        title: Text("Add Alarm"),
        backgroundColor: Color.fromARGB(255, 250, 250, 250),
        actions: [
          TextButton(
            onPressed: _saveAlarm,
            child: Text("Save", style: TextStyle(color: Colors.orange, fontSize: 18)),
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildTimePicker(),
          Divider(),
          ListTile(
            title: Text("Alarm Type"),
            subtitle: Text(_alarmType),
            trailing: DropdownButton<String>(
              dropdownColor: Color.fromARGB(255, 250, 250, 250),
              value: _alarmType,
              items: alarmTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _alarmType = val!),
            ),
          ),
          ListTile(
            title: Text("Alarm Image"),
            subtitle: Text(_alarmType == "Medication" ? "Add medicine image" : "Add custom image"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_alarmImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _alarmImage!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: Icon(Icons.error_outline, color: Colors.grey[600]),
                        );
                      },
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.add_photo_alternate),
                  onPressed: _pickImage,
                ),
              ],
            ),
          ),

          if (_alarmType == "Medication") ...[
            ListTile(
              title: Text("Label"),
              subtitle: Text(_label),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: _editLabel,
            ),
            ListTile(
              title: Text("Repeat Interval"),
              subtitle: Text(_repeatInterval),
              trailing: DropdownButton<String>(
                dropdownColor: Color.fromARGB(255, 250, 250, 250),
                value: _repeatInterval,
                items: repeatOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _repeatInterval = val!),
              ),
            ),
            if (_repeatInterval == "Custom Time")
              ListTile(
                title: Text("Custom Repeat Time"),
                subtitle: Text("Every $_customRepeatMinutes minutes"),
                trailing: Icon(Icons.timer),
                onTap: () => setState(() => _customRepeatMinutes += 5),
              ),
            SwitchListTile(
              title: Text("No Stop (24hr)"),
              value: _noStop,
              onChanged: (val) => setState(() => _noStop = val),
            ),
            if (!_noStop)
              ListTile(
                title: Text("Custom Stop Time"),
                subtitle: Text(_customEndTime?.format(context) ?? "Not Set"),
                trailing: Icon(Icons.timer),
                onTap: () => _pickTime(context, (time) => setState(() => _customEndTime = time)),
              ),
            ListTile(
              title: Text("Do Not Disturb Mode"),
            ),
            ListTile(
              title: Text("Start Time"),
              subtitle: Text(_dndStartTime?.format(context) ?? "Not Set"),
              trailing: Icon(Icons.access_time),
              onTap: () => _pickTime(context, (time) => setState(() => _dndStartTime = time)),
            ),
            ListTile(
              title: Text("End Time"),
              subtitle: Text(_dndEndTime?.format(context) ?? "Not Set"),
              trailing: Icon(Icons.access_time),
              onTap: () => _pickTime(context, (time) => setState(() => _dndEndTime = time)),
            ),
          ],

        ListTile(
  title: Text("Ringtone"),
  subtitle: Text(getSelectedRingtoneName()),
  trailing: Icon(Icons.arrow_forward_ios),
  onTap: _pickRingtone,
),

          SwitchListTile(
            title: Text("Snooze"),
            value: _snoozeEnabled,
            onChanged: (val) => setState(() => _snoozeEnabled = val),
          ),
          if (_snoozeEnabled)
            ListTile(
              title: Text("Snooze Duration"),
              subtitle: Text("$_snoozeDuration minutes"),
              trailing: DropdownButton<int>(
                dropdownColor: Color.fromARGB(255, 250, 250, 250),
                value: _snoozeDuration,
                items: snoozeDurations.map((duration) => DropdownMenuItem(
                  value: duration,
                  child: Text("$duration minutes"),
                )).toList(),
                onChanged: (val) => setState(() => _snoozeDuration = val!),
              ),
            ),
        ],
      ),
    );
  }
}