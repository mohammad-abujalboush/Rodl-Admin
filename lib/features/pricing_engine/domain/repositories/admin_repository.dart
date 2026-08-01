import '../../data/models/pricing_rule_model.dart';

abstract class AdminRepository {
  Future<List<PricingRuleModel>> getPricingRules();
  Future<bool> updatePricingRule(int serviceType, PricingRuleModel updatedRule);
  Future<double> overrideJobPricing(
    String requestId,
    Map<String, dynamic> overrideData,
  );
  Future<bool> createPricingRule(PricingRuleModel newRule);
}
