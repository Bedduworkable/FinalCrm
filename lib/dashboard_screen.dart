import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'lead_model.dart';
import 'database_service.dart';
import 'auth_service.dart';
import 'lead_detail_screen.dart';
import 'add_lead_screen.dart';
import 'settings_screen.dart';
import 'followups_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late AnimationController _filterAnimationController;
  late AnimationController _fabAnimationController;

  List<String> _statuses = [];
  List<String> _projects = [];
  List<String> _sources = [];

  String? _selectedStatusFilter;
  List<String> _selectedProjectFilters = [];
  List<String> _selectedSourceFilters = [];

  bool _showFilters = false;
  int _activeFollowUpsCount = 0;
  Map<String, int> _leadStats = {};

  // Date filter variables
  String _selectedDateFilter = 'All'; // Default to show all leads
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Premium color palette - matching other screens
  static const Color primaryBlue = Color(0xFF10187B);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color creamBackground = Color(0xFFFAF9F7);
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7080);
  static const Color textTertiary = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _loadCustomFields();
    _loadStatistics();
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    _fabAnimationController.dispose();
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
    setState(() {
      _leadStats = stats;
      _activeFollowUpsCount = followUpsCount;
    });
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
    if (_showFilters) {
      _filterAnimationController.forward();
    } else {
      _filterAnimationController.reverse();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedProjectFilters.clear();
      _selectedSourceFilters.clear();
    });
  }

  void _onDateFilterChanged(String filter) {
    setState(() {
      if (_selectedDateFilter == filter) {
        // If clicking the same filter, clear it (show all leads)
        _selectedDateFilter = 'All';
        _customStartDate = null;
        _customEndDate = null;
      } else {
        _selectedDateFilter = filter;
        if (filter != 'Select Range') {
          _customStartDate = null;
          _customEndDate = null;
        }
      }
    });
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
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

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedDateFilter = 'Select Range';
      });
    }
  }

  DateTimeRange? _getDateRange() {
    final now = DateTime.now();
    switch (_selectedDateFilter) {
      case 'Today':
        final today = DateTime(now.year, now.month, now.day);
        final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: today, end: endOfToday);
      case 'Y\'Day':
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        final endOfYesterday = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
        return DateTimeRange(start: yesterday, end: endOfYesterday);
      case 'Last 7 Days':
        final sevenDaysAgo = DateTime(now.year, now.month, now.day - 7);
        return DateTimeRange(start: sevenDaysAgo, end: now);
      case 'Last 30 Days':
        final thirtyDaysAgo = DateTime(now.year, now.month, now.day - 30);
        return DateTimeRange(start: thirtyDaysAgo, end: now);
      case 'Select Range':
        if (_customStartDate != null && _customEndDate != null) {
          final endOfCustomDay = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59);
          return DateTimeRange(start: _customStartDate!, end: endOfCustomDay);
        }
        return null;
      case 'All':
      default:
        return null; // No date filter
    }
  }

  Color _getProjectColor(String project) {
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
    return colors[project.hashCode % colors.length];
  }

  Future<void> _showSetNameDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Set Your Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Your Name',
            hintText: 'Enter your full name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await AuthService.updateUserProfile(name: result);
        setState(() {}); // Refresh the UI

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Name updated to $result'),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating name: $e'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFiltersPanel(),
            _buildDateFilterRow(),
            _buildStatsRow(),
            Expanded(child: _buildKanbanBoard()),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            HapticFeedback.lightImpact();
            final result = await Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const AddLeadScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: child,
                  );
                },
              ),
            );
            if (result == true) {
              _loadStatistics();
            }
          },
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Lead', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16), // Reduced padding
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, const Color(0xFF374BD3)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IGPL CRM',
                      style: TextStyle(
                        fontSize: 22, // Slightly smaller
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: AuthService.getUserProfile(),
                      builder: (context, snapshot) {
                        final name = snapshot.data?['name'] ?? 'User';

                        // If name is 'User' or email-like, show a button to set name
                        if (name == 'User' || name.contains('@')) {
                          return GestureDetector(
                            onTap: () => _showSetNameDialog(),
                            child: Row(
                              children: [
                                Text(
                                  'Hello, ${name == 'User' ? 'User' : name.split('@')[0]}',
                                  style: const TextStyle(
                                    fontSize: 13, // Smaller
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit,
                                  size: 11, // Smaller
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                          );
                        }

                        return Text(
                          'Hello, $name',
                          style: const TextStyle(
                            fontSize: 13, // Smaller
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Follow-ups Button with Badge
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FollowUpsScreen()),
                  );
                },
                icon: Stack(
                  children: [
                    const Icon(Icons.schedule_rounded, color: Colors.white, size: 22), // Smaller
                    if (_activeFollowUpsCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14, // Smaller
                            minHeight: 14,
                          ),
                          child: Text(
                            '$_activeFollowUpsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8, // Smaller
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Filters Button
              IconButton(
                onPressed: _toggleFilters,
                icon: AnimatedRotation(
                  turns: _showFilters ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22), // Smaller
                ),
              ),
              // Settings Button
              IconButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                  // Refresh custom fields when returning from settings
                  if (result != null || mounted) {
                    await _loadCustomFields();
                    await _loadStatistics();
                  }
                },
                icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 22), // Smaller
              ),
            ],
          ),
          if (_activeFollowUpsCount > 0) ...[
            const SizedBox(height: 12), // Smaller spacing
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FollowUpsScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Smaller padding
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16), // Smaller radius
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded, color: Colors.white, size: 14), // Smaller
                    const SizedBox(width: 6),
                    Text(
                      '$_activeFollowUpsCount pending follow-ups',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400, fontSize: 12), // Smaller
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 10), // Smaller
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: _showFilters ? null : 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _filterAnimationController,
          curve: Curves.easeOutCubic,
        )),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16), // Reduced padding
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Smaller
                  ),
                  const Spacer(),
                  if (_selectedStatusFilter != null ||
                      _selectedProjectFilters.isNotEmpty ||
                      _selectedSourceFilters.isNotEmpty)
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear All', style: TextStyle(fontSize: 13)), // Smaller
                    ),
                ],
              ),
              const SizedBox(height: 12), // Smaller spacing
              _buildFilterSection('Status', _statuses, _selectedStatusFilter, (value) {
                setState(() {
                  _selectedStatusFilter = _selectedStatusFilter == value ? null : value;
                });
              }, isSingleSelect: true),
              const SizedBox(height: 12),
              _buildFilterSection('Projects', _projects, _selectedProjectFilters, (value) {
                setState(() {
                  if (_selectedProjectFilters.contains(value)) {
                    _selectedProjectFilters.remove(value);
                  } else {
                    _selectedProjectFilters.add(value);
                  }
                });
              }),
              const SizedBox(height: 12),
              _buildFilterSection('Sources', _sources, _selectedSourceFilters, (value) {
                setState(() {
                  if (_selectedSourceFilters.contains(value)) {
                    _selectedSourceFilters.remove(value);
                  } else {
                    _selectedSourceFilters.add(value);
                  }
                });
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Compact padding
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildDateFilterChip('Today'),
            const SizedBox(width: 8),
            _buildDateFilterChip('Y\'Day'),
            const SizedBox(width: 8),
            _buildDateFilterChip('Last 7 Days'),
            const SizedBox(width: 8),
            _buildDateFilterChip('Last 30 Days'),
            const SizedBox(width: 8),
            _buildDateFilterChip('Select Range'),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterChip(String label) {
    final isSelected = _selectedDateFilter == label;
    final isCustomRange = label == 'Select Range' && _customStartDate != null && _customEndDate != null;
    final showCloseButton = isSelected && label != 'All';

    return GestureDetector(
      onTap: () {
        if (label == 'Select Range') {
          _selectCustomDateRange();
        } else {
          _onDateFilterChanged(label);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryBlue : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isCustomRange
                  ? '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}'
                  : label,
              style: TextStyle(
                color: isSelected ? Colors.white : textPrimary,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                fontSize: 12,
              ),
            ),
            if (showCloseButton) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDateFilter = 'All';
                    _customStartDate = null;
                    _customEndDate = null;
                  });
                },
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: isSelected ? Colors.white : textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> options, dynamic selected, Function(String) onTap, {bool isSingleSelect = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: textPrimary, fontSize: 13)), // Smaller
        const SizedBox(height: 6), // Smaller spacing
        Wrap(
          spacing: 6, // Smaller spacing
          runSpacing: 6,
          children: options.map((option) {
            final isSelected = isSingleSelect
                ? selected == option
                : (selected as List<String>).contains(option);

            return GestureDetector(
              onTap: () => onTap(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Smaller padding
                decoration: BoxDecoration(
                  color: isSelected ? primaryBlue : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14), // Smaller radius
                  border: Border.all(
                    color: isSelected ? primaryBlue : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? Colors.white : textPrimary,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    fontSize: 11, // Smaller font
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    if (_leadStats.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 60, // Reduced height
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Smaller margins
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _leadStats.length,
        itemBuilder: (context, index) {
          final entry = _leadStats.entries.elementAt(index);
          final color = _getProjectColor(entry.key);

          return Container(
            width: 100, // Reduced width
            margin: const EdgeInsets.only(right: 10), // Smaller margin
            padding: const EdgeInsets.all(8), // Smaller padding
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10), // Smaller radius
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.value.toString(),
                  style: TextStyle(
                    fontSize: 16, // Smaller font
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 9, // Smaller font
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKanbanBoard() {
    return StreamBuilder<List<Lead>>(
      stream: DatabaseService.getLeadsWithDateFilter(
        statusFilter: _selectedStatusFilter,
        projectFilters: _selectedProjectFilters.isEmpty ? null : _selectedProjectFilters,
        sourceFilters: _selectedSourceFilters.isEmpty ? null : _selectedSourceFilters,
        dateRange: _getDateRange(),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('Error loading leads', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                const SizedBox(height: 6),
                Text('${snapshot.error}', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
              ],
            ),
          );
        }

        final leads = snapshot.data ?? [];

        // Always show FAB after data loads
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fabAnimationController.forward();
        });

        if (leads.isEmpty) {
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
                    Icons.people_outline_rounded,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No leads found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedDateFilter != 'All'
                      ? 'No leads found for selected date range'
                      : 'Add your first lead to get started',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          );
        }

        final leadsByStatus = <String, List<Lead>>{};
        for (final status in _statuses) {
          leadsByStatus[status] = leads.where((lead) => lead.status == status).toList();
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _statuses.map((status) {
              final statusLeads = leadsByStatus[status] ?? [];
              return _buildStatusColumn(status, statusLeads);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildStatusColumn(String status, List<Lead> leads) {
    final color = _getProjectColor(status);

    return Container(
      width: 260, // Reduced width
      margin: const EdgeInsets.only(right: 12), // Smaller margin
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Smaller padding
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10), // Smaller radius
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6, // Smaller
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: color,
                      fontSize: 12, // Smaller font
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Smaller padding
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8), // Smaller radius
                  ),
                  child: Text(
                    leads.length.toString(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w500,
                      fontSize: 10, // Smaller font
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8), // Smaller spacing
          Expanded(
            child: ListView.builder(
              itemCount: leads.length,
              itemBuilder: (context, index) {
                return _buildLeadCard(leads[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCard(Lead lead) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        try {
          final result = await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => LeadDetailScreen(lead: lead),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                );
              },
            ),
          );
          // Refresh data when returning from lead detail
          if (result != null) {
            _loadStatistics();
          }
        } catch (e) {
          print('Error navigating to lead detail: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error opening lead details: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), // Smaller margin
        child: Card(
          elevation: 1,
          shadowColor: Colors.black.withOpacity(0.06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Smaller radius
          child: Container(
            padding: const EdgeInsets.all(10), // Smaller padding
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: cardWhite,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14, // Smaller
                      backgroundColor: _getProjectColor(lead.name).withOpacity(0.1),
                      child: Text(
                        lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _getProjectColor(lead.name),
                          fontSize: 12, // Smaller
                        ),
                      ),
                    ),
                    const SizedBox(width: 8), // Smaller spacing
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lead.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12, // Smaller
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
                                fontSize: 10, // Smaller
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                    ),
                    StreamBuilder<List<FollowUp>>(
                      stream: DatabaseService.getFollowUps(leadId: lead.id, status: FollowUpStatus.pending),
                      builder: (context, followUpSnapshot) {
                        final followUps = followUpSnapshot.data ?? [];
                        if (followUps.isEmpty) return const SizedBox.shrink();

                        final nextFollowUp = followUps.first;
                        final isOverdue = nextFollowUp.isOverdue;
                        final isDueToday = nextFollowUp.isDueToday;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // Smaller padding
                          decoration: BoxDecoration(
                            color: isOverdue
                                ? Colors.red.withOpacity(0.1)
                                : isDueToday
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6), // Smaller radius
                          ),
                          child: Icon(
                            Icons.schedule_rounded,
                            size: 12, // Smaller
                            color: isOverdue
                                ? Colors.red
                                : isDueToday
                                ? Colors.orange
                                : Colors.blue,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8), // Smaller spacing
                if (lead.projects.isNotEmpty || lead.sources.isNotEmpty) ...[
                  Wrap(
                    spacing: 4, // Smaller spacing
                    runSpacing: 4,
                    children: [
                      ...lead.projects.map((project) => _buildTag(project, _getProjectColor(project))),
                      ...lead.sources.map((source) => _buildTag(source, Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 6), // Smaller spacing
                ],
                StreamBuilder<List<FollowUp>>(
                  stream: DatabaseService.getFollowUps(leadId: lead.id, status: FollowUpStatus.pending),
                  builder: (context, snapshot) {
                    final followUps = snapshot.data ?? [];
                    if (followUps.isEmpty) {
                      return Text(
                        'No upcoming follow-ups',
                        style: TextStyle(
                          color: textTertiary,
                          fontSize: 9, // Smaller
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                        ),
                      );
                    }

                    final nextFollowUp = followUps.first;
                    final timeString = _formatTime(nextFollowUp.scheduledAt);

                    return Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 10, // Smaller
                          color: textTertiary,
                        ),
                        const SizedBox(width: 3), // Smaller spacing
                        Expanded(
                          child: Text(
                            'Next: $timeString',
                            style: const TextStyle(
                              color: textTertiary,
                              fontSize: 9, // Smaller
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Smaller padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6), // Smaller radius
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8, // Smaller
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateOnly == today) {
      return 'Today ${_formatTimeOnly(dateTime)}';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow ${_formatTimeOnly(dateTime)}';
    } else if (dateTime.isBefore(now)) {
      return 'Overdue';
    } else {
      return '${dateTime.day}/${dateTime.month} ${_formatTimeOnly(dateTime)}';
    }
  }

  String _formatTimeOnly(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}