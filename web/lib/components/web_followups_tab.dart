import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../lib/lead_model.dart';
import '../../../lib/database_service.dart';
import '../layouts/responsive_helper.dart';

class WebFollowUpsTab extends StatefulWidget {
  const WebFollowUpsTab({super.key});

  @override
  State<WebFollowUpsTab> createState() => _WebFollowUpsTabState();
}

class _WebFollowUpsTabState extends State<WebFollowUpsTab> with TickerProviderStateMixin {
  late TabController _tabController;

  // Premium color palette
  static const Color primaryBlue = Color(0xFF10187B);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7080);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color borderLight = Color(0xFFF1F3F4);

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
    return Column(
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
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.getContentPadding(context)),
      decoration: const BoxDecoration(
        color: cardWhite,
        border: Border(bottom: BorderSide(color: borderLight)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF74B9FF)],
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Follow-ups',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'Manage your scheduled tasks and reminders',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _buildStatsCard(),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return StreamBuilder<List<FollowUp>>(
      stream: DatabaseService.getFollowUps(status: FollowUpStatus.pending),
      builder: (context, snapshot) {
        final allFollowUps = snapshot.data ?? [];
        final overdueCount = allFollowUps.where((f) => f.isOverdue).length;
        final todayCount = allFollowUps.where((f) => f.isDueToday).length;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatItem('Overdue', overdueCount, Colors.red),
              const SizedBox(width: 16),
              _buildStatItem('Today', todayCount, Colors.orange),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: cardWhite,
        border: Border(bottom: BorderSide(color: borderLight)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: primaryBlue,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryBlue,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        tabs: const [
          Tab(
            icon: Icon(Icons.upcoming_rounded, size: 18),
            text: 'Upcoming',
          ),
          Tab(
            icon: Icon(Icons.warning_rounded, size: 18),
            text: 'Overdue',
          ),
          Tab(
            icon: Icon(Icons.check_circle_rounded, size: 18),
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

        return _buildFollowUpsList(upcomingFollowUps);
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

        return _buildFollowUpsList(overdueFollowUps, isOverdue: true);
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

        return _buildFollowUpsList(completedFollowUps, isCompleted: true);
      },
    );
  }

  Widget _buildFollowUpsList(List<FollowUp> followUps, {bool isOverdue = false, bool isCompleted = false}) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final padding = ResponsiveHelper.getContentPadding(context);

    if (isDesktop) {
      return _buildDesktopGrid(followUps, isOverdue: isOverdue, isCompleted: isCompleted);
    }

    return ListView.builder(
      padding: EdgeInsets.all(padding),
      itemCount: followUps.length,
      itemBuilder: (context, index) {
        return _buildFollowUpCard(followUps[index], isOverdue: isOverdue, isCompleted: isCompleted);
      },
    );
  }

  Widget _buildDesktopGrid(List<FollowUp> followUps, {bool isOverdue = false, bool isCompleted = false}) {
    final padding = ResponsiveHelper.getContentPadding(context);
    final crossAxisCount = ResponsiveHelper.isLargeDesktop(context) ? 3 : 2;

    return GridView.builder(
      padding: EdgeInsets.all(padding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8,
      ),
      itemCount: followUps.length,
      itemBuilder: (context, index) {
        return _buildFollowUpCard(followUps[index], isOverdue: isOverdue, isCompleted: isCompleted);
      },
    );
  }

  Widget _buildFollowUpCard(FollowUp followUp, {bool isOverdue = false, bool isCompleted = false}) {
    return FutureBuilder<Lead?>(
      future: DatabaseService.getLead(followUp.leadId),
      builder: (context, leadSnapshot) {
        final lead = leadSnapshot.data;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isOverdue ? Colors.red.withOpacity(0.3) : borderLight,
              width: isOverdue ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openLeadDetail(lead),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardHeader(followUp, lead, isOverdue, isCompleted),
                  const SizedBox(height: 12),
                  _buildCardContent(followUp),
                  const SizedBox(height: 12),
                  _buildCardFooter(followUp, isCompleted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardHeader(FollowUp followUp, Lead? lead, bool isOverdue, bool isCompleted) {
    return Row(
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (lead != null)
                Text(
                  lead.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (isOverdue)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'OVERDUE',
              style: TextStyle(
                color: Colors.red,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCardContent(FollowUp followUp) {
    if (followUp.description?.isEmpty ?? true) {
      return const SizedBox.shrink();
    }

    return Text(
      followUp.description!,
      style: const TextStyle(
        color: textSecondary,
        fontSize: 12,
        height: 1.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCardFooter(FollowUp followUp, bool isCompleted) {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.access_time_rounded,
              size: 14,
              color: textTertiary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                isCompleted
                    ? 'Completed ${_formatDateTime(followUp.completedAt ?? followUp.scheduledAt)}'
                    : _formatDateTime(followUp.scheduledAt),
                style: const TextStyle(
                  color: textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
            if (followUp.isDueToday && !isCompleted) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'TODAY',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 8,
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
                child: OutlinedButton(
                  onPressed: () => _markAsCompleted(followUp),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF84D187),
                    side: const BorderSide(color: Color(0xFF84D187)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('Done', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _snoozeFollowUp(followUp),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF74B9FF),
                    side: const BorderSide(color: Color(0xFF74B9FF)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.snooze_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('Snooze', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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

  void _openLeadDetail(Lead? lead) {
    if (lead != null) {
      // Implementation to open lead detail modal
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _markAsCompleted(FollowUp followUp) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84D187),
                foregroundColor: Colors.white,
              ),
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
            const SnackBar(
              content: Text('Follow-up marked as completed'),
              backgroundColor: Color(0xFF84D187),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            SnackBar(
              content: Text('Follow-up snoozed until ${_formatDateTime(newTime)}'),
              backgroundColor: const Color(0xFF74B9FF),
            ),
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
}