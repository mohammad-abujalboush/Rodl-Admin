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
                    Tab(icon: Icon(Icons.campaign), text: 'Campaign Tracker'),
                    Tab(
                      icon: Icon(Icons.mark_email_read),
                      text: 'Email Studio',
                    ),
                    Tab(
                      icon: Icon(Icons.notifications_active),
                      text: 'Push Engine',
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
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    } else if (state is MarketingError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: theme.colorScheme.error,
                        ),
                      );
                    }
                  },
                  buildWhen: (prev, current) =>
                      current is MarketingLoaded || current is MarketingLoading,
                  builder: (context, state) {
                    if (state is MarketingLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Marketing & Communications Studio',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Track acquisition channels, dispatch email blasts, and send push notifications.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text(
            'Refresh Data',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
            Text(
              'Active & Historical Campaigns',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Marketing Campaign',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showAddCampaignDialog(context, theme),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: campaigns.isEmpty
              ? Center(
                  child: Text(
                    'No marketing campaigns recorded yet.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                              : theme.disabledColor.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.pie_chart,
                            color: c.status == 1
                                ? Colors.green
                                : theme.disabledColor,
                          ),
                        ),
                        title: Text(
                          c.campaignName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${c.channel} • Started ${DateFormat('MMM dd, yyyy').format(c.startDate)}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
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
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  c.statusText,
                                  style: TextStyle(
                                    color: c.status == 1
                                        ? Colors.green.shade600
                                        : Colors.orange.shade600,
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
    int selectedAudience = 0;
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;

        List<Widget> children = [
          // COMPOSER
          Expanded(
            flex: isWide ? 1 : 0,
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
                      Text(
                        'MailerSend Email Studio',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedAudience,
                        dropdownColor: theme.cardColor,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Target Audience Cohort *',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 0,
                            child: Text(
                              'All Registered Users',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 1,
                            child: Text(
                              'Customers Only (B2C)',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text(
                              'Fleet Operators Only (Drivers)',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => selectedAudience = v!,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: subjectCtrl,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Email Subject Line *',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: bodyCtrl,
                        maxLines: 8,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Email Body Content (Supports HTML) *',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
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
          if (isWide) const SizedBox(width: 24) else const SizedBox(height: 24),
          // AUDIT HISTORY
          Expanded(
            flex: isWide ? 1 : 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email Delivery Audit Log',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: emailLogs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'No email history recorded.',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: !isWide,
                          physics: isWide
                              ? null
                              : const NeverScrollableScrollPhysics(),
                          itemCount: emailLogs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final log = emailLogs[i];
                            return Card(
                              elevation: 0,
                              color: theme.cardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.dividerColor.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.email,
                                  color: Colors.blue,
                                ),
                                title: Text(
                                  log.subject,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  'To: ${log.recipientEmail} (${log.targetAudience})',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Chip(
                                  label: Text(
                                    log.status,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: log.status == 'Sent'
                                      ? Colors.green.shade600
                                      : Colors.red.shade600,
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
        ];

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        } else {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          );
        }
      },
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

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;

        List<Widget> children = [
          // COMPOSER
          Expanded(
            flex: isWide ? 1 : 0,
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
                      Text(
                        'FCM Mobile Push Engine',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedAudience,
                        dropdownColor: theme.cardColor,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Target Mobile Cohort *',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 0,
                            child: Text(
                              'All Devices (Customers & Drivers)',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 1,
                            child: Text(
                              'Customers App Only',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text(
                              'Driver App Only',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => selectedAudience = v!,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: titleCtrl,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Push Notification Title *',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: messageCtrl,
                        maxLines: 4,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Alert Message Body *',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 20),
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
          if (isWide) const SizedBox(width: 24) else const SizedBox(height: 24),
          // HISTORY LOGS
          Expanded(
            flex: isWide ? 1 : 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push Broadcast History',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: pushLogs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'No push broadcast history.',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: !isWide,
                          physics: isWide
                              ? null
                              : const NeverScrollableScrollPhysics(),
                          itemCount: pushLogs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final log = pushLogs[i];
                            return Card(
                              elevation: 0,
                              color: theme.cardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.dividerColor.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.cell_tower,
                                  color: Colors.amber,
                                ),
                                title: Text(
                                  log.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  '${log.message}\nAudience: ${log.targetAudience} • Delivered: ${log.recipientCount} devices',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
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
        ];

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        } else {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          );
        }
      },
    );
  }

  // --- DIALOGS ---
  void _showAddCampaignDialog(BuildContext parentContext, ThemeData theme) {
    final nameCtrl = TextEditingController();
    final channelCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();

    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Marketing Campaign',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Campaign Name *',
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: channelCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Channel (e.g. Google Ads, Meta)',
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: budgetCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Budget (\$)',
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
            child: const Text(
              'Create Campaign',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
