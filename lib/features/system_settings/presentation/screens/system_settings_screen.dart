import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:roadside_service/features/system_settings/data/models/system_settings_models.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/system_settings_bloc.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _globalFormKey = GlobalKey<FormState>();

  // Part 1: Core Financials
  final _driverPayoutCtrl = TextEditingController();
  final _platformCommissionCtrl = TextEditingController();
  final _globalTaxCtrl = TextEditingController();
  final _gatewayFeePercentCtrl = TextEditingController();
  final _gatewayFeeFixedCtrl = TextEditingController();
  final _b2bCommissionCtrl = TextEditingController();
  final _b2bCorpCommissionCtrl = TextEditingController();

  // Part 2: Cancellation Tiers
  final _tier2FeeCtrl = TextEditingController();
  final _tier3FeeCtrl = TextEditingController();

  // Part 3: Operational Controls
  final _radiusCtrl = TextEditingController();
  final _supportEmailCtrl = TextEditingController();
  bool _isMaintenance = false;

  bool _isConfigInitialized = false;
  String _staffSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _driverPayoutCtrl.dispose();
    _platformCommissionCtrl.dispose();
    _globalTaxCtrl.dispose();
    _gatewayFeePercentCtrl.dispose();
    _gatewayFeeFixedCtrl.dispose();
    _b2bCommissionCtrl.dispose();
    _b2bCorpCommissionCtrl.dispose();
    _tier2FeeCtrl.dispose();
    _tier3FeeCtrl.dispose();
    _radiusCtrl.dispose();
    _supportEmailCtrl.dispose();
    super.dispose();
  }

  void _hydrateControllers(GlobalSettingsModel config) {
    _driverPayoutCtrl.text = (config.driverPayoutRatio * 100).toStringAsFixed(
      1,
    );
    _platformCommissionCtrl.text = (config.platformCommissionRate * 100)
        .toStringAsFixed(1);
    _globalTaxCtrl.text = (config.taxRate * 100).toStringAsFixed(1);
    _gatewayFeePercentCtrl.text = (config.gatewayFeePercentage * 100)
        .toStringAsFixed(2);
    _gatewayFeeFixedCtrl.text = config.gatewayFeeFixed.toStringAsFixed(2);
    _b2bCommissionCtrl.text = (config.b2bCommissionRate * 100).toStringAsFixed(
      1,
    );
    _b2bCorpCommissionCtrl.text = (config.b2bCorporateCommissionRate * 100)
        .toStringAsFixed(1);

    _tier2FeeCtrl.text = config.defaultTier2EnRouteCancellationFee
        .toStringAsFixed(2);
    _tier3FeeCtrl.text = config.defaultTier3ArrivedCancellationFee
        .toStringAsFixed(2);

    _radiusCtrl.text = config.maxDispatchRadiusKm.toString();
    _supportEmailCtrl.text = config.supportEmail;
    _isMaintenance = config.isMaintenanceMode;
    _isConfigInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return BlocProvider(
      create: (_) => sl<SystemSettingsBloc>()..add(FetchSystemSettings()),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, isMobile),
                SizedBox(height: isMobile ? 16 : 24),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.disabledColor,
                  indicatorColor: theme.colorScheme.primary,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(icon: Icon(Icons.tune), text: 'Platform & Economics'),
                    Tab(
                      icon: Icon(Icons.map_outlined),
                      text: 'Regional Tax Matrices',
                    ),
                    Tab(
                      icon: Icon(Icons.security),
                      text: 'Access Control (RBAC)',
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 16 : 24),
                Expanded(
                  child: BlocConsumer<SystemSettingsBloc, SystemSettingsState>(
                    listener: (context, state) {
                      if (state is SettingsActionSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else if (state is SettingsError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                      if (state is SettingsLoaded && !_isConfigInitialized) {
                        setState(() => _hydrateControllers(state.globalConfig));
                      }
                    },
                    buildWhen: (prev, current) =>
                        current is! SettingsActionSuccess &&
                        current is! SettingsError,
                    builder: (context, state) {
                      if (state is SettingsLoading && !_isConfigInitialized) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is SettingsLoaded) {
                        return TabBarView(
                          controller: _tabController,
                          children: [
                            _buildEconomicsTab(context, theme, isMobile),
                            _buildRegionalTaxTab(
                              context,
                              state.regionalTaxes,
                              theme,
                              isMobile,
                            ),
                            _buildStaffAccessTab(
                              context,
                              state.staffList,
                              theme,
                              isMobile,
                            ),
                          ],
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

  Widget _buildHeader(ThemeData theme, bool isMobile) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Platform Control & Economics',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Master control switch for platform payout rates, cancellation tiers, regional taxes, and RBAC security.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
        Builder(
          builder: (ctx) => FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text(
              'Resync Architecture',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: isMobile ? 12 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              setState(() => _isConfigInitialized = false);
              ctx.read<SystemSettingsBloc>().add(FetchSystemSettings());
            },
          ),
        ),
      ],
    );
  }

  // --- HELPER FOR RESPONSIVE FORM ROWS ---
  Widget _buildResponsiveFormRow(bool isMobile, List<Widget> children) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map(
              (c) =>
                  Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
            )
            .toList(),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map(
              (c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: c,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // --- TAB 1: ECONOMICS & OPERATIONS ---
  Widget _buildEconomicsTab(
    BuildContext context,
    ThemeData theme,
    bool isMobile,
  ) {
    final bloc = context.read<SystemSettingsBloc>();

    return SingleChildScrollView(
      child: Form(
        key: _globalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // EMERGENCY SECTION
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              decoration: BoxDecoration(
                color: _isMaintenance
                    ? theme.colorScheme.error.withValues(alpha: 0.08)
                    : theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isMaintenance
                      ? theme.colorScheme.error
                      : theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: SwitchListTile(
                title: Text(
                  'Environment Maintenance Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isMaintenance
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'Master killswitch: temporarily suspends incoming mobile requests and freezes driver dispatch.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                value: _isMaintenance,
                activeColor: theme.colorScheme.error,
                onChanged: (v) => setState(() => _isMaintenance = v),
              ),
            ),
            SizedBox(height: isMobile ? 16 : 24),

            // PART 1: CORE FINANCIAL CONFIGS
            _buildCardWrapper(
              theme: theme,
              title: 'Part 1: Core Financial Architecture',
              icon: Icons.account_balance,
              isMobile: isMobile,
              children: [
                _buildResponsiveFormRow(isMobile, [
                  _buildPercentageField(
                    'Driver Payout Ratio',
                    _driverPayoutCtrl,
                    theme,
                  ),
                  _buildPercentageField(
                    'Platform Commission',
                    _platformCommissionCtrl,
                    theme,
                  ),
                  _buildPercentageField(
                    'Global Fallback Tax',
                    _globalTaxCtrl,
                    theme,
                  ),
                ]),
                _buildResponsiveFormRow(isMobile, [
                  _buildPercentageField(
                    'Payment Gateway %',
                    _gatewayFeePercentCtrl,
                    theme,
                  ),
                  TextFormField(
                    controller: _gatewayFeeFixedCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Payment Gateway Flat (\$) *',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ]),
                _buildResponsiveFormRow(isMobile, [
                  _buildPercentageField(
                    'Standard B2B Referral Comm.',
                    _b2bCommissionCtrl,
                    theme,
                  ),
                  _buildPercentageField(
                    'Corporate B2B High-Vol Comm.',
                    _b2bCorpCommissionCtrl,
                    theme,
                  ),
                ]),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),

            // PART 2: CANCELLATION PENALTY TIERS
            _buildCardWrapper(
              theme: theme,
              title: 'Part 2: Cancellation Penalty Tiers',
              icon: Icons.cancel_schedule_send,
              isMobile: isMobile,
              children: [
                Text(
                  'Tier 1 is hardcoded to \$0.00 (Free) within the 5-minute grace period per roadside regulations.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                _buildResponsiveFormRow(isMobile, [
                  TextFormField(
                    controller: _tier2FeeCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Tier 2 (En Route Post 5-Min) Fee (\$) *',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _tier3FeeCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Tier 3 (Arrived / No-Show) Fee (\$) *',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ]),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),

            // PART 3: OPERATIONAL CONTROLS
            _buildCardWrapper(
              theme: theme,
              title: 'Part 3: Operational Controls',
              icon: Icons.alt_route,
              isMobile: isMobile,
              children: [
                _buildResponsiveFormRow(isMobile, [
                  TextFormField(
                    controller: _radiusCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Max Auto-Dispatch Radius (KM) *',
                      suffixText: 'km',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _supportEmailCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Central Support Routing Email *',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty || !v.contains('@')
                        ? 'Valid email required'
                        : null,
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text(
                  'Save & Broadcast Global Parameters',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (_globalFormKey.currentState!.validate()) {
                    bloc.add(
                      UpdateGlobalVariables(
                        settings: GlobalSettingsModel(
                          driverPayoutRatio:
                              (double.tryParse(_driverPayoutCtrl.text) ??
                                  80.0) /
                              100.0,
                          platformCommissionRate:
                              (double.tryParse(_platformCommissionCtrl.text) ??
                                  20.0) /
                              100.0,
                          taxRate:
                              (double.tryParse(_globalTaxCtrl.text) ?? 5.0) /
                              100.0,
                          gatewayFeePercentage:
                              (double.tryParse(_gatewayFeePercentCtrl.text) ??
                                  2.9) /
                              100.0,
                          gatewayFeeFixed:
                              double.tryParse(_gatewayFeeFixedCtrl.text) ??
                              0.30,
                          b2bCommissionRate:
                              (double.tryParse(_b2bCommissionCtrl.text) ??
                                  10.0) /
                              100.0,
                          b2bCorporateCommissionRate:
                              (double.tryParse(_b2bCorpCommissionCtrl.text) ??
                                  8.0) /
                              100.0,
                          defaultTier2EnRouteCancellationFee:
                              double.tryParse(_tier2FeeCtrl.text) ?? 15.0,
                          defaultTier3ArrivedCancellationFee:
                              double.tryParse(_tier3FeeCtrl.text) ?? 30.0,
                          isMaintenanceMode: _isMaintenance,
                          maxDispatchRadiusKm:
                              int.tryParse(_radiusCtrl.text) ?? 50,
                          supportEmail: _supportEmailCtrl.text.trim(),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: REGIONAL TAX MANAGEMENT ---
  Widget _buildRegionalTaxTab(
    BuildContext context,
    List<RegionalTaxRateModel> taxes,
    ThemeData theme,
    bool isMobile,
  ) {
    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Regional Tax Rates (Province / State Matrices)',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The engine queries ProvinceCode first. If absent or disabled, it falls back to the Global Tax Rate.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Add Rule'),
                  onPressed: () =>
                      _showRegionalTaxModal(context, null, isMobile),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: taxes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No regional tax rates defined. The system is operating on the Global Fallback Tax Rate.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth > 800
                                    ? constraints.maxWidth
                                    : 800,
                              ),
                              child: DataTable(
                                headingRowColor:
                                    WidgetStateProperty.resolveWith(
                                      (states) => theme.colorScheme.primary
                                          .withValues(alpha: 0.05),
                                    ),
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'Code',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Region Name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Applied Tax %',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Active State',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Actions',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: taxes.map((t) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          t.provinceCode,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          t.regionName,
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${(t.taxRate * 100).toStringAsFixed(2)}%',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Chip(
                                          label: Text(
                                            t.isActive ? 'Active' : 'Disabled',
                                            style: TextStyle(
                                              color: t.isActive
                                                  ? Colors.green
                                                  : Colors.grey,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          backgroundColor: t.isActive
                                              ? Colors.green.withValues(
                                                  alpha: 0.1,
                                                )
                                              : Colors.grey.withValues(
                                                  alpha: 0.1,
                                                ),
                                          side: BorderSide.none,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit,
                                                size: 18,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                              onPressed: () =>
                                                  _showRegionalTaxModal(
                                                    context,
                                                    t,
                                                    isMobile,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: theme.colorScheme.error,
                                              ),
                                              onPressed: () =>
                                                  _confirmDeleteTax(
                                                    context,
                                                    t.provinceCode,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegionalTaxModal(
    BuildContext context,
    RegionalTaxRateModel? tax,
    bool isMobile,
  ) {
    final isNew = tax == null;
    final codeCtrl = TextEditingController(text: tax?.provinceCode);
    final nameCtrl = TextEditingController(text: tax?.regionName);
    final rateCtrl = TextEditingController(
      text: tax != null ? (tax.taxRate * 100).toStringAsFixed(2) : '',
    );
    bool isActive = tax?.isActive ?? true;
    final formKey = GlobalKey<FormState>();
    final bloc = context.read<SystemSettingsBloc>();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isNew
                ? 'New Regional Tax Rate'
                : 'Edit Tax Rate (${tax.provinceCode})',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 400,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    enabled: isNew,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Province / State Code (e.g., ON, NY) *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Region Name (e.g., Ontario, New York) *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: rateCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Tax Rate (%) *',
                      suffixText: '%',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      'Active Status',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                    subtitle: Text(
                      'Toggle to disable lookup without deletion.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    value: isActive,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (v) => setModalState(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final parsedRate =
                      (double.tryParse(rateCtrl.text.trim()) ?? 5.0) / 100.0;
                  bloc.add(
                    SaveRegionalTaxRate(
                      taxRate: RegionalTaxRateModel(
                        provinceCode: codeCtrl.text.trim().toUpperCase(),
                        regionName: nameCtrl.text.trim(),
                        taxRate: parsedRate,
                        isActive: isActive,
                      ),
                      isNew: isNew,
                    ),
                  );
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text('Save Tax Rule'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTax(BuildContext context, String code) {
    final bloc = context.read<SystemSettingsBloc>();
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete $code Tax Rate?',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          'This will delete the regional rate. Requests from this province will automatically fall back to the Global Tax Rate.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () {
              bloc.add(DeleteRegionalTaxRate(provinceCode: code));
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: STAFF & RBAC ACCESS CONTROL ---
  Widget _buildStaffAccessTab(
    BuildContext context,
    List<StaffUserModel> staff,
    ThemeData theme,
    bool isMobile,
  ) {
    final filtered = staff.where((s) {
      return s.fullName.toLowerCase().contains(_staffSearchQuery) ||
          s.email.toLowerCase().contains(_staffSearchQuery) ||
          s.role.toLowerCase().contains(_staffSearchQuery);
    }).toList();

    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                Text(
                  'Role-Based Access Control (RBAC)',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Invite Staff'),
                  onPressed: () => _showInviteModal(context, isMobile),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search by Name, Role, or Email...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) =>
                  setState(() => _staffSearchQuery = v.toLowerCase()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No staff found.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.3),
                      ),
                      itemBuilder: (ctx, i) {
                        final s = filtered[i];
                        final bool isAdmin = s.role.toLowerCase().contains(
                          'admin',
                        );

                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: s.isActive
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  )
                                : theme.colorScheme.error.withValues(
                                    alpha: 0.1,
                                  ),
                            child: Icon(
                              Icons.shield,
                              color: s.isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                            ),
                          ),
                          title: Text(
                            s.fullName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                              decoration: s.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Text(
                            '${s.role} • ${s.email}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (!isMobile)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.key, size: 16),
                                  label: const Text('Access Map'),
                                  onPressed: s.isActive
                                      ? () => _showPrivilegesModal(
                                          context,
                                          s,
                                          isMobile,
                                        )
                                      : null,
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.key),
                                  onPressed: s.isActive
                                      ? () => _showPrivilegesModal(
                                          context,
                                          s,
                                          isMobile,
                                        )
                                      : null,
                                ),
                              IconButton(
                                icon: Icon(
                                  s.isActive ? Icons.block : Icons.restore,
                                  color: s.isActive
                                      ? theme.colorScheme.error
                                      : Colors.green,
                                ),
                                onPressed: () =>
                                    context.read<SystemSettingsBloc>().add(
                                      ToggleStaffStatus(
                                        staffId: s.id,
                                        isActive: !s.isActive,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardWrapper({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPercentageField(
    String label,
    TextEditingController ctrl,
    ThemeData theme,
  ) {
    return TextFormField(
      controller: ctrl,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: '$label (%) *',
        suffixIcon: const Icon(Icons.percent, size: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.scaffoldBackgroundColor,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  void _showInviteModal(BuildContext parentContext, bool isMobile) {
    final bloc = parentContext.read<SystemSettingsBloc>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedRole = 'Dispatcher';
    final theme = Theme.of(parentContext);

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Invite Staff Member',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 400,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Legal Name *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                    validator: (v) => v!.isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Corporate Email *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                    validator: (v) =>
                        !v!.contains('@') ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Base Role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                    items:
                        [
                              'Administrator',
                              'Operations Manager',
                              'Dispatcher',
                              'Financial Controller',
                            ]
                            .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)),
                            )
                            .toList(),
                    onChanged: (v) => selectedRole = v!,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  bloc.add(
                    InviteStaffMember(
                      fullName: nameCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      role: selectedRole,
                    ),
                  );
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Send Invite'),
            ),
          ],
        );
      },
    );
  }

  void _showPrivilegesModal(
    BuildContext parentContext,
    StaffUserModel staff,
    bool isMobile,
  ) {
    if (staff.role.toLowerCase().contains('admin')) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(
          content: Text(
            'System Administrators inherit all system permissions globally.',
          ),
        ),
      );
      return;
    }

    final bloc = parentContext.read<SystemSettingsBloc>();
    List<String> currentPerms = List.from(staff.permissions);
    final theme = Theme.of(parentContext);

    final Map<String, Map<String, String>> permissionGroups = {
      'Fleet & User Management': {
        'ViewUsers': 'View staff, drivers, and customer directories.',
        'ManageDrivers': 'Onboard, approve, suspend, and edit driver profiles.',
        'ManageStaff':
            'Provision new staff, edit HR records, and suspend accounts.',
        'ManageCustomers': 'Edit customer CRM profiles and vehicle garages.',
        'ManageRBAC':
            'Modify system access and permissions for other employees.',
      },
      'Dispatch & Operations': {
        'ViewRequests':
            'View active fleet map, live dispatches, and heatmap history.',
        'ManageRequests':
            'Update job statuses, assign drivers, and edit active dispatches.',
        'ManualDispatch':
            'Create emergency manual dispatch jobs and route them.',
        'CancelJobs':
            'Force cancel active jobs and apply cancellation penalties.',
        'ManageAddons':
            'Add or reverse financial addons and upload job photos.',
      },
      'Finance & Billing': {
        'ViewFinance':
            'View financial KPIs, revenue dashboards, and invoice history.',
        'ManageFinance': 'Create, edit, and delete B2B/B2C invoices.',
        'IssueRefunds': 'Process and approve Moneris payment refunds.',
        'OverridePricing':
            'Manually override total job fares and add custom surcharges.',
        'ManagePricing':
            'Adjust global rate cards, base fares, and surge metrics.',
      },
      'Helpdesk & Global Settings': {
        'ManageSupport':
            'View, escalate, and resolve customer support tickets.',
        'ViewCallLogs': 'Access and playback historical VoIP call recordings.',
        'ManageSettings':
            'Modify platform commission percentages and tax rates.',
      },
    };

    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Security Matrix: ${staff.fullName}',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Container(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            width: isMobile ? double.infinity : 800,
            child: ListView(
              shrinkWrap: true,
              children: permissionGroups.entries.map((group) {
                final allKeys = group.value.keys.toList();
                final allSelected = allKeys.every(
                  (k) => currentPerms.contains(k),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              group.key,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            child: Text(
                              allSelected ? 'Deselect All' : 'Select All',
                            ),
                            onPressed: () => setModalState(() {
                              if (allSelected) {
                                currentPerms.removeWhere(
                                  (k) => allKeys.contains(k),
                                );
                              } else {
                                for (var k in allKeys) {
                                  if (!currentPerms.contains(k))
                                    currentPerms.add(k);
                                }
                              }
                            }),
                          ),
                        ],
                      ),
                    ),
                    ...group.value.entries.map((perm) {
                      bool hasPerm = currentPerms.contains(perm.key);
                      return CheckboxListTile(
                        title: Text(
                          perm.key,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          perm.value,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        value: hasPerm,
                        activeColor: theme.colorScheme.primary,
                        dense: true,
                        onChanged: (v) => setModalState(() {
                          if (v == true) {
                            currentPerms.add(perm.key);
                          } else {
                            currentPerms.remove(perm.key);
                          }
                        }),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                bloc.add(
                  UpdateStaffPermissions(
                    staffId: staff.id,
                    permissions: currentPerms,
                  ),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Save Permissions'),
            ),
          ],
        ),
      ),
    );
  }
}
