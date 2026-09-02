import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/api_data.dart';

class FinancialOverviewScreen extends StatefulWidget {
  final FinancialLedgerService apiService;

  const FinancialOverviewScreen({super.key, required this.apiService});

  @override
  State<FinancialOverviewScreen> createState() =>
      _FinancialOverviewScreenState();
}

class _FinancialOverviewScreenState extends State<FinancialOverviewScreen> {
  late Future<Map<String, dynamic>> _kpiFuture;
  late Future<List<dynamic>> _payrollFuture;
  late Future<List<dynamic>> _invoicesFuture;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _refreshAllData();
  }

  void _refreshAllData() {
    setState(() {
      _kpiFuture = widget.apiService.getSystemKpis(
        startDate: _startDate,
        endDate: _endDate,
      );
      _payrollFuture = widget.apiService.getPayrollPreview();
      _invoicesFuture = widget.apiService.getInvoices();
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) =>
          Theme(data: Theme.of(context), child: child!),
    );

    if (picked != null) {
      _startDate = picked.start;
      _endDate = picked.end;
      _refreshAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildExecutiveKpis(theme),
                      const SizedBox(height: 32),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 1000) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildAccountsReceivable(theme),
                                ),
                                const SizedBox(width: 32),
                                Expanded(child: _buildAccountsPayable(theme)),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              _buildAccountsReceivable(theme),
                              const SizedBox(height: 32),
                              _buildAccountsPayable(theme),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final dateFmt = DateFormat('MMM dd, yyyy');
    final rangeText = _startDate != null && _endDate != null
        ? '${dateFmt.format(_startDate!)} - ${dateFmt.format(_endDate!)}'
        : 'All-Time';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Overview',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Track your total revenue, pending invoices, and driver payouts.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text(rangeText),
              onPressed: () => _selectDateRange(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                side: BorderSide(color: theme.dividerColor),
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Data'),
              onPressed: _refreshAllData,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExecutiveKpis(ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _kpiFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        if (snapshot.hasError)
          return _buildErrorState('Failed to load KPIs', theme);

        final data = snapshot.data ?? {};
        final totalRevenue = data['totalRevenue'] ?? 0.0;
        final activeTows = data['activeTows'] ?? 0;
        final unassignedJobs = data['unassignedJobs'] ?? 0;
        final slaBreaches = data['slaBreaches'] ?? 0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = constraints.maxWidth > 800
                ? (constraints.maxWidth / 4) - 24
                : (constraints.maxWidth / 2) - 16;
            return Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    title: 'Total Revenue',
                    value: NumberFormat.currency(
                      symbol: '\$',
                    ).format(totalRevenue),
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                    theme: theme,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    title: 'Active Jobs',
                    value: activeTows.toString(),
                    subtitle: 'Jobs currently running',
                    icon: Icons.local_shipping,
                    color: Colors.blue,
                    theme: theme,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    title: 'Pending Jobs',
                    value: unassignedJobs.toString(),
                    subtitle: 'Waiting for drivers',
                    icon: Icons.hourglass_empty,
                    color: Colors.orange,
                    theme: theme,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    title: 'Needs Attention',
                    value: slaBreaches.toString(),
                    subtitle: 'Jobs delayed or stuck',
                    icon: Icons.warning_amber_rounded,
                    color: theme.colorScheme.error,
                    theme: theme,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountsReceivable(ThemeData theme) {
    return _buildSectionContainer(
      title: 'Pending Invoices',
      icon: Icons.receipt_long,
      theme: theme,
      child: FutureBuilder<List<dynamic>>(
        future: _invoicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            );
          if (snapshot.hasError)
            return _buildErrorState('Unable to load invoices', theme);

          final invoices = snapshot.data ?? [];
          if (invoices.isEmpty)
            return _buildEmptyState(
              'No invoices found.',
              Icons.check_circle_outline,
              theme,
            );

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: invoices.take(5).length,
            separatorBuilder: (_, __) =>
                Divider(color: theme.dividerColor.withOpacity(0.5)),
            itemBuilder: (context, index) {
              final inv = invoices[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  inv['recipientName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Issued: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(inv['issueDate'] ?? DateTime.now().toIso8601String()))}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormat.currency(
                        symbol: '\$',
                      ).format(inv['totalAmount'] ?? 0.0),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildInvoiceStatusChip(inv['status'] ?? 0, theme),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAccountsPayable(ThemeData theme) {
    return _buildSectionContainer(
      title: 'Driver Payroll',
      icon: Icons.payments,
      theme: theme,
      child: FutureBuilder<List<dynamic>>(
        future: _payrollFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            );
          if (snapshot.hasError)
            return _buildErrorState('Unable to load pending payroll', theme);

          final payouts = snapshot.data ?? [];
          if (payouts.isEmpty)
            return _buildEmptyState(
              'All drivers are paid out.',
              Icons.domain_verification,
              theme,
            );

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: payouts.take(5).length,
            separatorBuilder: (_, __) =>
                Divider(color: theme.dividerColor.withOpacity(0.5)),
            itemBuilder: (context, index) {
              final payout = payouts[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: theme.primaryColor),
                ),
                title: Text(
                  payout['driverName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${payout['unpaidJobCount'] ?? 0} Jobs Pending'),
                trailing: Text(
                  NumberFormat.currency(
                    symbol: '\$',
                  ).format(payout['netPayout'] ?? 0.0),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Widget child,
    required ThemeData theme,
    Widget? action,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
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
                    Icon(icon, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                if (action != null) action,
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildInvoiceStatusChip(int status, ThemeData theme) {
    Color color;
    String label;
    switch (status) {
      case 0:
        color = Colors.orange;
        label = 'Pending';
        break;
      case 1:
        color = Colors.green;
        label = 'Paid';
        break;
      case 2:
        color = Colors.red;
        label = 'Overdue';
        break;
      default:
        color = theme.disabledColor;
        label = 'Void';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: theme.dividerColor),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(error, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ),
      ),
    );
  }
}
