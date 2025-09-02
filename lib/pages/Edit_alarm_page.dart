import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditAlarmPage extends StatefulWidget {
  final Map<String, dynamic> alarm;

  const EditAlarmPage({super.key, required this.alarm});

  @override
  _EditAlarmPageState createState() => _EditAlarmPageState();
}

class _EditAlarmPageState extends State<EditAlarmPage> {
  late int _selectedHour;
  late int _selectedMinute;
  late bool _snoozeEnabled;
  late int _snoozeDuration;
  late String _label;
  late String _ringtone;
  late String _repeatInterval;
  late bool _noStop;
  TimeOfDay? _customEndTime;
  TimeOfDay? _dndStartTime;
  TimeOfDay? _dndEndTime;
  late int _customRepeatMinutes;
  late String _alarmType;
  late int _alarmId;
  File? _alarmImage;
  final ImagePicker _picker = ImagePicker();

  final List<int> hours = List.generate(24, (index) => index);
  final List<int> minutes = List.generate(60, (index) => index);
  final List<String> repeatOptions = ["No Repeat", "1 Hour", "2 Hours", "3 Hours", "4 Hours", "Custom Time"];
  final List<String> alarmTypes = ["Standard", "Medication"];
  final List<int> snoozeDurations = [5, 10, 15, 20, 30]; // Snooze duration options in minutes
  final List<Map<String, String>> preloadedRingtones = [
    {"name": "Loud", "path": "assets/ringtones/ringtone_1.mp3", "raw": "ringtone_1"},
    {"name": "Gentle Wake", "path": "assets/ringtones/ringtone_2.mp3", "raw": "ringtone_2"},
    {"name": "Ocean Waves", "path": "assets/ringtones/ringtone_3.mp3", "raw": "ringtone_3"},
  ];

  @override
  void initState() {
    super.initState();

    final alarm = widget.alarm;
    final timeParts = (alarm['time'] as String).split(":");
    _selectedHour = int.tryParse(timeParts[0]) ?? 0;
    _selectedMinute = int.tryParse(timeParts[1]) ?? 0;
    _snoozeEnabled = alarm['snooze'] ?? false;
    _snoozeDuration = alarm['snooze_duration'] ?? 5;
    _label = alarm['label'] ?? "Alarm";
    _ringtone = alarm['ringtone'] ?? "Default";
    _repeatInterval = alarm['repeat'] ?? "No Repeat";
    _customRepeatMinutes = alarm['custom_time'] ?? 60;
    _noStop = alarm['stop_condition'] == "No Stop (24hr)";
    _alarmType = alarm['type'] ?? "Standard";
    _alarmId = widget.alarm["id"] ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
    
    // Load existing image if any
    if (alarm['image_path'] != null) {
      _alarmImage = File(alarm['image_path']);
    }

    // Safe parsing for Medication optional fields
    _customEndTime = _parseTime(alarm['stop_condition']);
    _dndStartTime = _parseTime(alarm['dnd_start']);
    _dndEndTime = _parseTime(alarm['dnd_end']);
  }

  TimeOfDay? _parseTime(dynamic timeStr) {
    if (timeStr == null || timeStr == "Normal" || timeStr == "No Stop (24hr)") return null;
    if (timeStr is! String || !timeStr.contains(":")) return null;
    final parts = timeStr.split(":");
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

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
      builder: (context) => AlertDialog(
        title: Text("Select Ringtone"),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: preloadedRingtones.map((ringtone) {
            return ListTile(
              title: Text(ringtone['name']!),
              onTap: () {
                setState(() {
                  _ringtone = ringtone['raw']!;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _editLabel() {
    TextEditingController labelController = TextEditingController(text: _label);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Label"),
        content: TextField(
          controller: labelController,
          decoration: InputDecoration(labelText: "Alarm Label"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          TextButton(
            onPressed: () {
              setState(() => _label = labelController.text.trim());
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
  if (picked != null) { HapticService.instance.selection(); setState(() => onSelected(picked)); }
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
  HapticService.instance.selection();
        setState(() {
          _alarmImage = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _saveEditedAlarm() {
    final isMedication = _alarmType == "Medication";
    final safeRepeat = isMedication ? (_repeatInterval.isNotEmpty ? _repeatInterval : "No Repeat") : "No Repeat";
    final safeCustomTime = (isMedication && _repeatInterval == "Custom Time") ? _customRepeatMinutes : 60;
    final safeStopCondition = isMedication
        ? (_noStop ? "No Stop (24hr)" : _customEndTime?.format(context) ?? "Normal")
        : "Normal";
    final safeDndStart = isMedication && _dndStartTime != null ? _dndStartTime!.format(context) : null;
    final safeDndEnd = isMedication && _dndEndTime != null ? _dndEndTime!.format(context) : null;

    Map<String, dynamic> updatedAlarm = {
      "id": _alarmId,
      "type": _alarmType,
      "time": "${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}",
      "label": _label.isNotEmpty ? _label : "Alarm",
      "ringtone": _ringtone.isNotEmpty ? _ringtone : "Default",
      "repeat": safeRepeat,
      "custom_time": safeCustomTime,
      "stop_condition": safeStopCondition,
      "dnd_start": safeDndStart,
      "dnd_end": safeDndEnd,
      "snooze": _snoozeEnabled,
      "snooze_duration": _snoozeDuration,
      "image_path": _alarmImage?.path,
      "active": true,
    };

    print("Updated Alarm: $updatedAlarm");
    Navigator.pop(context, updatedAlarm);
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
        title: Text("Edit Alarm"),
        backgroundColor: Color.fromARGB(255, 250, 250, 250),
        actions: [
          TextButton(
            onPressed: () { HapticService.instance.lightImpact(); _saveEditedAlarm(); },
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

          // Image Selection
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
                  onPressed: () { HapticService.instance.selection(); _pickImage(); },
                ),
              ],
            ),
          ),

          if (_alarmType == "Medication") ...[
            ListTile(title: Text("Label"), subtitle: Text(_label), trailing: Icon(Icons.edit), onTap: () { HapticService.instance.selection(); _editLabel(); }),
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
                onTap: () { HapticService.instance.selection(); setState(() => _customRepeatMinutes += 5); },
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
            ListTile(title: Text("Do Not Disturb Mode")),
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
            onTap: () { HapticService.instance.selection(); _pickRingtone(); },
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
