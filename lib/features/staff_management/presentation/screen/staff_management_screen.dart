import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:roadside_service/features/staff_management/presentation/bloc/staff_bloc.dart';
import '../../../../core/di/injection_container.dart';

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<StaffManagementBloc>()..add(FetchStaff()),
      child: const _StaffManagementView(),
    );
  }
}

class _StaffManagementView extends StatefulWidget {
  const _StaffManagementView();
  @override
  State<_StaffManagementView> createState() => _StaffManagementViewState();
}

class _StaffManagementViewState extends State<_StaffManagementView> {
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  // --- COMPREHENSIVE ENTERPRISE PERMISSIONS MATRIX ---
  final Map<String, Map<String, String>> _permissionGroups = {
    'Fleet & User Management': {
      'ViewUsers': 'View staff, drivers, and customer directories.',
      'ManageDrivers': 'Onboard, approve, suspend, and edit driver profiles.',
      'ManageStaff':
          'Provision new staff, edit HR records, and suspend accounts.',
      'ManageCustomers': 'Edit customer CRM profiles and vehicle garages.',
      'ManageRBAC': 'Modify system access and permissions for other employees.',
    },
    'Dispatch & Operations': {
      'ViewRequests':
          'View active fleet map, live dispatches, and heatmap history.',
      'ManageRequests':
          'Update job statuses, assign drivers, and edit active dispatches.',
      'ManualDispatch': 'Create emergency manual dispatch jobs and route them.',
      'CancelJobs':
          'Force cancel active jobs and apply cancellation penalties.',
      'ManageAddons': 'Add or reverse financial addons and upload job photos.',
    },
    'Finance & Billing': {
      'ViewFinance':
          'View financial KPIs, revenue dashboards, and invoice history.',
      'ManageFinance': 'Create, edit, and delete B2B/B2C invoices.',
      'IssueRefunds': 'Process and approve Moneris payment refunds.',
      'OverridePricing':
          'Manually override total job fares and add custom surcharges.',
      'ManagePricing':
          'Adjust global rate cards, base fares, and surge metrics.',
    },
    'Helpdesk & Global Settings': {
      'ManageSupport': 'View, escalate, and resolve customer support tickets.',
      'ViewCallLogs': 'Access and playback historical VoIP call recordings.',
      'ManageSettings': 'Modify platform commission percentages and tax rates.',
    },
  };

  // --- CORPORATE STRUCTURE DATABASE ---
  final Map<String, List<String>> _corporateStructure = {
    'Dispatch & Operations': [
      'Lead Dispatcher',
      'Night Dispatcher',
      'Logistics Coordinator',
      'Operations Manager',
    ],
    'Field Services': [
      'Tow Operator',
      'Roadside Technician',
      'Heavy Duty Specialist',
      'Fleet Manager',
    ],
    'Customer Support': [
      'Support Agent',
      'Customer Success Lead',
      'Dispute Resolution Specialist',
    ],
    'Finance & Billing': [
      'Billing Specialist',
      'Accountant',
      'Claims Adjuster',
    ],
    'Human Resources': ['HR Generalist', 'Recruiter', 'Compliance Officer'],
    'Fleet Maintenance': [
      'Head Mechanic',
      'Service Technician',
      'Parts Manager',
    ],
    'IT & Engineering': [
      'System Administrator',
      'Software Engineer',
      'IT Support',
    ],
    'Management & Executive': [
      'General Manager',
      'Director of Operations',
      'CEO',
      'CFO',
    ],
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, context),
              const SizedBox(height: 24),

              SizedBox(
                width: 400,
                child: TextField(
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search employees by name, ID, or role...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: BlocConsumer<StaffManagementBloc, StaffState>(
                  listener: (context, state) {
                    if (state is StaffError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: theme.colorScheme.error,
                        ),
                      );
                    } else if (state is StaffSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    }
                  },
                  buildWhen: (prev, current) =>
                      current is StaffLoaded || current is StaffLoading,
                  builder: (context, state) {
                    if (state is StaffLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state is StaffLoaded) {
                      final filtered = state.staff.where((s) {
                        return s.fullName.toLowerCase().contains(
                              _searchQuery,
                            ) ||
                            s.employeeNumber.toLowerCase().contains(
                              _searchQuery,
                            ) ||
                            s.department.toLowerCase().contains(_searchQuery) ||
                            s.jobTitle.toLowerCase().contains(_searchQuery);
                      }).toList();

                      return _buildStaffTable(filtered, theme);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Human Resources CRM',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Manage internal corporate staff, documentation, payroll models, and RBAC permissions.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.badge),
          label: const Text(
            'Provision New Employee',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () => _showEmployeeModal(context, theme, null),
        ),
      ],
    );
  }

