import 'dart:convert';
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
            if (!questionNodes.any((q) => q.id == selectedCondQuestionId))
              selectedCondQuestionId = questionNodes.first.id;
            final parentQuestion = questionNodes.firstWhere(
              (q) => q.id == selectedCondQuestionId,
            );
            if (!parentQuestion.options.contains(selectedCondAnswer))
              selectedCondAnswer = parentQuestion.options.isNotEmpty
                  ? parentQuestion.options.first
                  : '';
          }

          if (activeServices.isNotEmpty &&
              !activeServices.any(
                (s) => s.serviceType == selectedServiceType,
              )) {
            selectedServiceType = activeServices.first.serviceType;
          }

          return AlertDialog(
            backgroundColor: theme.scaffoldBackgroundColor,
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
                      ? Colors.blueAccent
                      : node.type == 'condition'
                      ? Colors.orangeAccent
                      : Colors.greenAccent,
                ),
                const SizedBox(width: 12),
                Text(
                  'Edit ${node.type.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(
                maxWidth: 600,
                maxHeight: 600,
              ), // Responsive constraints added
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: node.type == 'question'
                            ? 'Question for Customer App'
                            : 'Box Title',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: theme.cardColor,
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),

                    if (node.type == 'question') ...[
                      const Text(
                        'Answers',
                        style: TextStyle(
                          color: Colors.blueAccent,
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
                                  decoration: InputDecoration(
                                    labelText: 'Answer ${idx + 1}',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: theme.cardColor,
                                  ),
                                  style: const TextStyle(color: Colors.white),
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
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.blueAccent,
                        ),
                        label: const Text(
                          'Add Answer',
                          style: TextStyle(color: Colors.blueAccent),
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
                            style: TextStyle(color: Colors.orangeAccent),
                          ),
                        )
                      else ...[
                        const Text(
                          '1. Which Question?',
                          style: TextStyle(
                            color: Colors.orangeAccent,
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
                            fillColor: theme.cardColor,
                          ),
                          items: questionNodes
                              .map(
                                (q) => DropdownMenuItem(
                                  value: q.id,
                                  child: Text(
                                    q.title,
                                    style: const TextStyle(color: Colors.white),
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
                            color: Colors.orangeAccent,
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
                            fillColor: theme.cardColor,
                          ),
                          items: questionNodes
                              .firstWhere((q) => q.id == selectedCondQuestionId)
                              .options
                              .map(
                                (opt) => DropdownMenuItem(
                                  value: opt,
                                  child: Text(
                                    opt,
                                    style: const TextStyle(color: Colors.white),
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
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (activeServices.isEmpty)
                        const Text(
                          '⚠️ No Services Found.',
                          style: TextStyle(color: Colors.redAccent),
                        )
                      else
                        DropdownButtonFormField<int>(
                          value: selectedServiceType,
                          dropdownColor: theme.cardColor,
                          decoration: InputDecoration(
                            labelText: 'Assign this Service *',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: theme.cardColor,
                          ),
                          items: activeServices
                              .map(
                                (rule) => DropdownMenuItem(
                                  value: rule.serviceType,
                                  child: Text(
                                    '${rule.ruleName} (Base: \$${rule.baseFare.toStringAsFixed(2)})',
                                    style: const TextStyle(color: Colors.white),
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
                          fillColor: theme.cardColor,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 1,
                            child: Text(
                              'Wheel Lift',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text(
                              'Flatbed',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text(
                              'Low Clearance Van',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 4,
                            child: Text(
                              'Heavy Duty Truck',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 5,
                            child: Text(
                              'Service Vehicle (No Towing)',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 6,
                            child: Text(
                              'Motorcycle Trailer',
                              style: TextStyle(color: Colors.white),
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
                        decoration: InputDecoration(
                          labelText: 'Extra Fee (\$)',
                          prefixIcon: const Icon(
                            Icons.attach_money,
                            color: Colors.greenAccent,
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: theme.cardColor,
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Notes to Driver',
                          hintText: 'e.g. Bring extra dollies',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: theme.cardColor,
                        ),
                        style: const TextStyle(color: Colors.white),
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Save Workflow',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a note for your team about what changed:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: 'Notes (e.g. Added motorcycle questions)',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              style: const TextStyle(color: Colors.white),
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
          style: const TextStyle(
            color: Colors.white,
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
            icon: const Icon(Icons.local_shipping, color: Colors.greenAccent),
            label: const Text(
              'Assign Service',
              style: TextStyle(color: Colors.greenAccent),
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
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'View History',
            onPressed: () {
              context.read<DispatchRulesBloc>().add(FetchRulesHistoryEvent());
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      endDrawer: _buildHistoryDrawer(),
      body: BlocConsumer<DispatchRulesBloc, DispatchRulesState>(
        listener: (context, state) {
          if (state is RulesSaveSuccess)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Workflow Saved!'),
                backgroundColor: Colors.green,
              ),
            );
          else if (state is RulesError)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          else if (state is RulesLoaded) {
            setState(() {
              nodes = List.from(state.nodes);
              edges = List.from(state.edges);
              activeServices = state.activeServices;
              currentVersionLabel = "v${state.activeVersion ?? '1.0'}";
              if (nodes.isEmpty)
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
                        painter: EdgePainter(nodes: nodes, edges: edges),
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
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Click target box to link...',
                          style: TextStyle(
                            color: Colors.amber,
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
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      width: 400,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Version History',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: BlocBuilder<DispatchRulesBloc, DispatchRulesState>(
                buildWhen: (prev, current) =>
                    current is RulesHistoryLoaded || current is RulesLoading,
                builder: (context, state) {
                  if (state is RulesHistoryLoaded) {
                    if (state.history.isEmpty)
                      return const Center(
                        child: Text(
                          'No version records found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final version = state.history[i];
                        return Card(
                          elevation: 0,
                          color: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: version.isActive
                                  ? Colors.green
                                  : Theme.of(context).dividerColor,
                            ),
                          ),
                          child: ListTile(
                            title: Text(
                              'Version ${version.version}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              version.description,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: version.isActive
                                ? const Chip(
                                    label: Text('ACTIVE'),
                                    backgroundColor: Colors.green,
                                    labelStyle: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  )
                                : const Icon(Icons.restore, color: Colors.grey),
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
        height: 160,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : _getNodeHeaderColor(node.type),
            width: isSelected ? 3 : 2,
          ),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
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
                    else if (node.type == 'action')
                      Text(
                        'Service: ${_getDynamicServiceName(node.dispatchServiceType)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.greenAccent,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  style: TextStyle(fontSize: 11, color: Colors.amber),
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
