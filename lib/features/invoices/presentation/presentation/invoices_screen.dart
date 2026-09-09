import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:roadside_service/features/invoices/data/invoice_model.dart';
import '../bloc/invoice_bloc.dart';
import '../../../../core/di/injection_container.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String _searchQuery = '';
  InvoiceType? _selectedTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => sl<InvoicesBloc>()..add(FetchInvoices()),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor, // Light theme compliant
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, context),
                const SizedBox(height: 24),

                SizedBox(
                  width: 350,
                  child: TextField(
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search recipient or ID...',
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

                BlocBuilder<InvoicesBloc, InvoicesState>(
                  builder: (context, state) {
                    if (state is InvoicesLoaded) {
                      return _buildFinancialKpis(state, theme);
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<InvoiceType?>(
                    segments: const [
                      ButtonSegment(
                        value: null, // null represents "All"
                        label: Text('All'),
                        icon: Icon(Icons.all_inclusive),
                      ),
                      ButtonSegment(
                        value: InvoiceType.b2bBatch,
                        label: Text('Corporate B2B'),
                        icon: Icon(Icons.business),
                      ),
                      ButtonSegment(
                        value: InvoiceType.b2cReceipt,
                        label: Text('Customer Receipts'),
                        icon: Icon(Icons.receipt_long),
                      ),
                      ButtonSegment(
                        value: InvoiceType.driverSettlement,
                        label: Text('Driver Settlements'),
                        icon: Icon(Icons.payments),
                      ),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (Set<InvoiceType?> selection) =>
                        setState(() => _selectedTab = selection.first),
                  ),
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: BlocConsumer<InvoicesBloc, InvoicesState>(
                    listener: (context, state) {
                      if (state is InvoiceActionSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      } else if (state is InvoicesError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      if (state is InvoicesLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is InvoicesLoaded) {
                        final filtered = state.invoices.where((inv) {
                          // If _selectedTab is null, show everything. Otherwise, match the type.
                          return _selectedTab == null ||
                              inv.type == _selectedTab;
                        }).toList();

                        return _buildDesktopTable(context, filtered, theme);
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

  Widget _buildHeader(ThemeData theme, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financial Documents',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Manage corporate billing, customer receipts, and driver settlements.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Builder(
          builder: (dialogContext) => FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text(
              'Generate Invoice',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _showInvoiceGeneratorModal(dialogContext, null),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialKpis(InvoicesLoaded state, ThemeData theme) {
    final currency = NumberFormat.currency(symbol: '\$');
    return LayoutBuilder(
      builder: (context, constraints) {
        double spacing = 24.0;
        int columns = constraints.maxWidth > 800
            ? 3
            : (constraints.maxWidth > 500 ? 2 : 1);
        double cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns - 0.1;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _KpiCard(
                title: 'B2B Outstanding',
                value: currency.format(state.totalOutstanding),
                icon: Icons.pending_actions,
                color: Colors.orange,
                theme: theme,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _KpiCard(
                title: 'Overdue',
                value: currency.format(state.totalOverdue),
                icon: Icons.warning_amber,
                color: theme.colorScheme.error,
                theme: theme,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _KpiCard(
                title: 'Paid This Month',
                value: currency.format(state.paidThisMonth),
                icon: Icons.check_circle_outline,
                color: Colors.green,
                theme: theme,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    List<InvoiceModel> invoices,
    ThemeData theme,
  ) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              'No financial documents found in this view.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    final currency = NumberFormat.currency(symbol: '\$');

    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: invoices.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
        itemBuilder: (ctx, index) {
          final inv = invoices[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(
                inv.status,
              ).withValues(alpha: 0.1),
              child: Icon(Icons.receipt, color: _getStatusColor(inv.status)),
            ),
            title: Text(
              inv.recipientName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '#${inv.id.substring(0, 8).toUpperCase()} • Issued: ${DateFormat('MMM dd, yyyy').format(inv.issueDate)}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(
                    inv.statusText,
                    style: TextStyle(
                      color: _getStatusColor(inv.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: _getStatusColor(
                    inv.status,
                  ).withValues(alpha: 0.1),
                  side: BorderSide.none,
                ),
                const SizedBox(width: 24),
                Text(
                  currency.format(inv.totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
            onTap: () => _showInvoiceDetailsModal(context, inv, theme),
          );
        },
      ),
    );
  }

  // FIX: Removed the unmapped "partial" enum constant to prevent compiler errors
  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return Colors.grey;
      case InvoiceStatus.unpaid:
        return Colors.orange;
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.overdue:
        return Colors.red;
      case InvoiceStatus.voided:
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  void _showInvoiceDetailsModal(
    BuildContext parentContext,
    InvoiceModel inv,
    ThemeData theme,
  ) {
    final currency = NumberFormat.currency(symbol: '\$');
    final bloc = parentContext.read<InvoicesBloc>();

    showDialog(
      context: parentContext,
      builder: (dialogContext) => Dialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice #${inv.id.substring(0, 8).toUpperCase()}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            inv.typeText,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Edit Invoice',
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showInvoiceGeneratorModal(parentContext, inv);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete Permanently',
                          onPressed: () {
                            bloc.add(DeleteInvoice(invoiceId: inv.id));
                            Navigator.pop(dialogContext);
                          },
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: theme.colorScheme.onSurface,
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Billed To:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          inv.recipientName,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                        Text(
                          inv.recipientEmail,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Issued: ${DateFormat('MMM dd, yyyy').format(inv.issueDate)}',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                        if (inv.dueDate != null)
                          Text(
                            'Due Date: ${DateFormat('MMM dd, yyyy').format(inv.dueDate!)}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ...inv.lineItems.map(
                        (item) => ListTile(
                          title: Text(
                            item.description,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'Qty: ${item.quantity} × ${currency.format(item.unitPrice)}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          trailing: Text(
                            currency.format(item.total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.3),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subtotal:',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  currency.format(inv.subtotal),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tax (16%):',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  currency.format(inv.tax),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  currency.format(inv.totalAmount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text(
                        'View / Print PDF',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.dividerColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () {
                        PdfInvoiceGenerator.generateAndPrint(inv);
                      },
                    ),
                    const Spacer(),

                    SizedBox(
                      width: 250,
                      child: DropdownButtonFormField<InvoiceStatus>(
                        value: inv.status,
                        dropdownColor: theme.cardColor,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Change Status',
                          filled: true,
                          fillColor: theme.cardColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: InvoiceStatus.values.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(
                              status.toString().split('.').last.toUpperCase(),
                            ),
                          );
                        }).toList(),
                        onChanged: (newStatus) {
                          if (newStatus != null && newStatus != inv.status) {
                            bloc.add(
                              UpdateInvoiceStatus(
                                invoiceId: inv.id,
                                newStatus: newStatus,
                              ),
                            );
                            Navigator.pop(dialogContext);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInvoiceGeneratorModal(
    BuildContext context,
    InvoiceModel? existingInvoice,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return BlocProvider.value(
          value: context.read<InvoicesBloc>(),
          child: InvoiceGeneratorDialog(existingInvoice: existingInvoice),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final ThemeData theme;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INVOICE GENERATOR / EDITOR DIALOG
// ============================================================================
class InvoiceGeneratorDialog extends StatefulWidget {
  final InvoiceModel? existingInvoice;
  const InvoiceGeneratorDialog({super.key, this.existingInvoice});

  @override
  State<InvoiceGeneratorDialog> createState() => _InvoiceGeneratorDialogState();
}

class _InvoiceGeneratorDialogState extends State<InvoiceGeneratorDialog> {
  final _formKey = GlobalKey<FormState>();

  late InvoiceType _selectedType;
  final TextEditingController _recipientNameCtrl = TextEditingController();
  final TextEditingController _recipientEmailCtrl = TextEditingController();
  late DateTime _dueDate;

  final List<_LineItemInput> _lineItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingInvoice != null) {
      final inv = widget.existingInvoice!;
      _selectedType = inv.type;
      _recipientNameCtrl.text = inv.recipientName;
      _recipientEmailCtrl.text = inv.recipientEmail;
      _dueDate = inv.dueDate ?? DateTime.now().add(const Duration(days: 14));

      for (var item in inv.lineItems) {
        _lineItems.add(
          _LineItemInput(
            desc: item.description,
            qty: item.quantity.toString(),
            price: item.unitPrice.toString(),
          ),
        );
      }
    } else {
      _selectedType = InvoiceType.b2bBatch;
      _dueDate = DateTime.now().add(const Duration(days: 14));
      _lineItems.add(_LineItemInput());
    }
  }

  @override
  void dispose() {
    _recipientNameCtrl.dispose();
    _recipientEmailCtrl.dispose();
    for (var item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(_LineItemInput());
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      if (_lineItems.length > 1) {
        _lineItems[index].dispose();
        _lineItems.removeAt(index);
      }
    });
  }

  double get _subtotal {
    double sum = 0;
    for (var item in _lineItems) {
      final q = double.tryParse(item.quantityCtrl.text.trim()) ?? 0;
      final p = double.tryParse(item.unitPriceCtrl.text.trim()) ?? 0;
      sum += (q * p);
    }
    return sum;
  }

  double get _tax => _subtotal * 0.16;
  double get _total => _subtotal + _tax;

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final payload = {
        'type': _selectedType.index,
        'recipientName': _recipientNameCtrl.text.trim(),
        'recipientEmail': _recipientEmailCtrl.text.trim(),
        'dueDate': _dueDate.toIso8601String(),
        'lineItems': _lineItems
            .map(
              (item) => {
                'description': item.descriptionCtrl.text.trim(),
                'quantity': int.tryParse(item.quantityCtrl.text.trim()) ?? 1,
                'unitPrice':
                    double.tryParse(item.unitPriceCtrl.text.trim()) ?? 0.0,
              },
            )
            .toList(),
      };

      if (widget.existingInvoice != null) {
        context.read<InvoicesBloc>().add(
          UpdateInvoice(
            invoiceId: widget.existingInvoice!.id,
            invoiceData: payload,
          ),
        );
      } else {
        context.read<InvoicesBloc>().add(CreateInvoice(invoiceData: payload));
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '\$');

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingInvoice != null
                        ? 'Edit Invoice'
                        : 'Generate Financial Invoice',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 32),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Billing Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<InvoiceType>(
                              decoration: InputDecoration(
                                labelText: 'Invoice Type',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: theme.cardColor,
                              ),
                              dropdownColor: theme.cardColor,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                              value: _selectedType,
                              items: [
                                DropdownMenuItem(
                                  value: InvoiceType.b2bBatch,
                                  child: Text(
                                    'Corporate B2B Invoice',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: InvoiceType.b2cReceipt,
                                  child: Text(
                                    'Customer Receipt',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: InvoiceType.driverSettlement,
                                  child: Text(
                                    'Driver Settlement',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedType = val!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDueDate(context),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Due Date',
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: theme.cardColor,
                                ),
                                child: Text(
                                  DateFormat('MMM dd, yyyy').format(_dueDate),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _recipientNameCtrl,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Recipient Name',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: theme.cardColor,
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _recipientEmailCtrl,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Recipient Email',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: theme.cardColor,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Required';
                                if (!value.contains('@'))
                                  return 'Invalid Email';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Line Items',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item Line'),
                            onPressed: _addLineItem,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: _lineItems.asMap().entries.map((entry) {
                            int idx = entry.key;
                            _LineItemInput item = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: item.descriptionCtrl,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Description',
                                        border: const OutlineInputBorder(),
                                        filled: true,
                                        fillColor:
                                            theme.scaffoldBackgroundColor,
                                      ),
                                      validator: (val) =>
                                          val == null || val.isEmpty
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      controller: item.quantityCtrl,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Qty',
                                        border: const OutlineInputBorder(),
                                        filled: true,
                                        fillColor:
                                            theme.scaffoldBackgroundColor,
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setState(() {}),
                                      validator: (val) =>
                                          val == null || val.isEmpty
                                          ? 'Req'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      controller: item.unitPriceCtrl,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Price',
                                        prefixText: '\$',
                                        border: const OutlineInputBorder(),
                                        filled: true,
                                        fillColor:
                                            theme.scaffoldBackgroundColor,
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setState(() {}),
                                      validator: (val) =>
                                          val == null || val.isEmpty
                                          ? 'Req'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_lineItems.length > 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _removeLineItem(idx),
                                    )
                                  else
                                    const SizedBox(width: 40),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subtotal:',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  currency.format(_subtotal),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tax (16%):',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  currency.format(_tax),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Grand Total:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  currency.format(_total),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(
                      widget.existingInvoice != null
                          ? 'Save Changes'
                          : 'Generate Invoice',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                    ),
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineItemInput {
  final TextEditingController descriptionCtrl;
  final TextEditingController quantityCtrl;
  final TextEditingController unitPriceCtrl;

  _LineItemInput({String desc = '', String qty = '1', String price = ''})
    : descriptionCtrl = TextEditingController(text: desc),
      quantityCtrl = TextEditingController(text: qty),
      unitPriceCtrl = TextEditingController(text: price);

  void dispose() {
    descriptionCtrl.dispose();
    quantityCtrl.dispose();
    unitPriceCtrl.dispose();
  }
}

// ============================================================================
// PDF GENERATOR ENGINE (RODL BRAND COMPLIANT)
// ============================================================================
class PdfInvoiceGenerator {
  static Future<void> generateAndPrint(InvoiceModel inv) async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(symbol: '\$');

    final interRegular = await PdfGoogleFonts.interRegular();
    final interSemiBold = await PdfGoogleFonts.interSemiBold();
    final interBold = await PdfGoogleFonts.interBold();

    final rodlGreen = PdfColor.fromHex('#43B02A');
    final charcoal = PdfColor.fromHex('#111827');
    final softGray = PdfColor.fromHex('#F5F7F6');
    final pureWhite = PdfColor.fromHex('#FFFFFF');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: interRegular, bold: interBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'rodl',
                        style: pw.TextStyle(
                          font: interBold,
                          fontSize: 48,
                          color: rodlGreen,
                          letterSpacing: -2.5,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'RODL INVESTMENT CORP',
                        style: pw.TextStyle(
                          font: interBold,
                          fontSize: 12,
                          color: charcoal,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Edmonton, Canada',
                        style: pw.TextStyle(
                          font: interRegular,
                          fontSize: 12,
                          color: charcoal,
                        ),
                      ),
                      pw.Text(
                        'billing@rodl.ca | rodl.ca',
                        style: pw.TextStyle(
                          font: interRegular,
                          fontSize: 12,
                          color: charcoal,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          font: interBold,
                          fontSize: 28,
                          color: charcoal,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '#${inv.id.substring(0, 8).toUpperCase()}',
                        style: pw.TextStyle(
                          font: interRegular,
                          fontSize: 14,
                          color: charcoal,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: pw.BoxDecoration(
                          color: inv.status == InvoiceStatus.paid
                              ? rodlGreen
                              : softGray,
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(16),
                          ),
                        ),
                        child: pw.Text(
                          inv.statusText.toUpperCase(),
                          style: pw.TextStyle(
                            font: interBold,
                            fontSize: 12,
                            color: inv.status == InvoiceStatus.paid
                                ? pureWhite
                                : charcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 48),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BILL TO',
                        style: pw.TextStyle(
                          font: interBold,
                          fontSize: 10,
                          color: rodlGreen,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        inv.recipientName,
                        style: pw.TextStyle(
                          font: interSemiBold,
                          fontSize: 16,
                          color: charcoal,
                        ),
                      ),
                      pw.Text(
                        inv.recipientEmail,
                        style: pw.TextStyle(
                          font: interRegular,
                          fontSize: 12,
                          color: charcoal,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Issue Date: ${DateFormat('MMM dd, yyyy').format(inv.issueDate)}',
                        style: pw.TextStyle(
                          font: interRegular,
                          fontSize: 12,
                          color: charcoal,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      if (inv.dueDate != null)
                        pw.Text(
                          'Due Date: ${DateFormat('MMM dd, yyyy').format(inv.dueDate!)}',
                          style: pw.TextStyle(
                            font: interBold,
                            fontSize: 12,
                            color: charcoal,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Table(
                border: pw.TableBorder.all(color: softGray, width: 2),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        color: softGray,
                        padding: const pw.EdgeInsets.all(16),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(
                            font: interSemiBold,
                            fontSize: 12,
                            color: charcoal,
                          ),
                        ),
                      ),
                      pw.Container(
                        color: softGray,
                        padding: const pw.EdgeInsets.all(16),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(
                            font: interSemiBold,
                            fontSize: 12,
                            color: charcoal,
                          ),
                        ),
                      ),
                      pw.Container(
                        color: softGray,
                        padding: const pw.EdgeInsets.all(16),
                        child: pw.Text(
                          'Unit Price',
                          style: pw.TextStyle(
                            font: interSemiBold,
                            fontSize: 12,
                            color: charcoal,
                          ),
                        ),
                      ),
                      pw.Container(
                        color: softGray,
                        padding: const pw.EdgeInsets.all(16),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(
                            font: interSemiBold,
                            fontSize: 12,
                            color: charcoal,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  ...inv.lineItems.map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(16),
                          child: pw.Text(
                            item.description,
                            style: pw.TextStyle(
                              font: interRegular,
                              fontSize: 12,
                              color: charcoal,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(16),
                          child: pw.Text(
                            item.quantity.toString(),
                            style: pw.TextStyle(
                              font: interRegular,
                              fontSize: 12,
                              color: charcoal,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(16),
                          child: pw.Text(
                            currency.format(item.unitPrice),
                            style: pw.TextStyle(
                              font: interRegular,
                              fontSize: 12,
                              color: charcoal,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(16),
                          child: pw.Text(
                            currency.format(item.total),
                            style: pw.TextStyle(
                              font: interRegular,
                              fontSize: 12,
                              color: charcoal,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 32),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Subtotal:',
                              style: pw.TextStyle(
                                font: interRegular,
                                fontSize: 12,
                                color: charcoal,
                              ),
                            ),
                            pw.Text(
                              currency.format(inv.subtotal),
                              style: pw.TextStyle(
                                font: interRegular,
                                fontSize: 12,
                                color: charcoal,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Tax (16%):',
                              style: pw.TextStyle(
                                font: interRegular,
                                fontSize: 12,
                                color: charcoal,
                              ),
                            ),
                            pw.Text(
                              currency.format(inv.tax),
                              style: pw.TextStyle(
                                font: interRegular,
                                fontSize: 12,
                                color: charcoal,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 16),
                        pw.Divider(color: softGray, thickness: 2),
                        pw.SizedBox(height: 16),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Grand Total',
                              style: pw.TextStyle(
                                font: interBold,
                                fontSize: 16,
                                color: charcoal,
                              ),
                            ),
                            pw.Text(
                              currency.format(inv.totalAmount),
                              style: pw.TextStyle(
                                font: interBold,
                                fontSize: 20,
                                color: rodlGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Divider(color: softGray, thickness: 2),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'Peace of mind, made simple.',
                  style: pw.TextStyle(
                    font: interBold,
                    fontSize: 16,
                    color: rodlGreen,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'RODL INVESTMENT CORP | EDMONTON, CANADA | RODL.CA',
                  style: pw.TextStyle(
                    font: interSemiBold,
                    fontSize: 10,
                    color: charcoal,
                    letterSpacing: 1,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rodl_Invoice_${inv.id.substring(0, 8)}.pdf',
    );
  }
}
