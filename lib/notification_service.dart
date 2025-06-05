import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'lead_model.dart';
import 'database_service.dart';
import 'lead_detail_screen.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static Timer? _followUpTimer;
  static OverlayEntry? _currentOverlay;
  static BuildContext? _context;
  static Set<String> _notifiedFollowUps = {};

  static Future<void> initialize(BuildContext context) async {
    _context = context;

    // Request permission for notifications
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
      print('User granted permission');
      await _setupNotifications();
      _startFollowUpChecker();
    } else {
      print('User declined or has not accepted permission');
    }
  }

  static Future<void> _setupNotifications() async {
    // Get FCM token
    String? token = await _messaging.getToken();
    print('FCM Token: $token');

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showSimpleFloatingNotification(
          title: message.notification!.title ?? 'Follow-up Reminder',
          body: message.notification!.body ?? 'You have a pending follow-up',
          data: message.data,
        );
      }
    });

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      _handleNotificationTap(message.data);
    });

    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data);
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("Handling a background message: ${message.messageId}");
  }

  static void _startFollowUpChecker() {
    // Check for due follow-ups every 30 seconds
    _followUpTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkDueFollowUps();
    });
  }

  static Future<void> _checkDueFollowUps() async {
    try {
      final now = DateTime.now();

      // Get pending follow-ups
      final followUpsStream = DatabaseService.getPendingFollowUps();

      followUpsStream.listen((followUps) {
        for (final followUp in followUps) {
          // Skip if already notified for this follow-up
          if (_notifiedFollowUps.contains(followUp.id)) continue;

          final timeDiff = followUp.scheduledAt.difference(now).inMinutes;

          // Show notification if follow-up is due (within 5 minutes or overdue)
          if (timeDiff <= 5 && timeDiff >= -30) {
            _showFollowUpNotification(followUp);
            _notifiedFollowUps.add(followUp.id); // Mark as notified
          }
        }
      });
    } catch (e) {
      print('Error checking due follow-ups: $e');
    }
  }

  static Future<void> _showFollowUpNotification(FollowUp followUp) async {
    if (_context == null) return;

    // Get lead details
    final lead = await DatabaseService.getLead(followUp.leadId);
    if (lead == null) return;

    final title = '${lead.name} - Follow-up Due';
    final body = followUp.title;

    _showSimpleFloatingNotification(
      title: title,
      body: body,
      data: {
        'type': 'follow_up',
        'followUpId': followUp.id,
        'leadId': followUp.leadId,
      },
    );
  }

  static void _showSimpleFloatingNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    if (_context == null) return;

    // Dismiss any existing overlay
    _dismissCurrentOverlay();

    _currentOverlay = OverlayEntry(
      builder: (context) => SimpleFloatingNotification(
        title: title,
        body: body,
        data: data,
        onDismiss: _dismissCurrentOverlay,
        onTap: () => _handleNotificationTap(data),
      ),
    );

    Overlay.of(_context!).insert(_currentOverlay!);

    // Auto dismiss after 8 seconds
    Timer(const Duration(seconds: 8), () {
      _dismissCurrentOverlay();
    });
  }

  static void _dismissCurrentOverlay() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  static Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    if (_context == null) return;

    _dismissCurrentOverlay();

    final type = data['type'];

    if (type == 'follow_up') {
      final leadId = data['leadId'];
      final followUpId = data['followUpId'];

      if (leadId != null) {
        final lead = await DatabaseService.getLead(leadId);
        if (lead != null) {
          Navigator.of(_context!).push(
            MaterialPageRoute(
              builder: (context) => LeadDetailScreen(lead: lead),
            ),
          );

          // Show quick action dialog if followUpId is provided
          if (followUpId != null) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _showQuickActionDialog(_context!, followUpId);
            });
          }
        }
      }
    }
  }

  static Future<void> _showQuickActionDialog(BuildContext context, String followUpId) async {
    HapticFeedback.lightImpact();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.schedule_rounded, color: Color(0xFF6C5CE7)),
            SizedBox(width: 8),
            Text('Follow-up Action'),
          ],
        ),
        content: Text('What would you like to do with this follow-up?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'dismiss'),
            child: Text('Dismiss'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'snooze_1h'),
            child: Text('Snooze 1h'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'snooze_tomorrow'),
            child: Text('Tomorrow'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'mark_done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
            ),
            child: Text('Mark Done'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _handleSnoozeAction(context, followUpId, result);
    }
  }

  static Future<void> _handleSnoozeAction(
      BuildContext context,
      String followUpId,
      String action,
      ) async {
    try {
      DateTime? newTime;

      switch (action) {
        case 'snooze_1h':
          newTime = DateTime.now().add(const Duration(hours: 1));
          break;
        case 'snooze_tomorrow':
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          newTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
          break;
        case 'mark_done':
          await DatabaseService.completeFollowUp(followUpId, 'Completed from notification');
          _notifiedFollowUps.remove(followUpId); // Remove from notified set
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Follow-up marked as completed'),
              backgroundColor: Color(0xFF84D187),
            ),
          );
          return;
        case 'dismiss':
          return;
      }

      if (newTime != null) {
        await DatabaseService.snoozeFollowUp(followUpId, newTime);
        _notifiedFollowUps.remove(followUpId); // Remove from notified set

        final timeString = action == 'snooze_1h'
            ? '1 hour'
            : 'tomorrow at 9:00 AM';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Follow-up snoozed for $timeString'),
            backgroundColor: const Color(0xFF74B9FF),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  static void dispose() {
    _followUpTimer?.cancel();
    _dismissCurrentOverlay();
    _notifiedFollowUps.clear();
  }
}

class SimpleFloatingNotification extends StatefulWidget {
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const SimpleFloatingNotification({
    super.key,
    required this.title,
    required this.body,
    required this.data,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<SimpleFloatingNotification> createState() => _SimpleFloatingNotificationState();
}

class _SimpleFloatingNotificationState extends State<SimpleFloatingNotification>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start entrance animation
    _slideController.forward();

    // Add haptic feedback
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap();
  }

  void _handleDismiss() {
    _slideController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          shadowColor: Colors.black.withOpacity(0.2),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: InkWell(
              onTap: _handleTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.body,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _handleDismiss,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}