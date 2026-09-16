import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:roadside_service/features/helpdesk/data/models/support_ticket_model.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/helpdesk_bloc.dart';

class CustomerCrmDto {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String email;

  CustomerCrmDto({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.email,
  });
}

class HelpdeskScreen extends StatefulWidget {
  const HelpdeskScreen({super.key});

  @override
  State<HelpdeskScreen> createState() => _HelpdeskScreenState();
}

class _HelpdeskScreenState extends State<HelpdeskScreen> {
  String _searchQuery = '';
  int? _priorityFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => sl<HelpdeskBloc>()..add(FetchTickets()),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        floatingActionButton: Builder(
          builder: (blocContext) => FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Log Ticket'),
            onPressed: () => _showManualTicketModal(blocContext),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                const SizedBox(height: 24),
                Expanded(
                  child: BlocConsumer<HelpdeskBloc, HelpdeskState>(
                    listener: (context, state) {
                      if (state is HelpdeskActionSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else if (state is HelpdeskError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      if (state is HelpdeskLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is HelpdeskLoaded) {
                        final filtered = state.tickets.where((t) {
                          final matchesSearch =
                              t.subject.toLowerCase().contains(_searchQuery) ||
                              t.customerName.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              t.id.contains(_searchQuery);
                          final matchesPriority =
                              _priorityFilter == null ||
                              t.priority == _priorityFilter;
                          return matchesSearch && matchesPriority;
                        }).toList();

                        return ScreenTypeLayout.builder(
                          desktop: (_) =>
                              _buildKanbanBoard(filtered, theme, context),
                          mobile: (_) =>
                              _buildMobileView(filtered, theme, context),
                          tablet: (_) =>
                              _buildMobileView(filtered, theme, context),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rodl Helpdesk',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage active support disputes and escalations.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _priorityFilter,
                  dropdownColor: theme.cardColor,
                  hint: Text(
                    "Filter Priority",
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(
                        "All Priorities",
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 3,
                      child: Text(
                        "Urgent (SLA Alert)",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 2,
                      child: Text(
                        "High",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(
                        "Normal",
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 0,
                      child: Text(
                        "Low",
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _priorityFilter = val),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 300,
              child: TextField(
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search ID, Subject, Customer...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                onChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKanbanBoard(
    List<SupportTicketModel> tickets,
    ThemeData theme,
    BuildContext blocContext,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDragTargetColumn(
                    'Open',
                    0,
                    tickets.where((t) => t.status == 0).toList(),
                    theme,
                    Colors.blue,
                    blocContext,
                  ),
                  const SizedBox(width: 12),
                  _buildDragTargetColumn(
                    'In Progress',
                    1,
                    tickets.where((t) => t.status == 1).toList(),
                    theme,
                    Colors.orange,
                    blocContext,
                  ),
                  const SizedBox(width: 12),
                  _buildDragTargetColumn(
                    'Awaiting Cust.',
                    2,
                    tickets.where((t) => t.status == 2).toList(),
                    theme,
                    Colors.amber.shade700,
                    blocContext,
                  ),
                  const SizedBox(width: 12),
                  _buildDragTargetColumn(
                    'Escalated',
                    3,
                    tickets.where((t) => t.status == 3).toList(),
                    theme,
                    Colors.red,
                    blocContext,
                  ),
                  const SizedBox(width: 12),
                  _buildDragTargetColumn(
                    'Resolved/Closed',
                    5,
                    tickets.where((t) => t.status >= 4).toList(),
                    theme,
                    Colors.green,
                    blocContext,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragTargetColumn(
    String title,
    int targetStatus,
    List<SupportTicketModel> tickets,
    ThemeData theme,
    Color color,
    BuildContext blocContext,
  ) {
    return SizedBox(
      width: 280,
      child: DragTarget<SupportTicketModel>(
        onWillAcceptWithDetails: (details) =>
            details.data.status != targetStatus,
        onAcceptWithDetails: (details) {
          blocContext.read<HelpdeskBloc>().add(
            UpdateTicketStatus(
              ticketId: details.data.id,
              newStatus: targetStatus,
            ),
          );
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHovering
                  ? color.withValues(alpha: 0.08)
                  : theme.cardColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHovering
                    ? color
                    : theme.dividerColor.withValues(alpha: 0.2),
                width: isHovering ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${tickets.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _DraggableTicketCard(
                      ticket: tickets[i],
                      blocContext: blocContext,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileView(
    List<SupportTicketModel> tickets,
    ThemeData theme,
    BuildContext blocContext,
  ) {
    return ListView.separated(
      itemCount: tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) =>
          _DraggableTicketCard(ticket: tickets[i], blocContext: blocContext),
    );
  }

  void _showManualTicketModal(BuildContext blocContext) {
    final formKey = GlobalKey<FormState>();
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String? selectedCustomerId;
    int priority = 1;

    showDialog(
      context: blocContext,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'Log Helpdesk Ticket',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Form(
              key: formKey,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Autocomplete<CustomerCrmDto>(
                      displayStringForOption: (c) =>
                          '${c.fullName} - ${c.phoneNumber}',
                      optionsBuilder: (textEditingValue) async {
                        if (textEditingValue.text.length < 2) {
                          return const Iterable<CustomerCrmDto>.empty();
                        }
                        final results = await blocContext
                            .read<HelpdeskBloc>()
                            .searchCustomers(textEditingValue.text);
                        return results
                            .map(
                              (json) => CustomerCrmDto(
                                id: json['id'] ?? '',
                                fullName: json['fullName'] ?? 'Unknown',
                                phoneNumber: json['phoneNumber'] ?? '',
                                email: json['email'] ?? '',
                              ),
                            )
                            .toList();
                      },
                      onSelected: (c) {
                        setModalState(() {
                          selectedCustomerId = c.id;
                          nameCtrl.text = c.fullName;
                        });
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Search CRM Customer (Name, Phone)',
                                filled: true,
                                fillColor: theme.cardColor,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.search),
                              ),
                              onChanged: (val) {
                                selectedCustomerId = null;
                                nameCtrl.text = val;
                              },
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            );
                          },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: subjectCtrl,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Ticket Subject *',
                        filled: true,
                        fillColor: theme.cardColor,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 4,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Detailed Description / Notes',
                        filled: true,
                        fillColor: theme.cardColor,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: priority,
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Priority Level',
                        filled: true,
                        fillColor: theme.cardColor,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(
                            'Low',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            'Normal',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 2,
                          child: Text(
                            'High',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 3,
                          child: Text(
                            'Urgent (SLA Alert)',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setModalState(() => priority = val ?? 1),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.send),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    blocContext.read<HelpdeskBloc>().add(
                      CreateManualTicket(
                        subject: subjectCtrl.text,
                        description: descCtrl.text,
                        customerId: selectedCustomerId,
                        customerName: nameCtrl.text.isEmpty
                            ? 'Guest Caller'
                            : nameCtrl.text,
                        priority: priority,
                      ),
                    );
                    Navigator.pop(ctx);
                  }
                },
                label: const Text('Create Ticket'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DraggableTicketCard extends StatelessWidget {
  final SupportTicketModel ticket;
  final BuildContext blocContext;
  const _DraggableTicketCard({required this.ticket, required this.blocContext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget cardUI = Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: ticket.priority == 3
              ? Colors.red.withValues(alpha: 0.6)
              : theme.dividerColor.withValues(alpha: 0.2),
          width: ticket.priority == 3 ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _openDetailDialog(blocContext, ticket),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ticket.priorityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ticket.priorityText,
                      style: TextStyle(
                        color: ticket.priorityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ticket.customerName,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM dd, hh:mm a').format(ticket.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    '#${ticket.id.length > 6 ? ticket.id.substring(0, 6).toUpperCase() : ticket.id.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return LongPressDraggable<SupportTicketModel>(
      data: ticket,
      delay: const Duration(milliseconds: 150),
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        child: SizedBox(
          width: 260,
          child: Opacity(opacity: 0.9, child: cardUI),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: cardUI),
      child: cardUI,
    );
  }

  void _openDetailDialog(BuildContext blocContext, SupportTicketModel ticket) {
    int currentStatus = ticket.status;
    final notesController = TextEditingController(
      text: ticket.adminNotes ?? '',
    );

    showDialog(
      context: blocContext,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: theme.scaffoldBackgroundColor,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700),
              padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            ticket.subject,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Ticket',
                              onPressed: () {
                                _showDeleteConfirmation(
                                  ctx,
                                  blocContext,
                                  ticket,
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: theme.colorScheme.onSurface,
                              ),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Full Customer Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer Identity',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      ticket.customerName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Contact Information',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      ticket.customerPhone.isEmpty
                                          ? 'N/A'
                                          : ticket.customerPhone,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.email,
                                      size: 16,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      ticket.customerEmail.isEmpty
                                          ? 'N/A'
                                          : ticket.customerEmail,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ticket Metadata',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Chip(
                                  label: Text(
                                    'Priority: ${ticket.priorityText}',
                                  ),
                                  backgroundColor: ticket.priorityColor
                                      .withValues(alpha: 0.15),
                                  labelStyle: TextStyle(
                                    color: ticket.priorityColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  side: BorderSide.none,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Created At',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat(
                                    'MMM dd, yyyy - hh:mm a',
                                  ).format(ticket.createdAt),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'Ticket Description',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        ticket.description.isEmpty
                            ? 'No description provided.'
                            : ticket.description,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'CRM Controls',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Current Status:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: currentStatus,
                            dropdownColor: theme.cardColor,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              filled: true,
                              fillColor: theme.cardColor,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 0,
                                child: Text(
                                  'Open',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 1,
                                child: Text(
                                  'In Progress',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 2,
                                child: Text(
                                  'Waiting on Customer',
                                  style: TextStyle(color: Colors.amber),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Text(
                                  'Escalated',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 4,
                                child: Text(
                                  'Resolved',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 5,
                                child: Text(
                                  'Closed',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => currentStatus = val);
                                blocContext.read<HelpdeskBloc>().add(
                                  UpdateTicketStatus(
                                    ticketId: ticket.id,
                                    newStatus: val,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText:
                            'Internal Admin Notes (Not visible to customer)',
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: theme.cardColor,
                        suffixIcon: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.save, color: Colors.blue),
                              tooltip: 'Save Note',
                              onPressed: () =>
                                  blocContext.read<HelpdeskBloc>().add(
                                    UpdateTicketNote(
                                      ticketId: ticket.id,
                                      note: notesController.text,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext ctx,
    BuildContext blocContext,
    SupportTicketModel ticket,
  ) {
    showDialog(
      context: ctx,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        title: Text(
          'Delete Ticket',
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to permanently delete ticket #${ticket.id.substring(0, 6).toUpperCase()}? This action cannot be undone.',
          style: TextStyle(
            color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              blocContext.read<HelpdeskBloc>().add(
                DeleteTicket(ticketId: ticket.id),
              );
              Navigator.pop(confirmCtx); // Close confirm
              Navigator.pop(ctx); // Close detail modal
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
