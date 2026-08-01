import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:roadside_service/features/system_settings/data/models/system_settings_models.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/system_settings_bloc.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  String _staffSearchQuery = '';
  final _globalFormKey = GlobalKey<FormState>();

  // --- CACHED CONTROLLERS (Prevents cursor jumping on state rebuilds) ---
  final _commissionCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _supportEmailCtrl = TextEditingController();
  bool _isMaintenance = false;
  bool _isConfigInitialized = false;

  @override
  void dispose() {
    _commissionCtrl.dispose();
    _taxCtrl.dispose();
    _radiusCtrl.dispose();
    _supportEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => sl<SystemSettingsBloc>()..add(FetchSystemSettings()),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, context),
                const SizedBox(height: 32),
                Expanded(
                  child: BlocConsumer<SystemSettingsBloc, SystemSettingsState>(
                    listener: (context, state) {
                      // Handle notifications
                      if (state is SettingsActionSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      } else if (state is SettingsError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }

                      // Safely initialize the text controllers ONLY once when data is fetched
                      if (state is SettingsLoaded && !_isConfigInitialized) {
                        _commissionCtrl.text =
                            (state.globalConfig.platformCommissionRate * 100)
                                .toStringAsFixed(2);
                        _taxCtrl.text = (state.globalConfig.taxRate * 100)
                            .toStringAsFixed(2);
                        _radiusCtrl.text = state
                            .globalConfig
                            .maxDispatchRadiusKm
                            .toString();
                        _supportEmailCtrl.text =
                            state.globalConfig.supportEmail;
                        setState(() {
                          _isMaintenance = state.globalConfig.isMaintenanceMode;
                          _isConfigInitialized = true;
                        });
                      }
                    },
                    buildWhen: (prev, current) =>
                        current is! SettingsActionSuccess &&
                        current is! SettingsError,
                    builder: (context, state) {
                      if (state is SettingsLoading && !_isConfigInitialized) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state is SettingsLoaded) {
                        final filteredStaff = state.staffList
                            .where(
                              (s) =>
                                  s.fullName.toLowerCase().contains(
                                    _staffSearchQuery,
                                  ) ||
                                  s.email.toLowerCase().contains(
                                    _staffSearchQuery,
                                  ) ||
                                  s.role.toLowerCase().contains(
                                    _staffSearchQuery,
                                  ),
                            )
                            .toList();

                        return ResponsiveBuilder(
                          builder: (context, sizingInfo) {
                            // --- DESKTOP LAYOUT (Split, Independent Scrolling) ---
                            if (sizingInfo.isDesktop) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: SizedBox(
                                      height: double.infinity,
                                      child: SingleChildScrollView(
                                        child: _buildGlobalConfigPanel(
                                          context,
                                          theme,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 32),
                                  Expanded(
                                    flex: 2,
                                    child: _buildStaffPanel(
                                      context,
                                      filteredStaff,
                                      theme,
                                      isDesktop: true,
                                    ),
                                  ),
                                ],
                              );
                            }

                            // --- MOBILE/TABLET LAYOUT (Single Continuous Scroll) ---
                            return SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildGlobalConfigPanel(context, theme),
                                  const SizedBox(height: 32),
                                  _buildStaffPanel(
                                    context,
                                    filteredStaff,
                                    theme,
                                    isDesktop: false,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
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
              'Platform Control & Security',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage global environment operations, financial limits, and staff authorization structures.',
              style: TextStyle(color: theme.disabledColor),
            ),
          ],
        ),
        Builder(
          builder: (ctx) => FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Resync Architecture'),
            onPressed: () =>
                ctx.read<SystemSettingsBloc>().add(FetchSystemSettings()),
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalConfigPanel(BuildContext context, ThemeData theme) {
    final bloc = context.read<SystemSettingsBloc>();

    return Form(
      key: _globalFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- EMERGENCY CONTROLS ---
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _isMaintenance
                  ? Colors.red.withValues(alpha: 0.1)
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isMaintenance ? Colors.red : theme.dividerColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: _isMaintenance ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Emergency Controls',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isMaintenance ? Colors.red : Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(
                    'Environment Maintenance Killswitch',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isMaintenance ? Colors.red : Colors.white,
                    ),
                  ),
                  subtitle: const Text(
                    'Suspends external client APIs and freezes driver allocations.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: _isMaintenance,
                  activeColor: Colors.red,
                  activeTrackColor: Colors.red.withValues(alpha: 0.3),
                  onChanged: (val) => setState(() => _isMaintenance = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- FINANCIAL PARAMETERS ---
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      'Financial Parameters',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _commissionCtrl,
                  decoration: InputDecoration(
                    labelText: 'Platform Commission Yield (%)',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    suffixIcon: const Icon(Icons.percent),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _taxCtrl,
                  decoration: InputDecoration(
                    labelText: 'Regional Tax Base Rate (%)',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    suffixIcon: const Icon(Icons.percent),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- OPERATIONAL PARAMETERS ---
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.settings_applications,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Operational Parameters',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _radiusCtrl,
                  decoration: InputDecoration(
                    labelText: 'Max Auto-Dispatch Radius (KM)',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    suffixIcon: const Icon(Icons.radar),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _supportEmailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Public Helpdesk Email',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    suffixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  validator: (v) => v!.isEmpty || !v.contains('@')
                      ? 'Valid email required'
                      : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: FilledButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: const Text(
                'Commit Configuration to Cloud',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onPressed: () {
                if (_globalFormKey.currentState!.validate()) {
                  bloc.add(
                    UpdateGlobalVariables(
                      settings: GlobalSettingsModel(
                        platformCommissionRate:
                            (double.tryParse(_commissionCtrl.text) ?? 20.0) /
                            100.0,
                        taxRate:
                            (double.tryParse(_taxCtrl.text) ?? 13.0) / 100.0,
                        isMaintenanceMode: _isMaintenance,
                        maxDispatchRadiusKm:
                            int.tryParse(_radiusCtrl.text) ?? 50,
                        supportEmail: _supportEmailCtrl.text,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffPanel(
    BuildContext context,
    List<StaffUserModel> staff,
    ThemeData theme, {
    required bool isDesktop,
  }) {
    final bloc = context.read<SystemSettingsBloc>();

    Widget listWidget = ListView.separated(
      // FIX: Seamlessly handle unbounded height exceptions on mobile by utilizing shrinkWrap
      shrinkWrap: !isDesktop,
      physics: isDesktop
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: staff.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
      itemBuilder: (ctx, i) {
        final s = staff[i];
        final bool isAdmin = s.role.toLowerCase().contains('admin');

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          leading: CircleAvatar(
            backgroundColor: s.isActive
                ? theme.colorScheme.secondary.withValues(alpha: 0.2)
                : Colors.red.withValues(alpha: 0.2),
            child: Icon(
              Icons.shield,
              color: s.isActive ? theme.colorScheme.secondary : Colors.red,
            ),
          ),
          title: Row(
            children: [
              Text(
                s.fullName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  decoration: s.isActive ? null : TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 8),
              if (isAdmin)
                Chip(
                  label: const Text(
                    'System Admin',
                    style: TextStyle(fontSize: 10, color: Colors.purple),
                  ),
                  backgroundColor: Colors.purple.withValues(alpha: 0.2),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              if (!s.isActive)
                Chip(
                  label: const Text(
                    'Suspended',
                    style: TextStyle(fontSize: 10, color: Colors.red),
                  ),
                  backgroundColor: Colors.red.withValues(alpha: 0.2),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
            ],
          ),
          subtitle: Text(
            '${s.role} | ${s.email}',
            style: TextStyle(color: theme.disabledColor),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.key),
                label: const Text('Access Map'),
                onPressed: s.isActive
                    ? () => _showPrivilegesModal(context, s)
                    : null,
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(
                  s.isActive ? Icons.block : Icons.restore,
                  color: s.isActive ? Colors.red : Colors.green,
                ),
                tooltip: s.isActive ? 'Lock Out User' : 'Restore Connection',
                onPressed: () => _confirmSuspension(context, s, bloc),
              ),
            ],
          ),
        );
      },
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Access Control Matrix',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Provision User'),
                  onPressed: () => _showInviteModal(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Name, Role, or Email...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) =>
                  setState(() => _staffSearchQuery = val.toLowerCase()),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          if (staff.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(
                child: Text(
                  'No matching infrastructure records found.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            // FIX: If we are on Desktop, this claims the rest of the unbounded height securely. If mobile, it fits naturally.
            isDesktop ? Expanded(child: listWidget) : listWidget,
        ],
      ),
    );
  }

  void _confirmSuspension(
    BuildContext context,
    StaffUserModel user,
    SystemSettingsBloc bloc,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          user.isActive ? 'Suspend Security Node?' : 'Reactivate Profile?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          user.isActive
              ? 'This action will instantly terminate all active JWT sessions for ${user.fullName} and reject further API access.'
              : 'This will restore ${user.fullName}\'s ability to authenticate using their existing credentials.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel Request'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: user.isActive ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              bloc.add(
                ToggleStaffStatus(staffId: user.id, isActive: !user.isActive),
              );
              Navigator.pop(ctx);
            },
            child: Text(
              user.isActive ? 'Execute Suspension' : 'Confirm Restoration',
            ),
          ),
        ],
      ),
    );
  }

  void _showInviteModal(BuildContext parentContext) {
    final bloc = parentContext.read<SystemSettingsBloc>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedRole = 'Dispatcher';

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        final theme = Theme.of(parentContext);
        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          title: const Text(
            'Provision New Network Identity',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Legal Name',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (v) => v!.isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Corporate Email',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (v) => !v!.contains('@')
                        ? 'Valid domain email required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Initial Base Role',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                    dropdownColor: theme.cardColor,
                    value: selectedRole,
                    items:
                        [
                              'Administrator',
                              'Operations Manager',
                              'Dispatcher',
                              'Financial Controller',
                            ]
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null) selectedRole = val;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abort'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  bloc.add(
                    InviteStaffMember(
                      fullName: nameCtrl.text,
                      email: emailCtrl.text,
                      role: selectedRole,
                    ),
                  );
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Generate Activation Link'),
            ),
          ],
        );
      },
    );
  }

  void _showPrivilegesModal(BuildContext parentContext, StaffUserModel staff) {
    if (staff.role.toLowerCase().contains('admin')) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(
          content: Text(
            'System Administrators inherently bypass all RBAC locks. Modify role to restrict.',
          ),
        ),
      );
      return;
    }

    final bloc = parentContext.read<SystemSettingsBloc>();
    List<String> currentPerms = List.from(staff.permissions);

    final Map<String, Map<String, String>> permissionGroups = {
      'Fleet & CRM Access': {
        'ViewUsers': 'View staff, drivers, and customer directories.',
        'ManageDrivers': 'Onboard, approve, suspend, and edit driver profiles.',
        'ManageStaff':
            'Provision new staff, edit HR records, and suspend accounts.',
        'ManageCustomers': 'Edit customer CRM profiles and vehicle garages.',
      },
      'Dispatch Routing': {
        'ViewRequests':
            'View active fleet map, live dispatches, and heatmap history.',
        'ManageRequests':
            'Update job statuses, assign drivers, and edit active dispatches.',
        'ManualDispatch':
            'Create emergency manual dispatch jobs and route them.',
        'CancelJobs':
            'Force cancel active jobs and apply cancellation penalties.',
      },
      'Finance & Treasury': {
        'ViewFinance':
            'View financial KPIs, revenue dashboards, and invoice history.',
        'ManageFinance': 'Create, edit, and delete B2B/B2C invoices.',
        'IssueRefunds': 'Process and approve Moneris payment refunds.',
        'OverridePricing':
            'Manually override total job fares and add custom surcharges.',
      },
    };

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        final theme = Theme.of(parentContext);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: theme.scaffoldBackgroundColor,
              title: Text(
                'Security Matrix: ${staff.fullName}',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 700,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Changes to Role-Based Access Control take effect upon the user\'s next API interaction.',
                              style: TextStyle(
                                color: Colors.orange.shade200,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // FIX: Replaced Expanded with Flexible + shrinkWrap: true so the dialog never overflows vertically
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: permissionGroups.entries.map((group) {
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
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                width: double.infinity,
                                child: Text(
                                  group.key,
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
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
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    perm.value,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  value: hasPerm,
                                  dense: true,
                                  activeColor: theme.primaryColor,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true)
                                        currentPerms.add(perm.key);
                                      else
                                        currentPerms.remove(perm.key);
                                    });
                                  },
                                );
                              }).toList(),
                              const SizedBox(height: 16),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Discard'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.local_fire_department),
                  onPressed: () {
                    bloc.add(
                      UpdateStaffPermissions(
                        staffId: staff.id,
                        permissions: currentPerms,
                      ),
                    );
                    Navigator.pop(dialogContext);
                  },
                  label: const Text('Burn Policies to Token'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
