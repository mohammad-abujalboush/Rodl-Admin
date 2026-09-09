import 'dart:convert';
// Using dart:html to natively force a file download in Chrome/Flutter Web
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:go_router/go_router.dart';
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
  String _activePreset = 'All Time';

  @override
  void initState() {
    super.initState();
    _applyDatePreset('All Time');
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

  void _applyDatePreset(String preset) {
    setState(() {
      _activePreset = preset;
      final now = DateTime.now().toUtc();
      switch (preset) {
        case 'Today':
          _startDate = DateTime.utc(now.year, now.month, now.day);
          _endDate = DateTime.utc(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'This Week':
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate = now;
          break;
        case 'This Month':
          _startDate = DateTime.utc(now.year, now.month, 1);
          _endDate = DateTime.utc(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case 'YTD':
          _startDate = DateTime.utc(now.year, 1, 1);
          _endDate = now;
          break;
        case 'All Time':
          _startDate = null;
          _endDate = null;
          break;
      }
    });
    _refreshAllData();
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
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
      setState(() {
        _activePreset = 'Custom';
        _startDate = picked.start.toUtc();
        _endDate = picked.end.toUtc();
      });
      _refreshAllData();
    }
  }

  // --- NATIVE WEB CSV DOWNLOADER ---
  void _exportFinancialReport() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Downloading CSV Report...')));

    try {
      final invoices = await _invoicesFuture;
      final payroll = await _payrollFuture;

      StringBuffer csv = StringBuffer();

      csv.writeln('--- RODL FINANCIAL REPORT ---');
      csv.writeln('Date Filter:,$_activePreset');
      csv.writeln('Export Date:,${DateTime.now().toIso8601String()}');
      csv.writeln('');

      csv.writeln('--- ACCOUNTS RECEIVABLE (INVOICES) ---');
      csv.writeln('Recipient,Issue Date,Amount,Status');
      for (var inv in invoices) {
        final rawDate =
            inv['issueDate']?.toString() ?? inv['IssueDate']?.toString() ?? '';
        final parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
        final dateStr = DateFormat('yyyy-MM-dd').format(parsedDate);
        final amount = ((inv['totalAmount'] ?? inv['TotalAmount'] ?? 0) as num)
            .toDouble();
        final status = _getInvoiceStatusString(
          ((inv['status'] ?? inv['Status'] ?? 0) as num).toInt(),
        );

        final name = (inv['recipientName'] ?? inv['RecipientName'] ?? 'Unknown')
            .toString()
            .replaceAll(',', ' ');
        csv.writeln('$name,$dateStr,\$${amount.toStringAsFixed(2)},$status');
      }

      csv.writeln('');

      csv.writeln('--- ACCOUNTS PAYABLE (PAYROLL) ---');
      csv.writeln('Driver Name,Pending Dispatches,Net Payout Owed');
      for (var p in payroll) {
        final name = (p['driverName'] ?? p['DriverName'] ?? 'Unknown')
            .toString()
            .replaceAll(',', ' ');
        final jobs = ((p['unpaidJobCount'] ?? p['UnpaidJobCount'] ?? 0) as num)
            .toInt();
        final amount = ((p['netPayout'] ?? p['NetPayout'] ?? 0) as num)
            .toDouble();
        csv.writeln('$name,$jobs,\$${amount.toStringAsFixed(2)}');
      }

      // Creates a raw blob and forces the browser to download it as a physical file
      final bytes = utf8.encode(csv.toString());
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute(
          "download",
          "Financial_Report_${DateTime.now().millisecondsSinceEpoch}.csv",
        )
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getInvoiceStatusString(int status) {
    switch (status) {
      case 0:
        return 'Draft';
      case 1:
        return 'Unpaid';
      case 2:
        return 'Partial';
      case 3:
        return 'Paid';
      case 4:
        return 'Overdue';
      case 5:
        return 'Voided';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 16.0 : 32.0,
          ),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'All Time', label: Text('All Time')),
                ButtonSegment(value: 'This Month', label: Text('Month')),
                ButtonSegment(value: 'YTD', label: Text('YTD')),
              ],
              selected: {
                _activePreset != 'Custom' &&
                        _activePreset != 'Today' &&
                        _activePreset != 'This Week'
                    ? _activePreset
                    : 'All Time',
              },
              onSelectionChanged: (set) => _applyDatePreset(set.first),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                _activePreset == 'Custom' ? rangeText : 'Custom Range',
              ),
              onPressed: () => _selectCustomDateRange(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
                foregroundColor: theme.colorScheme.onSurface,
              ),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
              onPressed: _exportFinancialReport,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
            IconButton.filled(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Ledger',
              onPressed: _refreshAllData,
              padding: const EdgeInsets.all(16),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _buildErrorState(
            'Failed to load KPIs.',
            snapshot.error,
            theme,
          );
        }

        final data = snapshot.data ?? {};
        // Dual fallback logic covers camelCase and PascalCase
        final totalRevenue =
            ((data['totalRevenue'] ?? data['TotalRevenue'] ?? 0) as num)
                .toDouble();
        final activeTows =
            ((data['activeTows'] ?? data['ActiveTows'] ?? 0) as num).toInt();
        final unassignedJobs =
            ((data['unassignedJobs'] ?? data['UnassignedJobs'] ?? 0) as num)
                .toInt();
        final slaBreaches =
            ((data['slaBreaches'] ?? data['SlaBreaches'] ?? 0) as num).toInt();

        return LayoutBuilder(
          builder: (context, constraints) {
            int columns = constraints.maxWidth > 1200
                ? 4
                : (constraints.maxWidth > 800 ? 2 : 1);
            double spacing = 24.0;
            double cardWidth =
                ((constraints.maxWidth - (spacing * (columns - 1))) / columns)
                    .floorToDouble();

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    title: 'Gross Revenue',
                    value: NumberFormat.currency(
                      symbol: '\$',
                    ).format(totalRevenue),
                    subtitle: 'Settled + Pending',
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                    theme: theme,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    title: 'Active Dispatches',
                    value: activeTows.toString(),
                    subtitle: 'Generating revenue now',
                    icon: Icons.local_shipping,
                    color: Colors.blue,
                    theme: theme,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    title: 'Pending Queue',
                    value: unassignedJobs.toString(),
                    subtitle: 'Awaiting assignment',
                    icon: Icons.hourglass_empty,
                    color: Colors.orange,
                    theme: theme,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    title: 'SLA Escalations',
                    value: slaBreaches.toString(),
                    subtitle: 'Jobs delayed > 45m',
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
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountsReceivable(ThemeData theme) {
    return _buildSectionContainer(
      title: 'Accounts Receivable (Invoices)',
      icon: Icons.receipt_long,
      theme: theme,
      action: TextButton(
        onPressed: () => context.go('/invoices'),
        child: const Text('View All Ledger'),
      ),
      child: FutureBuilder<List<dynamic>>(
        future: _invoicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _buildErrorState(
              'Unable to load invoices',
              snapshot.error,
              theme,
            );
          }

          final invoices = snapshot.data ?? [];
          if (invoices.isEmpty) {
            return _buildEmptyState(
              'No invoices found.',
              Icons.check_circle_outline,
              theme,
            );
          }

          double totalOutstanding = 0;
          double totalPaid = 0;
          for (var inv in invoices) {
            final amt = ((inv['totalAmount'] ?? inv['TotalAmount'] ?? 0) as num)
                .toDouble();
            final status = ((inv['status'] ?? inv['Status'] ?? 0) as num)
                .toInt();
            if (status == 3)
              totalPaid += amt;
            else if (status == 1 || status == 2 || status == 4)
              totalOutstanding += amt;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Outstanding',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          Text(
                            NumberFormat.currency(
                              symbol: '\$',
                            ).format(totalOutstanding),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Settled',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          Text(
                            NumberFormat.currency(
                              symbol: '\$',
                            ).format(totalPaid),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: invoices.take(6).length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
                itemBuilder: (context, index) {
                  final inv = invoices[index];
                  final rawDate =
                      inv['issueDate']?.toString() ??
                      inv['IssueDate']?.toString() ??
                      '';
                  final parsedDate =
                      DateTime.tryParse(rawDate) ?? DateTime.now();
                  final amount =
                      ((inv['totalAmount'] ?? inv['TotalAmount'] ?? 0) as num)
                          .toDouble();

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    title: Text(
                      (inv['recipientName'] ??
                              inv['RecipientName'] ??
                              'Unknown')
                          .toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Issued: ${DateFormat('MMM dd, yyyy').format(parsedDate)}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInvoiceStatusChip(
                          ((inv['status'] ?? inv['Status'] ?? 0) as num)
                              .toInt(),
                          theme,
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min, // Prevents layout crashes
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat.currency(symbol: '\$').format(amount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountsPayable(ThemeData theme) {
    return _buildSectionContainer(
      title: 'Accounts Payable (Driver Payroll)',
      icon: Icons.payments,
      theme: theme,
      action: FilledButton.tonal(
        onPressed: () => context.go('/payroll'),
        child: const Text('Process Payouts'),
      ),
      child: FutureBuilder<List<dynamic>>(
        future: _payrollFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _buildErrorState(
              'Unable to load pending payroll',
              snapshot.error,
              theme,
            );
          }

          final payouts = snapshot.data ?? [];
          if (payouts.isEmpty) {
            return _buildEmptyState(
              'All active fleets are settled.',
              Icons.domain_verification,
              theme,
            );
          }

          double totalOwed = 0;
          for (var payout in payouts) {
            totalOwed +=
                ((payout['netPayout'] ?? payout['NetPayout'] ?? 0) as num)
                    .toDouble();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Payroll Liability',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    Text(
                      NumberFormat.currency(symbol: '\$').format(totalOwed),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payouts.take(6).length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
                itemBuilder: (context, index) {
                  final payout = payouts[index];
                  final amount =
                      ((payout['netPayout'] ?? payout['NetPayout'] ?? 0) as num)
                          .toDouble();

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: theme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: Icon(Icons.engineering, color: theme.primaryColor),
                    ),
                    title: Text(
                      (payout['driverName'] ??
                              payout['DriverName'] ??
                              'Unknown')
                          .toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '${((payout['unpaidJobCount'] ?? payout['UnpaidJobCount'] ?? 0) as num).toInt()} Unsettled Dispatches',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min, // Prevents layout crashes
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat.currency(symbol: '\$').format(amount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
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
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(icon, color: theme.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) action,
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
          child,
        ],
      ),
    );
  }

  Widget _buildInvoiceStatusChip(int status, ThemeData theme) {
    Color color;
    String label = _getInvoiceStatusString(status);

    switch (status) {
      case 0:
        color = Colors.grey;
        break;
      case 1:
        color = Colors.orange;
        break;
      case 2:
        color = Colors.blue;
        break;
      case 3:
        color = Colors.green;
        break;
      case 4:
        color = Colors.red;
        break;
      case 5:
        color = Colors.grey;
        break;
      default:
        color = theme.disabledColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    String errorTitle,
    Object? exception,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              errorTitle,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (exception != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: SelectableText(
                  exception.toString(),
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
