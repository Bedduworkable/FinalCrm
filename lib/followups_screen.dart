import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lead_model.dart';
import 'database_service.dart';
import 'lead_detail_screen.dart';

class FollowUpsScreen extends StatefulWidget {
  const FollowUpsScreen({super.key});

  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(FollowUpStatus status) {
    switch (status) {
      case FollowUpStatus.pending:
        return const Color(0xFF6C5CE7);
      case FollowUpStatus.completed:
        return const Color(0xFF84D187);
      case FollowUpStatus.snoozed:
        return const Color(0xFF74B9FF);
      case FollowUpStatus.cancelled:
        return const Color(0xFFFF7675);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUpcomingTab(),
                  _buildOverdueTab(),
                  _buildCompletedTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C5CE7), Color(0xFF74B9FF)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Follow-ups',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Manage your scheduled tasks',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF6C5CE7),
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: const Color(0xFF6C5CE7),
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(Icons.upcoming_rounded),
            text: 'Upcoming',
          ),
          Tab(
            icon: Icon(Icons.warning_rounded),
            text: 'Overdue',
          ),
          Tab(
            icon: Icon(Icons.check_circle_rounded),
            text: 'Completed',
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingTab() {
    return StreamBuilder<List<FollowUp>>(
      stream: DatabaseService.getFollowUps(status: FollowUpStatus.pending),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allFollowUps = snapshot.data ?? [];
        final upcomingFollowUps = allFollowUps.where((f) => !f.isOverdue).toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        if (upcomingFollowUps.isEmpty) {
          return _buildEmptyState(
            Icons.schedule_rounded,
            'No upcoming follow-ups',
            'All caught up! Schedule follow-ups from lead details.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: upcomingFollowUps.length,
          itemBuilder: (context, index) {
            return _buildFollowUpCard(upcomingFollowUps[index]);
          },
        );
      },
    );
  }

  Widget _buildOverdueTab() {
    return StreamBuilder<List<FollowUp>>(
      stream: DatabaseService.getFollowUps(status: FollowUpStatus.pending),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allFollowUps = snapshot.data ?? [];
        final overdueFollowUps = allFollowUps.where((f) => f.isOverdue).toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        if (overdueFollowUps.isEmpty) {
          return _buildEmptyState(
            Icons.celebration_rounded,
            'No overdue follow-ups',
            'Great job staying on top of your tasks!',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: overdueFollowUps.length,
          itemBuilder: (context, index) {
            return _buildFollowUpCard(overdueFollowUps[index], isOverdue: true);
          },
        );
      },
    );
  }

  Widget _buildCompletedTab() {
    return StreamBuilder<List<FollowUp>>(
      stream: DatabaseService.getFollowUps(status: FollowUpStatus.completed),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final completedFollowUps = snapshot.data ?? []
          ..sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));

        if (completedFollowUps.isEmpty) {
          return _buildEmptyState(
            Icons.task_alt_rounded,
            'No completed follow-ups',
            'Completed follow-ups will appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completedFollowUps.length,
          itemBuilder: (context, index) {
            return _buildFollowUpCard(completedFollowUps[index], isCompleted: true);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard(FollowUp followUp, {bool isOverdue = false, bool isCompleted = false}) {
    return FutureBuilder<Lead?>(
      future: DatabaseService.getLead(followUp.leadId),
      builder: (context, leadSnapshot) {
        final lead = leadSnapshot.data;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                if (lead != null) {
                  HapticFeedback.lightImpact();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LeadDetailScreen(lead: lead)),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: isOverdue
                      ? Border.all(color: Colors.red.withOpacity(0.3), width: 2)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(followUp.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isCompleted
                                ? Icons.check_circle_rounded
                                : isOverdue
                                ? Icons.warning_rounded
                                : Icons.schedule_rounded,
                            color: _getStatusColor(followUp.status),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                followUp.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (lead != null)
                                Text(
                                  lead.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'OVERDUE',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (followUp.description != null) ...[
                      Text(
                        followUp.description!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle : Icons.access_time_rounded,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCompleted
                              ? 'Completed ${_formatDateTime(followUp.completedAt ?? followUp.scheduledAt)}'
                              : _formatDateTime(followUp.scheduledAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        if (followUp.isDueToday && !isCompleted && !isOverdue) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'TODAY',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!isCompleted) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _markAsCompleted(followUp),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Mark Done'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF84D187),
                                side: const BorderSide(color: Color(0xFF84D187)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _snoozeFollowUp(followUp),
                              icon: const Icon(Icons.snooze_rounded, size: 16),
                              label: const Text('Snooze'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF74B9FF),
                                side: const BorderSide(color: Color(0xFF74B9FF)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _markAsCompleted(FollowUp followUp) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Mark as Completed'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Completion Notes (Optional)',
              hintText: 'Add any notes about the outcome...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Mark Done'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        await DatabaseService.completeFollowUp(followUp.id, result);
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Follow-up marked as completed')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _snoozeFollowUp(FollowUp followUp) async {
    final result = await showDialog<Duration>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Snooze Follow-up'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('1 Hour'),
              onTap: () => Navigator.pop(context, const Duration(hours: 1)),
            ),
            ListTile(
              title: const Text('Tomorrow 9 AM'),
              onTap: () => Navigator.pop(context, const Duration(days: 1)),
            ),
            ListTile(
              title: const Text('Next Week'),
              onTap: () => Navigator.pop(context, const Duration(days: 7)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        DateTime newTime;
        if (result.inDays == 1) {
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          newTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
        } else {
          newTime = DateTime.now().add(result);
        }

        await DatabaseService.snoozeFollowUp(followUp.id, newTime);
        if (mounted) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Follow-up snoozed until ${_formatDateTime(newTime)}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeString = '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (dateOnly == today) {
      return 'Today at $timeString';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow at $timeString';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at $timeString';
    }
  }
}