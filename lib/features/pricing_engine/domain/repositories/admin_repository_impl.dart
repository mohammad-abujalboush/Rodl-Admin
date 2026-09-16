import 'package:roadside_service/features/pricing_engine/data/models/pricing_rule_model.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  final DioClient _dioClient;

  AdminRepositoryImpl(this._dioClient);

  // --- PRICING ENGINE ---
  @override
  Future<bool> createPricingRule(PricingRuleModel newRule) async {
    try {
      final response = await _dioClient.dio.post(
        '/api/admin/pricing-rules',
        data: newRule.toJson(),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<PricingRuleModel>> getPricingRules() async {
    try {
      final response = await _dioClient.dio.get('/api/admin/pricing-rules');
      return (response.data as List)
          .map((json) => PricingRuleModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load pricing rules: $e');
    }
  }

  @override
  Future<bool> updatePricingRule(
    int serviceType,
    PricingRuleModel updatedRule,
  ) async {
    try {
      final response = await _dioClient.dio.put(
        '/api/admin/pricing-rules/$serviceType',
        data: updatedRule.toJson(),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to update pricing rule: $e');
    }
  }

  @override
  Future<double> overrideJobPricing(
    String requestId,
    Map<String, dynamic> overrideData,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        '/api/admin/override-job/$requestId',
        data: overrideData,
      );
      return (response.data['newTotal'] as num).toDouble();
    } catch (e) {
      throw Exception('Failed to override job pricing: $e');
    }
  }

  @override
  Future<bool> deletePricingRule(String id) async {
    try {
      final response = await _dioClient.dio.delete(
        '/api/admin/pricing-rules/$id',
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to delete pricing rule: $e');
    }
  }

  // --- PROMOTIONS ---
  @override
  Future<List<dynamic>> getPromotions() async {
    try {
      final response = await _dioClient.dio.get('/api/admin/promotions');
      return response.data as List;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> createPromotion(Map<String, dynamic> promoData) async {
    try {
      final response = await _dioClient.dio.post(
        '/api/admin/promotions',
        data: promoData,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deletePromotion(String id) async {
    try {
      final response = await _dioClient.dio.delete('/api/admin/promotions/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- POLICY HUB ---
  @override
  Future<String> getPolicyDocument(String type) async {
    try {
      final response = await _dioClient.dio.get('/api/Policies/$type');
      return response.data['content'] ?? '';
    } catch (e) {
      return '';
    }
  }

  @override
  Future<bool> updatePolicyDocument(String type, String content) async {
    try {
      final response = await _dioClient.dio.put(
        '/api/Policies/$type',
        data: {'content': content},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- AUDIT LOGS ---
  @override
  Future<List<dynamic>> getAuditLogs() async {
    try {
      final response = await _dioClient.dio.get('/api/admin/audit-logs');
      return response.data as List;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> updatePromotion(String id, Map<String, dynamic> data) async {
    try {
      await _dioClient.dio.put('/api/admin/promotions/$id', data: data);
    } catch (e) {
      throw Exception('Failed to update promotion');
    }
  }
}
