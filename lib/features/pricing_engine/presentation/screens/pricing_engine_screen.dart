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
            label: const Text('Add Pricing Rule'),
            backgroundColor: theme.primaryColor,
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
                const SizedBox(height: 32),
                Expanded(
                  child: BlocConsumer<PricingEngineBloc, PricingEngineState>(
                    listener: (context, state) {
                      if (state is PricingActionSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.green,
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
                      if (state is PricingLoading)
                        return const Center(child: CircularProgressIndicator());
                      if (state is PricingLoaded) {
                        if (state.rules.isEmpty)
                          return const Center(
                            child: Text(
                              'No pricing rules defined.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );

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
                          itemCount: state.rules.length,
                          itemBuilder: (ctx, i) =>
                              _buildRuleCard(state.rules[i], theme, ctx),
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
          'Pricing Rules',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage starting prices, per-kilometer fees, and extra charges.',
          style: TextStyle(color: theme.disabledColor),
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
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
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
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              rule.description,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Base Price',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    Text(
                      '\$${rule.baseFare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Distance Rate',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    Text(
                      '\$${rule.ratePerKm.toStringAsFixed(2)} /km',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                FilledButton.tonal(
                  onPressed: () => _showPricingWizard(blocContext, rule),
                  child: const Text('Edit Prices'),
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (!widget.isNew && widget.existingRule != null) {
      final r = widget.existingRule!;
      _nameCtrl.text = r.ruleName;
      _descCtrl.text = r.description;
      _serviceType = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].contains(r.serviceType)
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
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use BoxConstraints to ensure it scales down nicely on mobile screens
    return Container(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 750),
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isNew
                      ? 'Add New Pricing Rule'
                      : 'Edit Pricing: ${_nameCtrl.text}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
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
                    decoration: InputDecoration(
                      labelText: 'Pricing Rule Name *',
                      filled: true,
                      fillColor: theme.cardColor,
                      border: const OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<int>(
                    value: _serviceType,
                    dropdownColor: theme.cardColor,
                    decoration: InputDecoration(
                      labelText: 'Target Service Type',
                      filled: true,
                      fillColor: theme.cardColor,
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 1,
                        child: Text(
                          'Wheel Lift Towing',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text(
                          'Flatbed Carrier',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text(
                          'Underground / Low Clearance',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 4,
                        child: Text(
                          'Heavy Duty / Commercial Tow',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 5,
                        child: Text(
                          'Motorcycle Towing',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 6,
                        child: Text(
                          'Battery Jump Start',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 7,
                        child: Text(
                          'Flat Tire Service',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 8,
                        child: Text(
                          'Vehicle Lockout Service',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 9,
                        child: Text(
                          'Fuel / Fluid Delivery',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 10,
                        child: Text(
                          'Winching / Off-Road Recovery',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
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
              decoration: InputDecoration(
                labelText: 'Notes',
                filled: true,
                fillColor: theme.cardColor,
                border: const OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            TabBar(
              controller: _tabController,
              labelColor: theme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: theme.primaryColor,
              tabs: const [
                Tab(text: 'Standard Fees'),
                Tab(text: 'Wait Fees'),
                Tab(text: 'Extra Fees'),
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
            const Divider(height: 32),
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
                      label: const Text('Save Pricing Rule'),
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
          'Starting Base Price (\$)',
          _baseFareCtrl,
          theme,
          isRequired: true,
        ),
        _buildNumericInput(
          'Free Kilometers Included',
          _incDistCtrl,
          theme,
          isRequired: true,
        ),
        _buildCurrencyInput(
          'Per-Kilometer Extra Fee (\$)',
          _rateKmCtrl,
          theme,
          isRequired: true,
        ),
        _buildCurrencyInput(
          'Cancellation Fee (\$)',
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
          'Winching Base Fee (\$)',
          _recBaseCtrl,
          theme,
          isRequired: true,
        ),
        _buildNumericInput(
          'Free Winching Time (Minutes)',
          _recIncMinCtrl,
          theme,
          isRequired: true,
        ),
        _buildCurrencyInput(
          'Extra Winching Time Fee (\$ / Min)',
          _recRateMinCtrl,
          theme,
          isRequired: true,
        ),
        const Divider(height: 32),
        _buildNumericInput(
          'Free Waiting Time for Driver (Minutes)',
          _waitFreeMinCtrl,
          theme,
          isRequired: true,
        ),
        _buildCurrencyInput(
          'Driver Waiting Fee (\$ / Min)',
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
          'Night / After-Hours Extra Fee (\$)',
          _afterHoursCtrl,
          theme,
          isRequired: false,
        ),
        _buildCurrencyInput(
          'Holiday Extra Fee (\$)',
          _holidayCtrl,
          theme,
          isRequired: false,
        ),
        _buildCurrencyInput(
          'Heavy Vehicle Extra Fee (\$)',
          _duallyCtrl,
          theme,
          isRequired: false,
        ),
        _buildCurrencyInput(
          'Multiple Trucks Extra Fee (\$)',
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
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.attach_money, size: 16),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          border: const OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white),
        validator: isRequired ? (v) => v!.isEmpty ? 'Required' : null : null,
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
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        validator: isRequired ? (v) => v!.isEmpty ? 'Required' : null : null,
      ),
    );
  }

  void _saveRule() {
    if (_formKey.currentState!.validate()) {
      final rule = PricingRuleModel(
        id: widget.existingRule?.id ?? '',
        ruleName: _nameCtrl.text,
        description: _descCtrl.text,
        serviceType: _serviceType,
        baseFare: double.parse(_baseFareCtrl.text),
        includedDistanceKm: double.parse(_incDistCtrl.text),
        ratePerKm: double.parse(_rateKmCtrl.text),
        hourlyRate: 0,
        recoveryBaseRate: double.parse(_recBaseCtrl.text),
        recoveryIncludedMinutes: int.parse(_recIncMinCtrl.text),
        recoveryRatePerMinute: double.parse(_recRateMinCtrl.text),
        freeWaitingTimeMinutes: int.parse(_waitFreeMinCtrl.text),
        waitingRatePerMinute: double.parse(_waitRateMinCtrl.text),
        cancellationFee: double.parse(_cancelFeeCtrl.text),
        afterHoursSurcharge: double.tryParse(_afterHoursCtrl.text),
        holidaySurcharge: double.tryParse(_holidayCtrl.text),
        duallySurcharge: double.tryParse(_duallyCtrl.text),
        multiTruckSurcharge: double.tryParse(_multiTruckCtrl.text),
        isActive: true,
      );
      widget.bloc.add(SavePricingRule(rule: rule, isNew: widget.isNew));
      Navigator.pop(context);
    }
  }
}
