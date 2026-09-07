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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPromos();
  }

  Future<void> _loadPromos() async {
    setState(() => _isLoading = true);
    try {
      _promos = await _repo.getPromotions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load promotions from server.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddPromoDialog() {
    final theme = Theme.of(context);
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    int type = 0; // 0 = Percentage, 1 = Flat

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Add Discount Code',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Code (e.g., SUMMER20) *',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: type,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Discount Type *',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 0,
                        child: Text(
                          'Percentage (%)',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(
                          'Flat Amount (\$)',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => type = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: valueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Discount Value *',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (codeCtrl.text.isNotEmpty &&
                            valueCtrl.text.isNotEmpty) {
                          setModalState(() => _isSaving = true);
                          try {
                            await _repo.createPromotion({
                              'code': codeCtrl.text.toUpperCase().trim(),
                              'discountType': type,
                              'discountValue':
                                  double.tryParse(valueCtrl.text.trim()) ?? 0.0,
                            });
                            if (mounted) Navigator.pop(ctx);
                            _loadPromos();
                          } catch (e) {
                            setModalState(() => _isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Failed to publish promotion.',
                                  ),
                                  backgroundColor: theme.colorScheme.error,
                                ),
                              );
                            }
                          }
                        }
                      },
                child: _isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Publish Promotion',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 32),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _promos.isEmpty
                    ? Center(
                        child: Text(
                          'No promotional discount codes found.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      )
                    : Card(
                        elevation: 0,
                        color: theme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: ListView.separated(
                          itemCount: _promos.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: theme.dividerColor.withValues(alpha: 0.3),
                          ),
                          itemBuilder: (ctx, i) {
                            final p = _promos[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.withValues(
                                  alpha: 0.1,
                                ),
                                child: const Icon(
                                  Icons.local_offer,
                                  color: Colors.green,
                                ),
                              ),
                              title: Text(
                                p['code'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                p['discountType'] == 0
                                    ? '${p['discountValue']}% Off Total Fare'
                                    : '\$${p['discountValue']} Flat Rate Off',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_forever,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Delete Promotion',
                                onPressed: () async {
                                  try {
                                    await _repo.deletePromotion(p['id']);
                                    _loadPromos();
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Failed to delete promotion.',
                                          ),
                                          backgroundColor:
                                              theme.colorScheme.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Promotions & Discounts',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Manage active discount vouchers and flat-rate promos for customers.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: _showAddPromoDialog,
          icon: const Icon(Icons.add),
          label: const Text(
            'Add Promo Code',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
