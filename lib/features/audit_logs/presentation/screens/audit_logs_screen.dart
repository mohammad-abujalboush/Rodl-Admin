import 'package:flutter/material.dart';
import 'package:roadside_service/features/pricing_engine/domain/repositories/admin_repository.dart';
import '../../../../core/di/injection_container.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final AdminRepository _repo = sl<AdminRepository>();
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    _logs = await _repo.getAuditLogs();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Activity Logs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(32),
              itemCount: _logs.length,
              separatorBuilder: (c, i) => const Divider(),
              itemBuilder: (ctx, i) {
                final log = _logs[i];
                return ListTile(
                  leading: const Icon(Icons.history, color: Colors.blue),
                  title: Text(
                    log['action'] ?? 'System Action',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${log['userEmail'] ?? 'Unknown User'} • ${log['timestamp']}',
                  ),
                  trailing: Text(log['entityName'] ?? ''),
                );
              },
            ),
    );
  }
}
