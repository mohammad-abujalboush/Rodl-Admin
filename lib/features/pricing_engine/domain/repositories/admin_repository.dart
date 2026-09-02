import '../../data/models/pricing_rule_model.dart';

abstract class AdminRepository {
  // Pricing Rules
  Future<List<PricingRuleModel>> getPricingRules();
  Future<bool> updatePricingRule(int serviceType, PricingRuleModel updatedRule);
  Future<double> overrideJobPricing(
    String requestId,
    Map<String, dynamic> overrideData,
  );
  Future<bool> createPricingRule(PricingRuleModel newRule);
  Future<bool> deletePricingRule(String id);

  // Promotions (Note 14)
  Future<List<dynamic>> getPromotions();
  Future<bool> createPromotion(Map<String, dynamic> promoData);
  Future<bool> deletePromotion(String id);

  // Policy Hub (Note 11)
  Future<String> getPolicyDocument(String type);
  Future<bool> updatePolicyDocument(String type, String content);

  // Audit Logs (Note 12)
  Future<List<dynamic>> getAuditLogs();
}
