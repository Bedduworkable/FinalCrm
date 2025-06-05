import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lead_model.dart';
import 'database_service.dart';
import 'auth_service.dart';

class LeadDetailScreen extends StatefulWidget {
  final Lead lead;

  const LeadDetailScreen({super.key, required this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> _statuses = [];
  bool _showQuickActions = false;

  // Premium color palette
  static const Color primaryBlue = Color(0xFF10187B);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color lightGrey = Color(0xFFF8F9FB);
  static const Color softWhite = Color(0xFFFFFFFE);
  static const Color lightViolet = Color(0xFFF5F6FF);
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _loadCustomFields();
  }

  @override
  void dispose() {
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

  Future<void> _makePhoneCall() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: widget.lead.mobile);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: widget.lead.email,
      query: 'subject=Regarding Your Property Inquiry',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
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

  Future<void> _addRemark() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      await DatabaseService.addRemark(
        leadId: widget.lead.id,
        content: _messageController.text.trim(),
        type: RemarkType.note,
      );

      _messageController.clear();
      _scrollToBottom();
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding remark: $e')),
        );
      }
    }
  }

  Future<void> _scheduleFollowUp() async {
    try {
      // Check if there's already a pending follow-up
      final followUpsSnapshot = await FirebaseFirestore.instance
          .collection('followUps')
          .where('leadId', isEqualTo: widget.lead.id)
          .where('userId', isEqualTo: AuthService.currentUserId)
          .where('status', isEqualTo: FollowUpStatus.pending.toString())
          .get();

      if (followUpsSnapshot.docs.isNotEmpty && mounted) {
        final shouldReplace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: softWhite,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: accentGold, size: 18),
                ),
                const SizedBox(width: 12),
                const Text('Existing Follow-up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
              ],
            ),
            content: const Text(
              'There\'s already a pending follow-up for this lead. Would you like to replace it with a new one?',
              style: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Replace', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        );

        if (shouldReplace != true) return;
      }
    } catch (e) {
      print('Error checking existing follow-ups: $e');
    }

    if (!mounted) return;

    // Step 1: Select Date
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null || !mounted) return;

    // Step 2: Select Time
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time == null || !mounted) return;

    final scheduledDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!mounted) return;

    // Step 3: Get Title and Description
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _FollowUpDialog(),
    );

    if (result != null && result['title']?.isNotEmpty == true && mounted) {
      final title = result['title']!;
      final description = result['description'];

      try {
        final followUp = FollowUp(
          id: '',
          leadId: widget.lead.id,
          scheduledAt: scheduledDateTime,
          title: title,
          description: description?.isEmpty == true ? null : description,
          status: FollowUpStatus.pending,
          createdAt: DateTime.now(),
          userId: AuthService.currentUserId!,
        );

        await DatabaseService.createFollowUp(followUp);

        if (mounted) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Follow-up scheduled for ${_formatDateTime(scheduledDateTime)}'),
              backgroundColor: primaryBlue,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error scheduling follow-up: ${e.toString()}'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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
      return 'today at $timeString';
    } else if (dateOnly == tomorrow) {
      return 'tomorrow at $timeString';
    } else {
      return '${dateTime.day}/${dateTime.month} at $timeString';
    }
  }

  Future<void> _changeStatus() async {
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: softWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.swap_horiz_rounded, color: primaryBlue, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Change Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _statuses.map((status) {
            final isSelected = status == widget.lead.status;
            final color = _getStatusColor(status);

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? color : textPrimary,
                  ),
                ),
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                trailing: isSelected ? Icon(Icons.check_circle, color: color, size: 18) : null,
                selected: isSelected,
                selectedTileColor: color.withOpacity(0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: isSelected ? null : () => Navigator.pop(context, status),
              ),
            );
          }).toList(),
        ),
      ),
    );

    if (newStatus != null && newStatus != widget.lead.status) {
      try {
        await DatabaseService.updateLeadStatus(
          widget.lead.id,
          newStatus,
          widget.lead.status,
        );

        if (mounted) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status changed to $newStatus'),
              backgroundColor: _getStatusColor(newStatus),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error changing status: $e'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGrey,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildChatArea()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        color: softWhite,
        border: Border(bottom: BorderSide(color: borderLight, width: 0.5)),
      ),
      child: Column(
        children: [
          // Navigation and actions row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: lightGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: textPrimary),
                  padding: EdgeInsets.zero,
                ),
              ),
              const Spacer(),
              PopupMenuButton(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: lightGrey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.more_horiz, size: 18, color: textPrimary),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'status',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded, color: primaryBlue, size: 16),
                        const SizedBox(width: 8),
                        Text('Change Status', style: TextStyle(fontSize: 13, color: textPrimary)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'whatsapp',
                    child: Row(
                      children: [
                        Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 16),
                        const SizedBox(width: 8),
                        Text('WhatsApp', style: TextStyle(fontSize: 13, color: textPrimary)),
                      ],
                    ),
                  ),
                  if (widget.lead.email.isNotEmpty)
                    PopupMenuItem(
                      value: 'email',
                      child: Row(
                        children: [
                          Icon(Icons.email_rounded, color: Color(0xFF1976D2), size: 16),
                          const SizedBox(width: 8),
                          Text('Send Email', style: TextStyle(fontSize: 13, color: textPrimary)),
                        ],
                      ),
                    ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'status':
                      _changeStatus();
                      break;
                    case 'whatsapp':
                      _openWhatsApp();
                      break;
                    case 'email':
                      _sendEmail();
                      break;
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Profile section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
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
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Name, phone, status
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
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (widget.lead.mobile.isNotEmpty)
                      Text(
                        widget.lead.mobile,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: textSecondary,
                          height: 1.3,
                        ),
                      ),
                    const SizedBox(height: 8),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _firestore.collection('leads')
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
              ),
            ],
          ),

          // Action buttons
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.phone,
                  label: 'Call',
                  onTap: _makePhoneCall,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  onTap: _openWhatsApp,
                  color: const Color(0xFF25D366),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.schedule,
                  label: 'Schedule',
                  onTap: _scheduleFollowUp,
                  color: accentGold,
                ),
              ),
            ],
          ),

          // Tags section
          if (widget.lead.projects.isNotEmpty || widget.lead.sources.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightViolet,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderLight, width: 0.5),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...widget.lead.projects.map((project) => _buildTag(project, primaryBlue, 'Project')),
                  ...widget.lead.sources.map((source) => _buildTag(source, const Color(0xFF059669), 'Source')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
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
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color, String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 9,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return StreamBuilder<List<Remark>>(
      stream: DatabaseService.getRemarks(widget.lead.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.error_outline, size: 32, color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Error loading conversation',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: primaryBlue),
                ),
              ],
            ),
          );
        }

        final remarks = snapshot.data ?? [];

        if (remarks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 28,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Start the conversation',
                  style: TextStyle(
                    fontSize: 16,
                    color: textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add your first remark to begin tracking\ninteractions with this lead',
                  style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollToBottom();
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: remarks.length,
          itemBuilder: (context, index) {
            return _buildRemarkBubble(remarks[index]);
          },
        );
      },
    );
  }

  Widget _buildRemarkBubble(Remark remark) {
    final isSystemMessage = remark.type.isSystemGenerated;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isSystemMessage
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.end,
        children: [
          if (isSystemMessage)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: lightViolet,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderLight, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: textSecondary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getRemarkIcon(remark.type),
                      size: 10,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      remark.content,
                      style: const TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
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
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                remark.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: isSystemMessage ? MainAxisAlignment.center : MainAxisAlignment.end,
            children: [
              Icon(
                Icons.access_time,
                size: 10,
                color: textSecondary.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                _formatMessageTime(remark.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: textSecondary.withOpacity(0.8),
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: softWhite,
        border: const Border(top: BorderSide(color: borderLight, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_showQuickActions) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lightViolet,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderLight, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flash_on, color: textSecondary, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.schedule,
                            label: 'Schedule Follow-up',
                            color: primaryBlue,
                            onTap: _scheduleFollowUp,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.swap_horiz,
                            label: 'Change Status',
                            color: const Color(0xFF059669),
                            onTap: _changeStatus,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _showQuickActions ? primaryBlue : lightGrey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _showQuickActions = !_showQuickActions;
                      });
                      HapticFeedback.lightImpact();
                    },
                    icon: Icon(
                      _showQuickActions ? Icons.close : Icons.add,
                      color: _showQuickActions ? Colors.white : textSecondary,
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: lightGrey,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderLight, width: 0.5),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Add a remark...',
                        hintStyle: TextStyle(
                          color: textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _addRemark,
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
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
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} $timeString';
    }
  }
}

