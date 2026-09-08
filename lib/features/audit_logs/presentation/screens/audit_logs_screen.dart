import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:responsive_builder/responsive_builder.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/di/injection_container.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final DioClient _dioClient = sl<DioClient>();

  List<dynamic> _logs = [];
  bool _isLoading = true;
  int _totalCount = 0;

  // Filter States
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedAction = 'All';
  int _pageNumber = 1;

  final List<String> _actionTypes = [
    'All',
    'JOB_FINANCIAL_FINALIZED',
    'ManualPriceOverride',
    'Staff Account Suspended',
    'Staff Account Reactivated',
  ];

  @override
  void initState() {
    super.initState();
    _fetchFilteredLogs();
  }

  Future<void> _fetchFilteredLogs() async {
    setState(() => _isLoading = true);

    try {
      final response = await _dioClient.dio.post(
        '/api/admin/audit-logs/filtered',
        data: {
          'searchTerm': _searchQuery.isEmpty ? null : _searchQuery,
          'action': _selectedAction == 'All' ? null : _selectedAction,
          'startDate': _startDate?.toIso8601String(),
          'endDate': _endDate?.toIso8601String(),
          'pageNumber': _pageNumber,
          'pageSize': 50,
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _logs = response.data['logs'] ?? [];
          _totalCount = response.data['totalCount'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load audit logs.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _pageNumber = 1;
      });
      _fetchFilteredLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Light theme compliant
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 24),
              _buildFilterRow(theme),
              const SizedBox(height: 24),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _logs.isEmpty
                    ? _buildEmptyState(theme)
                    : ResponsiveBuilder(
                        builder: (context, sizingInfo) {
                          if (sizingInfo.isMobile || sizingInfo.isTablet) {
                            return _buildMobileList(theme);
                          }
                          return _buildDesktopTable(theme);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Activity & Audit Logs',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Showing $_totalCount recorded system events.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
        FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text(
            'Refresh',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _fetchFilteredLogs,
        ),
      ],
    );
  }

  Widget _buildFilterRow(ThemeData theme) {
    final dateFmt = DateFormat('MMM dd, yyyy');
    final rangeText = _startDate != null && _endDate != null
        ? '${dateFmt.format(_startDate!)} - ${dateFmt.format(_endDate!)}'
        : 'All-Time';

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search Job ID, Action, or Payload...',
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
            onSubmitted: (val) {
              setState(() {
                _searchQuery = val;
                _pageNumber = 1;
              });
              _fetchFilteredLogs();
            },
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_month),
          label: Text(rangeText),
          onPressed: _selectDateRange,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
            foregroundColor: theme.colorScheme.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        SizedBox(
          width: 250,
          child: DropdownButtonFormField<String>(
            value: _selectedAction,
            dropdownColor: theme.cardColor,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.cardColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
            ),
            items: _actionTypes
                .map(
                  (action) =>
                      DropdownMenuItem(value: action, child: Text(action)),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedAction = val;
                  _pageNumber = 1;
                });
                _fetchFilteredLogs();
              }
            },
          ),
        ),
        if (_searchQuery.isNotEmpty ||
            _startDate != null ||
            _selectedAction != 'All')
          TextButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('Clear Filters'),
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _startDate = null;
                _endDate = null;
                _selectedAction = 'All';
                _pageNumber = 1;
              });
              _fetchFilteredLogs();
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_search, size: 80, color: theme.dividerColor),
          const SizedBox(height: 16),
          Text(
            'No logs match your filters',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting the date range or clearing the search query.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(ThemeData theme) {
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
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.resolveWith(
              (states) => theme.primaryColor.withValues(alpha: 0.05),
            ),
            dataRowMaxHeight: 70,
            columns: [
              DataColumn(
                label: Text(
                  'Timestamp',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Actor / Trigger',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Action Type',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Target Entity',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Payload',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
            rows: _logs.map((log) {
              final action = log['action'] ?? 'Unknown';
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      log['timestamp'] ?? '',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        Icon(
                          log['userEmail'].toString().contains('System')
                              ? Icons.smart_toy
                              : Icons.person,
                          size: 16,
                          color: theme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          log['userEmail'] ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getActionColor(action).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        action,
                        style: TextStyle(
                          color: _getActionColor(action),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      log['entityName'] ?? '',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ),
                  DataCell(
                    log['details'] != null &&
                            log['details'].toString().isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.data_object,
                              color: Colors.blue,
                            ),
                            tooltip: 'View JSON Payload',
                            onPressed: () =>
                                _showPayloadDialog(log['details'], theme),
                          )
                        : Text(
                            'No Data',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
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

  Widget _buildMobileList(ThemeData theme) {
    return ListView.separated(
      itemCount: _logs.length,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final log = _logs[i];
        final action = log['action'] ?? 'Unknown';

        return Card(
          color: theme.cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              action,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getActionColor(action),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${log['userEmail']} • ${log['timestamp']}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Target: ${log['entityName']}',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ],
            ),
            trailing:
                log['details'] != null && log['details'].toString().isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.data_object, color: Colors.blue),
                    onPressed: () => _showPayloadDialog(log['details'], theme),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _showPayloadDialog(String payload, ThemeData theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          'Audit Payload',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Container(
          width: 500,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              payload,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String action) {
    if (action.contains('FINANCIAL') || action.contains('Payment'))
      return Colors.green;
    if (action.contains('Override') ||
        action.contains('Delete') ||
        action.contains('Suspended'))
      return Colors.red;
    if (action.contains('Create') || action.contains('Add')) return Colors.blue;
    return Colors.orange;
  }
}
