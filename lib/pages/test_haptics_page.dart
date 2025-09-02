import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import 'package:flutter/foundation.dart';

class TestHapticsPage extends StatelessWidget {
  const TestHapticsPage({super.key});

  Future<void> _checkAndRunVib(int ms) async {
  debugPrint('TestHapticsPage: delegating vibrate($ms) to HapticService');
  await HapticService.instance.vibrate(ms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Haptics test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                debugPrint('TestHapticsPage: Calling HapticService.selection() enabled=${HapticService.instance.enabled}');
                HapticService.instance.selection();
              },
              child: const Text('Haptic selection'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                debugPrint('TestHapticsPage: Calling HapticService.lightImpact() enabled=${HapticService.instance.enabled}');
                HapticService.instance.lightImpact();
              },
              child: const Text('Haptic lightImpact'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                    debugPrint('TestHapticsPage: Calling HapticService.heavyImpactWithVibration() enabled=${HapticService.instance.enabled}');
                    HapticService.instance.heavyImpactWithVibration();
                    _checkAndRunVib(300);
                },
              child: const Text('Haptic heavy + vibration 300ms'),
            ),
            const SizedBox(height: 24),
            const Text('Open device keyboard or use system navigation to compare system haptics.'),
          ],
        ),
      ),
    );
  }
}
