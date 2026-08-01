import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roadside_service/core/utils/call_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/di/injection_container.dart';

class CallLogModel {
  final String id;
  final String callerName;
  final String receiverName;
  final String receiverId;
  final String? serviceRequestId;
  final String callReason;
  final DateTime startedAt;
  final int durationSeconds;
  final String recordingUrl;

  CallLogModel({
    required this.id,
    required this.callerName,
    required this.receiverName,
    required this.receiverId,
    this.serviceRequestId,
    required this.callReason,
    required this.startedAt,
    required this.durationSeconds,
    required this.recordingUrl,
  });

  factory CallLogModel.fromJson(Map<String, dynamic> json) => CallLogModel(
    id: json['id'] ?? '',
    callerName: json['callerName'] ?? 'Unknown Caller',
    receiverName: json['receiverName'] ?? 'Unknown Recipient',
    receiverId: json['receiverId'] ?? '',
    serviceRequestId: json['serviceRequestId'],
    callReason: json['callReason'] ?? 'Direct Assistance',
    startedAt: json['startedAt'] != null
        ? DateTime.parse(json['startedAt'])
        : DateTime.now(),
    durationSeconds: json['durationSeconds'] ?? 0,
    recordingUrl: json['recordingUrl'] ?? '',
  );

  String get durationFormatted {
    if (durationSeconds <= 0) return '0s (Missed / Cancelled)';
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}

class CallManagementScreen extends StatefulWidget {
  const CallManagementScreen({super.key});

  @override
  State<CallManagementScreen> createState() => _CallManagementScreenState();
}

class _CallManagementScreenState extends State<CallManagementScreen> {
  final DioClient _dioClient = sl<DioClient>();
  List<CallLogModel> _calls = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchCallHistory();
  }

  Future<void> _fetchCallHistory() async {
    setState(() => _isLoading = true);
    try {
      final response = await _dioClient.dio.get('/api/admin/call-recordings');
      if (response.statusCode == 200 && response.data != null) {
        final list = (response.data as List)
            .map((j) => CallLogModel.fromJson(j))
            .toList();
        setState(() => _calls = list);
      }
    } catch (_) {
      // Fallback sample data if endpoint is fresh
      setState(() => _calls = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = _calls
        .where(
          (c) =>
              c.callerName.toLowerCase().contains(_searchQuery) ||
              c.receiverName.toLowerCase().contains(_searchQuery) ||
              c.callReason.toLowerCase().contains(_searchQuery) ||
              (c.serviceRequestId != null &&
                  c.serviceRequestId!.toLowerCase().contains(_searchQuery)),
        )
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 24),
              _buildKpiMetrics(theme),
              const SizedBox(height: 24),
              _buildFilterBar(theme),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCallTable(filtered, theme),
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
              'Agora Voice Communications Audit',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Monitor real-time call connections, duration metrics, and audio recordings.',
              style: TextStyle(color: theme.disabledColor),
            ),
          ],
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Call Logs',
          onPressed: _fetchCallHistory,
        ),
      ],
    );
  }

  Widget _buildKpiMetrics(ThemeData theme) {
    final totalCalls = _calls.length;
    final totalDuration = _calls.fold<int>(
      0,
      (sum, item) => sum + item.durationSeconds,
    );
    final avgDuration = totalCalls > 0
        ? (totalDuration / totalCalls).round()
        : 0;
    final recordedCalls = _calls.where((c) => c.recordingUrl.isNotEmpty).length;

    return Row(
      children: [
        _kpiCard(
          'Total Call Sessions',
          '$totalCalls',
          Icons.phone_in_talk,
          Colors.blueAccent,
          theme,
        ),
        const SizedBox(width: 16),
        _kpiCard(
          'Avg. Conversation',
          '${avgDuration}s',
          Icons.timer,
          Colors.greenAccent,
          theme,
        ),
        const SizedBox(width: 16),
        _kpiCard(
          'Recorded Audios',
          '$recordedCalls Files',
          Icons.mic,
          Colors.orangeAccent,
          theme,
        ),
      ],
    );
  }

  Widget _kpiCard(
    String title,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return SizedBox(
      width: 400,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search by Name, Reason, or Job ID...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: theme.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
      ),
    );
  }

  Widget _buildCallTable(List<CallLogModel> calls, ThemeData theme) {
    if (calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_missed, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No call records found.',
              style: TextStyle(color: theme.disabledColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: calls.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
        itemBuilder: (ctx, i) {
          final call = calls[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: call.durationSeconds > 0
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.red.withValues(alpha: 0.15),
              child: Icon(
                call.durationSeconds > 0 ? Icons.call_made : Icons.call_missed,
                color: call.durationSeconds > 0 ? Colors.green : Colors.red,
              ),
            ),
            title: Row(
              children: [
                Text(
                  '${call.callerName} → ${call.receiverName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 12),
                if (call.serviceRequestId != null)
                  Chip(
                    label: Text(
                      'Job #${call.serviceRequestId!.substring(0, 6)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.blueAccent,
                      ),
                    ),
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${call.callReason} • ${DateFormat('MMM dd, yyyy • hh:mm a').format(call.startedAt)}',
                style: TextStyle(color: theme.disabledColor, fontSize: 12),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  call.durationFormatted,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 24),

                // AUDIO RECORDING PLAYBACK
                if (call.recordingUrl.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.amber,
                    ),
                    tooltip: 'Play Audio Recording',
                    onPressed: () async {
                      final uri = Uri.parse(call.recordingUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),

                // INITIATE CALLBACK
                IconButton(
                  icon: const Icon(
                    Icons.phone_callback,
                    color: Colors.greenAccent,
                  ),
                  tooltip: 'Initiate Instant Callback',
                  onPressed: () => triggerVoiceCall(
                    context: context,
                    dioClient: _dioClient,
                    receiverUserId: call.receiverId,
                    currentUserId: 'ADMIN',
                    receiverName: call.receiverName,
                    serviceRequestId: call.serviceRequestId,
                    reason: 'Admin Follow-up: ${call.callReason}',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
