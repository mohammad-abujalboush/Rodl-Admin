import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/services/agora_call_service.dart';

class ActiveCallDialog extends StatefulWidget {
  final String callId;
  final String channelName;
  final String agoraAppId;
  final String token;
  final String userAccount;
  final String peerName;
  final String callReason;
  final DioClient dioClient;

  const ActiveCallDialog({
    super.key,
    required this.callId,
    required this.channelName,
    required this.agoraAppId,
    required this.token,
    required this.userAccount,
    required this.peerName,
    required this.callReason,
    required this.dioClient,
  });

  @override
  State<ActiveCallDialog> createState() => _ActiveCallDialogState();
}

class _ActiveCallDialogState extends State<ActiveCallDialog> {
  final AgoraCallService _agoraService = AgoraCallService();
  Timer? _callTimer;
  int _secondsElapsed = 0;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _startCallSession();
  }

  Future<void> _startCallSession() async {
    try {
      await _agoraService.joinCall(
        appId: widget.agoraAppId,
        channelName: widget.channelName,
        token: widget.token,
        userAccount: widget.userAccount,
      );

      setState(() => _isConnected = true);

      _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _secondsElapsed++);
        }
      });
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _endCall() async {
    _callTimer?.cancel();
    await _agoraService.leaveCall();

    try {
      await widget.dioClient.dio.post(
        '/api/calls/${widget.callId}/end',
        data: {'durationSeconds': _secondsElapsed},
      );
    } catch (_) {}

    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
              child: Icon(Icons.person, size: 48, color: theme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              widget.peerName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.callReason,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _isConnected ? _formatDuration(_secondsElapsed) : 'Connecting...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _isConnected ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  iconSize: 28,
                  icon: Icon(_agoraService.isMuted ? Icons.mic_off : Icons.mic),
                  color: _agoraService.isMuted
                      ? Colors.red
                      : theme.colorScheme.onSurface,
                  onPressed: () async {
                    await _agoraService.toggleMute();
                    setState(() {});
                  },
                ),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  elevation: 0,
                  onPressed: _endCall,
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                IconButton.filledTonal(
                  iconSize: 28,
                  icon: Icon(
                    _agoraService.isSpeakerPhone
                        ? Icons.volume_up
                        : Icons.volume_off,
                  ),
                  color: _agoraService.isSpeakerPhone
                      ? Colors.blue
                      : theme.colorScheme.onSurface,
                  onPressed: () async {
                    await _agoraService.toggleSpeaker();
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
