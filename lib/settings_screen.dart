import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Map<String, List<String>> _customFields = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
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
        _customFields = fields;
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
        return const Color(0xFF10187B);
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
      // Check for duplicates
      final currentValues = List<String>.from(_customFields[fieldType] ?? []);
      if (currentValues.contains(result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This item already exists')),
          );
        }
        return;
      }

      try {
        // Add the new value to the list
        currentValues.add(result);

        // Update the entire custom fields map
        final updatedFields = Map<String, List<String>>.from(_customFields);
        updatedFields[fieldType] = currentValues;

        await AuthService.updateCustomFields(updatedFields);
        await _loadCustomFields();

        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$result added successfully!'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding item: $e')),
          );
        }
      }
    }

    controller.dispose();
  }

  Future<void> _renameField(String fieldType, String oldValue) async {
    final controller = TextEditingController(text: oldValue);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename ${_getFieldTitle(fieldType).replaceAll('s', '')}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name',
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
              if (controller.text.trim().isNotEmpty && controller.text.trim() != oldValue) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getFieldColor(fieldType),
              foregroundColor: Colors.white,
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result != oldValue) {
      try {
        final currentValues = List<String>.from(_customFields[fieldType] ?? []);
        final index = currentValues.indexOf(oldValue);
        if (index != -1) {
          currentValues[index] = result;

          // Update the entire custom fields map
          final updatedFields = Map<String, List<String>>.from(_customFields);
          updatedFields[fieldType] = currentValues;

          await AuthService.updateCustomFields(updatedFields);
          await _loadCustomFields();

          if (mounted) {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Renamed to $result successfully!'),
                backgroundColor: const Color(0xFF059669),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error renaming item: $e')),
          );
        }
      }
    }

    controller.dispose();
  }

  Future<void> _deleteField(String fieldType, String value) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "$value"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final currentValues = List<String>.from(_customFields[fieldType] ?? []);
        currentValues.remove(value);

        // Update the entire custom fields map
        final updatedFields = Map<String, List<String>>.from(_customFields);
        updatedFields[fieldType] = currentValues;

        await AuthService.updateCustomFields(updatedFields);
        await _loadCustomFields();

        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$value deleted successfully!'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting item: $e')),
          );
        }
      }
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
              backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFD),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F3F4), width: 1)),
      ),
      child: Column(
        children: [
          // Navigation row
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 20,
              right: 20,
              bottom: 8,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBFBFD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 14, color: Color(0xFF1A1D29)),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          // Header section with cream background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            decoration: const BoxDecoration(
              color: Color(0xFFFAF9F7),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10187B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: 20,
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
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1D29),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Customize your CRM',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7080),
                          height: 1.3,
                        ),
                      ),
                    ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCustomFieldsSection(),
          const SizedBox(height: 30),
          _buildUserSection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCustomFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Custom Fields',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1D29),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage your lead pipeline settings',
          style: TextStyle(
            color: Color(0xFF6B7080),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 20),
        ..._customFields.entries.map((entry) => _buildFieldCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildFieldCard(String fieldType, List<String> values) {
    final color = _getFieldColor(fieldType);
    final icon = _getFieldIcon(fieldType);
    final title = _getFieldTitle(fieldType);
    final description = _getFieldDescription(fieldType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F3F4), width: 1),
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
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1D29),
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF6B7080),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _addNewField(fieldType),
                icon: Icon(Icons.add_rounded, color: color, size: 18),
                tooltip: 'Add new ${fieldType.replaceAll('s', '')}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((value) {
              return GestureDetector(
                onTap: () => _renameField(fieldType, value),
                onLongPress: () => _deleteField(fieldType, value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.2), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
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
          ),
          if (values.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBFD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F3F4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: const Color(0xFF9CA3AF), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'No ${fieldType.replaceAll('s', '')}s added yet',
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1D29),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F3F4), width: 1),
          ),
          child: Column(
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: AuthService.getUserProfile(),
                builder: (context, snapshot) {
                  final profile = snapshot.data;
                  final name = profile?['name'] ?? 'User';
                  final email = profile?['email'] ?? '';

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10187B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: Color(0xFF1A1D29),
                      ),
                    ),
                    subtitle: Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7080),
                      ),
                    ),
                    trailing: const Icon(Icons.account_circle_outlined, color: Color(0xFF6B7080)),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F3F4)),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                ),
                title: const Text(
                  'App Information',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1A1D29),
                  ),
                ),
                subtitle: const Text(
                  'IGPL CRM v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7080),
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF6B7080)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: const Text('App Information'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('IGPL CRM'),
                          Text('Version: 1.0.0'),
                          SizedBox(height: 8),
                          Text('A simple and effective CRM for real estate professionals.'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F3F4)),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.exit_to_app_rounded, color: Colors.red, size: 16),
                ),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1A1D29),
                  ),
                ),
                subtitle: const Text(
                  'Sign out of your account',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7080),
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF6B7080)),
                onTap: _signOut,
              ),
            ],
          ),
        ),
      ],
    );
  }
}