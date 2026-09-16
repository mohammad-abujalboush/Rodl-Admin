import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:roadside_service/features/staff_management/presentation/bloc/employee_payroll_bloc.dart';
import '../../../../core/di/injection_container.dart';

class EmployeePayrollScreen extends StatelessWidget {
  const EmployeePayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EmployeePayrollBloc>()..add(FetchEmployeePayroll()),
      child: const _EmployeePayrollView(),
    );
  }
}

class _EmployeePayrollView extends StatefulWidget {
  const _EmployeePayrollView();

  @override
  State<_EmployeePayrollView> createState() => _EmployeePayrollViewState();
}

class _EmployeePayrollViewState extends State<_EmployeePayrollView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER & ACTIONS ---
              BlocBuilder<EmployeePayrollBloc, EmployeePayrollState>(
                builder: (context, state) {
                  bool hasPending =
                      state is EmployeePayrollLoaded &&
                      state.payrolls.isNotEmpty;
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
                            'Internal Staff Payroll',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Manage salaried and hourly employee timesheets, bonuses, and tax deductions.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh Ledger',
                            color: theme.colorScheme.onSurface,
                            onPressed: () => context
                                .read<EmployeePayrollBloc>()
                                .add(FetchEmployeePayroll()),
                          ),
                          const SizedBox(width: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.account_balance),
                            label: const Text('Execute HR Batch Wire'),
                            style: FilledButton.styleFrom(
                              backgroundColor: hasPending
                                  ? Colors.blue.shade700
                                  : theme.disabledColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: hasPending
                                ? () => _showExecutePayrollModal(
                                    context,
                                    state,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // --- CONTENT ---
              Expanded(
                child: BlocConsumer<EmployeePayrollBloc, EmployeePayrollState>(
                  listener: (context, state) {
                    if (state is EmployeePayrollSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    } else if (state is EmployeePayrollError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: theme.colorScheme.error,
                        ),
                      );
                    }
                  },
                  buildWhen: (prev, current) =>
                      current is! EmployeePayrollSuccess,
                  builder: (context, state) {
                    if (state is EmployeePayrollLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state is EmployeePayrollLoaded) {
                      if (state.payrolls.isEmpty)
                        return _buildEmptyState(theme);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SUMMARY CARDS
                          LayoutBuilder(
                            builder: (context, constraints) {
                              double spacing = 16.0;
                              int columns = constraints.maxWidth > 800
                                  ? 3
                                  : (constraints.maxWidth > 500 ? 2 : 1);
                              double cardWidth =
                                  (constraints.maxWidth -
                                          (spacing * (columns - 1))) /
                                      columns -
                                  0.1;

                              return Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                children: [
                                  SizedBox(
                                    width: cardWidth,
                                    child: _SummaryCard(
                                      title: 'Total Net Payout',
                                      value: currencyFormat.format(
                                        state.totalNetPayout,
                                      ),
                                      icon: Icons.payments,
                                      isPrimary: true,
                                      theme: theme,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _SummaryCard(
                                      title: 'Total Taxes Withheld',
                                      value: currencyFormat.format(
                                        state.totalTaxWithheld,
                                      ),
                                      icon: Icons.account_balance,
                                      theme: theme,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _SummaryCard(
                                      title: 'Staff Members',
                                      value: state.payrolls.length.toString(),
                                      icon: Icons.badge,
                                      theme: theme,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          Expanded(
                            child: _buildDesktopTable(
                              context,
                              state.payrolls,
                              theme,
                              currencyFormat,
                            ),
                          ),
                        ],
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
    );
  }

  // --- EMPTY STATE ---
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 80, color: Colors.blue.shade300),
          const SizedBox(height: 16),
          Text(
            'All Staff Paid',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no pending timesheets, bonuses, or salary runs.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // --- DATA TABLE ---
  Widget _buildDesktopTable(
    BuildContext context,
    List<EmployeePayrollPreviewModel> payrolls,
    ThemeData theme,
    NumberFormat format,
  ) {
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
            constraints: const BoxConstraints(minWidth: 1000),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.resolveWith(
                (states) => theme.primaryColor.withValues(alpha: 0.05),
              ),
              dataRowMaxHeight: 70,
              columns: [
                DataColumn(
                  label: Text(
                    'Employee',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Pay Structure',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Gross Base',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Bonuses',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Taxes (-)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Net Payout',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const DataColumn(label: Text('')), // Actions
              ],
              rows: payrolls.map((p) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: Icon(
                              Icons.person,
                              size: 16,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                p.department,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Chip(
                            label: Text(
                              p.payrollType == 1 ? 'Salaried' : 'Hourly',
                              style: TextStyle(
                                fontSize: 10,
                                color: p.payrollType == 1
                                    ? Colors.purple
                                    : Colors.orange.shade700,
                              ),
                            ),
                            backgroundColor: p.payrollType == 1
                                ? Colors.purple.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                          ),
                          Text(
                            p.payrollType == 1
                                ? '${format.format(p.baseRate)} / yr'
                                : '${p.unpaidHours} hrs @ ${format.format(p.baseRate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        format.format(p.grossBasePay),
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),
                    DataCell(
                      Text(
                        format.format(p.pendingBonuses),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        format.format(p.taxDeductionAmount),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                    DataCell(
                      Text(
                        format.format(p.netPayout),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.add_box, color: Colors.blue),
                        tooltip: 'Add Commission / Bonus',
                        onPressed: () => _showAddBonusDialog(
                          context,
                          p.employeeProfileId,
                          p.fullName,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // --- ADD BONUS MODAL ---
  void _showAddBonusDialog(
    BuildContext context,
    String employeeId,
    String empName,
  ) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final bloc = context.read<EmployeePayrollBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Append Bonus/Commission',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adding bonus for $empName',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: const InputDecoration(
                labelText: 'Amount (\$)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: const InputDecoration(
                labelText: 'Reason (e.g. Call Center Upsell)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(amountController.text);
              if (amt != null && reasonController.text.isNotEmpty) {
                bloc.add(
                  AddEmployeeBonus(
                    employeeProfileId: employeeId,
                    amount: amt,
                    reason: reasonController.text,
                  ),
                );
                Navigator.pop(dialogContext);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Valid amount and reason required.'),
                  ),
                );
              }
            },
            child: const Text('Add to Ledger'),
          ),
        ],
      ),
    );
  }

  // --- EXECUTE BATCH MODAL ---
  void _showExecutePayrollModal(
    BuildContext parentContext,
    EmployeePayrollLoaded state,
  ) {
    final bloc = parentContext.read<EmployeePayrollBloc>();
    final refController = TextEditingController();
    bool isBiWeekly = true;
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: Theme.of(parentContext).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Confirm HR Batch Wire',
                style: TextStyle(
                  color: Theme.of(parentContext).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are about to lock the ledgers and mark timesheets and bonuses as PAID. '
                  'This will clear ${currencyFormat.format(state.totalNetPayout)} across ${state.payrolls.length} employees.',
                  style: TextStyle(
                    color: Theme.of(parentContext).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(parentContext).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        parentContext,
                      ).dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'Process Salaried Staff',
                      style: TextStyle(
                        color: Theme.of(parentContext).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Include bi-weekly base pay for salaried workers.',
                      style: TextStyle(
                        color: Theme.of(
                          parentContext,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    value: isBiWeekly,
                    activeColor: Colors.blue,
                    onChanged: (val) => setModalState(() => isBiWeekly = val),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: refController,
                  style: TextStyle(
                    color: Theme.of(parentContext).colorScheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Bank Reference / Trace ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (refController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Bank Reference is required.'),
                    ),
                  );
                  return;
                }
                bloc.add(
                  ExecuteEmployeeBatch(
                    bankWireReference: refController.text.trim(),
                    isBiWeeklySalaryRun: isBiWeekly,
                  ),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Execute & Lock Ledgers'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- SUMMARY CARD COMPONENT ---
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isPrimary;
  final ThemeData theme;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.isPrimary = false,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isPrimary ? Colors.blue.shade700 : theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPrimary
            ? BorderSide.none
            : BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: isPrimary
                    ? Colors.white70
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPrimary
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  icon,
                  size: 32,
                  color: isPrimary
                      ? Colors.white30
                      : Colors.blue.withValues(alpha: 0.2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
