import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../lib/lead_model.dart';
import '../../../lib/database_service.dart';
import '../layouts/responsive_helper.dart';

class WebKanbanBoard extends StatefulWidget {
  final List<String> statuses;
  final String? statusFilter;
  final List<String>? projectFilters;
  final List<String>? sourceFilters;
  final DateTimeRange? dateRange;
  final Function(Lead) onLeadTap;
  final VoidCallback onFiltersChanged;

  const WebKanbanBoard({
    super.key,
    required this.statuses,
    this.statusFilter,
    this.projectFilters,
    this.sourceFilters,
    this.dateRange,
    required this.onLeadTap,
    required this.onFiltersChanged,
  });

  @override
  State<WebKanbanBoard> createState() => _WebKanbanBoardState();
}

class _WebKanbanBoardState extends State<WebKanbanBoard> {
  final ScrollController _horizontalScrollController = ScrollController();

  // Premium color palette
  static const Color primaryBlue = Color(0xFF10187B);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7080);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color borderLight = Color(0xFFF1F3F4);

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lead>>(
      stream: DatabaseService.getLeadsWithDateFilter(
        statusFilter: widget.statusFilter,
        projectFilters: widget.projectFilters,
        sourceFilters: widget.sourceFilters,
        dateRange: widget.dateRange,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final leads = snapshot.data ?? [];

        if (leads.isEmpty) {
          return _buildEmptyState();
        }

        // Group leads by status
        final leadsByStatus = <String, List<Lead>>{};
        for (final status in widget.statuses) {
          leadsByStatus[status] = leads.where((lead) => lead.status == status).toList();
        }

        return _buildKanbanBoard(leadsByStatus);
      },
    );
  }

  Widget _buildKanbanBoard(Map<String, List<Lead>> leadsByStatus) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final columnWidth = ResponsiveHelper.getLeadCardWidth(context);
    final contentPadding = ResponsiveHelper.getContentPadding(context);

    return Container(
      padding: EdgeInsets.all(contentPadding),
      child: Column(
        children: [
          if (isDesktop) _buildFiltersBar(),
          Expanded(
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.statuses.map((status) {
                    final statusLeads = leadsByStatus[status] ?? [];
                    return _buildStatusColumn(
                      status,
                      statusLeads,
                      columnWidth,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, size: 20, color: textSecondary),
          const SizedBox(width: 8),
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),
          const SizedBox(width: 16),
          _buildDateFilterChips(),
          const Spacer(),
          Text(
            '${_getTotalLeadsCount()} leads',
            style: const TextStyle(
              fontSize: 12,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChips() {
    final dateFilters = ['All', 'Today', 'Last 7 Days', 'Last 30 Days'];

    return Row(
      children: dateFilters.map((filter) {
        final isSelected = _getSelectedDateFilter() == filter;
        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) => _onDateFilterChanged(filter),
            selectedColor: primaryBlue.withOpacity(0.1),
            checkmarkColor: primaryBlue,
            side: BorderSide(
              color: isSelected ? primaryBlue : borderLight,
            ),
            labelStyle: TextStyle(
              color: isSelected ? primaryBlue : textSecondary,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusColumn(String status, List<Lead> leads, double width) {
    final color = _getStatusColor(status);

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildColumnHeader(status, leads.length, color),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.1)),
              ),
              child: leads.isEmpty
                  ? _buildEmptyColumn(status)
                  : _buildLeadsColumn(leads),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(String status, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: color,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadsColumn(List<Lead> leads) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: leads.length,
      itemBuilder: (context, index) {
        return _buildLeadCard(leads[index]);
      },
    );
  }

  Widget _buildLeadCard(Lead lead) {
    return Container(
      margin: ResponsiveHelper.getCardMargin(context),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderLight, width: 1),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onLeadTap(lead);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeadHeader(lead),
                const SizedBox(height: 8),
                _buildLeadDetails(lead),
                const SizedBox(height: 8),
                _buildLeadTags(lead),
                const SizedBox(height: 8),
                _buildLeadFooter(lead),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadHeader(Lead lead) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: _getStatusColor(lead.name).withOpacity(0.1),
          child: Text(
            lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: _getStatusColor(lead.name),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lead.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (lead.mobile.isNotEmpty)
                Text(
                  lead.mobile,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        _buildFollowUpIndicator(lead),
      ],
    );
  }

  Widget _buildLeadDetails(Lead lead) {
    if (lead.email.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(Icons.email_outlined, size: 12, color: textTertiary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            lead.email,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLeadTags(Lead lead) {
    final allTags = [...lead.projects, ...lead.sources];
    if (allTags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: allTags.take(3).map((tag) {
        final isProject = lead.projects.contains(tag);
        final color = isProject ? primaryBlue : const Color(0xFF059669);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeadFooter(Lead lead) {
    return Row(
      children: [
        Icon(
          Icons.access_time_rounded,
          size: 10,
          color: textTertiary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _formatTime(lead.updatedAt),
            style: const TextStyle(
              color: textTertiary,
              fontSize: 9,
            ),
          ),
        ),
        if (ResponsiveHelper.isDesktop(context)) ...[
          IconButton(
            onPressed: () => widget.onLeadTap(lead),
            icon: const Icon(Icons.open_in_new_rounded, size: 12),
            iconSize: 12,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            tooltip: 'Open Lead',
          ),
        ],
      ],
    );
  }

  Widget _buildFollowUpIndicator(Lead lead) {
    return StreamBuilder<List<FollowUp>>(
      stream: DatabaseService.getFollowUps(leadId: lead.id, status: FollowUpStatus.pending),
      builder: (context, snapshot) {
        final followUps = snapshot.data ?? [];
        if (followUps.isEmpty) return const SizedBox.shrink();

        final nextFollowUp = followUps.first;
        final isOverdue = nextFollowUp.isOverdue;
        final isDueToday = nextFollowUp.isDueToday;

        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isOverdue
                ? Colors.red
                : isDueToday
                ? Colors.orange
                : Colors.blue,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildEmptyColumn(String status) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                color: _getStatusColor(status).withOpacity(0.5),
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No leads',
              style: TextStyle(
                color: textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
            child: const Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No leads found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.dateRange != null
                ? 'No leads found for selected date range'
                : 'Start by adding your first lead',
            style: const TextStyle(
              color: textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error loading leads',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _getSelectedDateFilter() {
    // This would be connected to the parent component's state
    return 'All';
  }

  void _onDateFilterChanged(String filter) {
    // This would trigger the parent component to update filters
    widget.onFiltersChanged();
  }

  int _getTotalLeadsCount() {
    // This would return the total count from the stream
    return 0;
  }
}