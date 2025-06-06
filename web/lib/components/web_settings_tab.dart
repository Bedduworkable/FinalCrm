import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../lib/auth_service.dart';
import '../../../lib/database_service.dart';
import '../layouts/responsive_helper.dart';

class WebSettingsTab extends StatefulWidget {
  const WebSettingsTab({super.key});

  @override
  State<WebSettingsTab> createState() => _WebSettingsTabState();
}

class _WebSettingsTabState extends State<WebSettingsTab> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Map<String, List<String>> _customFields = {};
  Map<String, List<String>> _originalCustomFields = {};
  bool _isLoading = true;

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
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _loadCustomFields();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomFields() async {
    try {
      final fields = await AuthService.getCustomFields();
      setState(() {
        _customFields = Map<String, List<String>>.from(fields);
        _originalCustomFields = Map<String, List<String>>.from(fields);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Color _getFieldColor(String fieldType) {
    switch (fieldType) {
      case 'statuses':
        return primaryBlue;
      case 'projects':
        return const Color(0xFF059669);
      case 'sources':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF374151);
    }
  }

  IconData _getFieldIcon(String fieldType) {
    switch (fieldType) {
      case 'statuses':
        return Icons.track_changes_rounded;
      case 'projects':
        return Icons.business_rounded;
      case 'sources':
        return Icons.source_rounded;
      default:
        return Icons.settings_rounded;
    }
  }

  String _getFieldTitle(String fieldType) {
    switch (fieldType) {
      case 'statuses':
        return 'Lead Statuses';
      case 'projects':
        return 'Projects';
      case 'sources':
        return 'Lead Sources';
      default:
        return fieldType;
    }
  }

  String _getFieldDescription(String fieldType) {
    switch (fieldType) {
      case 'statuses':
        return 'Manage pipeline stages for leads';
      case 'projects':
        return 'Manage property projects';
      case 'sources':
        return 'Manage lead acquisition channels';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildContent()),
        ],
      ),
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
              color: primaryBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.settings_rounded,
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
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'Customize your CRM configuration',
                  style: TextStyle(
                    fontSize: 13,
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

  Widget _buildContent() {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final padding = ResponsiveHelper.getContentPadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) _buildDesktopLayout() else _buildMobileLayout(),
          const SizedBox(height: 32),
          _buildUserSection(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Custom Fields',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage your lead pipeline settings and categories',
          style: TextStyle(
            color: textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 1.2,
          ),
          itemCount: _customFields.entries.length,
          itemBuilder: (context, index) {
            final entry = _customFields.entries.elementAt(index);
            return _buildFieldCard(entry.key, entry.value, isDesktop: true);
          },
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Custom Fields',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage your lead pipeline settings',
          style: TextStyle(
            color: textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        ..._customFields.entries.map((entry) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildFieldCard(entry.key, entry.value),
            ),
        ),
      ],
    );
  }

  Widget _buildFieldCard(String fieldType, List<String> values, {bool isDesktop = false}) {
    final color = _getFieldColor(fieldType);
    final icon = _getFieldIcon(fieldType);
    final title = _getFieldTitle(fieldType);
    final description = _getFieldDescription(fieldType);

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _addNewField(fieldType),
                icon: Icon(Icons.add_rounded, color: color, size: 20),
                tooltip: 'Add new ${fieldType.replaceAll('s', '')}',
                style: IconButton.styleFrom(
                  backgroundColor: color.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (values.isEmpty)
            _buildEmptyFieldState(fieldType)
          else
            _buildFieldValues(values, color, isDesktop),
        ],
      ),
    );
  }

  Widget _buildEmptyFieldState(String fieldType) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: textTertiary, size: 16),
          const SizedBox(width: 8),
          Text(
            'No ${fieldType.replaceAll('s', '')}s added yet',
            style: const TextStyle(color: textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldValues(List<String> values, Color color, bool isDesktop) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        return GestureDetector(
          onTap: () => _editField(values.indexOf(value), value, color),
          onLongPress: () => _deleteField(values.indexOf(value), value, color),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                    fontSize: isDesktop ? 13 : 12,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.edit_rounded,
                  size: 12,
                  color: color.withOpacity(0.7),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<Map<String, dynamic>?>(
            future: AuthService.getUserProfile(),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              final name = profile?['name'] ?? 'User';
              final email = profile?['email'] ?? '';

              return Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Administrator',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Sign Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Divider(color: borderLight),
          const SizedBox(height: 16),
          _buildInfoRow('Version', 'IGPL CRM v1.0.0', Icons.info_outline),
          const SizedBox(height: 12),
          _buildInfoRow('Platform', 'Web Application', Icons.web_rounded),
          const SizedBox(height: 12),
          _buildInfoRow('Last Updated', 'December 2024', Icons.update_rounded),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: textSecondary),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
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
    );
  }

  Future<void> _addNewField(String fieldType) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add New ${_getFieldTitle(fieldType).replaceAll('s', '')}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: 'Enter ${fieldType.replaceAll('s', '')} name',
            border: const OutlineInputBorder(),
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
              backgroundColor: _getFieldColor(fieldType),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _performFieldOperation(() async {
        final currentValues = List<String>.from(_customFields[fieldType] ?? []);
        if (currentValues.contains(result)) {
          throw 'This item already exists';
        }
        currentValues.add(result);
        final updatedFields = Map<String, List<String>>.from(_customFields);
        updatedFields[fieldType] = currentValues;
        await DatabaseService.updateCustomFieldsWithMigration(updatedFields, _originalCustomFields);
        setState(() {
          _customFields = updatedFields;
          _originalCustomFields = Map<String, List<String>>.from(updatedFields);
        });
        _showSuccess('$result added successfully!');
      });
    }

    controller.dispose();
  }

  Future<void> _editField(int index, String oldValue, Color color) async {
    // Implementation for editing field
  }

  Future<void> _deleteField(int index, String value, Color color) async {
    // Implementation for deleting field
  }

  Future<void> _performFieldOperation(Future<void> Function() operation) async {
    try {
      await operation();
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AuthService.signOut();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      }
    }
  }
}