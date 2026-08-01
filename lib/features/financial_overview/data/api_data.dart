import 'package:dio/dio.dart';

class FinancialLedgerService {
  final Dio _dio;

  FinancialLedgerService(this._dio);

  // Maps to POST /api/Admin/kpis/filtered
  Future<Map<String, dynamic>> getSystemKpis({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _dio.post(
        '/api/Admin/kpis/filtered',
        data: {
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load KPIs: $e');
    }
  }

  // Maps to GET /api/admin/payroll/preview
  Future<List<dynamic>> getPayrollPreview() async {
    try {
      final response = await _dio.get('/api/admin/payroll/preview');
      return response.data as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to load payroll preview: $e');
    }
  }

  // Maps to GET /api/Admin/invoices
  Future<List<dynamic>> getInvoices() async {
    try {
      final response = await _dio.get('/api/Admin/invoices');
      return response.data['invoices'] ?? [];
    } catch (e) {
      throw Exception('Failed to load invoices: $e');
    }
  }
}
