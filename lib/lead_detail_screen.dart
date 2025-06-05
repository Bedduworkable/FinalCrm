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

class _LeadDetailScreenState extends State<LeadDetailScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _headerAnimationController;
  late AnimationController _messageAnimationController;

  List<String> _statuses = [];
  bool _showQuickActions = false;

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadCustomFields();
    _headerAnimationController.forward();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _headerAnimationController.dispose();
    _messageAnimationController.dispose();
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
      const Color(0xFF6C5CE7),
      const Color(0xFF74B9FF),
      const Color(0xFF00CEC9),
      const Color(0xFF55A3FF),
      const Color(0xFFFF7675),
      const Color(0xFFFF6B9D),
      const Color(0xFFFFBE0B),
      const Color(0xFF84D187),
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
            title: const Text('Existing Follow-up'),
            content: const Text('There\'s already a pending follow-up. Replace it?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Replace'),
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
              primary: const Color(0xFF6C5CE7),
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
              primary: const Color(0xFF6C5CE7),
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
    final titleController = TextEditingController(text: 'Follow-up call');
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Schedule Follow-up'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g., Call about property visit',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Additional details...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                Navigator.pop(context, {
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                });
              } else {
                // Don't use ScaffoldMessenger inside dialog - just return
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
            ),
            child: const Text('Schedule'),
          ),
        ],
      ),
    );

    // Clean up controllers immediately
    final title = result?['title'];
    final description = result?['description'];
    titleController.dispose();
    descriptionController.dispose();

    if (title != null && title.isNotEmpty && mounted) {
      // Step 4: Create Follow-up
      try {
        print('Creating follow-up with title: $title');

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

        // Create follow-up and immediately wait for completion
        await DatabaseService.createFollowUp(followUp);
        print('Follow-up created successfully');

        // Only show UI feedback if widget is still mounted
        if (mounted) {
          HapticFeedback.heavyImpact();

          // Use post frame callback to ensure UI is ready
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Follow-up scheduled for ${_formatDateTime(scheduledDateTime)}'),
                  backgroundColor: const Color(0xFF84D187),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          });
        }
      } catch (e) {
        print('Error creating follow-up: $e');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error scheduling follow-up: ${e.toString()}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
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
        title: const Text('Change Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _statuses.map((status) {
            final isSelected = status == widget.lead.status;
            final color = _getStatusColor(status);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(status),
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_circle) : null,
                selected: isSelected,
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
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status changed to $newStatus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error changing status: $e')),
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
      backgroundColor: const Color(0xFFF0F2F5),
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
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOutCubic,
      )),
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _getStatusColor(widget.lead.status).withOpacity(0.1),
                  child: Text(
                    widget.lead.name.isNotEmpty ? widget.lead.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(widget.lead.status),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.lead.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      StreamBuilder<DocumentSnapshot>(
                        stream: _firestore.collection('leads')
                            .doc(widget.lead.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(widget.lead.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _getStatusColor(widget.lead.status).withOpacity(0.3)),
                              ),
                              child: Text(
                                widget.lead.status,
                                style: TextStyle(
                                  color: _getStatusColor(widget.lead.status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }

                          final leadData = snapshot.data!.data() as Map<String, dynamic>;
                          final currentLead = Lead.fromMap(leadData, snapshot.data!.id);
                          final color = _getStatusColor(currentLead.status);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Text(
                              currentLead.status,
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _makePhoneCall,
                  icon: const Icon(Icons.phone_rounded, color: Color(0xFF6C5CE7)),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'status',
                      child: const Row(
                        children: [
                          Icon(Icons.swap_horiz_rounded),
                          SizedBox(width: 12),
                          Text('Change Status'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'whatsapp',
                      child: const Row(
                        children: [
                          Icon(Icons.chat_rounded),
                          SizedBox(width: 12),
                          Text('WhatsApp'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'email',
                      child: const Row(
                        children: [
                          Icon(Icons.email_rounded),
                          SizedBox(width: 12),
                          Text('Send Email'),
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
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.lead.mobile.isNotEmpty) ...[
                  Icon(Icons.phone_rounded, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    widget.lead.mobile,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                ],
                if (widget.lead.email.isNotEmpty) ...[
                  Icon(Icons.email_rounded, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.lead.email,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    return StreamBuilder<List<Remark>>(
      stream: DatabaseService.getRemarks(widget.lead.id),
      builder: (context, snapshot) {
        print('Remarks stream state: ${snapshot.connectionState}');
        print('Remarks data: ${snapshot.data?.length ?? 0} remarks');
        print('Remarks error: ${snapshot.error}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Refresh
                  },
                  child: const Text('Retry'),
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
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No remarks yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start the conversation by adding a remark',
                  style: TextStyle(color: Colors.grey.shade500),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isSystemMessage
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.end,
        children: [
          if (isSystemMessage)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getRemarkIcon(remark.type),
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      remark.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
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
              decoration: const BoxDecoration(
                color: Color(0xFF6C5CE7),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                remark.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            _formatMessageTime(remark.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRemarkIcon(RemarkType type) {
    switch (type) {
      case RemarkType.followUpSet:
        return Icons.schedule_rounded;
      case RemarkType.followUpSnoozed:
        return Icons.snooze_rounded;
      case RemarkType.followUpCompleted:
        return Icons.check_circle_rounded;
      case RemarkType.statusChanged:
        return Icons.swap_horiz_rounded;
      case RemarkType.leadCreated:
        return Icons.person_add_rounded;
      default:
        return Icons.chat_rounded;
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_showQuickActions) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _scheduleFollowUp,
                      icon: const Icon(Icons.schedule_rounded),
                      label: const Text('Schedule Follow-up'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF74B9FF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _changeStatus,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Change Status'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00CEC9),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showQuickActions = !_showQuickActions;
                    });
                  },
                  icon: AnimatedRotation(
                    turns: _showQuickActions ? 0.125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.add_rounded),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Add a remark...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addRemark,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C5CE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
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