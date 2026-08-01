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
                  decoration: InputDecoration(
                    hintText: 'Search employees by name, ID, or role...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
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
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else if (state is StaffSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  buildWhen: (prev, current) =>
                      current is StaffLoaded || current is StaffLoading,
                  builder: (context, state) {
                    if (state is StaffLoading)
                      return const Center(child: CircularProgressIndicator());
                    if (state is StaffLoaded) {
                      final filtered = state.staff
                          .where(
                            (s) =>
                                s.fullName.toLowerCase().contains(
                                  _searchQuery,
                                ) ||
                                s.employeeNumber.toLowerCase().contains(
                                  _searchQuery,
                                ) ||
                                s.department.toLowerCase().contains(
                                  _searchQuery,
                                ),
                          )
                          .toList();

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Human Resources CRM',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage internal corporate staff, documentation, and RBAC permissions.',
              style: TextStyle(color: theme.disabledColor),
            ),
          ],
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          ),
          icon: const Icon(Icons.badge),
          label: const Text('Provision New Employee'),
          onPressed: () => _showEmployeeModal(context, theme, null),
        ),
      ],
    );
  }

  Widget _buildStaffTable(List<StaffMemberModel> staff, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ListView.separated(
        itemCount: staff.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final s = staff[index];
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
                Text(
                  s.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                if (!s.isActive)
                  Chip(
                    label: const Text(
                      'Suspended',
                      style: TextStyle(color: Colors.red, fontSize: 10),
                    ),
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                if (s.role == 'Admin')
                  Chip(
                    label: const Text(
                      'System Admin',
                      style: TextStyle(color: Colors.purple, fontSize: 10),
                    ),
                    backgroundColor: Colors.purple.withValues(alpha: 0.1),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            subtitle: Text(
              '${s.jobTitle} • ${s.department} • ${s.employeeNumber}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Manage Profile',
                  onPressed: () => _showEmployeeModal(context, theme, s),
                ),
                IconButton(
                  icon: const Icon(Icons.vpn_key, color: Colors.orange),
                  tooltip: 'Manage Permissions',
                  onPressed: () => _showPermissionsModal(context, s, theme),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEmployeeModal(
    BuildContext parentContext,
    ThemeData theme,
    StaffMemberModel? employee,
  ) {
    final isEditing = employee != null;
    final formKey = GlobalKey<FormState>();
    final bloc = parentContext.read<StaffManagementBloc>();

    final nameCtrl = TextEditingController(text: employee?.fullName);
    final emailCtrl = TextEditingController(text: employee?.email);
    final phoneCtrl = TextEditingController(text: employee?.phoneNumber);
    final empNumCtrl = TextEditingController(text: employee?.employeeNumber);

    // Safeguard the Dropdown State
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
                  content: Text('Document attached.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }

          return Dialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              width: 900,
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
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(dialogContext),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 48),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: emailCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Corporate Email *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: phoneCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (!isEditing)
                                CheckboxListTile(
                                  title: const Text(
                                    'Send Welcome Email & Password',
                                  ),
                                  value: sendInvite,
                                  onChanged: (val) => setModalState(
                                    () => sendInvite = val ?? true,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isEditing)
                                DropdownButtonFormField<int>(
                                  decoration: const InputDecoration(
                                    labelText: 'System Access Level *',
                                    border: OutlineInputBorder(),
                                  ),
                                  value: roleType,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Text('Standard Employee'),
                                    ),
                                    DropdownMenuItem(
                                      value: 4,
                                      child: Text('System Administrator'),
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
                                decoration: const InputDecoration(
                                  labelText:
                                      'Employee ID (Auto-generated if blank)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Department *',
                                        border: OutlineInputBorder(),
                                      ),
                                      value: selectedDept,
                                      items: _corporateStructure.keys
                                          .map(
                                            (dept) => DropdownMenuItem(
                                              value: dept,
                                              child: Text(dept),
                                            ),
                                          )
                                          .toList(),
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
                                      decoration: const InputDecoration(
                                        labelText: 'Job Title *',
                                        border: OutlineInputBorder(),
                                      ),
                                      value: selectedTitle,
                                      items: selectedDept == null
                                          ? []
                                          : _corporateStructure[selectedDept]!
                                                .map(
                                                  (title) => DropdownMenuItem(
                                                    value: title,
                                                    child: Text(title),
                                                  ),
                                                )
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
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: uploadedDocs.keys.map((key) {
                        bool isUp = uploadedDocs[key]!.isNotEmpty;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () => pickAndUploadFile(key),
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: isUp
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : theme.scaffoldBackgroundColor,
                                  border: Border.all(
                                    color: isUp
                                        ? Colors.green
                                        : theme.dividerColor,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isUp ? Icons.check : Icons.upload,
                                      size: 24,
                                      color: isUp ? Colors.green : Colors.grey,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      key,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final Map<String, dynamic> payload = {
                              'fullName': nameCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'phoneNumber': phoneCtrl.text.trim(),
                              'employeeNumber': empNumCtrl.text.trim(),
                              'department': selectedDept,
                              'jobTitle': selectedTitle,
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
                              ? 'Save Changes'
                              : 'Provision Employee Account',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
    StaffMemberModel employee,
    ThemeData theme,
  ) {
    if (employee.role == 'Admin') {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(
          content: Text(
            'System Administrators inherit all permissions globally.',
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
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              width: 800,
              height: 750,
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Access Matrix: ${employee.fullName}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // --- THE NEW GRANULAR PERMISSIONS LIST ---
                  Expanded(
                    child: ListView(
                      children: _permissionGroups.entries.map((group) {
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
                                  alpha: 0.05,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              width: double.infinity,
                              child: Text(
                                group.key,
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...group.value.entries.map((perm) {
                              bool hasPerm = currentPerms.contains(perm.key);
                              return CheckboxListTile(
                                title: Text(
                                  perm.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  perm.value,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                value: hasPerm,
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true)
                                      currentPerms.add(perm.key);
                                    else
                                      currentPerms.remove(perm.key);
                                  });
                                },
                              );
                            }).toList(),
                            const SizedBox(height: 24),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      onPressed: () {
                        bloc.add(UpdatePermissions(employee.id, currentPerms));
                        Navigator.pop(dialogContext);
                      },
                      child: const Text(
                        'Save Access Control List',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
