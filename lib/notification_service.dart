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
        _showTruecallerStyleNotification(
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
    // Check for due follow-ups every minute
    _followUpTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
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
          final timeDiff = followUp.scheduledAt.difference(now).inMinutes;

          // Show notification if follow-up is due (within 2 minutes)
          if (timeDiff <= 2 && timeDiff >= -5) {
            _showFollowUpNotification(followUp);
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

    _showTruecallerStyleNotification(
      title: title,
      body: body,
      data: {
        'type': 'follow_up',
        'followUpId': followUp.id,
        'leadId': followUp.leadId,
      },
    );
  }

  static void _showTruecallerStyleNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    if (_context == null) return;

    // Dismiss any existing overlay
    _dismissCurrentOverlay();

    _currentOverlay = OverlayEntry(
      builder: (context) => TruecallerStyleNotification(
        title: title,
        body: body,
        data: data,
        onDismiss: _dismissCurrentOverlay,
        onTap: () => _handleNotificationTap(data),
      ),
    );

    Overlay.of(_context!).insert(_currentOverlay!);

    // Auto dismiss after 10 seconds
    Timer(const Duration(seconds: 10), () {
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

          // Show snooze dialog if followUpId is provided
          if (followUpId != null) {
            _showSnoozeDialog(_context!, followUpId);
          }
        }
      }
    }
  }

  static Future<void> _showSnoozeDialog(BuildContext context, String followUpId) async {
    HapticFeedback.lightImpact();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Follow-up Action'),
        content: const Text('What would you like to do with this follow-up?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'dismiss'),
            child: const Text('Dismiss'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'snooze_1h'),
            child: const Text('Snooze 1h'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'snooze_tomorrow'),
            child: const Text('Tomorrow'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'mark_done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Done'),
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
  }
}

class TruecallerStyleNotification extends StatefulWidget {
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const TruecallerStyleNotification({
    super.key,
    required this.title,
    required this.body,
    required this.data,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<TruecallerStyleNotification> createState() => _TruecallerStyleNotificationState();
}

class _TruecallerStyleNotificationState extends State<TruecallerStyleNotification>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    // Start entrance animation
    _slideController.forward();

    // Add haptic feedback
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
      widget.onTap();
    });
  }

  void _handleDismiss() {
    _slideController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            shadowColor: Colors.black.withOpacity(0.3),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6C5CE7),
                    Color(0xFF74B9FF),
                  ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: _handleTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF6C5CE7),
                                  Color(0xFF74B9FF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.schedule_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.body,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 32,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            // Show snooze options
                                            _showSnoozeOptions();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF74B9FF),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                          child: const Text(
                                            'Snooze',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        height: 32,
                                        child: ElevatedButton(
                                          onPressed: _handleTap,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF6C5CE7),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                          child: const Text(
                                            'Open Lead',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _handleDismiss,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
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
          ),
        ),
      ),
    );
  }

  void _showSnoozeOptions() {
    final followUpId = widget.data['followUpId'];
    if (followUpId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Snooze Follow-up',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildSnoozeOption('15 minutes', () {
              Navigator.pop(context);
              _snoozeFollowUp(followUpId, Duration(minutes: 15));
            }),
            _buildSnoozeOption('1 hour', () {
              Navigator.pop(context);
              _snoozeFollowUp(followUpId, Duration(hours: 1));
            }),
            _buildSnoozeOption('Tomorrow 9 AM', () {
              Navigator.pop(context);
              final tomorrow = DateTime.now().add(Duration(days: 1));
              final snoozeTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
              _snoozeFollowUpToTime(followUpId, snoozeTime);
            }),
            _buildSnoozeOption('Custom time', () {
              Navigator.pop(context);
              _showCustomSnoozeDialog(followUpId);
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSnoozeOption(String title, VoidCallback onTap) {
    return ListTile(
      title: Text(title),
      leading: const Icon(Icons.schedule_rounded, color: Color(0xFF6C5CE7)),
      onTap: onTap,
    );
  }

  void _snoozeFollowUp(String followUpId, Duration duration) {
    final newTime = DateTime.now().add(duration);
    _snoozeFollowUpToTime(followUpId, newTime);
  }

  void _snoozeFollowUpToTime(String followUpId, DateTime newTime) async {
    try {
      await DatabaseService.snoozeFollowUp(followUpId, newTime);
      widget.onDismiss();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Follow-up snoozed until ${_formatDateTime(newTime)}'),
          backgroundColor: const Color(0xFF74B9FF),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error snoozing follow-up: $e')),
      );
    }
  }

  void _showCustomSnoozeDialog(String followUpId) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (!mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (time == null) return;

    final snoozeDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    _snoozeFollowUpToTime(followUpId, snoozeDateTime);
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeString = '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (dateOnly == today) {
      return 'today at $timeString';
    } else if (dateOnly == tomorrow) {
      return 'tomorrow at $timeString';
    } else {
      return '${dateTime.day}/${dateTime.month} at $timeString';
    }
  }
}