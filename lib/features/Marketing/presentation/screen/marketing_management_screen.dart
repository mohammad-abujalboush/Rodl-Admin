import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/marketing_bloc.dart';
import '../../data/models/marketing_models.dart';

class MarketingManagementScreen extends StatelessWidget {
  const MarketingManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MarketingBloc>()..add(FetchMarketingData()),
      child: const _MarketingManagementView(),
    );
  }
}

class _MarketingManagementView extends StatefulWidget {
  const _MarketingManagementView();

  @override
  State<_MarketingManagementView> createState() =>
      _MarketingManagementViewState();
}

class _MarketingManagementViewState extends State<_MarketingManagementView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: theme.primaryColor,
                  indicatorWeight: 3,
                  labelColor: theme.primaryColor,
                  unselectedLabelColor: theme.disabledColor,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.campaign),
                      text: 'Campaign Performance Tracker',
                    ),
                    Tab(
                      icon: Icon(Icons.mark_email_read),
                      text: 'MailerSend Email Studio',
                    ),
                    Tab(
                      icon: Icon(Icons.notifications_active),
                      text: 'Push Notification Engine',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: BlocConsumer<MarketingBloc, MarketingState>(
                  listener: (context, state) {
                    if (state is MarketingActionSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else if (state is MarketingError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  buildWhen: (prev, current) =>
                      current is MarketingLoaded || current is MarketingLoading,
                  builder: (context, state) {
                    if (state is MarketingLoading)
                      return const Center(child: CircularProgressIndicator());
                    if (state is MarketingLoaded) {
                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCampaignsTab(state.campaigns, theme, context),
                          _buildEmailStudioTab(state.emailLogs, theme, context),
                          _buildPushEngineTab(
                            state.notificationLogs,
                            theme,
                            context,
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
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Marketing & Communications Studio',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Track acquisition channels, dispatch MailerSend email blasts, and fire mobile push notifications.',
              style: TextStyle(color: theme.disabledColor),
            ),
          ],
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Marketing Hub',
          onPressed: () =>
              context.read<MarketingBloc>().add(FetchMarketingData()),
        ),
      ],
    );
  }

  // --- TAB 1: CAMPAIGN TRACKER ---
  Widget _buildCampaignsTab(
    List<MarketingCampaignModel> campaigns,
    ThemeData theme,
    BuildContext context,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Active & Historical Campaigns',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Marketing Campaign'),
              onPressed: () => _showAddCampaignDialog(context, theme),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: campaigns.isEmpty
              ? const Center(
                  child: Text(
                    'No marketing campaigns recorded yet.',
                    style: TextStyle(color: Colors.grey),
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
                    itemCount: campaigns.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (ctx, i) {
                      final c = campaigns[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: c.status == 1
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.pie_chart,
                            color: c.status == 1 ? Colors.green : Colors.grey,
                          ),
                        ),
                        title: Text(
                          c.campaignName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          '${c.channel} • Started ${DateFormat('MMM dd, yyyy').format(c.startDate)}',
                          style: TextStyle(color: theme.disabledColor),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${c.spent.toStringAsFixed(2)} / \$${c.budget.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  c.statusText,
                                  style: TextStyle(
                                    color: c.status == 1
                                        ? Colors.green
                                        : Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => context
                                  .read<MarketingBloc>()
                                  .add(DeleteCampaign(c.id)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // --- TAB 2: MAILERSEND EMAIL STUDIO ---
  Widget _buildEmailStudioTab(
    List<EmailLogModel> emailLogs,
    ThemeData theme,
    BuildContext context,
  ) {
    int selectedAudience = 0; // 0=All, 1=Customers, 2=Drivers
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // DISPATCH COMPOSER
        Expanded(
          flex: 1,
          child: Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MailerSend Email Studio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedAudience,
                      dropdownColor: theme.cardColor,
                      decoration: const InputDecoration(
                        labelText: 'Target Audience Cohort *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(
                            'All Registered Users',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            'Customers Only (B2C)',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(
                            'Fleet Operators Only (Drivers)',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                      onChanged: (v) => selectedAudience = v!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email Subject Line *',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: bodyCtrl,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Email Body Content (Supports HTML) *',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        icon: const Icon(Icons.send),
                        label: const Text(
                          'Send Email Blast via MailerSend',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          if (subjectCtrl.text.isNotEmpty &&
                              bodyCtrl.text.isNotEmpty) {
                            context.read<MarketingBloc>().add(
                              SendEmailBlast(
                                targetAudience: selectedAudience,
                                subject: subjectCtrl.text.trim(),
                                bodyHtml: bodyCtrl.text.trim(),
                              ),
                            );
                            subjectCtrl.clear();
                            bodyCtrl.clear();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // EMAIL AUDIT HISTORY
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Email Delivery Audit Log',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: emailLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'No email history recorded.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: emailLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final log = emailLogs[i];
                          return Card(
                            color: theme.cardColor,
                            child: ListTile(
                              leading: const Icon(
                                Icons.email,
                                color: Colors.blueAccent,
                              ),
                              title: Text(
                                log.subject,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                'To: ${log.recipientEmail} (${log.targetAudience})',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Chip(
                                label: Text(
                                  log.status,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: log.status == 'Sent'
                                    ? Colors.green
                                    : Colors.red,
                                side: BorderSide.none,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 3: PUSH NOTIFICATION ENGINE ---
  Widget _buildPushEngineTab(
    List<NotificationLogModel> pushLogs,
    ThemeData theme,
    BuildContext context,
  ) {
    int selectedAudience = 0;
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PUSH COMPOSER
        Expanded(
          flex: 1,
          child: Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FCM Mobile Push Engine',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedAudience,
                      dropdownColor: theme.cardColor,
                      decoration: const InputDecoration(
                        labelText: 'Target Mobile Cohort *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(
                            'All Devices (Customers & Drivers)',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            'Customers App Only',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(
                            'Driver App Only',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                      onChanged: (v) => selectedAudience = v!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Push Notification Title *',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: messageCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Alert Message Body *',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        icon: const Icon(Icons.notifications_active),
                        label: const Text(
                          'Broadcast FCM Push Alert',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          if (titleCtrl.text.isNotEmpty &&
                              messageCtrl.text.isNotEmpty) {
                            context.read<MarketingBloc>().add(
                              SendPushBlast(
                                targetAudience: selectedAudience,
                                title: titleCtrl.text.trim(),
                                message: messageCtrl.text.trim(),
                              ),
                            );
                            titleCtrl.clear();
                            messageCtrl.clear();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // PUSH LOGS
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Push Broadcast History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: pushLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'No push broadcast history.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: pushLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final log = pushLogs[i];
                          return Card(
                            color: theme.cardColor,
                            child: ListTile(
                              leading: const Icon(
                                Icons.cell_tower,
                                color: Colors.amber,
                              ),
                              title: Text(
                                log.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                '${log.message}\nAudience: ${log.targetAudience} • Delivered: ${log.recipientCount} devices',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddCampaignDialog(BuildContext parentContext, ThemeData theme) {
    final nameCtrl = TextEditingController();
    final channelCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();

    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text(
          'Add Marketing Campaign',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Campaign Name *',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: channelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Channel (e.g. Google Ads, Meta)',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: budgetCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Budget (\$)',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
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
            child: const Text('Create Campaign'),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                parentContext.read<MarketingBloc>().add(
                  CreateCampaign({
                    'campaignName': nameCtrl.text.trim(),
                    'channel': channelCtrl.text.trim(),
                    'budget': double.tryParse(budgetCtrl.text) ?? 0.0,
                    'spent': 0.0,
                    'status': 1,
                    'startDate': DateTime.now().toIso8601String(),
                  }),
                );
                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }
}
