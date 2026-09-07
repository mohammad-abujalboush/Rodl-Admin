import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/models/dispatch_graph_model.dart';
import '../bloc/dispatch_rulers_bloc.dart';
import '../widgets/edge_painter.dart';

class VisualBuilderScreen extends StatelessWidget {
  const VisualBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DispatchRulesBloc>()..add(FetchRulesEvent()),
      child: const _VisualBuilderView(),
    );
  }
}

class _VisualBuilderView extends StatefulWidget {
  const _VisualBuilderView();

  @override
  State<_VisualBuilderView> createState() => _VisualBuilderViewState();
}

class _VisualBuilderViewState extends State<_VisualBuilderView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<DispatchNode> nodes = [];
  List<DispatchEdge> edges = [];
  List<PricingRuleOption> activeServices = [];

  String? selectedNodeId;
  String? linkingFromNodeId;
  String currentVersionLabel = "Loading...";

  bool _isGuideOpen = true;

  void _addNode(String type) {
    String defaultTitle = type == 'question'
        ? 'Customer Question'
        : type == 'condition'
        ? 'If Answer Is...'
        : 'Assign Service';
    setState(() {
      nodes.add(
        DispatchNode(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: defaultTitle,
          type: type,
          x: 400,
          y: 300,
          executionMode: 'standard', // Initialize with default
        ),
      );
    });
  }

  void _configureNode(DispatchNode node) {
    final titleCtrl = TextEditingController(text: node.title);
    final notesCtrl = TextEditingController(text: node.dispatchNotes);
    final surchargeCtrl = TextEditingController(
      text: node.customSurcharge.toString(),
    );

    int selectedServiceType = node.dispatchServiceType;
    int selectedTruckType = node.dispatchTruckType;
    String selectedCondQuestionId = node.conditionField;
    String selectedCondAnswer = node.conditionValue;
    String selectedExecutionMode =
        node.executionMode; // NEW: Track local execution mode

    List<TextEditingController> optionCtrls = node.options
        .map((opt) => TextEditingController(text: opt))
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          final theme = Theme.of(context);
          final questionNodes = nodes
              .where((n) => n.type == 'question')
              .toList();

          if (node.type == 'condition' && questionNodes.isNotEmpty) {
            if (!questionNodes.any((q) => q.id == selectedCondQuestionId)) {
              selectedCondQuestionId = questionNodes.first.id;
            }
            final parentQuestion = questionNodes.firstWhere(
              (q) => q.id == selectedCondQuestionId,
            );
            if (!parentQuestion.options.contains(selectedCondAnswer)) {
              selectedCondAnswer = parentQuestion.options.isNotEmpty
                  ? parentQuestion.options.first
                  : '';
            }
          }

          if (activeServices.isNotEmpty &&
              !activeServices.any(
                (s) => s.serviceType == selectedServiceType,
              )) {
            selectedServiceType = activeServices.first.serviceType;
          }

          return AlertDialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  node.type == 'question'
                      ? Icons.help_outline
                      : node.type == 'condition'
                      ? Icons.alt_route
                      : Icons.local_shipping,
                  color: node.type == 'question'
                      ? Colors.blue
                      : node.type == 'condition'
                      ? Colors.orange
                      : Colors.green,
                ),
                const SizedBox(width: 12),
                Text(
                  'Edit ${node.type.toUpperCase()}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: node.type == 'question'
                            ? 'Question for Customer App'
                            : 'Box Title',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (node.type == 'question') ...[
                      const Text(
                        'Answers',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...optionCtrls.asMap().entries.map((entry) {
                        int idx = entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: optionCtrls[idx],
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Answer ${idx + 1}',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: theme.scaffoldBackgroundColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => setModalState(
                                  () => optionCtrls.removeAt(idx),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        label: const Text(
                          'Add Answer',
                          style: TextStyle(color: Colors.blue),
                        ),
                        onPressed: () => setModalState(
                          () => optionCtrls.add(
                            TextEditingController(text: 'New Answer'),
                          ),
                        ),
                      ),
                    ],

                    if (node.type == 'condition') ...[
                      if (questionNodes.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '⚠️ Add a Question box first.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        )
                      else ...[
                        const Text(
                          '1. Which Question?',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedCondQuestionId,
                          dropdownColor: theme.cardColor,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: theme.scaffoldBackgroundColor,
                          ),
                          items: questionNodes
                              .map(
                                (q) => DropdownMenuItem(
                                  value: q.id,
                                  child: Text(
                                    q.title,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setModalState(() {
                            selectedCondQuestionId = v!;
                            final newParent = questionNodes.firstWhere(
                              (q) => q.id == selectedCondQuestionId,
                            );
                            selectedCondAnswer = newParent.options.isNotEmpty
                                ? newParent.options.first
                                : '';
                          }),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '2. If Customer Chooses...',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedCondAnswer.isEmpty
                              ? null
                              : selectedCondAnswer,
                          dropdownColor: theme.cardColor,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: theme.scaffoldBackgroundColor,
                          ),
                          items: questionNodes
                              .firstWhere((q) => q.id == selectedCondQuestionId)
                              .options
                              .map(
                                (opt) => DropdownMenuItem(
                                  value: opt,
                                  child: Text(
                                    opt,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setModalState(() => selectedCondAnswer = v!),
                        ),
                      ],
                    ],

                    if (node.type == 'action') ...[
                      const Text(
                        'Service to Assign',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- NEW: EXECUTION MODE DROPDOWN ---
                      DropdownButtonFormField<String>(
                        value: selectedExecutionMode,
                        dropdownColor: theme.cardColor,
                        decoration: InputDecoration(
                          labelText: 'Job Execution Behavior *',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'standard',
                            child: Text(
                              'Standard Tow (Requires Drop-off)',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'roadside',
                            child: Text(
                              'Roadside Repair (No Drop-off)',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'dual_dispatch',
                            child: Text(
                              'Highway Dual-Dispatch (+ Safety Truck)',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setModalState(() => selectedExecutionMode = v!),
                      ),
                      const SizedBox(height: 16),

                      if (activeServices.isEmpty)
                        const Text(
                          '⚠️ No Services Found.',
                          style: TextStyle(color: Colors.red),
                        )
                      else
                        DropdownButtonFormField<int>(
                          value: selectedServiceType,
                          dropdownColor: theme.cardColor,
                          decoration: InputDecoration(
                            labelText: 'Assign this Service *',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: theme.scaffoldBackgroundColor,
                          ),
                          items: activeServices
                              .map(
                                (rule) => DropdownMenuItem(
                                  value: rule.serviceType,
                                  child: Text(
                                    '${rule.ruleName} (Base: \$${rule.baseFare.toStringAsFixed(2)})',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setModalState(() => selectedServiceType = v!),
                        ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedTruckType,
                        dropdownColor: theme.cardColor,
                        decoration: InputDecoration(
                          labelText: 'Required Truck *',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 1,
                            child: Text(
                              'Standard Wrecker',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text(
                              'Flatbed Rollback',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text(
                              'Low Clearance Wrecker',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 4,
                            child: Text(
                              'Heavy Duty Rotator',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 5,
                            child: Text(
                              'Light Service Vehicle',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 6,
                            child: Text(
                              'Motorcycle Trailer',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 7,
                            child: Text(
                              'Medium Duty Flatbed',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 8,
                            child: Text(
                              'Integrated Tow Truck',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 9,
                            child: Text(
                              'Mobile EV Charging Van',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setModalState(() => selectedTruckType = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: surchargeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Extra Fee (\$)',
                          prefixIcon: const Icon(
                            Icons.attach_money,
                            color: Colors.green,
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Notes to Driver',
                          hintText: 'e.g. Bring extra dollies',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                ),
                onPressed: () {
                  setState(() {
                    node.title = titleCtrl.text.trim();
                    if (node.type == 'question') {
                      node.options = optionCtrls
                          .map((c) => c.text.trim())
                          .where((t) => t.isNotEmpty)
                          .toList();
                    } else if (node.type == 'condition') {
                      node.conditionField = selectedCondQuestionId;
                      node.conditionValue = selectedCondAnswer;
                    } else if (node.type == 'action') {
                      node.dispatchServiceType = selectedServiceType;
                      node.dispatchTruckType = selectedTruckType;
                      node.customSurcharge =
                          double.tryParse(surchargeCtrl.text.trim()) ?? 0.0;
                      node.dispatchNotes = notesCtrl.text.trim();
                      node.executionMode =
                          selectedExecutionMode; // NEW: Persist the selected execution behavior
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Save Box'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteNode(String nodeId) {
    setState(() {
      nodes.removeWhere((n) => n.id == nodeId);
      edges.removeWhere((e) => e.fromNodeId == nodeId || e.toNodeId == nodeId);
      if (selectedNodeId == nodeId) selectedNodeId = null;
      if (linkingFromNodeId == nodeId) linkingFromNodeId = null;
    });
  }

  void _saveGraph(BuildContext context) {
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Save Workflow',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a note for your team about what changed:',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Notes (e.g. Added motorcycle questions)',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.publish),
            label: const Text(
              'Save & Publish',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              final payload = {
                'nodes': nodes.map((n) => n.toJson()).toList(),
                'edges': edges.map((e) => e.toJson()).toList(),
              };
              context.read<DispatchRulesBloc>().add(
                SaveRulesEvent(jsonEncode(payload), descCtrl.text),
              );
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Color _getNodeHeaderColor(String type) {
    switch (type) {
      case 'question':
        return Colors.blue.shade700;
      case 'condition':
        return Colors.orange.shade800;
      case 'action':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 2,
        title: Text(
          'Dispatch Workflow - $currentVersionLabel',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.help_outline, color: Colors.blueAccent),
            label: const Text(
              'Add Question',
              style: TextStyle(color: Colors.blueAccent),
            ),
            onPressed: () => _addNode('question'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.alt_route, color: Colors.orangeAccent),
            label: const Text(
              'Add Condition',
              style: TextStyle(color: Colors.orangeAccent),
            ),
            onPressed: () => _addNode('condition'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.local_shipping, color: Colors.green),
            label: const Text(
              'Assign Service',
              style: TextStyle(color: Colors.green),
            ),
            onPressed: () => _addNode('action'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.save),
            label: const Text(
              'Save Workflow',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => _saveGraph(context),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.history, color: theme.colorScheme.onSurface),
            tooltip: 'View History',
            onPressed: () {
              context.read<DispatchRulesBloc>().add(FetchRulesHistoryEvent());
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      endDrawer: _buildHistoryDrawer(theme),
      body: BlocConsumer<DispatchRulesBloc, DispatchRulesState>(
        listener: (context, state) {
          if (state is RulesSaveSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Workflow Saved!'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is RulesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is RulesLoaded) {
            setState(() {
              nodes = List.from(state.nodes);
              edges = List.from(state.edges);
              activeServices = state.activeServices;
              currentVersionLabel = "v${state.activeVersion ?? '1.0'}";
              if (nodes.isEmpty) {
                nodes.add(
                  DispatchNode(
                    id: 'start_node',
                    title: 'Main Issue',
                    type: 'question',
                    x: 100,
                    y: 300,
                    options: ['Tire Blown', 'Car Won\'t Start', 'Locked Out'],
                  ),
                );
              }
            });
          }
        },
        buildWhen: (prev, current) =>
            current is RulesLoading || current is RulesLoaded,
        builder: (context, state) {
          if (state is RulesLoading && nodes.isEmpty)
            return const Center(child: CircularProgressIndicator());
          return Stack(
            children: [
              InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(5000),
                minScale: 0.1,
                maxScale: 2.0,
                child: SizedBox(
                  width: 10000,
                  height: 10000,
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: const Size(10000, 10000),
                        painter: EdgePainter(
                          nodes: nodes,
                          edges: edges,
                          lineColor: theme.dividerColor,
                          dotColor: theme.primaryColor,
                        ),
                      ),
                      ...edges.map((edge) {
                        final fromNode = nodes.cast<DispatchNode?>().firstWhere(
                          (n) => n?.id == edge.fromNodeId,
                          orElse: () => null,
                        );
                        final toNode = nodes.cast<DispatchNode?>().firstWhere(
                          (n) => n?.id == edge.toNodeId,
                          orElse: () => null,
                        );
                        if (fromNode == null || toNode == null)
                          return const SizedBox.shrink();
                        final startX = fromNode.x + 200;
                        final startY = fromNode.y + 50;
                        final endX = toNode.x;
                        final endY = toNode.y + 50;
                        final midX = (startX + endX) / 2;
                        final midY = (startY + endY) / 2;
                        return Positioned(
                          left: midX - 16,
                          top: midY - 16,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                edges.remove(edge);
                              });
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }),
                      ...nodes.map((node) {
                        return Positioned(
                          left: node.x,
                          top: node.y,
                          child: GestureDetector(
                            onPanUpdate: (details) => setState(() {
                              node.x += details.delta.dx;
                              node.y += details.delta.dy;
                            }),
                            child: _buildNodeCard(node, theme),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (linkingFromNodeId != null)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Click target box to link...',
                          style: TextStyle(
                            color: theme.colorScheme.surface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () =>
                              setState(() => linkingFromNodeId = null),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Collapsible Helper Guide
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                bottom: 24,
                right: _isGuideOpen ? 24 : -300,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 320,
                      decoration: BoxDecoration(
                        color: theme.cardColor.withValues(alpha: 0.85),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: theme.dividerColor.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.lightbulb,
                                      color: Colors.amber.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Workflow Guide',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  onPressed: () =>
                                      setState(() => _isGuideOpen = false),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildGuideStep(
                                  theme,
                                  '1. Question',
                                  'Ask the customer a diagnostic question.',
                                  Colors.blue,
                                ),
                                const SizedBox(height: 12),
                                _buildGuideStep(
                                  theme,
                                  '2. Condition',
                                  'Set logic based on their specific answer.',
                                  Colors.orange,
                                ),
                                const SizedBox(height: 12),
                                _buildGuideStep(
                                  theme,
                                  '3. Action',
                                  'Assign the correct service and required truck.',
                                  Colors.green,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tip: Drag boxes to organize. Click "Connect Route" on a box, then click another box to link them.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (!_isGuideOpen)
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: FloatingActionButton(
                    backgroundColor: theme.cardColor,
                    onPressed: () => setState(() => _isGuideOpen = true),
                    child: Icon(
                      Icons.help_outline,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGuideStep(
    ThemeData theme,
    String title,
    String desc,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryDrawer(ThemeData theme) {
    return Drawer(
      width: 400,
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Version History',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: BlocBuilder<DispatchRulesBloc, DispatchRulesState>(
                buildWhen: (prev, current) =>
                    current is RulesHistoryLoaded || current is RulesLoading,
                builder: (context, state) {
                  if (state is RulesHistoryLoaded) {
                    if (state.history.isEmpty) {
                      return Center(
                        child: Text(
                          'No version records found.',
                          style: TextStyle(color: theme.disabledColor),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final version = state.history[i];
                        return Card(
                          elevation: 0,
                          color: theme.cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: version.isActive
                                  ? Colors.green
                                  : theme.dividerColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: ListTile(
                            title: Text(
                              'Version ${version.version}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              version.description,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            trailing: version.isActive
                                ? const Chip(
                                    label: Text('ACTIVE'),
                                    backgroundColor: Colors.green,
                                    labelStyle: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    side: BorderSide.none,
                                  )
                                : Icon(
                                    Icons.restore,
                                    color: theme.disabledColor,
                                  ),
                            onTap: () {
                              if (!version.isActive) {
                                context.read<DispatchRulesBloc>().add(
                                  LoadSpecificVersionEvent(version.jsonPayload),
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Loaded preview. Click Publish to restore.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeCard(DispatchNode node, ThemeData theme) {
    final isSelected = selectedNodeId == node.id;
    return InkWell(
      onTap: () {
        if (linkingFromNodeId != null) {
          if (linkingFromNodeId != node.id) {
            setState(() {
              edges.add(
                DispatchEdge(fromNodeId: linkingFromNodeId!, toNodeId: node.id),
              );
              linkingFromNodeId = null;
            });
          }
        } else {
          setState(() => selectedNodeId = node.id);
        }
      },
      child: Container(
        width: 250,
        height: 170, // Increased slightly to fit execution mode
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : _getNodeHeaderColor(node.type),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getNodeHeaderColor(node.type),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    node.type.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _configureNode(node),
                        child: const Icon(
                          Icons.settings,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (node.id != 'start_node')
                        InkWell(
                          onTap: () => _deleteNode(node.id),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      node.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (node.type == 'question')
                      Text(
                        '${node.options.length} Answer Options',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.blueAccent,
                        ),
                      )
                    else if (node.type == 'condition')
                      Text(
                        'If Choice == "${node.conditionValue}"',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.orangeAccent,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (node.type == 'action') ...[
                      Text(
                        'Service: ${_getDynamicServiceName(node.dispatchServiceType)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // --- Display Execution Mode on Card ---
                      Text(
                        'Mode: ${node.executionMode.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 10,
                          color: node.executionMode == 'dual_dispatch'
                              ? Colors.redAccent
                              : Colors.amber.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              height: 28,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: TextButton(
                onPressed: () => setState(() => linkingFromNodeId = node.id),
                child: const Text(
                  'Connect Route →',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDynamicServiceName(int id) {
    if (activeServices.isEmpty) return 'Unknown Asset';
    final match = activeServices.where((s) => s.serviceType == id).toList();
    if (match.isNotEmpty) return match.first.ruleName;
    return 'Unknown Asset';
  }
}
