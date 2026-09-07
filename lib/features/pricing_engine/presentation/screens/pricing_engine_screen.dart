import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:roadside_service/features/pricing_engine/data/models/pricing_rule_model.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/pricing_engine_bloc.dart';

class PricingEngineScreen extends StatefulWidget {
  const PricingEngineScreen({super.key});

  @override
  State<PricingEngineScreen> createState() => _PricingEngineScreenState();
}

class _PricingEngineScreenState extends State<PricingEngineScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => sl<PricingEngineBloc>()..add(FetchPricingRules()),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        floatingActionButton: Builder(
          builder: (blocContext) => FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text(
              'Add Pricing Rule',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: theme.primaryColor,
            foregroundColor: theme.colorScheme.onPrimary,
            onPressed: () => _showPricingWizard(blocContext, null),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                const SizedBox(height: 24),
                SizedBox(
                  width: 380,
                  child: TextField(
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search by service name or category...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.toLowerCase()),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: BlocConsumer<PricingEngineBloc, PricingEngineState>(
                    listener: (context, state) {
                      if (state is PricingActionSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      } else if (state is PricingError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                    },
                    buildWhen: (prev, current) =>
                        current is PricingLoaded || current is PricingLoading,
                    builder: (context, state) {
                      if (state is PricingLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is PricingLoaded) {
                        final filteredRules = state.rules.where((r) {
                          return r.ruleName.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              r.serviceTypeName.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              r.description.toLowerCase().contains(
                                _searchQuery,
                              );
                        }).toList();

                        if (filteredRules.isEmpty) {
                          return Center(
                            child: Text(
                              'No pricing rules match your search.',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 16,
                              ),
                            ),
                          );
                        }

                        return GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: getValueForScreenType<int>(
                                  context: context,
                                  mobile: 1,
                                  tablet: 2,
                                  desktop: 3,
                                ),
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                                childAspectRatio: 1.8,
                              ),
                          itemCount: filteredRules.length,
                          itemBuilder: (ctx, i) =>
                              _buildRuleCard(filteredRules[i], theme, ctx),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pricing Engine & Rate Cards',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Configure base hookup rates, distance brackets, wait penalties, and multi-truck surcharges.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildRuleCard(
    PricingRuleModel rule,
    ThemeData theme,
    BuildContext blocContext,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    rule.ruleName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text(
                    rule.serviceTypeName,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              rule.description.isEmpty
                  ? 'No description provided.'
                  : rule.description,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Divider(
              height: 20,
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base Price',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '\$${rule.baseFare.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance Rate',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '\$${rule.ratePerKm.toStringAsFixed(2)} /km',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                FilledButton.tonal(
                  onPressed: () => _showPricingWizard(blocContext, rule),
                  child: const Text('Edit Rates'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPricingWizard(
    BuildContext parentContext,
    PricingRuleModel? existingRule,
  ) {
    final bloc = parentContext.read<PricingEngineBloc>();
    final isNew = existingRule == null;

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(parentContext).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: _PricingWizardForm(
          bloc: bloc,
          existingRule: existingRule,
          isNew: isNew,
        ),
      ),
    );
  }
}

class _PricingWizardForm extends StatefulWidget {
  final PricingEngineBloc bloc;
  final PricingRuleModel? existingRule;
  final bool isNew;

  const _PricingWizardForm({
    required this.bloc,
    this.existingRule,
    required this.isNew,
  });

  @override
  State<_PricingWizardForm> createState() => _PricingWizardFormState();
}

class _PricingWizardFormState extends State<_PricingWizardForm>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _serviceType = 1;

  final _baseFareCtrl = TextEditingController();
  final _incDistCtrl = TextEditingController();
  final _rateKmCtrl = TextEditingController();

  final _recBaseCtrl = TextEditingController();
  final _recIncMinCtrl = TextEditingController();
  final _recRateMinCtrl = TextEditingController();
  final _waitFreeMinCtrl = TextEditingController();
  final _waitRateMinCtrl = TextEditingController();
  final _cancelFeeCtrl = TextEditingController();

  final _afterHoursCtrl = TextEditingController();
  final _holidayCtrl = TextEditingController();
  final _duallyCtrl = TextEditingController();
  final _multiTruckCtrl = TextEditingController();

  // The 17 backend service types mapping
  final Map<int, String> _allServiceTypes = const {
    1: 'Wheel Lift Towing',
    2: 'Flatbed Carrier',
    3: 'Underground / Specialty Tow',
    4: 'Heavy Duty Commercial Tow',
    5: 'Motorcycle Towing',
    6: 'Battery Jump Start',
    7: 'Flat Tire Service',
    8: 'Lockout Service',
    9: 'Fuel / Fluid Delivery',
    10: 'Winching / Off-Road Recovery',
    11: 'Dollies / Locked Wheels Towing',
    12: 'EV Mobile Charging',
    13: 'Accident Scene Clearance',
    14: 'Tire Inflation / Air Only',
    15: 'Electric Vehicle Flatbed Only',
    16: 'Exotic Luxury Enclosed Tow',
    17: 'Secondary Highway Escort (Safety Unit)',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (!widget.isNew && widget.existingRule != null) {
      final r = widget.existingRule!;
      _nameCtrl.text = r.ruleName;
      _descCtrl.text = r.description;
      _serviceType = _allServiceTypes.containsKey(r.serviceType)
          ? r.serviceType
          : 1;

      _baseFareCtrl.text = r.baseFare.toString();
      _incDistCtrl.text = r.includedDistanceKm.toString();
      _rateKmCtrl.text = r.ratePerKm.toString();

      _recBaseCtrl.text = r.recoveryBaseRate.toString();
      _recIncMinCtrl.text = r.recoveryIncludedMinutes.toString();
      _recRateMinCtrl.text = r.recoveryRatePerMinute.toString();
      _waitFreeMinCtrl.text = r.freeWaitingTimeMinutes.toString();
      _waitRateMinCtrl.text = r.waitingRatePerMinute.toString();
      _cancelFeeCtrl.text = r.cancellationFee.toString();

      _afterHoursCtrl.text = r.afterHoursSurcharge?.toString() ?? '';
      _holidayCtrl.text = r.holidaySurcharge?.toString() ?? '';
      _duallyCtrl.text = r.duallySurcharge?.toString() ?? '';
      _multiTruckCtrl.text = r.multiTruckSurcharge?.toString() ?? '';
    } else {
      _baseFareCtrl.text = '75.00';
      _incDistCtrl.text = '5.0';
      _rateKmCtrl.text = '3.50';
      _recBaseCtrl.text = '50.00';
      _recIncMinCtrl.text = '15';
      _recRateMinCtrl.text = '2.00';
      _waitFreeMinCtrl.text = '10';
      _waitRateMinCtrl.text = '1.50';
      _cancelFeeCtrl.text = '50.00';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _baseFareCtrl.dispose();
    _incDistCtrl.dispose();
    _rateKmCtrl.dispose();
    _recBaseCtrl.dispose();
    _recIncMinCtrl.dispose();
    _recRateMinCtrl.dispose();
    _waitFreeMinCtrl.dispose();
    _waitRateMinCtrl.dispose();
    _cancelFeeCtrl.dispose();
    _afterHoursCtrl.dispose();
    _holidayCtrl.dispose();
    _duallyCtrl.dispose();
    _multiTruckCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.isNew
                        ? 'Add New Pricing Rule'
                        : 'Edit Pricing: ${_nameCtrl.text}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _nameCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Pricing Rule Name *',
                      filled: true,
                      fillColor: theme.cardColor,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: _serviceType,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Target Service Type *',
                      filled: true,
                      fillColor: theme.cardColor,
                      border: const OutlineInputBorder(),
                    ),
                    items: _allServiceTypes.entries.map((entry) {
                      return DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: widget.isNew
                        ? (v) => setState(() => _serviceType = v!)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Description / Operational Notes',
                filled: true,
                fillColor: theme.cardColor,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            TabBar(
              controller: _tabController,
              labelColor: theme.primaryColor,
              unselectedLabelColor: theme.disabledColor,
              indicatorColor: theme.primaryColor,
              tabs: const [
                Tab(text: 'Standard Rates'),
                Tab(text: 'Recovery & Waiting'),
                Tab(text: 'Addons & Surcharges'),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCoreRatesTab(theme),
                  _buildRecoveryTab(theme),
                  _buildSurchargesTab(theme),
                ],
              ),
            ),
            Divider(
              height: 32,
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!widget.isNew)
                  TextButton.icon(
                    onPressed: () {
                      widget.bloc.add(
                        DeletePricingRule(widget.existingRule!.id),
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'Delete Rule',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'Save Pricing Rule',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      onPressed: _saveRule,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoreRatesTab(ThemeData theme) {
    return ListView(
      children: [
        _buildCurrencyInput(
          'Base Hookup Fee (\$)',
          _baseFareCtrl,
          theme,
          isRequired: true,
        ),
        _buildNumericInput(
          'Distance Included Free (km)',
          _incDistCtrl,
          theme,
          isRequired: true,
        ),
        _buildCurrencyInput(
          'Rate per Excess Kilometer (\$ / km)',
          _rateKmCtrl,
          theme,
          isRequired: true,
        ),
        _buildCurrencyInput(
          'Cancellation Penalty Fee (\$)',
          _cancelFeeCtrl,
          theme,
          isRequired: true,
        ),
      ],
    );
  }

  Widget _buildRecoveryTab(ThemeData theme) {
    return ListView(
      children: [
        _buildCurrencyInput(
          'Off-Road Winching Base Fee (\$)',
          _recBaseCtrl,
          theme,
          isRequired: true,
        ),
        _buildNumericInput(
          'Included Winching Time (Minutes)',
          _recIncMinCtrl,
          theme,
          isRequired: true,
        ),
        _buildCurrencyInput(
          'Excess Winching Fee (\$ / Minute)',
          _recRateMinCtrl,
          theme,
          isRequired: true,
        ),
        Divider(height: 32, color: theme.dividerColor.withValues(alpha: 0.3)),
        _buildNumericInput(
          'Free Driver Waiting Window (Minutes)',
          _waitFreeMinCtrl,
          theme,
          isRequired: true,
        ),
        _buildCurrencyInput(
          'Driver Wait Penalty (\$ / Minute)',
          _waitRateMinCtrl,
          theme,
          isRequired: true,
        ),
      ],
    );
  }

  Widget _buildSurchargesTab(ThemeData theme) {
    return ListView(
      children: [
        _buildCurrencyInput(
          'Night / After-Hours Surcharge (\$)',
          _afterHoursCtrl,
          theme,
          isRequired: false,
        ),
        _buildCurrencyInput(
          'Statutory Holiday Surcharge (\$)',
          _holidayCtrl,
          theme,
          isRequired: false,
        ),
        _buildCurrencyInput(
          'Dually / Heavy-Duty Wheelbase Surcharge (\$)',
          _duallyCtrl,
          theme,
          isRequired: false,
        ),
        _buildCurrencyInput(
          'Dual-Dispatch / Multi-Truck Surcharge (\$)',
          _multiTruckCtrl,
          theme,
          isRequired: false,
        ),
      ],
    );
  }

  Widget _buildCurrencyInput(
    String label,
    TextEditingController ctrl,
    ThemeData theme, {
    required bool isRequired,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: ctrl,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.attach_money, size: 18),
          filled: true,
          fillColor: theme.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: isRequired
            ? (v) => (v == null || v.isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _buildNumericInput(
    String label,
    TextEditingController ctrl,
    ThemeData theme, {
    required bool isRequired,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: ctrl,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: theme.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
        ),
        keyboardType: TextInputType.number,
        validator: isRequired
            ? (v) => (v == null || v.isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  void _saveRule() {
    if (_formKey.currentState!.validate()) {
      final rule = PricingRuleModel(
        id: widget.existingRule?.id ?? '',
        ruleName: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        serviceType: _serviceType,
        baseFare: double.tryParse(_baseFareCtrl.text.trim()) ?? 0.0,
        includedDistanceKm: double.tryParse(_incDistCtrl.text.trim()) ?? 0.0,
        ratePerKm: double.tryParse(_rateKmCtrl.text.trim()) ?? 0.0,
        hourlyRate: 0.0,
        recoveryBaseRate: double.tryParse(_recBaseCtrl.text.trim()) ?? 0.0,
        recoveryIncludedMinutes: int.tryParse(_recIncMinCtrl.text.trim()) ?? 0,
        recoveryRatePerMinute:
            double.tryParse(_recRateMinCtrl.text.trim()) ?? 0.0,
        freeWaitingTimeMinutes: int.tryParse(_waitFreeMinCtrl.text.trim()) ?? 0,
        waitingRatePerMinute:
            double.tryParse(_waitRateMinCtrl.text.trim()) ?? 0.0,
        cancellationFee: double.tryParse(_cancelFeeCtrl.text.trim()) ?? 0.0,
        afterHoursSurcharge: double.tryParse(_afterHoursCtrl.text.trim()),
        holidaySurcharge: double.tryParse(_holidayCtrl.text.trim()),
        duallySurcharge: double.tryParse(_duallyCtrl.text.trim()),
        multiTruckSurcharge: double.tryParse(_multiTruckCtrl.text.trim()),
        isActive: true,
      );
      widget.bloc.add(SavePricingRule(rule: rule, isNew: widget.isNew));
      Navigator.pop(context);
    }
  }
}
