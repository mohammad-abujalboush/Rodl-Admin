import 'package:flutter/material.dart';
import '../../data/models/dispatch_graph_model.dart';

class EdgePainter extends CustomPainter {
  final List<DispatchNode> nodes;
  final List<DispatchEdge> edges;

  EdgePainter({required this.nodes, required this.edges});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (var edge in edges) {
      final fromNode = nodes.cast<DispatchNode?>().firstWhere(
        (n) => n?.id == edge.fromNodeId,
        orElse: () => null,
      );
      final toNode = nodes.cast<DispatchNode?>().firstWhere(
        (n) => n?.id == edge.toNodeId,
        orElse: () => null,
      );

      if (fromNode != null && toNode != null) {
        // Calculate center points of the nodes (assuming node width is approx 200, height 100)
        final startX = fromNode.x + 200;
        final startY = fromNode.y + 50;
        final endX = toNode.x;
        final endY = toNode.y + 50;

        // Draw a smooth cubic bezier curve
        final path = Path();
        path.moveTo(startX, startY);
        path.cubicTo(
          startX + 100,
          startY, // Control point 1
          endX - 100,
          endY, // Control point 2
          endX,
          endY, // Destination
        );

        canvas.drawPath(path, paint);

        // Draw connection dots
        canvas.drawCircle(
          Offset(startX, startY),
          6,
          Paint()..color = Colors.blueGrey,
        );
        canvas.drawCircle(
          Offset(endX, endY),
          6,
          Paint()..color = Colors.blueGrey,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
