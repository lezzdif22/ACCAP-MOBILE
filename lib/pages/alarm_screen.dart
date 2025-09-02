import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import 'dart:io';

class AlarmScreen extends StatefulWidget {
  final String alarmName;
  final String ringtone;
  final bool hasSnooze;
  final int snoozeDuration;
  final String? imagePath;
  final Function() onStop;
  final Function() onSnooze;

  const AlarmScreen({
    super.key,
    required this.alarmName,
    required this.ringtone,
    required this.hasSnooze,
    required this.snoozeDuration,
    this.imagePath,
    required this.onStop,
    required this.onSnooze,
  });

  @override
  _AlarmScreenState createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  double _dragDistance = 0;
  final bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _startVibration();
  }

  @override
  void dispose() {
    _controller.dispose();
    _stopVibration();
    super.dispose();
  }

  void _startVibration() async {
    await HapticService.instance.vibrate(1000, repeat: 1);
  }

  void _stopVibration() {
    HapticService.instance.cancel();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragDistance -= details.delta.dy;
      if (_dragDistance < 0) _dragDistance = 0;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragDistance > 200) {
      _controller.forward().then((_) {
        widget.onStop();
        Navigator.pop(context);
      });
    } else {
      setState(() {
        _dragDistance = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragUpdate: _handleDragUpdate,
        onVerticalDragEnd: _handleDragEnd,
        child: Stack(
          children: [
            // Background Image
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: widget.imagePath != null
                      ? FileImage(File(widget.imagePath!))
                      : AssetImage('assets/images/alarm_background.jpg') as ImageProvider,
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.5),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
            
            // Content
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top section with time
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 72,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.alarmName,
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom section with swipe instructions
                  Transform.translate(
                    offset: Offset(0, -_dragDistance),
                    child: Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.white,
                            size: 40,
                          ),
                          Text(
                            'Swipe up to stop',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          if (widget.hasSnooze) ...[
                            SizedBox(height: 20),
                            TextButton(
                              onPressed: () {
                                widget.onSnooze();
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Snooze (${widget.snoozeDuration}m)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 