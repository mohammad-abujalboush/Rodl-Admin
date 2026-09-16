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

  factory MarketingCampaignModel.fromJson(Map<String, dynamic> json) =>
      MarketingCampaignModel(
        id: (json['id'] ?? json['Id'] ?? '').toString(),
        campaignName:
            json['campaignName'] ?? json['CampaignName'] ?? 'Unnamed Campaign',
        channel: json['channel'] ?? json['Channel'] ?? 'General',
        budget: ((json['budget'] ?? json['Budget'] ?? 0) as num).toDouble(),
        spent: ((json['spent'] ?? json['Spent'] ?? 0) as num).toDouble(),
        status: ((json['status'] ?? json['Status'] ?? 1) as num).toInt(),
        startDate:
            DateTime.tryParse(json['startDate'] ?? json['StartDate'] ?? '') ??
            DateTime.now(),
        endDate: json['endDate'] != null || json['EndDate'] != null
            ? DateTime.tryParse(json['endDate'] ?? json['EndDate'] ?? '')
            : null,
        notes: json['notes'] ?? json['Notes'] ?? '',
      );

  String get statusText {
    switch (status) {
      case 0:
        return 'Draft';
      case 1:
        return 'Active';
      case 2:
        return 'Paused';
      case 3:
        return 'Completed';
      default:
        return 'Unknown';
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
    id: (json['id'] ?? json['Id'] ?? '').toString(),
    recipientEmail: json['recipientEmail'] ?? json['RecipientEmail'] ?? '',
    recipientName:
        json['recipientName'] ?? json['RecipientName'] ?? 'Valued User',
    subject: json['subject'] ?? json['Subject'] ?? 'No Subject',
    targetAudience: json['targetAudience'] ?? json['TargetAudience'] ?? 'All',
    status: json['status'] ?? json['Status'] ?? 'Sent',
    sentAt:
        DateTime.tryParse(json['sentAt'] ?? json['SentAt'] ?? '') ??
        DateTime.now(),
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

  factory NotificationLogModel.fromJson(
    Map<String, dynamic> json,
  ) => NotificationLogModel(
    id: (json['id'] ?? json['Id'] ?? '').toString(),
    title: json['title'] ?? json['Title'] ?? 'Alert',
    message: json['message'] ?? json['Message'] ?? '',
    targetAudience: json['targetAudience'] ?? json['TargetAudience'] ?? 'All',
    recipientCount:
        ((json['recipientCount'] ?? json['RecipientCount'] ?? 0) as num)
            .toInt(),
    broadcastAt:
        DateTime.tryParse(json['broadcastAt'] ?? json['BroadcastAt'] ?? '') ??
        DateTime.now(),
  );
}
