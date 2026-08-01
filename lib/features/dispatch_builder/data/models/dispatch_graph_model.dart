class PricingRuleOption {
  final int serviceType;
  final String ruleName;
  final double baseFare;
  final bool isActive;

  PricingRuleOption({
    required this.serviceType,
    required this.ruleName,
    required this.baseFare,
    required this.isActive,
  });

  factory PricingRuleOption.fromJson(Map<String, dynamic> json) =>
      PricingRuleOption(
        serviceType: json['serviceType'] ?? 1,
        ruleName: json['ruleName'] ?? 'Unknown Service',
        baseFare: (json['baseFare'] ?? 0).toDouble(),
        isActive: json['isActive'] ?? true,
      );
}

class DispatchNode {
  final String id;
  String title;
  String type;
  double x;
  double y;

  int dispatchServiceType;
  int dispatchTruckType;
  String dispatchNotes;
  double customSurcharge;

  String conditionField;
  String conditionOperator;
  String conditionValue;
  List<String> options;

  DispatchNode({
    required this.id,
    required this.title,
    required this.type,
    required this.x,
    required this.y,
    this.dispatchServiceType = 1,
    this.dispatchTruckType = 1,
    this.dispatchNotes = '',
    this.customSurcharge = 0.0,
    this.conditionField = '',
    this.conditionOperator = 'equals',
    this.conditionValue = '',
    List<String>? options,
  }) : options = options ?? ['Option 1'];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'x': x,
    'y': y,
    'dispatchServiceType': dispatchServiceType,
    'dispatchTruckType': dispatchTruckType,
    'dispatchNotes': dispatchNotes,
    'customSurcharge': customSurcharge,
    'conditionField': conditionField,
    'conditionOperator': conditionOperator,
    'conditionValue': conditionValue,
    'options': options,
  };

  factory DispatchNode.fromJson(Map<String, dynamic> json) => DispatchNode(
    id: json['id'] ?? '',
    title: json['title'] ?? 'New Node',
    type: json['type'] ?? 'question',
    x: (json['x'] ?? 100).toDouble(),
    y: (json['y'] ?? 100).toDouble(),
    dispatchServiceType: json['dispatchServiceType'] ?? 1,
    dispatchTruckType: json['dispatchTruckType'] ?? 1,
    dispatchNotes: json['dispatchNotes'] ?? '',
    customSurcharge: (json['customSurcharge'] ?? 0).toDouble(),
    conditionField: json['conditionField'] ?? '',
    conditionOperator: json['conditionOperator'] ?? 'equals',
    conditionValue: json['conditionValue'] ?? '',
    options: json['options'] != null
        ? List<String>.from(json['options'])
        : ['Option 1'],
  );
}

class DispatchEdge {
  final String fromNodeId;
  final String toNodeId;

  DispatchEdge({required this.fromNodeId, required this.toNodeId});

  Map<String, dynamic> toJson() => {
    'fromNodeId': fromNodeId,
    'toNodeId': toNodeId,
  };

  factory DispatchEdge.fromJson(Map<String, dynamic> json) => DispatchEdge(
    fromNodeId: json['fromNodeId'] ?? '',
    toNodeId: json['toNodeId'] ?? '',
  );
}
