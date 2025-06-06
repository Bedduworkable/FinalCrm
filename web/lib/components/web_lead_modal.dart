import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../lib/lead_model.dart';
import '../../../lib/database_service.dart';
import '../../../lib/auth_service.dart';
import '../layouts/responsive_helper.dart';

class WebLeadModal extends StatefulWidget {
  final Lead lead;
  final VoidCallback onLeadUpdated;

  const WebLeadModal({
    super.key,
    required this.lead,
    required this.onLeadUpdated,
  });

  @override
  State<WebLeadModal> createState() => _WebLeadModalState();
}

class _WebLeadModalState extends State<WebLeadModal> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<String> _statuses = [];
  bool _showQuickActions = false;

  // Premium color palette
  static const Color primaryBlue = Color(0xFF10187B);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color backgroundLight = Color(0xFFFBFBFD);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7080);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color borderLight = Color(0xFFF1F3F4);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCustomFields();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomFields() async {
    final customFields = await AuthService.getCustomFields();
    setState(() {
      _statuses = customFields['statuses'] ?? [];
    });
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: ResponsiveHelper.getModalConstraints(context),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildModalHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildConversationTab(),
                  _buildDetailsTab(),
                  _buildFollowUpsTab(),
                ],
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildModalHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: backgroundLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(bottom: BorderSide(color: borderLight)),
      ),
      child: Row(
        children: [
          // Lead Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.lead.name.isNotEmpty ? widget.lead.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Lead Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lead.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (widget.lead.mobile.isNotEmpty) ...[
                      Text(
                        widget.lead.mobile,
                        style: const TextStyle(
                          fontSize: 14,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('leads')
                          .doc(widget.lead.id)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return _buildStatusChip(widget.lead.status);
                        }
                        final leadData = snapshot.data!.data() as Map<String, dynamic>;
                        final currentLead = Lead.fromMap(leadData, snapshot.data!.id);
                        return _buildStatusChip(currentLead.status);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Quick Actions
          Row(
            children: [
              _buildActionButton(
                icon: Icons.phone,
                onTap: _makePhoneCall,
                color: primaryBlue,
                tooltip: 'Call',
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.chat,
                onTap: _openWhatsApp,
                color: const Color(0xFF25D366),
                tooltip: 'WhatsApp',
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.schedule,
                onTap: _scheduleFollowUp,
                color: accentGold,
                tooltip: 'Schedule Follow-up',
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Close',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return GestureDetector(
      onTap: _changeStatus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
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
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 12, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: borderLight)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: primaryBlue,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryBlue,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        tabs: const [
          Tab(text: 'Conversation'),
          Tab(text: 'Details'),
          Tab(text: 'Follow-ups'),
        ],
      ),
    );
  }

  Widget _buildConversationTab() {
    return StreamBuilder<List<Remark>>(
      stream: DatabaseService.getRemarks(widget.lead.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading conversation');
        }

        final remarks = snapshot.data ?? [];

        if (remarks.isEmpty) {
          return _buildEmptyConversation();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          itemCount: remarks.length,
          itemBuilder: (context, index) {
            return _buildRemarkBubble(remarks[index]);
          },
        );
      },
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailSection('Contact Information', [
            _buildDetailRow('Name', widget.lead.name, Icons.person_outline),
            _buildDetailRow('Mobile', widget.lead.mobile, Icons.phone_outlined),
            if (widget.lead.email.isNotEmpty)
              _buildDetailRow('Email', widget.lead.email, Icons.email_outlined),
          ]),
          const SizedBox(height: 24),
          _buildDetailSection('Lead Information', [
            _buildDetailRow('Status', widget.lead.status, Icons.flag_outlined),
            if (widget.lead.projects.isNotEmpty)
              _buildDetailRow('Projects', widget.lead.projects.join(', '), Icons.business_outlined),
            if (widget.lead.sources.isNotEmpty)
              _buildDetailRow('Sources', widget.lead.sources.join(', '), Icons.source_outlined),
          ]),
          const SizedBox(height: 24),
          _buildDetailSection('Timeline', [
            _buildDetailRow('Created', _formatDateTime(widget.lead.createdAt), Icons.add_circle_outline),
            _buildDetailRow('Last Updated', _formatDateTime(widget.lead.updatedAt), Icons.update_outlined),
          ]),
        ],
      ),
    );
  }

  Widget _buildFollowUpsTab() {
    return StreamBuilder<List<FollowUp>>(
      stream: DatabaseService.getFollowUps(leadId: widget.lead.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final followUps = snapshot.data ?? [];

        if (followUps.isEmpty) {
          return _buildEmptyFollowUps();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: followUps.length,
          itemBuilder: (context, index) {
            return _buildFollowUpCard(followUps[index]);
          },
        );
      },
    );
  }

  Widget _buildDetailSection(String title, List<Widget> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderLight),
          ),
          child: Column(
            children: details,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarkBubble(Remark remark) {
    final isSystemMessage = remark.type.isSystemGenerated;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isSystemMessage ? CrossAxisAlignment.center : CrossAxisAlignment.end,
        children: [
          if (isSystemMessage)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getRemarkIcon(remark.type), size: 12, color: textTertiary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      remark.content,
                      style: const TextStyle(
                        fontSize: 12,
                        color: textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                remark.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            _formatMessageTime(remark.createdAt),
            style: const TextStyle(
              fontSize: 10,
              color: textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard(FollowUp followUp) {
    final color = _getFollowUpColor(followUp.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(_getFollowUpIcon(followUp.status), size: 12, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  followUp.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                followUp.status.displayName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          if (followUp.description != null) ...[
            const SizedBox(height: 8),
            Text(
              followUp.description!,
              style: const TextStyle(
                fontSize: 12,
                color: textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Scheduled: ${_formatDateTime(followUp.scheduledAt)}',
            style: const TextStyle(
              fontSize: 11,
              color: textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConversation() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: textTertiary),
          SizedBox(height: 16),
          Text(
            'No conversation yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start the conversation by adding a remark',
            style: TextStyle(fontSize: 12, color: textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFollowUps() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule_outlined, size: 48, color: textTertiary),
          const SizedBox(height: 16),
          const Text(
            'No follow-ups scheduled',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Schedule a follow-up to stay connected',
            style: TextStyle(fontSize: 12, color: textTertiary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _scheduleFollowUp,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Schedule Follow-up'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: backgroundLight,
        border: Border(top: BorderSide(color: borderLight)),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _showQuickActions = !_showQuickActions;
              });
            },
            icon: Icon(
              _showQuickActions ? Icons.close : Icons.add,
              color: primaryBlue,
            ),
            tooltip: 'Quick Actions',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Add a remark...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cardWhite,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _addRemark,
            icon: const Icon(Icons.send, color: primaryBlue),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getRemarkIcon(RemarkType type) {
    switch (type) {
      case RemarkType.followUpSet:
        return Icons.schedule;
      case RemarkType.followUpSnoozed:
        return Icons.snooze;
      case RemarkType.followUpCompleted:
        return Icons.check_circle;
      case RemarkType.statusChanged:
        return Icons.swap_horiz;
      case RemarkType.leadCreated:
        return Icons.person_add;
      default:
        return Icons.chat;
    }
  }

  Color _getFollowUpColor(FollowUpStatus status) {
    switch (status) {
      case FollowUpStatus.pending:
        return primaryBlue;
      case FollowUpStatus.completed:
        return const Color(0xFF059669);
      case FollowUpStatus.snoozed:
        return const Color(0xFFEA580C);
      case FollowUpStatus.cancelled:
        return const Color(0xFFDC2626);
    }
  }

  IconData _getFollowUpIcon(FollowUpStatus status) {
    switch (status) {
      case FollowUpStatus.pending:
        return Icons.schedule;
      case FollowUpStatus.completed:
        return Icons.check_circle;
      case FollowUpStatus.snoozed:
        return Icons.snooze;
      case FollowUpStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeString = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (messageDate == today) {
      return timeString;
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $timeString';
    } else {
      return '${dateTime.day}/${dateTime.month} $timeString';
    }
  }

  // Action methods
  Future<void> _makePhoneCall() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: widget.lead.mobile);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _openWhatsApp() async {
    final Uri whatsappUri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/${widget.lead.mobile.replaceAll(RegExp(r'\D'), '')}',
      query: 'text=Hello! I\'m following up regarding your property inquiry.',
    );
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _scheduleFollowUp() async {
    // Implementation similar to mobile version
    // This would show a dialog to schedule follow-up
  }

  Future<void> _changeStatus() async {
    // Implementation similar to mobile version
    // This would show a dialog to change status
  }

  Future<void> _addRemark() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      await DatabaseService.addRemark(
        leadId: widget.lead.id,
        content: _messageController.text.trim(),
        type: RemarkType.note,
      );

      _messageController.clear();
      widget.onLeadUpdated();
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding remark: $e')),
        );
      }
    }
  }
}