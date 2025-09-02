import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Listens for admin updates to emergencyStatus for the current user
/// and surfaces them as local notifications while the app is in use.
class PushListenerService {
  PushListenerService._();

  static final PushListenerService _instance = PushListenerService._();
  static PushListenerService get instance => _instance;

  StreamSubscription<QuerySnapshot>? _subscription;
  String? _listeningForUserId;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Idempotently start listening for a given userId.
  Future<void> start(String userId) async {
    if (_listeningForUserId == userId && _subscription != null) {
      return;
    }
    await stop();

    _listeningForUserId = userId;

    // Ensure local notifications are initialized (safe to call multiple times)
    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: initAndroid,
    );
    await _localNotifications.initialize(initSettings);

    // Optional: define a basic Android channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'emergency_status_channel',
      'Emergency Status Updates',
      description: 'Notifies you when admins update your emergency status',
      importance: Importance.high,
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    // Listen to this user's notifications documents
    _subscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(_handleSnapshot, onError: (_) {});
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _listeningForUserId = null;
  }

  Future<void> _handleSnapshot(QuerySnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.modified) continue;

      final doc = change.doc;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final String? newStatus = _asString(data['emergencyStatus']);
      if (newStatus == null || newStatus.trim().isEmpty) continue;

      final String cacheKey = 'lastStatus_${doc.id}';
      final String lastStatus = prefs.getString(cacheKey) ?? '';
      if (lastStatus == newStatus) {
        // No status change since we last saw it
        continue;
      }

      // Persist latest to avoid duplicate notifications
      await prefs.setString(cacheKey, newStatus);

      final String title = 'Emergency status updated';
      final String body = 'Status is now: $newStatus';

      await _localNotifications.show(
        // Use a stable id derived from doc id hashCode to avoid stacking endlessly
        doc.id.hashCode.abs(),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'emergency_status_channel',
            'Emergency Status Updates',
            channelDescription:
                'Notifies you when admins update your emergency status',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }
}


