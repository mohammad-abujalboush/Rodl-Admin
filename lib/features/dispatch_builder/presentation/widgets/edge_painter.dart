import 'package:flutter/material.dart';
import '../../data/models/dispatch_graph_model.dart';

class EdgePainter extends CustomPainter {
  final List<DispatchNode> nodes;
  final List<DispatchEdge> edges;
  final Color lineColor;
  final Color dotColor;

  EdgePainter({
    required this.nodes,
    required this.edges,
    required this.lineColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

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
        final startX = fromNode.x + 200;
        final startY = fromNode.y + 50;
        final endX = toNode.x;
        final endY = toNode.y + 50;

        final path = Path();
        path.moveTo(startX, startY);
        path.cubicTo(startX + 100, startY, endX - 100, endY, endX, endY);

        canvas.drawPath(path, paint);

        canvas.drawCircle(Offset(startX, startY), 6, dotPaint);
        canvas.drawCircle(Offset(endX, endY), 6, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
