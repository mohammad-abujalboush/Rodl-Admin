class DispatchNode {
  String id;
  String title;
  String type; // 'question', 'condition', 'action'
  double x;
  double y;

  // Question properties
  List<String> options;

  // Condition properties
  String conditionField;
  String conditionValue;

  // Action properties
  int dispatchServiceType;
  int dispatchTruckType;
  double customSurcharge;
  String dispatchNotes;

  // --- NEW: Execution Mode ---
  String executionMode;

  DispatchNode({
    required this.id,
    required this.title,
    required this.type,
    required this.x,
    required this.y,
    this.options = const [],
    this.conditionField = '',
    this.conditionValue = '',
    this.dispatchServiceType = 1,
    this.dispatchTruckType = 1,
    this.customSurcharge = 0.0,
    this.dispatchNotes = '',
    this.executionMode = 'standard', // Default to standard tow
  });

  factory DispatchNode.fromJson(Map<String, dynamic> json) => DispatchNode(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    type: json['type'] ?? 'question',
    x: (json['x'] ?? 0).toDouble(),
    y: (json['y'] ?? 0).toDouble(),
    options: List<String>.from(json['options'] ?? []),
    conditionField: json['conditionField'] ?? '',
    conditionValue: json['conditionValue'] ?? '',
    dispatchServiceType: json['dispatchServiceType'] ?? 1,
    dispatchTruckType: json['dispatchTruckType'] ?? 1,
    customSurcharge: (json['customSurcharge'] ?? 0).toDouble(),
    dispatchNotes: json['dispatchNotes'] ?? '',
    executionMode: json['executionMode'] ?? 'standard',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'x': x,
    'y': y,
    'options': options,
    'conditionField': conditionField,
    'conditionValue': conditionValue,
    'dispatchServiceType': dispatchServiceType,
    'dispatchTruckType': dispatchTruckType,
    'customSurcharge': customSurcharge,
    'dispatchNotes': dispatchNotes,
    'executionMode': executionMode,
  };
}

class DispatchEdge {
  String fromNodeId;
  String toNodeId;

  DispatchEdge({required this.fromNodeId, required this.toNodeId});

  factory DispatchEdge.fromJson(Map<String, dynamic> json) => DispatchEdge(
    fromNodeId: json['fromNodeId'] ?? '',
    toNodeId: json['toNodeId'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'fromNodeId': fromNodeId,
    'toNodeId': toNodeId,
  };
}

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
        isActive: json['isActive'] ?? false,
      );
}
