import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lead_model.dart';
import 'database_service.dart';
import 'auth_service.dart';

class AddLeadScreen extends StatefulWidget {
  const AddLeadScreen({super.key});

  @override
  State<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _remarksController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<String> _statuses = [];
  List<String> _projects = [];
  List<String> _sources = [];

  String _selectedStatus = '';
  String? _selectedProject; // Changed to single selection
  String? _selectedSource; // Changed to single selection

  bool _isLoading = false;

  // Premium color palette - matching lead detail
  static const Color primaryBlue = Color(0xFF10187B);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color backgroundLight = Color(0xFFFBFBFD);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color creamBackground = Color(0xFFFAF9F7);
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
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
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
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _remarksController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomFields() async {
    final customFields = await AuthService.getCustomFields();
    setState(() {
      _statuses = customFields['statuses'] ?? [];
      _projects = customFields['projects'] ?? [];
      _sources = customFields['sources'] ?? [];

      if (_statuses.isNotEmpty) {
        _selectedStatus = _statuses.first;
      }
    });
  }

  Color _getProjectColor(String item) {
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
    return colors[item.hashCode % colors.length];
  }

  Future<void> _saveLead() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a project'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a source'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final lead = Lead(
        id: '',
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        status: _selectedStatus,
        projects: [_selectedProject!], // Single project in list
        sources: [_selectedSource!], // Single source in list
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userId: AuthService.currentUserId!,
      );

      final leadId = await DatabaseService.createLead(lead);

      // Add initial remark if provided
      if (_remarksController.text.trim().isNotEmpty) {
        await DatabaseService.addRemark(
          leadId: leadId,
          content: _remarksController.text.trim(),
          type: RemarkType.note,
        );
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lead added successfully!'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding lead: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildForm(),
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
        color: cardWhite,
        border: Border(bottom: BorderSide(color: borderLight, width: 1)),
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
                    color: backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 14, color: textPrimary),
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
              color: creamBackground,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
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
                        'Add New Lead',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Capture lead information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: textSecondary,
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

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: 24),
            _buildSelectionSection(),
            const SizedBox(height: 24),
            _buildRemarksSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: primaryBlue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _nameController,
            label: 'Full Name *',
            hint: 'Enter lead\'s full name',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _mobileController,
            label: 'Mobile Number *',
            hint: 'Enter mobile number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Mobile number is required';
              }
              if (value.length < 10) {
                return 'Enter valid mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'Enter email address (optional)',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Enter valid email address';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization? textCapitalization,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: textSecondary),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: textTertiary),
        prefixIcon: Icon(icon, size: 18, color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1),
        ),
        filled: true,
        fillColor: backgroundLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: const TextStyle(fontSize: 14, color: textPrimary),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization ?? TextCapitalization.none,
      validator: validator,
    );
  }

  Widget _buildSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF059669),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Lead Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Status Selection
          _buildStatusDropdown(),
          const SizedBox(height: 20),

          // Project Selection
          _buildSingleSelectionField(
            title: 'Project *',
            items: _projects,
            selectedItem: _selectedProject,
            onItemSelected: (project) {
              setState(() {
                _selectedProject = project;
              });
            },
            emptyMessage: 'Select a project',
          ),
          const SizedBox(height: 20),

          // Source Selection
          _buildSingleSelectionField(
            title: 'Lead Source *',
            items: _sources,
            selectedItem: _selectedSource,
            onItemSelected: (source) {
              setState(() {
                _selectedSource = source;
              });
            },
            emptyMessage: 'Select a source',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedStatus.isEmpty ? null : _selectedStatus,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderLight, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderLight, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: primaryBlue, width: 1.5),
            ),
            filled: true,
            fillColor: backgroundLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: const TextStyle(fontSize: 14, color: textPrimary),
          items: _statuses.map((status) {
            final color = _getProjectColor(status);
            return DropdownMenuItem(
              value: status,
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
                  const SizedBox(width: 10),
                  Text(status, style: const TextStyle(fontSize: 14)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedStatus = value ?? '';
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a status';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSingleSelectionField({
    required String title,
    required List<String> items,
    required String? selectedItem,
    required Function(String?) onItemSelected,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderLight, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: textTertiary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'No options available',
                  style: TextStyle(color: textTertiary, fontSize: 13),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              final isSelected = selectedItem == item;
              final color = _getProjectColor(item);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onItemSelected(isSelected ? null : item);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color : backgroundLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? color : borderLight,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      color: isSelected ? Colors.white : textPrimary,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        if (selectedItem == null && items.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            emptyMessage,
            style: TextStyle(
              color: textTertiary,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRemarksSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.note_rounded,
                  color: accentGold,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Initial Remarks',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _remarksController,
            decoration: InputDecoration(
              labelText: 'Remarks (Optional)',
              labelStyle: const TextStyle(fontSize: 13, color: textSecondary),
              hintText: 'Add any initial notes about this lead...',
              hintStyle: const TextStyle(fontSize: 13, color: textTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: borderLight, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: borderLight, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: primaryBlue, width: 1.5),
              ),
              filled: true,
              fillColor: backgroundLight,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontSize: 14, color: textPrimary),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveLead,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          shadowColor: primaryBlue.withOpacity(0.2),
        ),
        child: _isLoading
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Text(
          'Save Lead',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}