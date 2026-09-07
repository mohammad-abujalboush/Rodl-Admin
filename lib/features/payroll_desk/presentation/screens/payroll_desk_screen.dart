import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';
import 'package:roadside_service/features/payroll_desk/data/models/driver_payout_preview_model.dart';
import 'package:roadside_service/features/payroll_desk/data/models/driver_payout_detail_model.dart';
import 'package:roadside_service/features/payroll_desk/data/models/payout_history_model.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/payroll_desk_bloc.dart';

class PayrollDeskScreen extends StatefulWidget {
  const PayrollDeskScreen({super.key});

  @override
  State<PayrollDeskScreen> createState() => _PayrollDeskScreenState();
}

class _PayrollDeskScreenState extends State<PayrollDeskScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return BlocProvider(
      create: (_) => sl<PayrollDeskBloc>()..add(FetchPayrollPreview()),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor, // Light mode compliant
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER & ACTIONS ---
                BlocBuilder<PayrollDeskBloc, PayrollDeskState>(
                  builder: (context, state) {
                    bool hasPending =
                        state is PayrollLoaded && state.payouts.isNotEmpty;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payroll & Settlement Desk',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Manage driver earnings, manual adjustments, and batch wire transfers.',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Refresh Ledger',
                              color: theme.colorScheme.onSurface,
                              onPressed: () => context
                                  .read<PayrollDeskBloc>()
                                  .add(FetchPayrollPreview()),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.account_balance),
                              label: const Text('Execute Batch Wire'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasPending
                                    ? Colors.green.shade700
                                    : theme.disabledColor,
                                foregroundColor: Colors.white,
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
                                      state as PayrollLoaded,
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

                // --- TABS ---
                TabBar(
                  controller: _tabController,
                  labelColor: theme.primaryColor,
                  unselectedLabelColor: theme.disabledColor,
                  indicatorColor: theme.primaryColor,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.pending_actions),
                      text: 'Active Unpaid Ledger',
                    ),
                    Tab(
                      icon: Icon(Icons.history),
                      text: 'Executed Batch History',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- CONTENT ---
                Expanded(
                  child: BlocConsumer<PayrollDeskBloc, PayrollDeskState>(
                    listener: (context, state) {
                      if (state is PayrollActionSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      } else if (state is PayrollError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                    },
                    buildWhen: (prev, current) =>
                        current is! PayrollActionSuccess,
                    builder: (context, state) {
                      if (state is PayrollLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is PayrollLoaded) {
                        return TabBarView(
                          controller: _tabController,
                          children: [
                            _buildActiveLedgerTab(
                              context,
                              state,
                              theme,
                              currencyFormat,
                            ),
                            _buildHistoryTab(
                              state.history,
                              theme,
                              currencyFormat,
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
      ),
    );
  }

  // --- TAB 1: ACTIVE UNPAID LEDGER ---
  Widget _buildActiveLedgerTab(
    BuildContext context,
    PayrollLoaded state,
    ThemeData theme,
    NumberFormat currencyFormat,
  ) {
    if (state.payouts.isEmpty) return _buildEmptyState(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SUMMARY CARDS (FIXED TO BE RESPONSIVE)
        LayoutBuilder(
          builder: (context, constraints) {
            double spacing = 16.0;
            int columns = constraints.maxWidth > 800
                ? 3
                : (constraints.maxWidth > 500 ? 2 : 1);
            double cardWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns -
                0.1;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _SummaryCard(
                    title: 'Total Net to Transfer',
                    value: currencyFormat.format(state.totalNetPayout),
                    icon: Icons.payments,
                    isPrimary: true,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _SummaryCard(
                    title: 'Platform Commission Retained',
                    value: currencyFormat.format(state.totalPlatformFees),
                    icon: Icons.pie_chart,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _SummaryCard(
                    title: 'Drivers to Pay',
                    value: state.payouts.length.toString(),
                    icon: Icons.people,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),

        // INDIVIDUAL BREAKDOWN
        Row(
          children: [
            Text(
              'Individual Payout Breakdown ',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '(Click row to view line items & apply holds)',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (state.isDetailsLoading)
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _buildDesktopTable(
            context,
            state.payouts,
            theme,
            currencyFormat,
          ),
        ),
      ],
    );
  }

  // --- TAB 2: EXECUTED BATCH HISTORY ---
  Widget _buildHistoryTab(
    List<PayoutHistoryModel> history,
    ThemeData theme,
    NumberFormat format,
  ) {
    if (history.isEmpty) {
      return Center(
        child: Text(
          'No past executed payroll batches found.',
          style: TextStyle(color: theme.disabledColor),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: ListView.separated(
        itemCount: history.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
        itemBuilder: (context, index) {
          final item = history[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              child: const Icon(Icons.check, color: Colors.green),
            ),
            title: Text(
              '${item.driverName} • ${format.format(item.totalAmount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              'Wire Ref: ${item.batchReference} | ${DateFormat('MMM dd, yyyy - HH:mm').format(item.processedAt)}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            trailing: Chip(
              label: Text(
                '${item.jobsIncluded} Items Locked',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: theme.primaryColor.withValues(alpha: 0.08),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }

  // --- EMPTY STATE ---
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 80, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(
            'Ledgers are Clear',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All drivers have been paid for completed jobs.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // --- UNPAID DATA TABLE ---
  Widget _buildDesktopTable(
    BuildContext context,
    List<DriverPayoutPreviewModel> payouts,
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
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.resolveWith(
              (states) => theme.primaryColor.withValues(alpha: 0.05),
            ),
            dataRowMaxHeight: 70,
            columns: [
              DataColumn(
                label: Text(
                  'Driver Name',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Completed Jobs',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Gross Earnings',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Platform Fee (-)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Net Payout (Owed)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
            rows: payouts.map((p) {
              return DataRow(
                onSelectChanged: (_) {
                  final bloc = context.read<PayrollDeskBloc>();
                  bloc.add(FetchDriverPayoutDetails(driverId: p.driverId));
                  _openReactiveDriverModal(context, bloc, p.driverId);
                },
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.primaryColor.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            p.driverName.isNotEmpty
                                ? p.driverName[0].toUpperCase()
                                : 'D',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          p.driverName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      p.totalJobsCompleted.toString(),
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ),
                  DataCell(
                    Text(
                      format.format(p.grossEarnings),
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ),
                  DataCell(
                    Text(
                      format.format(p.platformFee),
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
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --- REACTIVE DRIVER DETAIL DRAWER MODAL ---
  void _openReactiveDriverModal(
    BuildContext parentContext,
    PayrollDeskBloc bloc,
    String driverId,
  ) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          height: MediaQuery.of(parentContext).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(parentContext).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: BlocBuilder<PayrollDeskBloc, PayrollDeskState>(
              bloc: bloc,
              builder: (context, state) {
                if (state is PayrollLoaded &&
                    state.selectedDriverDetails != null) {
                  final details = state.selectedDriverDetails!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${details.driverName} - Ledger Details',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            onPressed: () => Navigator.pop(modalContext),
                          ),
                        ],
                      ),
                      Text(
                        'Cleared for Payout: ${currencyFormat.format(details.totalNetOwed)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Divider(height: 40),

                      Expanded(
                        child: details.lineItems.isEmpty
                            ? Center(
                                child: Text(
                                  "No unpaid items found.",
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: details.lineItems.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final item = details.lineItems[index];
                                  return Card(
                                    color: item.isOnHold
                                        ? Colors.orange.shade50
                                        : Theme.of(context).cardColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).dividerColor.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    elevation: 0,
                                    child: ListTile(
                                      title: Text(
                                        item.description,
                                        style: TextStyle(
                                          decoration: item.isOnHold
                                              ? TextDecoration.lineThrough
                                              : null,
                                          fontWeight: FontWeight.bold,
                                          color: item.isOnHold
                                              ? Colors.black54
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Gross: ${currencyFormat.format(item.grossAmount)} | Fee: ${currencyFormat.format(item.platformFee)} • ${DateFormat('MMM dd - HH:mm').format(item.createdAt)}',
                                        style: TextStyle(
                                          color: item.isOnHold
                                              ? Colors.black45
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            currencyFormat.format(
                                              item.netPayout,
                                            ),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: item.netPayout < 0
                                                  ? Colors.red
                                                  : Colors.green.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Switch(
                                            activeColor: Colors.orange,
                                            value: item.isOnHold,
                                            onChanged: (val) {
                                              bloc.add(
                                                ToggleEarningHoldStatus(
                                                  earningId: item.earningId,
                                                  holdStatus: val,
                                                  driverId:
                                                      details.driverProfileId,
                                                ),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                            ),
                                            tooltip: 'Delete Line Item',
                                            onPressed: () {
                                              bloc.add(
                                                DeleteEarningItem(
                                                  earningId: item.earningId,
                                                  driverId:
                                                      details.driverProfileId,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text(
                            'Add Manual Adjustment',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            _showAddAdjustmentDialog(
                              parentContext,
                              details.driverProfileId,
                              bloc,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
        );
      },
    ).whenComplete(() {
      bloc.add(ClearSelectedDriver());
    });
  }

  // --- MANUAL ADJUSTMENT DIALOG ---
  void _showAddAdjustmentDialog(
    BuildContext context,
    String driverId,
    PayrollDeskBloc bloc,
  ) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Manual Adjustment',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: const InputDecoration(
                labelText: 'Amount (+/-)',
                hintText: 'e.g., -50.00 or 100.00',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: const InputDecoration(
                labelText: 'Reason for Adjustment',
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final amt = double.tryParse(amountController.text);
              if (amt != null && reasonController.text.isNotEmpty) {
                bloc.add(
                  SubmitManualAdjustment(
                    driverId: driverId,
                    amount: amt,
                    reason: reasonController.text,
                  ),
                );
                Navigator.pop(dialogContext);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount and reason.'),
                  ),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // --- EXECUTION MODAL ---
  void _showExecutePayrollModal(
    BuildContext parentContext,
    PayrollLoaded state,
  ) {
    final bloc = parentContext.read<PayrollDeskBloc>();
    final refController = TextEditingController();
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(parentContext).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text(
              'Confirm Batch Execution',
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
                'You are about to lock the ledgers and mark all pending jobs as PAID. '
                'This will flag ${currencyFormat.format(state.totalNetPayout)} as transferred to ${state.payouts.length} drivers.',
                style: TextStyle(
                  color: Theme.of(parentContext).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Please enter the Bank Wire or Transaction Reference Number:',
                style: TextStyle(
                  color: Theme.of(parentContext).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 12),
              const Text(
                'Note: This action is irreversible.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (refController.text.trim().isEmpty) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('Bank Reference is required.')),
                );
                return;
              }
              bloc.add(
                ExecutePayrollBatch(
                  bankWireReference: refController.text.trim(),
                ),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Execute & Lock Ledgers'),
          ),
        ],
      ),
    );
  }
}

// --- SUMMARY CARD COMPONENT (FIXED) ---
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isPrimary;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: isPrimary ? theme.primaryColor : theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // FIX: The compiler error was caused by passing Border.all() instead of BorderSide() here
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
                      : theme.primaryColor.withValues(alpha: 0.2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
