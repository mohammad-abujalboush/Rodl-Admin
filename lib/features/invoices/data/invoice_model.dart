enum InvoiceType { b2cReceipt, b2bBatch, driverSettlement }

enum InvoiceStatus { draft, unpaid, paid, overdue, voided }

class InvoiceModel {
  final String id;
  final InvoiceType type;
  final InvoiceStatus status;
  final String recipientName;
  final String recipientEmail;
  final String? referenceId;
  final DateTime issueDate;
  final DateTime? dueDate;
  final double subtotal;
  final double tax;
  final double totalAmount;
  final List<InvoiceLineItem> lineItems;

  InvoiceModel({
    required this.id,
    required this.type,
    required this.status,
    required this.recipientName,
    required this.recipientEmail,
    this.referenceId,
    required this.issueDate,
    this.dueDate,
    required this.subtotal,
    required this.tax,
    required this.totalAmount,
    required this.lineItems,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id']?.toString() ?? '',
      type: InvoiceType.values[(json['type'] ?? 0).clamp(0, 2)],
      status: InvoiceStatus.values[(json['status'] ?? 0).clamp(0, 4)],
      recipientName: json['recipientName'] ?? 'Unknown Recipient',
      recipientEmail: json['recipientEmail'] ?? '',
      referenceId: json['referenceId']?.toString(),
      issueDate: DateTime.parse(
        json['issueDate'] ?? DateTime.now().toIso8601String(),
      ),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      lineItems:
          (json['lineItems'] as List<dynamic>?)
              ?.map((item) => InvoiceLineItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  String get typeText {
    switch (type) {
      case InvoiceType.b2cReceipt:
        return 'Customer Receipt';
      case InvoiceType.b2bBatch:
        return 'Corporate B2B Invoice';
      case InvoiceType.driverSettlement:
        return 'Driver Settlement';
    }
  }

  String get statusText {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.unpaid:
        return 'Unpaid';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.voided:
        return 'Voided';
    }
  }
}

class InvoiceLineItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;

  InvoiceLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      description: json['description'] ?? 'Service Line Item',
      quantity: (json['quantity'] ?? 1) is double
          ? (json['quantity'] as double).toInt()
          : (json['quantity'] ?? 1),
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}
