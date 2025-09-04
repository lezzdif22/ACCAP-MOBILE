import 'package:flutter/material.dart';
import '../services/haptic_service.dart';

void main() => runApp(MaterialApp(home: HapticTestPage()));

class HapticTestPage extends StatelessWidget {
  const HapticTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Haptic Test')),
      body: Center(
        child: ElevatedButton(
          child: Text('Test Haptics & Vibration'),
            onPressed: () async {
            HapticService.instance.buttonPress();
            await Future.delayed(Duration(milliseconds: 300));
            HapticService.instance.buttonPress();
            await Future.delayed(Duration(milliseconds: 300));
            HapticService.instance.heavyImpactWithVibration();
            await Future.delayed(Duration(milliseconds: 300));
            await HapticService.instance.vibrate(500);
          },
        ),
      ),
    );
  }
}