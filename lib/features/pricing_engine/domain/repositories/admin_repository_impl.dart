import 'package:dio/dio.dart';
import 'package:roadside_service/features/pricing_engine/data/models/pricing_rule_model.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  final DioClient _dioClient;

  AdminRepositoryImpl(this._dioClient);

  @override
  Future<bool> createPricingRule(PricingRuleModel newRule) async {
    try {
      // Adjust the endpoint path if your API routing differs
      final response = await _dioClient.dio.post(
        '/api/admin/pricing-rules',
        data: newRule.toJson(),
      );

      // If you are using Dio directly instead of a remoteDataSource wrapper, use:
      // final response = await dio.post('/api/admin/pricing-rules', data: newRule.toJson());

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<PricingRuleModel>> getPricingRules() async {
    try {
      final response = await _dioClient.dio.get('/api/admin/pricing-rules');
      List<dynamic> data = response.data;
      return data.map((json) => PricingRuleModel.fromJson(json)).toList();
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
      // Returns the newly calculated total from the server
      return (response.data['newTotal'] as num).toDouble();
    } catch (e) {
      throw Exception('Failed to override job pricing: $e');
    }
  }
}
