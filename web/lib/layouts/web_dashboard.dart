import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../lib/auth_service.dart';
import '../../../lib/lead_model.dart';
import '../../../lib/database_service.dart';
import '../components/web_kanban.dart';
import '../components/web_lead_modal.dart';
import '../components/web_add_lead_modal.dart';
import '../components/web_followups_tab.dart';
import '../components/web_settings_tab.dart';
import 'responsive_helper.dart';

class WebDashboard extends StatefulWidget {
  const WebDashboard({super.key});

  @override
  State<WebDashboard> createState() => _WebDashboardState();
}

class _WebDashboardState extends State<WebDashboard> with TickerProviderStateMixin {
  late TabController _tabController;

  // Tab indices
  static const int dashboardTab = 0;
  static const int followupsTab = 1;
  static const int settingsTab = 2;

  // Filters state
  List<String> _statuses = [];
  List<String> _projects = [];
  List<String> _sources = [];

  String? _selectedStatusFilter;
  List<String> _selectedProjectFilters = [];
  List<String> _selectedSourceFilters = [];

  // Date filter
  String _selectedDateFilter = 'All';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Stats
  Map<String, int> _leadStats = {};
  int _activeFollowUpsCount = 0;

  // Premium color palette
  static const Color primaryBlue = Color(0xFF10187B);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color sidebarBg = Color(0xFFFBFBFD);
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7080);
  static const Color borderLight = Color(0xFFF1F3F4);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCustomFields();
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomFields() async {
    final customFields = await AuthService.getCustomFields();
    if (mounted) {
      setState(() {
        _statuses = customFields['statuses'] ?? [];
        _projects = customFields['projects'] ?? [];
        _sources = customFields['sources'] ?? [];
      });
    }
  }

  Future<void> _loadStatistics() async {
    final stats = await DatabaseService.getLeadStatistics();
    final followUpsCount = await DatabaseService.getActiveFollowUpsCount();
    if (mounted) {
      setState(() {
        _leadStats = stats;
        _activeFollowUpsCount = followUpsCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: Row(
        children: [
          if (ResponsiveHelper.shouldShowSidebar(context)) _buildSidebar(),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final sidebarWidth = ResponsiveHelper.getSidebarWidth(context);

    return Container(
      width: sidebarWidth,
      decoration: const BoxDecoration(
        color: sidebarBg,
        border: Border(
          right: BorderSide(color: borderLight, width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildSidebarHeader(),
          Expanded(child: _buildSidebarNavigation()),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: borderLight, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.home_work_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IGPL CRM',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'Web Dashboard',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavigation() {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildNavItem(
          icon: Icons.dashboard_rounded,
          label: 'Dashboard',
          isSelected: _tabController.index == dashboardTab,
          badge: _leadStats.values.fold(0, (sum, count) => sum + count),
          onTap: () => _tabController.animateTo(dashboardTab),
        ),
        _buildNavItem(
          icon: Icons.schedule_rounded,
          label: 'Follow-ups',
          isSelected: _tabController.index == followupsTab,
          badge: _activeFollowUpsCount,
          onTap: () => _tabController.animateTo(followupsTab),
        ),
        _buildNavItem(
          icon: Icons.settings_rounded,
          label: 'Settings',
          isSelected: _tabController.index == settingsTab,
          onTap: () => _tabController.animateTo(settingsTab),
        ),
        const SizedBox(height: 24),
        _buildQuickActions(),
      ],
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    int? badge,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        leading: Icon(
          icon,
          color: isSelected ? primaryBlue : textSecondary,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? primaryBlue : textPrimary,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
        trailing: badge != null && badge > 0
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? primaryBlue : textSecondary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            badge.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        )
            : null,
        selected: isSelected,
        selectedTileColor: primaryBlue.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryBlue.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            icon: Icons.person_add_rounded,
            label: 'Add Lead',
            onTap: () => _showAddLeadModal(),
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            icon: Icons.schedule_rounded,
            label: 'View Follow-ups',
            onTap: () => _tabController.animateTo(followupsTab),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: primaryBlue),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: primaryBlue,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: borderLight, width: 1)),
      ),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: AuthService.getUserProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final name = profile?['name'] ?? 'User';
          final email = profile?['email'] ?? '';

          return Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: primaryBlue,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 10,
                        color: textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showSignOutDialog(),
                icon: const Icon(Icons.logout_rounded, size: 16),
                tooltip: 'Sign Out',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildDashboardTab(),
        const WebFollowUpsTab(),
        const WebSettingsTab(),
      ],
    );
  }

  Widget _buildDashboardTab() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: WebKanbanBoard(
            statuses: _statuses,
            statusFilter: _selectedStatusFilter,
            projectFilters: _selectedProjectFilters.isEmpty ? null : _selectedProjectFilters,
            sourceFilters: _selectedSourceFilters.isEmpty ? null : _selectedSourceFilters,
            dateRange: _getDateRange(),
            onLeadTap: (lead) => _showLeadModal(lead),
            onFiltersChanged: () => _loadStatistics(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.getContentPadding(context)),
      decoration: const BoxDecoration(
        color: cardWhite,
        border: Border(bottom: BorderSide(color: borderLight, width: 1)),
      ),
      child: Row(
        children: [
          const Text(
            'Lead Pipeline',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const Spacer(),
          _buildStatsChips(),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _showAddLeadModal,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Lead'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsChips() {
    if (_leadStats.isEmpty) return const SizedBox.shrink();

    return Row(
      children: _leadStats.entries.take(3).map((entry) {
        final color = _getStatusColor(entry.key);
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${entry.value}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getStatusColor(String status) {
    final colors = [
      primaryBlue,
      const Color(0xFF059669),
      const Color(0xFFDC2626),
      const Color(0xFFEA580C),
      const Color(0xFF7C3AED),
      const Color(0xFF0891B2),
      accentGold,
      const Color(0xFF374151),
    ];
    return colors[status.hashCode % colors.length];
  }

  DateTimeRange? _getDateRange() {
    final now = DateTime.now();
    switch (_selectedDateFilter) {
      case 'Today':
        final today = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: today, end: now);
      case 'Last 7 Days':
        return DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      case 'Last 30 Days':
        return DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
      case 'Select Range':
        if (_customStartDate != null && _customEndDate != null) {
          return DateTimeRange(start: _customStartDate!, end: _customEndDate!);
        }
        return null;
      default:
        return null;
    }
  }

  void _showAddLeadModal() {
    showDialog(
      context: context,
      builder: (context) => WebAddLeadModal(
        onLeadAdded: () => _loadStatistics(),
      ),
    );
  }

  void _showLeadModal(Lead lead) {
    showDialog(
      context: context,
      builder: (context) => WebLeadModal(
        lead: lead,
        onLeadUpdated: () => _loadStatistics(),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await AuthService.signOut();
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}