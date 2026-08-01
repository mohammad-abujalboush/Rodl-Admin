import 'package:flutter/material.dart';

class SupportTicketModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone; // NEW
  final String customerEmail; // NEW
  final String subject;
  final String description;
  final int status;
  final int priority;
  final DateTime createdAt;
  final String? adminNotes;

  SupportTicketModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.adminNotes,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: json['ticketId'] ?? '',
      customerId: json['userId'] ?? '',
      customerName: json['customerName'] ?? 'Guest Customer',
      customerPhone: json['customerPhone'] ?? 'No Phone', // NEW
      customerEmail: json['customerEmail'] ?? 'No Email', // NEW
      subject: json['subject'] ?? 'No Subject',
      description: json['description'] ?? '',
      status: json['status'] ?? 0,
      priority: json['priority'] ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      adminNotes: json['adminNotes'],
    );
  }

  String get statusText {
    switch (status) {
      case 0:
        return 'Open';
      case 1:
        return 'In Progress';
      case 2:
        return 'Waiting on Customer';
      case 3:
        return 'Escalated';
      case 4:
        return 'Resolved';
      case 5:
        return 'Closed';
      default:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (status) {
      case 0:
        return Colors.blue;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.amber;
      case 3:
        return Colors.red;
      case 4:
        return Colors.green;
      case 5:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String get priorityText {
    switch (priority) {
      case 0:
        return 'Low';
      case 1:
        return 'Normal';
      case 2:
        return 'High';
      case 3:
        return 'Urgent';
      default:
        return 'Normal';
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 0:
        return Colors.blueGrey;
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.green;
    }
  }
}
