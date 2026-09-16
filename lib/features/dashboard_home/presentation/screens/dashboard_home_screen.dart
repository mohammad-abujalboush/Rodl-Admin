import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:roadside_service/features/dashboard_home/data/models/dashboard_filter_model.dart';
import 'package:roadside_service/features/dashboard_home/data/models/system_kpi_model.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/dashboard_bloc.dart';

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // FIX: Defaulted to All-Time so historical test data actually loads
  DashboardFilterModel _currentFilter = DashboardFilterModel(
    startDate: null,
    endDate: null,
  );

  void _applyFilter(DashboardFilterModel newFilter) {
    setState(() => _currentFilter = newFilter);
    context.read<DashboardBloc>().add(
      FetchDashboardKpis(filter: _currentFilter),
    );
    _scaffoldKey.currentState?.closeEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) =>
          sl<DashboardBloc>()..add(FetchDashboardKpis(filter: _currentFilter)),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.colorScheme.surface,
        endDrawer: _AdvancedFilterDrawer(
          currentFilter: _currentFilter,
          onApply: _applyFilter,
        ),
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
                  child: BlocBuilder<DashboardBloc, DashboardState>(
                    builder: (context, state) {
                      if (state is DashboardLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is DashboardError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                state.message,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                onPressed: () =>
                                    context.read<DashboardBloc>().add(
                                      FetchDashboardKpis(
                                        filter: _currentFilter,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (state is DashboardLoaded) {
                        // DEBUG LOG: Watch your terminal to verify data is arriving
                        debugPrint(
                          "DASHBOARD DATA LOADED: Revenue: \$${state.kpis.totalRevenue}, Tows: ${state.kpis.activeTows}",
                        );

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. OPERATIONS PULSE
                              _buildSectionTitle(
                                theme,
                                'Fleet & Operations Pulse',
                                Icons.cell_tower,
                              ),
                              const SizedBox(height: 16),
                              _buildOperationsGrid(state.kpis),

                              const SizedBox(height: 48),

                              // 2. FINANCIAL LEDGER
                              _buildSectionTitle(
                                theme,
                                'Financial Ledger & Yield',
                                Icons.account_balance,
                              ),
                              const SizedBox(height: 16),
                              _buildFinancialGrid(state.kpis),
                              const SizedBox(height: 24),
                              _buildAnalyticsRow(context, state.kpis),

                              const SizedBox(height: 48),

                              // 3. SYSTEM HEALTH & ESCALATIONS
                              _buildSectionTitle(
                                theme,
                                'System Health & Escalations',
                                Icons.health_and_safety,
                                isAlert: true,
                              ),
                              const SizedBox(height: 16),
                              _buildSystemHealthGrid(state.kpis),
                              const SizedBox(height: 24),

                              if (state.kpis.escalations.isNotEmpty) ...[
                                _buildEscalationsTable(
                                  context,
                                  state.kpis.escalations,
                                ),
                                const SizedBox(height: 48),
                              ],
                            ],
                          ),
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

  Widget _buildHeader(ThemeData theme) {
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
              'Command Center',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Full spectrum analysis of logistics, financials, and disputes.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
        FilledButton.icon(
          icon: const Icon(Icons.tune),
          label: const Text(
            'Advanced Filters',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    ThemeData theme,
    String title,
    IconData icon, {
    bool isAlert = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isAlert
                ? theme.colorScheme.error.withValues(alpha: 0.1)
                : theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isAlert ? theme.colorScheme.error : theme.primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isAlert
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveCardGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = width > 1200 ? 4 : (width > 800 ? 2 : 1);
        final spacing = 20.0;
        final cardWidth = ((width - (spacing * (columns - 1))) / columns)
            .floorToDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
  }

  Widget _buildOperationsGrid(SystemKpiModel kpis) {
    return _buildResponsiveCardGrid([
      _MetricCard(
        title: 'Unassigned Queue',
        value: kpis.unassignedJobs.toString(),
        isAlert: kpis.unassignedJobs > 5,
        icon: Icons.pending_actions,
        tooltip: 'ServiceRequests with Status = 0 (No Driver Assigned).',
      ),
      _MetricCard(
        title: 'Active Tows',
        value: kpis.activeTows.toString(),
        icon: Icons.rv_hookup,
        tooltip:
            'ServiceRequests currently En Route or In Progress (Status 1 or 2).',
      ),
      _MetricCard(
        title: 'Avg Wait Time',
        value: '${kpis.averageWaitTimeMinutes}m',
        icon: Icons.timer,
        tooltip: 'Average minutes from Request Creation to DriverArrivedAt.',
      ),
      _MetricCard(
        title: 'Online Fleet',
        value: kpis.onlineFleet.toString(),
        icon: Icons.local_shipping,
        highlightColor: Colors.green,
        tooltip: 'Drivers currently marked IsOnline in DriverProfile.',
      ),
    ]);
  }

  Widget _buildFinancialGrid(SystemKpiModel kpis) {
    return _buildResponsiveCardGrid([
      _MetricCard(
        title: 'Gross Revenue',
        value: '\$${kpis.totalRevenue.toStringAsFixed(2)}',
        icon: Icons.account_balance_wallet,
        tooltip: 'Total GrossRevenue from completed dispatches.',
      ),
      _MetricCard(
        title: 'Platform Net (Fees)',
        value: '\$${(kpis.totalRevenue * 0.15).toStringAsFixed(2)}',
        icon: Icons.savings,
        highlightColor: Colors.green,
        tooltip: 'Estimated platform retained revenue.',
      ),
      _MetricCard(
        title: 'Driver Payouts',
        value: '\$${(kpis.totalRevenue * 0.85).toStringAsFixed(2)}',
        icon: Icons.payments,
        highlightColor: Colors.orange,
        tooltip: 'Estimated driver allocation pending payout.',
      ),
      _MetricCard(
        title: 'Avg Ticket Size',
        value: '\$${kpis.averageTicketSize.toStringAsFixed(2)}',
        icon: Icons.receipt_long,
        tooltip: 'Average GrossRevenue per completed job.',
      ),
    ]);
  }

  Widget _buildSystemHealthGrid(SystemKpiModel kpis) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = width > 1200 ? 3 : 1;
        final spacing = 20.0;
        final cardWidth = ((width - (spacing * (columns - 1))) / columns)
            .floorToDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _MetricCard(
                title: 'SLA Breaches (>45m)',
                value: kpis.slaBreaches.toString(),
                isAlert: kpis.slaBreaches > 0,
                icon: Icons.warning_amber_rounded,
                tooltip: 'Jobs exceeding the 45-minute arrival SLA.',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _MetricCard(
                title: 'Cancellation Rate',
                value: '${(kpis.cancellationRate * 100).toStringAsFixed(1)}%',
                isAlert: kpis.cancellationRate > 0.15,
                icon: Icons.cancel_presentation,
                tooltip: 'Ratio of Cancellations to total ServiceRequests.',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: const _MetricCard(
                title: 'Open Support Tickets',
                value: '0',
                isAlert: false,
                icon: Icons.support_agent,
                tooltip: 'Active disputes in the SupportTicket table.',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnalyticsRow(BuildContext context, SystemKpiModel kpis) {
    return ResponsiveBuilder(
      builder: (context, sizingInfo) {
        if (sizingInfo.isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildRevenueChart(context, kpis)),
              const SizedBox(width: 24),
              Expanded(flex: 1, child: _buildServiceMixChart(context, kpis)),
            ],
          );
        }
        return Column(
          children: [
            _buildRevenueChart(context, kpis),
            const SizedBox(height: 24),
            _buildServiceMixChart(context, kpis),
          ],
        );
      },
    );
  }

  Widget _buildRevenueChart(BuildContext context, SystemKpiModel kpis) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.compactCurrency(symbol: '\$');
    final spots = kpis.revenueTrend.isNotEmpty
        ? kpis.revenueTrend
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.y))
              .toList()
        : [const FlSpot(0, 0)];

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Trend',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 320,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) => Text(
                        currencyFormatter.format(value),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < kpis.revenueTrend.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Text(
                              kpis.revenueTrend[value.toInt()].xLabel,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: theme.primaryColor,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          theme.primaryColor.withValues(alpha: 0.2),
                          theme.primaryColor.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceMixChart(BuildContext context, SystemKpiModel kpis) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resource Demand',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 320,
            child: kpis.serviceMix.isEmpty
                ? Center(
                    child: Text(
                      'No data for selected filters',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 70,
                      sections: kpis.serviceMix.asMap().entries.map((entry) {
                        final colorList = [
                          theme.primaryColor,
                          theme.colorScheme.secondary,
                          theme.colorScheme.tertiary,
                          Colors.orange,
                        ];
                        final displayName = entry.value.serviceName;
                        return PieChartSectionData(
                          color: colorList[entry.key % colorList.length],
                          value: entry.value.percentage,
                          title:
                              '${entry.value.percentage.toStringAsFixed(0)}%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          badgeWidget: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.dividerColor.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: colorList[entry.key % colorList.length],
                              ),
                            ),
                          ),
                          badgePositionPercentageOffset: 1.1,
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscalationsTable(
    BuildContext context,
    List<EscalationJobModel> escalations,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.error.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                ),
                dataRowMaxHeight: 70,
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                  fontSize: 14,
                ),
                columns: const [
                  DataColumn(label: Text('Assigned Driver')),
                  DataColumn(label: Text('Service Request Type')),
                  DataColumn(label: Text('Wait Time SLA')),
                  DataColumn(label: Text('Current Status')),
                ],
                rows: escalations.map((esc) {
                  final isCritical = esc.waitTimeMinutes > 60;
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.error
                                  .withValues(alpha: 0.1),
                              radius: 16,
                              child: Icon(
                                Icons.person,
                                size: 16,
                                color: theme.colorScheme.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              esc.driverName.isEmpty
                                  ? 'Unassigned'
                                  : esc.driverName,
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
                          esc.serviceName,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isCritical
                                ? theme.colorScheme.error
                                : Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${esc.waitTimeMinutes} mins',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          esc.statusText,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String tooltip;
  final bool isAlert;
  final Color? highlightColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tooltip,
    this.isAlert = false,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = isAlert
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.15)
        : theme.cardColor;
    final borderColor = isAlert
        ? theme.colorScheme.error.withValues(alpha: 0.5)
        : theme.dividerColor.withValues(alpha: 0.2);
    final iconColor =
        highlightColor ??
        (isAlert ? theme.colorScheme.error : theme.primaryColor);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: tooltip,
                padding: const EdgeInsets.all(12),
                textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.dividerColor, width: 1.5),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    size: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isAlert
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdvancedFilterDrawer extends StatefulWidget {
  final DashboardFilterModel currentFilter;
  final Function(DashboardFilterModel) onApply;

  const _AdvancedFilterDrawer({
    required this.currentFilter,
    required this.onApply,
  });

  @override
  State<_AdvancedFilterDrawer> createState() => _AdvancedFilterDrawerState();
}

class _AdvancedFilterDrawerState extends State<_AdvancedFilterDrawer> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  final Set<int> _selectedServices = {};
  final Set<int> _selectedStatuses = {};

  @override
  void initState() {
    super.initState();
    _startDate = widget.currentFilter.startDate;
    _endDate = widget.currentFilter.endDate;
    if (widget.currentFilter.serviceTypes != null) {
      _selectedServices.addAll(widget.currentFilter.serviceTypes!);
    }
    if (widget.currentFilter.statuses != null) {
      _selectedStatuses.addAll(widget.currentFilter.statuses!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: 450,
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tune, color: theme.primaryColor),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Deep Entity Filters',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Temporal Range',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.5),
                            ),
                          ),
                          icon: Icon(
                            Icons.date_range,
                            size: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) setState(() => _startDate = date);
                          },
                          label: Text(
                            _startDate != null
                                ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                : 'Start Date',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.5),
                            ),
                          ),
                          icon: Icon(
                            Icons.date_range,
                            size: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) setState(() => _endDate = date);
                          },
                          label: Text(
                            _endDate != null
                                ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                : 'End Date',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  Text(
                    'Service Classification',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildIntFilterChip('Wheel-Lift', 1, _selectedServices),
                      _buildIntFilterChip('Flatbed', 2, _selectedServices),
                      _buildIntFilterChip('Jump Start', 6, _selectedServices),
                      _buildIntFilterChip('Lockout', 8, _selectedServices),
                      _buildIntFilterChip('Fuel', 9, _selectedServices),
                    ],
                  ),
                  const SizedBox(height: 48),

                  Text(
                    'Status Configuration',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildIntFilterChip(
                        'Pending Dispatch',
                        0,
                        _selectedStatuses,
                      ),
                      _buildIntFilterChip(
                        'Driver Accepted',
                        1,
                        _selectedStatuses,
                      ),
                      _buildIntFilterChip('Arrived', 2, _selectedStatuses),
                      _buildIntFilterChip('Completed', 3, _selectedStatuses),
                      _buildIntFilterChip('Cancelled', 99, _selectedStatuses),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    widget.onApply(
                      DashboardFilterModel(
                        startDate: _startDate,
                        endDate: _endDate,
                        serviceTypes: _selectedServices.isEmpty
                            ? null
                            : _selectedServices.toList(),
                        statuses: _selectedStatuses.isEmpty
                            ? null
                            : _selectedStatuses.toList(),
                      ),
                    );
                  },
                  child: const Text(
                    'Execute Deep Filter Query',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntFilterChip(String label, int value, Set<int> targetSet) {
    final theme = Theme.of(context);
    final isSelected = targetSet.contains(value);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: theme.primaryColor.withValues(alpha: 0.15),
      backgroundColor: theme.cardColor,
      labelStyle: TextStyle(
        color: isSelected ? theme.primaryColor : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected
            ? theme.primaryColor
            : theme.dividerColor.withValues(alpha: 0.5),
        width: isSelected ? 2 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (selected) => setState(
        () => selected ? targetSet.add(value) : targetSet.remove(value),
      ),
    );
  }
}
