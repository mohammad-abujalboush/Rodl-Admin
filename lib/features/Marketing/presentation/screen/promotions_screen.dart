import 'package:flutter/material.dart';
import 'package:roadside_service/features/pricing_engine/domain/repositories/admin_repository.dart';
import '../../../../core/di/injection_container.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  final AdminRepository _repo = sl<AdminRepository>();
  List<dynamic> _promos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPromos();
  }

  Future<void> _loadPromos() async {
    setState(() => _isLoading = true);
    _promos = await _repo.getPromotions();
    setState(() => _isLoading = false);
  }

  void _showAddPromoDialog() {
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    int type = 0; // 0 = Percentage, 1 = Flat

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Discount Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Code (e.g., SUMMER20)',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: type,
              decoration: const InputDecoration(labelText: 'Discount Type'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Percentage (%)')),
                DropdownMenuItem(value: 1, child: Text('Flat Amount (\$)')),
              ],
              onChanged: (v) => type = v!,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Discount Value'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (codeCtrl.text.isNotEmpty && valueCtrl.text.isNotEmpty) {
                await _repo.createPromotion({
                  'code': codeCtrl.text,
                  'discountType': type,
                  'discountValue': double.tryParse(valueCtrl.text) ?? 0,
                });
                Navigator.pop(ctx);
                _loadPromos();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promotions & Discounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPromoDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Promo Code'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(32),
              itemCount: _promos.length,
              itemBuilder: (ctx, i) {
                final p = _promos[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_offer, color: Colors.green),
                    title: Text(
                      p['code'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      p['discountType'] == 0
                          ? '${p['discountValue']}% Off'
                          : '\$${p['discountValue']} Off',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await _repo.deletePromotion(p['id']);
                        _loadPromos();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
