import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'lead_model.dart';
import 'database_service.dart';
import 'lead_detail_screen.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static Timer? _followUpTimer;
  static OverlayEntry? _currentOverlay;
  static BuildContext? _context;
  static Set<String> _notifiedFollowUps = {};
  static bool _overlayEnabled = true;

  static Future<void> initialize(BuildContext context) async {
    _context = context;

    // Load overlay preference
    await _loadOverlayPreference();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Request notification permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Notification permission granted');
      await _setupNotifications();
      _startPreciseFollowUpChecker();
    } else {
      print('Notification permission denied');
    }
  }

  static Future<void> _loadOverlayPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _overlayEnabled = prefs.getBool('overlay_notifications_enabled') ?? true;
  }

  static Future<void> setOverlayEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('overlay_notifications_enabled', enabled);
    _overlayEnabled = enabled;
  }

  static bool get overlayEnabled => _overlayEnabled;

  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create high priority notification channel for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'follow_up_urgent_channel',
        'Urgent Follow-up Reminders',
        description: 'High priority notifications for follow-up reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  static Future<void> _setupNotifications() async {
    String? token = await _messaging.getToken();
    print('FCM Token: $token');

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground FCM message received');
      if (message.notification != null) {
        _handleIncomingNotification(
          title: message.notification!.title ?? 'Follow-up Reminder',
          body: message.notification!.body ?? 'You have a pending follow-up',
          followUpId: message.data['followUpId'] ?? '',
          leadId: message.data['leadId'] ?? '',
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap({
        'leadId': message.data['leadId'],
        'followUpId': message.data['followUpId'],
      });
    });

    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap({
        'leadId': initialMessage.data['leadId'],
        'followUpId': initialMessage.data['followUpId'],
      });
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("Background FCM message: ${message.messageId}");
  }

  static void _startPreciseFollowUpChecker() {
    // Check every 10 seconds for maximum precision
    _followUpTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkExactFollowUpTiming();
    });

    // Also schedule local notifications for when app is closed
    _scheduleLocalNotificationsForAllFollowUps();
  }

  static Future<void> _scheduleLocalNotificationsForAllFollowUps() async {
    try {
      // Cancel all existing scheduled notifications
      await _localNotifications.cancelAll();

      // Get all pending follow-ups and schedule them
      final followUpsStream = DatabaseService.getPendingFollowUps();

      followUpsStream.listen((followUps) async {
        for (final followUp in followUps) {
          final lead = await DatabaseService.getLead(followUp.leadId);
          if (lead != null) {
            await _scheduleExactNotification(
              id: followUp.id.hashCode,
              scheduledDate: followUp.scheduledAt,
              title: '${lead.name} - Follow-up Due',
              body: followUp.title,
              payload: '${followUp.leadId}|${followUp.id}',
            );
          }
        }
      });
    } catch (e) {
      print('Error scheduling notifications: $e');
    }
  }

  static Future<void> _scheduleExactNotification({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'follow_up_urgent_channel',
        'Urgent Follow-up Reminders',
        channelDescription: 'High priority notifications for follow-up reminders',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        autoCancel: false,
        ongoing: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'call_action',
            'Call Now',
            icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'open_action',
            'Open Lead',
            showsUserInterface: true,
          ),
        ],
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);

      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('📅 Scheduled notification with actions for: $scheduledDate');
    } catch (e) {
      print('Error scheduling individual notification: $e');
    }
  }

  static Future<void> _checkExactFollowUpTiming() async {
    try {
      final now = DateTime.now();

      // Get pending follow-ups
      final followUpsStream = DatabaseService.getPendingFollowUps();

      followUpsStream.listen((followUps) {
        for (final followUp in followUps) {
          // Skip if already notified
          if (_notifiedFollowUps.contains(followUp.id)) continue;

          // Calculate exact time difference in seconds
          final timeDiffInSeconds = followUp.scheduledAt.difference(now).inSeconds;

          // Trigger exactly at scheduled time (within 10 second window)
          if (timeDiffInSeconds <= 10 && timeDiffInSeconds >= -5) {
            print('🔔 EXACT TIME REACHED! Follow-up: ${followUp.title}');
            print('📅 Scheduled: ${followUp.scheduledAt}');
            print('🕐 Current: $now');
            print('⏱️ Difference: ${timeDiffInSeconds} seconds');

            _triggerFollowUpNotification(followUp);
            _notifiedFollowUps.add(followUp.id);
          }
        }
      });
    } catch (e) {
      print('Error checking follow-up timing: $e');
    }
  }

  static Future<void> _triggerFollowUpNotification(FollowUp followUp) async {
    final lead = await DatabaseService.getLead(followUp.leadId);
    if (lead == null) return;

    final title = '${lead.name} - Follow-up Due';
    final body = followUp.title;

    // Always send system notification (for when app is closed)
    await _sendSystemNotification(
      title: title,
      body: body,
      payload: '${followUp.leadId}|${followUp.id}',
    );

    // Show overlay or beep based on user preference
    if (_overlayEnabled && _context != null) {
      // Show Truecaller-style overlay
      _showTruecallerOverlay(
        title: title,
        body: body,
        followUpId: followUp.id,
        leadId: followUp.leadId,
      );
    } else {
      // Just play notification sound/vibration
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
  }

  static Future<void> _sendSystemNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'follow_up_urgent_channel',
        'Urgent Follow-up Reminders',
        channelDescription: 'High priority notifications for follow-up reminders',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        autoCancel: false,
        ongoing: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'call_action',
            'Call Now',
            icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'open_action',
            'Open Lead',
            showsUserInterface: true,
          ),
        ],
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      print('📱 System notification with actions sent: $title');
    } catch (e) {
      print('❌ Error sending system notification: $e');
    }
  }

  static void _showTruecallerOverlay({
    required String title,
    required String body,
    required String followUpId,
    required String leadId,
  }) {
    if (_context == null) return;

    // Dismiss any existing overlay
    _dismissOverlay();

    // Heavy haptic feedback like Truecaller
    HapticFeedback.heavyImpact();

    _currentOverlay = OverlayEntry(
      builder: (context) => TruecallerStyleOverlay(
        title: title,
        body: body,
        followUpId: followUpId,
        leadId: leadId,
        onDismiss: _dismissOverlay,
        onAnswer: () => _handleAnswerCall(leadId),
        onDecline: () => _handleDeclineCall(followUpId),
      ),
    );

    Overlay.of(_context!).insert(_currentOverlay!);

    print('📞 Truecaller overlay shown');
  }

  static void _dismissOverlay() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  static Future<void> _handleAnswerCall(String leadId) async {
    _dismissOverlay();

    final lead = await DatabaseService.getLead(leadId);
    if (lead != null && _context != null) {
      // Add remark that user clicked call
      await DatabaseService.addRemark(
        leadId: leadId,
        content: 'Follow-up call initiated from notification',
        type: RemarkType.note,
      );

      // Make direct phone call
      await _makePhoneCall(lead.mobile);

      // Also navigate to lead details
      Navigator.of(_context!).push(
        MaterialPageRoute(
          builder: (context) => LeadDetailScreen(lead: lead),
        ),
      );
    }
  }

  static Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        print('📞 Calling: $phoneNumber');
      } else {
        print('❌ Cannot make call to: $phoneNumber');
      }
    } catch (e) {
      print('Error making phone call: $e');
    }
  }

  static Future<void> _handleDeclineCall(String followUpId) async {
    _dismissOverlay();

    // Show snooze options
    if (_context != null) {
      _showQuickSnoozeDialog(followUpId);
    }
  }

  static void _handleIncomingNotification({
    required String title,
    required String body,
    required String followUpId,
    required String leadId,
  }) {
    if (_overlayEnabled) {
      _showTruecallerOverlay(
        title: title,
        body: body,
        followUpId: followUpId,
        leadId: leadId,
      );
    } else {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;

    print('📱 Notification action: $actionId, payload: $payload');

    if (payload != null) {
      final parts = payload.split('|');
      if (parts.length == 2) {
        final leadId = parts[0];
        final followUpId = parts[1];

        if (actionId == 'call_action') {
          // Handle call action
          _handleCallAction(leadId);
        } else if (actionId == 'open_action') {
          // Handle open lead action
          _handleNotificationTap({
            'leadId': leadId,
            'followUpId': followUpId,
          });
        } else {
          // Default tap (no action button)
          _handleNotificationTap({
            'leadId': leadId,
            'followUpId': followUpId,
          });
        }
      }
    }
  }

  static Future<void> _handleCallAction(String leadId) async {
    try {
      final lead = await DatabaseService.getLead(leadId);
      if (lead != null && lead.mobile.isNotEmpty) {
        // Add remark that user clicked call from notification
        await DatabaseService.addRemark(
          leadId: leadId,
          content: 'Follow-up call initiated from notification',
          type: RemarkType.note,
        );

        // Make direct phone call
        await _makePhoneCall(lead.mobile);

        print('📞 Call initiated from notification for: ${lead.mobile}');
      }
    } catch (e) {
      print('Error handling call action: $e');
    }
  }

  static Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    if (_context == null) return;

    final leadId = data['leadId'];
    if (leadId != null) {
      final lead = await DatabaseService.getLead(leadId);
      if (lead != null) {
        Navigator.of(_context!).push(
          MaterialPageRoute(
            builder: (context) => LeadDetailScreen(lead: lead),
          ),
        );
      }
    }
  }

  static Future<void> _showQuickSnoozeDialog(String followUpId) async {
    if (_context == null) return;

    final result = await showDialog<String>(
      context: _context!,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Snooze Follow-up'),
        content: const Text('When would you like to be reminded again?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, '15min'),
            child: const Text('15 minutes'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, '1hour'),
            child: const Text('1 hour'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'tomorrow'),
            child: const Text('Tomorrow'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'dismiss'),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    if (result != null && result != 'dismiss') {
      await _handleSnoozeAction(followUpId, result);
    }
  }

  static Future<void> _handleSnoozeAction(String followUpId, String action) async {
    try {
      DateTime? newTime;

      switch (action) {
        case '15min':
          newTime = DateTime.now().add(const Duration(minutes: 15));
          break;
        case '1hour':
          newTime = DateTime.now().add(const Duration(hours: 1));
          break;
        case 'tomorrow':
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          newTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
          break;
      }

      if (newTime != null) {
        await DatabaseService.snoozeFollowUp(followUpId, newTime);
        _notifiedFollowUps.remove(followUpId);
        print('⏰ Follow-up snoozed to: $newTime');
      }
    } catch (e) {
      print('Error snoozing follow-up: $e');
    }
  }

  static void dispose() {
    _followUpTimer?.cancel();
    _dismissOverlay();
    _notifiedFollowUps.clear();
  }
}

class TruecallerStyleOverlay extends StatefulWidget {
  final String title;
  final String body;
  final String followUpId;
  final String leadId;
  final VoidCallback onDismiss;
  final VoidCallback onAnswer;
  final VoidCallback onDecline;

  const TruecallerStyleOverlay({
    super.key,
    required this.title,
    required this.body,
    required this.followUpId,
    required this.leadId,
    required this.onDismiss,
    required this.onAnswer,
    required this.onDecline,
  });

  @override
  State<TruecallerStyleOverlay> createState() => _TruecallerStyleOverlayState();
}

class _TruecallerStyleOverlayState extends State<TruecallerStyleOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200), // Much faster
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800), // Slower pulse
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1), // Minimal slide
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut, // Simple curve
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05, // Subtle pulse
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
    _pulseController.repeat(reverse: true);

    // Auto dismiss after 30 seconds
    Timer(const Duration(seconds: 30), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1a1a1a),
                  Color(0xFF2d2d2d),
                ],
              ),
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildContent()),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Text(
            'Follow-up Reminder',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onDismiss,
            icon: const Icon(
              Icons.close,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF74B9FF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            widget.body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Text(
            'Tap call to dial directly',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Decline/Snooze Button
          GestureDetector(
            onTap: widget.onDecline,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.snooze_rounded,
                color: Colors.white,
                size: 35,
              ),
            ),
          ),
          // Answer/Call Button
          GestureDetector(
            onTap: widget.onAnswer,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.phone_rounded,
                color: Colors.white,
                size: 35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}