  Widget _buildStaffTable(List<dynamic> staff, ThemeData theme) {
    if (staff.isEmpty) {
      return Center(
        child: Text(
          'No employee records match your search.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          elevation: 0,
          color: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 8,
            radius: const Radius.circular(8),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: SizedBox(
                  width: constraints.maxWidth < 900
                      ? 900
                      : constraints.maxWidth,
                  child: ListView.separated(
                    itemCount: staff.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.2),
                    ),
                    itemBuilder: (context, index) {
                      final s = staff[index];
                      // Determine payroll label dynamically
                      final payrollTypeLabel = (s.payrollType == 1)
                          ? 'Salaried'
                          : 'Hourly';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: s.isActive
                              ? theme.primaryColor.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          child: Icon(
                            s.role == 'Admin' ? Icons.security : Icons.person,
                            color: s.isActive ? theme.primaryColor : Colors.red,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(
                                payrollTypeLabel,
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: Colors.blue.withValues(
                                alpha: 0.1,
                              ),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            if (!s.isActive)
                              Chip(
                                label: const Text(
                                  'Suspended',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: Colors.red.withValues(
                                  alpha: 0.1,
                                ),
                                side: BorderSide.none,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            if (s.role == 'Admin')
                              Chip(
                                label: const Text(
                                  'System Admin',
                                  style: TextStyle(
                                    color: Colors.purple,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: Colors.purple.withValues(
                                  alpha: 0.1,
                                ),
                                side: BorderSide.none,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${s.jobTitle} • ${s.department} • ${s.employeeNumber}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Manage Profile',
                              onPressed: () =>
                                  _showEmployeeModal(context, theme, s),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.vpn_key,
                                color: Colors.orange,
                              ),
                              tooltip: 'Manage Permissions',
                              onPressed: () =>
                                  _showPermissionsModal(context, s, theme),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEmployeeModal(
    BuildContext parentContext,
    ThemeData theme,
    dynamic employee,
  ) {
    final isEditing = employee != null;
    final formKey = GlobalKey<FormState>();
    final bloc = parentContext.read<StaffManagementBloc>();

    // Identity Controllers
    final nameCtrl = TextEditingController(text: employee?.fullName);
    final emailCtrl = TextEditingController(text: employee?.email);
    final phoneCtrl = TextEditingController(text: employee?.phoneNumber);
    final empNumCtrl = TextEditingController(text: employee?.employeeNumber);

    // NEW: Payroll Controllers
    int payrollType = employee?.payrollType ?? 0; // 0=Hourly, 1=Salaried
    final baseRateCtrl = TextEditingController(
      text: employee?.baseRate?.toString() ?? '',
    );
    final taxDeductionCtrl = TextEditingController(
      text: employee?.taxDeductionPercentage != null
          ? (employee!.taxDeductionPercentage * 100).toStringAsFixed(1)
          : '0.0',
    );

    String? selectedDept = employee?.department;
    if (selectedDept != null &&
        !_corporateStructure.containsKey(selectedDept)) {
      selectedDept = 'Dispatch & Operations';
    }

    String? selectedTitle = employee?.jobTitle;
    if (selectedDept != null &&
        selectedTitle != null &&
        !_corporateStructure[selectedDept]!.contains(selectedTitle)) {
      selectedTitle = null;
    }

    int roleType = employee?.role == 'Admin' ? 4 : 3;
    bool sendInvite = !isEditing;

    Map<String, String> uploadedDocs = {
      'Government ID': employee?.documents['Government ID'] ?? '',
      'Employment Contract': employee?.documents['Employment Contract'] ?? '',
      'NDA': employee?.documents['NDA'] ?? '',
    };

    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickAndUploadFile(String docKey) async {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'jpg', 'png'],
            );
            if (result != null) {
              setModalState(() {
                uploadedDocs[docKey] =
                    'https://secure-storage.rodl.ca/uploads/${result.files.single.name}';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Document attached successfully.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }

          return Dialog(
            backgroundColor: theme.scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 850),
              padding: const EdgeInsets.all(40),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing
                              ? 'Manage Employee Profile'
                              : 'Provision New Staff',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Row(
                          children: [
                            if (isEditing)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete Employee',
                                onPressed: () {
                                  bloc.add(DeleteStaffMember(employee.id));
                                  Navigator.pop(dialogContext);
                                },
                              ),
                            if (isEditing)
                              IconButton(
                                icon: Icon(
                                  employee.isActive
                                      ? Icons.block
                                      : Icons.restore,
                                  color: Colors.orange,
                                ),
                                tooltip: employee.isActive
                                    ? 'Suspend Access'
                                    : 'Restore Access',
                                onPressed: () {
                                  bloc.add(
                                    ToggleStaffStatus(
                                      employee.id,
                                      !employee.isActive,
                                    ),
                                  );
                                  Navigator.pop(dialogContext);
                                },
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: theme.colorScheme.onSurface,
                              ),
                              onPressed: () => Navigator.pop(dialogContext),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Expanded(
                      child: SingleChildScrollView(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isSmall = constraints.maxWidth < 700;

                            final leftColumn = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Identity & Contact',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: nameCtrl,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Full Name *',
                                    filled: true,
                                    fillColor: theme.cardColor,
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      v!.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: emailCtrl,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Corporate Email *',
                                    filled: true,
                                    fillColor: theme.cardColor,
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      v!.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: phoneCtrl,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number',
                                    filled: true,
                                    fillColor: theme.cardColor,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (!isEditing)
                                  CheckboxListTile(
                                    title: Text(
                                      'Send Welcome Email & Temporary Password',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 13,
                                      ),
                                    ),
                                    value: sendInvite,
                                    activeColor: theme.primaryColor,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (val) => setModalState(
                                      () => sendInvite = val ?? true,
                                    ),
                                  ),
                              ],
                            );

                            final rightColumn = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Job Details & Placement',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (!isEditing)
                                  DropdownButtonFormField<int>(
                                    decoration: InputDecoration(
                                      labelText: 'System Access Level *',
                                      filled: true,
                                      fillColor: theme.cardColor,
                                      border: const OutlineInputBorder(),
                                    ),
                                    dropdownColor: theme.cardColor,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    value: roleType,
                                    items: [
                                      DropdownMenuItem(
                                        value: 3,
                                        child: Text(
                                          'Standard Employee',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 4,
                                        child: Text(
                                          'System Administrator',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null)
                                        setModalState(() => roleType = val);
                                    },
                                  ),
                                if (!isEditing) const SizedBox(height: 16),
                                TextFormField(
                                  controller: empNumCtrl,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText:
                                        'Employee ID (Auto-generated if blank)',
                                    filled: true,
                                    fillColor: theme.cardColor,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: 'Department *',
                                          filled: true,
                                          fillColor: theme.cardColor,
                                          border: const OutlineInputBorder(),
                                        ),
                                        dropdownColor: theme.cardColor,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        value: selectedDept,
                                        items: _corporateStructure.keys.map((
                                          dept,
                                        ) {
                                          return DropdownMenuItem(
                                            value: dept,
                                            child: Text(
                                              dept,
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) => setModalState(() {
                                          selectedDept = val;
                                          selectedTitle = null;
                                        }),
                                        validator: (v) =>
                                            v == null ? 'Required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: 'Job Title *',
                                          filled: true,
                                          fillColor: theme.cardColor,
                                          border: const OutlineInputBorder(),
                                        ),
                                        dropdownColor: theme.cardColor,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        value: selectedTitle,
                                        items: selectedDept == null
                                            ? []
                                            : _corporateStructure[selectedDept]!
                                                  .map((title) {
                                                    return DropdownMenuItem(
                                                      value: title,
                                                      child: Text(
                                                        title,
                                                        style: TextStyle(
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface,
                                                        ),
                                                      ),
                                                    );
                                                  })
                                                  .toList(),
                                        onChanged: (val) => setModalState(
                                          () => selectedTitle = val,
                                        ),
                                        validator: (v) =>
                                            v == null ? 'Required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isSmall) ...[
                                  leftColumn,
                                  const SizedBox(height: 32),
                                  rightColumn,
                                ] else
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: leftColumn),
                                      const SizedBox(width: 32),
                                      Expanded(child: rightColumn),
                                    ],
                                  ),
                                const SizedBox(height: 32),

                                // --- NEW: COMPENSATION & PAYROLL SECTION ---
                                Text(
                                  'Compensation & Payroll',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        decoration: InputDecoration(
                                          labelText: 'Compensation Model *',
                                          filled: true,
                                          fillColor: theme.cardColor,
                                          border: const OutlineInputBorder(),
                                        ),
                                        dropdownColor: theme.cardColor,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        value: payrollType,
                                        items: [
                                          DropdownMenuItem(
                                            value: 0,
                                            child: Text(
                                              'Hourly Wage',
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 1,
                                            child: Text(
                                              'Salaried (Fixed)',
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null)
                                            setModalState(
                                              () => payrollType = val,
                                            );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: baseRateCtrl,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: payrollType == 1
                                              ? 'Annual Salary (\$)'
                                              : 'Hourly Rate (\$)',
                                          filled: true,
                                          fillColor: theme.cardColor,
                                          border: const OutlineInputBorder(),
                                        ),
                                        validator: (v) =>
                                            v!.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: taxDeductionCtrl,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Flat Tax Withholding (%)',
                                          hintText: 'e.g. 15.0',
                                          filled: true,
                                          fillColor: theme.cardColor,
                                          border: const OutlineInputBorder(),
                                        ),
                                        validator: (v) =>
                                            v!.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),

                                Text(
                                  'HR & Compliance Documents',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: uploadedDocs.keys.map((key) {
                                    bool isUp = uploadedDocs[key]!.isNotEmpty;
                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: InkWell(
                                          onTap: () => pickAndUploadFile(key),
                                          child: Container(
                                            height: 80,
                                            decoration: BoxDecoration(
                                              color: isUp
                                                  ? Colors.green.withValues(
                                                      alpha: 0.1,
                                                    )
                                                  : theme.cardColor,
                                              border: Border.all(
                                                color: isUp
                                                    ? Colors.green
                                                    : theme.dividerColor
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isUp
                                                      ? Icons.check_circle
                                                      : Icons.upload_file,
                                                  size: 24,
                                                  color: isUp
                                                      ? Colors.green
                                                      : theme
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  key,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const Divider(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            // Ensure percentage is sent as a decimal (e.g., 15.0 -> 0.15) to match backend
                            double taxRaw =
                                double.tryParse(taxDeductionCtrl.text.trim()) ??
                                0.0;
                            double taxDecimal = taxRaw / 100.0;

                            final Map<String, dynamic> payload = {
                              'fullName': nameCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'phoneNumber': phoneCtrl.text.trim(),
                              'employeeNumber': empNumCtrl.text.trim(),
                              'department': selectedDept,
                              'jobTitle': selectedTitle,
                              // --- NEW PAYROLL PAYLOAD ---
                              'payrollType': payrollType,
                              'baseRate':
                                  double.tryParse(baseRateCtrl.text.trim()) ??
                                  0.0,
                              'taxDeductionPercentage': taxDecimal,

                              'governmentIdUrl': uploadedDocs['Government ID'],
                              'employmentContractUrl':
                                  uploadedDocs['Employment Contract'],
                              'nonDisclosureAgreementUrl': uploadedDocs['NDA'],
                            };

                            if (isEditing) {
                              bloc.add(EditStaffMember(employee.id, payload));
                            } else {
                              payload['role'] = roleType;
                              payload['sendInviteEmail'] = sendInvite;
                              bloc.add(AddStaffMember(payload));
                            }
                            Navigator.pop(dialogContext);
                          }
                        },
                        child: Text(
                          isEditing
                              ? 'Save Profile Changes'
                              : 'Provision Employee Account',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPermissionsModal(
    BuildContext parentContext,
    dynamic employee,
    ThemeData theme,
  ) {
    if (employee.role == 'Admin') {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(
          content: Text(
            'System Administrators inherit all system permissions globally.',
          ),
        ),
      );
      return;
    }

    final bloc = parentContext.read<StaffManagementBloc>();
    List<String> currentPerms = List.from(employee.permissions);

    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: theme.scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Access Control Matrix: ${employee.fullName}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configure granular role-based permissions.',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: theme.colorScheme.onSurface,
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  Expanded(
                    child: ListView(
                      children: _permissionGroups.entries.map((group) {
                        final allGroupKeys = group.value.keys.toList();
                        final bool allSelected = allGroupKeys.every(
                          (k) => currentPerms.contains(k),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    group.key,
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        if (allSelected) {
                                          currentPerms.removeWhere(
                                            (k) => allGroupKeys.contains(k),
                                          );
                                        } else {
                                          for (var k in allGroupKeys) {
                                            if (!currentPerms.contains(k))
                                              currentPerms.add(k);
                                          }
                                        }
                                      });
                                    },
                                    child: Text(
                                      allSelected
                                          ? 'Deselect All'
                                          : 'Select All',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...group.value.entries.map((perm) {
                              bool hasPerm = currentPerms.contains(perm.key);
                              return CheckboxListTile(
                                title: Text(
                                  perm.key,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  perm.value,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                value: hasPerm,
                                activeColor: theme.primaryColor,
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      currentPerms.add(perm.key);
                                    } else {
                                      currentPerms.remove(perm.key);
                                    }
                                  });
                                },
                              );
                            }),
                            const SizedBox(height: 24),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        bloc.add(UpdatePermissions(employee.id, currentPerms));
                        Navigator.pop(dialogContext);
                      },
                      child: const Text(
                        'Save Access Control List',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
