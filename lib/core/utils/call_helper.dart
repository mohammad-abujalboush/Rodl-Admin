import 'package:flutter/material.dart';
import '../api/dio_client.dart';
import '../../features/communication/presentation/widgets/active_call_dialog.dart';

Future<void> triggerVoiceCall({
  required BuildContext context,
  required DioClient dioClient,
  required String receiverUserId,
  required String currentUserId,
  required String receiverName,
  String? serviceRequestId,
  String reason = 'Direct Communications',
}) async {
  try {
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await dioClient.dio.post(
      '/api/calls/initiate',
      data: {
        'receiverId': receiverUserId,
        'serviceRequestId': serviceRequestId,
        'callReason': reason,
      },
    );

    if (context.mounted) Navigator.pop(context); // Close loading

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data;

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => ActiveCallDialog(
            callId: data['callId'],
            channelName: data['channelName'],
            agoraAppId: data['agoraAppId'],
            token: data['token'],
            userAccount: currentUserId,
            peerName: receiverName,
            callReason: reason,
            dioClient: dioClient,
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to initiate call. Ensure recipient is available.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