// Follow-up dialog with premium styling
class _FollowUpDialog extends StatefulWidget {
  @override
  _FollowUpDialogState createState() => _FollowUpDialogState();
}

class _FollowUpDialogState extends State<_FollowUpDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  // Premium color palette
  static const Color primaryBlue = Color(0xFF10187B);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color lightGrey = Color(0xFFF8F9FB);
  static const Color softWhite = Color(0xFFFFFFFE);
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Follow-up call');
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: softWhite,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.schedule, color: primaryBlue, size: 18),
          ),
          const SizedBox(width: 12),
          const Text(
            'Schedule Follow-up',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title *',
                labelStyle: const TextStyle(fontSize: 13, color: textSecondary),
                hintText: 'e.g., Call about property visit',
                hintStyle: const TextStyle(fontSize: 13, color: textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: borderLight, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: borderLight, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: primaryBlue, width: 1),
                ),
                filled: true,
                fillColor: lightGrey,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14, color: textPrimary),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: const TextStyle(fontSize: 13, color: textSecondary),
                hintText: 'Additional details...',
                hintStyle: const TextStyle(fontSize: 13, color: textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: borderLight, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: borderLight, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: primaryBlue, width: 1),
                ),
                filled: true,
                fillColor: lightGrey,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14, color: textPrimary),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'title': _titleController.text.trim(),
                'description': _descriptionController.text.trim(),
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text(
            'Schedule',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }