import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:roadside_service/core/utils/call_helper.dart';
import 'package:roadside_service/features/customer_crm/data/models/customer_crm_models.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/customer_crm_bloc.dart';

class CustomerCrmScreen extends StatefulWidget {
  const CustomerCrmScreen({super.key});
  @override
  State<CustomerCrmScreen> createState() => _CustomerCrmScreenState();
}

class _CustomerCrmScreenState extends State<CustomerCrmScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => sl<CustomerCrmBloc>()..add(FetchCustomers()),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor, // Light theme compliant
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, context),
                const SizedBox(height: 32),
                Expanded(
                  child: BlocConsumer<CustomerCrmBloc, CustomerCrmState>(
                    listener: (context, state) {
                      if (state is CustomerActionSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      } else if (state is CrmError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                    },
                    buildWhen: (prev, current) =>
                        current is CustomersLoaded || current is CrmLoading,
                    builder: (context, state) {
                      if (state is CrmLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is CustomersLoaded) {
                        final filtered = state.customers.where((c) {
                          return c.fullName.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              c.phone.contains(_searchQuery) ||
                              c.email.toLowerCase().contains(_searchQuery);
                        }).toList();
                        return _buildDesktopTable(filtered, theme);
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Profiles (CRM)',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Manage identities, fleets, and lifetime value.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search Name, Phone, or Email...',
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
            const SizedBox(width: 16),
            Builder(
              builder: (innerContext) => FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.person_add),
                label: const Text(
                  'Add Customer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showCreateCustomerForm(innerContext, theme),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopTable(List<CustomerModel> customers, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: ListView.separated(
        itemCount: customers.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
        itemBuilder: (ctx, i) {
          final c = customers[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
              child: Text(
                c.fullName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              c.fullName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${c.phone} • Joined ${DateFormat('MMM dd, yyyy').format(c.joinedAt)}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.phone_in_talk, color: Colors.green),
                  tooltip: 'Voice Call via Agora',
                  onPressed: () => triggerVoiceCall(
                    context: ctx,
                    dioClient: sl<DioClient>(),
                    receiverUserId: c.id,
                    currentUserId: 'ADMIN',
                    receiverName: c.fullName,
                    reason: 'CRM Direct Account Follow-up',
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${c.totalSpent.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${c.totalRequests} Jobs',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                FilledButton.tonal(
                  onPressed: () {
                    ctx.read<CustomerCrmBloc>().add(
                      FetchCustomerProfile(customerId: c.id),
                    );
                    _showProfileModal(ctx, theme);
                  },
                  child: const Text('Manage'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreateCustomerForm(BuildContext parentContext, ThemeData theme) {
    final bloc = parentContext.read<CustomerCrmBloc>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: parentContext,
      builder: (ctx) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Create Customer Identity',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'A secure B2C profile will be generated. Temporary login credentials will be emailed to the client automatically.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Divider(height: 48),
                TextFormField(
                  controller: nameCtrl,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Full Legal Name *',
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneCtrl,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Primary Phone Number *',
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailCtrl,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Email Address *',
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    icon: const Icon(Icons.person_add),
                    label: const Text(
                      'Provision Customer Identity',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        bloc.add(
                          CreateNewCustomer(
                            fullName: nameCtrl.text,
                            phone: phoneCtrl.text,
                            email: emailCtrl.text,
                          ),
                        );
                        Navigator.pop(ctx);
                      }
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

  void _showProfileModal(BuildContext parentContext, ThemeData theme) {
    final customerCrmBloc = parentContext.read<CustomerCrmBloc>();

    showGeneralDialog(
      context: parentContext,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      pageBuilder: (dialogContext, _, __) => BlocProvider.value(
        value: customerCrmBloc,
        child: Dialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: 1000,
            height: 800,
            padding: const EdgeInsets.all(40),
            child: BlocBuilder<CustomerCrmBloc, CustomerCrmState>(
              buildWhen: (prev, current) =>
                  current is ProfileLoading || current is CustomerProfileLoaded,
              builder: (context, state) {
                if (state is ProfileLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is CustomerProfileLoaded) {
                  return _ProfileTabs(
                    profile: state.profile,
                    bloc: context.read<CustomerCrmBloc>(),
                    theme: theme,
                  );
                }
                return Center(
                  child: Text(
                    'Error loading profile data.',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ).then((_) {
      customerCrmBloc.add(FetchCustomers());
    });
  }
}

class _ProfileTabs extends StatelessWidget {
  final CustomerProfileModel profile;
  final CustomerCrmBloc bloc;
  final ThemeData theme;

  const _ProfileTabs({
    required this.profile,
    required this.bloc,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
                    child: Text(
                      profile.customer.fullName.substring(0, 1),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.customer.fullName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'LTV: \$${profile.lifetimeValue.toStringAsFixed(2)} • ${profile.totalTows} Lifetime Jobs',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.phone),
                    label: const Text(
                      'Call Client',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => triggerVoiceCall(
                      context: context,
                      dioClient: sl<DioClient>(),
                      receiverUserId: profile.customer.id,
                      currentUserId: 'ADMIN',
                      receiverName: profile.customer.fullName,
                      reason: 'Customer Dossier Inquiry',
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.bolt),
                    label: const Text(
                      'Emergency Dispatch',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      context.go(
                        '/active-jobs',
                        extra: {
                          'prefill': {
                            'customerId': profile.customer.id,
                            'name': profile.customer.fullName,
                            'phone': profile.customer.phone,
                            'email': profile.customer.email,
                            'vehicles': profile.vehicles
                                .map(
                                  (v) => {
                                    'id': v.id,
                                    'year': v.year,
                                    'make': v.make,
                                    'model': v.model,
                                    'color': v.color,
                                    'licensePlate': v.licensePlate,
                                  },
                                )
                                .toList(),
                          },
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          TabBar(
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.disabledColor,
            indicatorColor: theme.primaryColor,
            tabs: const [
              Tab(text: 'Identity & Details'),
              Tab(text: 'Vehicle Garage'),
              Tab(text: 'Job History Ledger'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              children: [
                _buildIdentityTab(context),
                _buildVehiclesTab(context),
                _buildJobHistoryTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityTab(BuildContext context) {
    final nameCtrl = TextEditingController(text: profile.customer.fullName);
    final phoneCtrl = TextEditingController(text: profile.customer.phone);
    final emailCtrl = TextEditingController(text: profile.customer.email);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update Secure Identity',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Phone',
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                onPressed: () => bloc.add(
                  UpdateCustomerInfo(
                    customerId: profile.customer.id,
                    fullName: nameCtrl.text,
                    phone: phoneCtrl.text,
                    email: emailCtrl.text,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Danger Zone',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.all(16),
                  ),
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Force Password Reset'),
                  onPressed: () {},
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.all(16),
                  ),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Purge Customer Record'),
                  onPressed: () {
                    bloc.add(DeleteCustomer(customerId: profile.customer.id));
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehiclesTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Registered Fleet',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.directions_car),
              label: const Text('Add Vehicle'),
              onPressed: () => _showVehicleForm(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: profile.vehicles.isEmpty
              ? Center(
                  child: Text(
                    'No vehicles attached to this profile.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: profile.vehicles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final v = profile.vehicles[i];
                    return Card(
                      color: theme.scaffoldBackgroundColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: v.isDefault
                              ? theme.primaryColor
                              : theme.dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Icon(
                          Icons.directions_car,
                          color: v.isDefault
                              ? theme.primaryColor
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                          size: 32,
                        ),
                        title: Text(
                          '${v.year} ${v.make} ${v.model} (${v.color})',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          'Plate: ${v.licensePlate ?? 'N/A'}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (v.isDefault)
                              Chip(
                                label: const Text(
                                  'Primary',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                                backgroundColor: theme.primaryColor,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                side: BorderSide.none,
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showVehicleForm(context, vehicleToEdit: v),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => bloc.add(
                                RemoveCustomerVehicle(
                                  customerId: profile.customer.id,
                                  vehicleId: v.id,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildJobHistoryTab(BuildContext context) {
    if (profile.jobHistory.isEmpty) {
      return Center(
        child: Text(
          'No job history available.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: profile.jobHistory.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
        itemBuilder: (ctx, i) {
          final job = profile.jobHistory[i];
          Color statusColor = job.status == 'Completed'
              ? Colors.green
              : job.status == 'Cancelled'
              ? Colors.red
              : Colors.orange;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            title: Text(
              job.serviceType,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              DateFormat('MMM dd, yyyy • HH:mm a').format(job.date),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '\$${job.totalPaid.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      job.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.open_in_new, color: Colors.blue),
                  tooltip: 'Manage Dispatch Incident',
                  onPressed: () {
                    Navigator.pop(context);
                    context.go(
                      '/active-jobs',
                      extra: {'autoOpenJobId': job.requestId},
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showVehicleForm(
    BuildContext parentContext, {
    CustomerVehicleModel? vehicleToEdit,
  }) {
    final bool isEditing = vehicleToEdit != null;
    final formKey = GlobalKey<FormState>();
    final plateCtrl = TextEditingController(
      text: vehicleToEdit?.licensePlate ?? '',
    );
    final colorCtrl = TextEditingController(text: vehicleToEdit?.color ?? '');
    bool isDefault = vehicleToEdit?.isDefault ?? false;

    final Map<String, List<String>> brandDatabase = {
      'Toyota': ['Camry', 'Corolla', 'RAV4', 'Highlander', 'Tacoma'],
      'Honda': ['Civic', 'Accord', 'CR-V', 'Pilot'],
      'Ford': ['F-150', 'Mustang', 'Explorer', 'Escape'],
      'Chevrolet': ['Silverado', 'Malibu', 'Equinox', 'Tahoe'],
      'BMW': ['3 Series', '5 Series', 'X3', 'X5'],
      'Mercedes-Benz': ['C-Class', 'E-Class', 'GLC', 'GLE'],
      'Nissan': ['Altima', 'Sentra', 'Rogue', 'Pathfinder'],
    };

    String? selectedMake = vehicleToEdit?.make;
    String? selectedModel = vehicleToEdit?.model;
    int selectedYear = vehicleToEdit?.year ?? DateTime.now().year;
    List<int> years = List.generate(30, (index) => DateTime.now().year - index);

    if (selectedMake != null && !brandDatabase.containsKey(selectedMake)) {
      selectedMake = null;
      selectedModel = null;
    }

    showDialog(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text(
            isEditing ? 'Edit Vehicle Details' : 'Attach Vehicle',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      key: ValueKey(selectedYear),
                      initialValue: selectedYear,
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Year',
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                        border: const OutlineInputBorder(),
                      ),
                      items: years
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text(y.toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() => selectedYear = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey(selectedMake),
                      initialValue: selectedMake,
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Make',
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                        border: const OutlineInputBorder(),
                      ),
                      items: brandDatabase.keys
                          .map(
                            (make) => DropdownMenuItem(
                              value: make,
                              child: Text(make),
                            ),
                          )
                          .toList(),
                      validator: (v) => v == null ? 'Required' : null,
                      onChanged: (v) => setModalState(() {
                        selectedMake = v!;
                        selectedModel = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey(selectedModel),
                      initialValue: selectedModel,
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Model',
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                        border: const OutlineInputBorder(),
                      ),
                      items: selectedMake == null
                          ? []
                          : brandDatabase[selectedMake]!
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m),
                                  ),
                                )
                                .toList(),
                      validator: (v) => v == null ? 'Required' : null,
                      onChanged: (v) => setModalState(() => selectedModel = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: colorCtrl,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Exterior Color *',
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: plateCtrl,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'License Plate (Optional)',
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(
                        'Set as Primary Vehicle',
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      value: isDefault,
                      activeColor: theme.primaryColor,
                      onChanged: (v) => setModalState(() => isDefault = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final payload = {
                    'year': selectedYear,
                    'make': selectedMake,
                    'model': selectedModel,
                    'color': colorCtrl.text,
                    'licensePlate': plateCtrl.text,
                    'isDefault': isDefault,
                  };

                  if (isEditing) {
                    bloc.add(
                      EditCustomerVehicle(
                        customerId: profile.customer.id,
                        vehicleId: vehicleToEdit.id,
                        vehicleData: payload,
                      ),
                    );
                  } else {
                    bloc.add(
                      AddCustomerVehicle(
                        customerId: profile.customer.id,
                        vehicleData: payload,
                      ),
                    );
                  }
                  Navigator.pop(ctx);
                }
              },
              child: Text(isEditing ? 'Save Changes' : 'Attach to Garage'),
            ),
          ],
        ),
      ),
    );
  }
}
