class MarketingCampaignModel {
  final String id;
  final String campaignName;
  final String channel;
  final double budget;
  final double spent;
  final int status; // 0=Draft, 1=Active, 2=Paused, 3=Completed
  final DateTime startDate;
  final DateTime? endDate;
  final String notes;

  MarketingCampaignModel({
    required this.id,
    required this.campaignName,
    required this.channel,
    required this.budget,
    required this.spent,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.notes,
  });

  factory MarketingCampaignModel.fromJson(Map<String, dynamic> json) => MarketingCampaignModel(
    id: json['id'] ?? '',
    campaignName: json['campaignName'] ?? 'Unnamed Campaign',
    channel: json['channel'] ?? 'General',
    budget: (json['budget'] ?? 0).toDouble(),
    spent: (json['spent'] ?? 0).toDouble(),
    status: json['status'] ?? 1,
    startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now(),
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    notes: json['notes'] ?? '',
  );

  String get statusText {
    switch (status) {
      case 0: return 'Draft';
      case 1: return 'Active';
      case 2: return 'Paused';
      case 3: return 'Completed';
      default: return 'Unknown';
    }
  }
}

class EmailLogModel {
  final String id;
  final String recipientEmail;
  final String recipientName;
  final String subject;
  final String targetAudience;
  final String status;
  final DateTime sentAt;

  EmailLogModel({
    required this.id,
    required this.recipientEmail,
    required this.recipientName,
    required this.subject,
    required this.targetAudience,
    required this.status,
    required this.sentAt,
  });

  factory EmailLogModel.fromJson(Map<String, dynamic> json) => EmailLogModel(
    id: json['id'] ?? '',
    recipientEmail: json['recipientEmail'] ?? '',
    recipientName: json['recipientName'] ?? 'Valued User',
    subject: json['subject'] ?? 'No Subject',
    targetAudience: json['targetAudience'] ?? 'All',
    status: json['status'] ?? 'Sent',
    sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt']) : DateTime.now(),
  );
}

class NotificationLogModel {
  final String id;
  final String title;
  final String message;
  final String targetAudience;
  final int recipientCount;
  final DateTime broadcastAt;

  NotificationLogModel({
    required this.id,
    required this.title,
    required this.message,
    required this.targetAudience,
    required this.recipientCount,
    required this.broadcastAt,
  });

  factory NotificationLogModel.fromJson(Map<String, dynamic> json) => NotificationLogModel(
    id: json['id'] ?? '',
    title: json['title'] ?? 'Alert',
    message: json['message'] ?? '',
    targetAudience: json['targetAudience'] ?? 'All',
    recipientCount: json['recipientCount'] ?? 0,
    broadcastAt: json['broadcastAt'] != null ? DateTime.parse(json['broadcastAt']) : DateTime.now(),
  );
}