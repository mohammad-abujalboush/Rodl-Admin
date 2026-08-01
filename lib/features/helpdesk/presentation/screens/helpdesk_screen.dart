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
                      if (state is HelpdeskLoading)
                        return const Center(child: CircularProgressIndicator());
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rodl Helpdesk',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage active support disputes and escalations.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _priorityFilter,
                  dropdownColor: theme.cardColor,
                  hint: const Text(
                    "Filter Priority",
                    style: TextStyle(color: Colors.white),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text(
                        "All Priorities",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(
                        "Urgent (SLA Alert)",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(
                        "High",
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(
                        "Normal",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 0,
                      child: Text("Low", style: TextStyle(color: Colors.white)),
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
                decoration: InputDecoration(
                  hintText: 'Search ID, Subject, Customer...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
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

  // --- INTERACTIVE DRAG & DROP KANBAN BOARD ---
  Widget _buildKanbanBoard(
    List<SupportTicketModel> tickets,
    ThemeData theme,
    BuildContext blocContext,
  ) {
    return Row(
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
          Colors.amber,
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
        // Group Resolved (4) and Closed (5) together. Defaults to Closed (5) when dropped here.
        _buildDragTargetColumn(
          'Resolved/Closed',
          5,
          tickets.where((t) => t.status >= 4).toList(),
          theme,
          Colors.green,
          blocContext,
        ),
      ],
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
    return Expanded(
      child: DragTarget<SupportTicketModel>(
        onWillAcceptWithDetails: (details) =>
            details.data.status !=
            targetStatus, // Only accept if it's actually changing status
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
                  ? color.withValues(alpha: 0.1)
                  : theme.cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: isHovering
                  ? Border.all(color: color, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
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
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${tickets.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
            title: const Text(
              'Log Helpdesk Ticket',
              style: TextStyle(color: Colors.white),
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Autocomplete<CustomerCrmDto>(
                      displayStringForOption: (c) =>
                          '${c.fullName} - ${c.phoneNumber}',
                      optionsBuilder: (textEditingValue) async {
                        if (textEditingValue.text.length < 2)
                          return const Iterable<CustomerCrmDto>.empty();
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
                              style: const TextStyle(color: Colors.white),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            );
                          },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: subjectCtrl,
                      decoration: InputDecoration(
                        labelText: 'Ticket Subject *',
                        filled: true,
                        fillColor: theme.cardColor,
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Detailed Description / Notes',
                        filled: true,
                        fillColor: theme.cardColor,
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: priority,
                      dropdownColor: theme.cardColor,
                      decoration: InputDecoration(
                        labelText: 'Priority Level',
                        filled: true,
                        fillColor: theme.cardColor,
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(
                            'Low',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            'Normal',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(
                            'High',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(
                            'Urgent (SLA Alert)',
                            style: TextStyle(color: Colors.red),
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

// --- DRAGGABLE TICKET WIDGET ---
class _DraggableTicketCard extends StatelessWidget {
  final SupportTicketModel ticket;
  final BuildContext blocContext;
  const _DraggableTicketCard({required this.ticket, required this.blocContext});

  @override
  Widget build(BuildContext context) {
    // The visual UI of the card
    Widget cardUI = Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: ticket.priority == 3
              ? Colors.red.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 2,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                      color: ticket.priorityColor.withValues(alpha: 0.2),
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
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM dd, hh:mm a').format(ticket.createdAt),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                  Text(
                    '#${ticket.id.length > 6 ? ticket.id.substring(0, 6) : ticket.id}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
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

    // Make it long-press draggable
    return LongPressDraggable<SupportTicketModel>(
      data: ticket,
      delay: const Duration(
        milliseconds: 150,
      ), // Slight delay ensures we can still scroll lists on touch devices
      feedback: Material(
        color: Colors.transparent,
        elevation: 12,
        child: SizedBox(
          width: 300, // Keep width fixed while dragging
          child: Opacity(opacity: 0.9, child: cardUI),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: cardUI,
      ), // Dim original while dragging
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
              width: 700,
              padding: const EdgeInsets.all(32),
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
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- FULL CUSTOMER DETAILS GRID ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
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
                                  color: theme.disabledColor,
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Contact Information',
                                style: TextStyle(
                                  color: theme.disabledColor,
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
                                    ticket.customerPhone,
                                    style: const TextStyle(color: Colors.white),
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
                                    ticket.customerEmail,
                                    style: const TextStyle(color: Colors.white),
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
                                  color: theme.disabledColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Chip(
                                label: Text('Priority: ${ticket.priorityText}'),
                                backgroundColor: ticket.priorityColor
                                    .withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  color: ticket.priorityColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Created At',
                                style: TextStyle(
                                  color: theme.disabledColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy - hh:mm a',
                                ).format(ticket.createdAt),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 32),
                  Text(
                    'Ticket Description',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ticket.description.isEmpty
                          ? 'No description provided.'
                          : ticket.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'CRM Controls',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Current Status:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: currentStatus,
                          dropdownColor: theme.cardColor,
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
                    style: const TextStyle(color: Colors.white),
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
          );
        },
      ),
    );
  }
}
