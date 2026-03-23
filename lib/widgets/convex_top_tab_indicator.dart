import 'package:flutter/material.dart';

class ConvexTopTabIndicator extends Decoration {
  final Color color;
  final double cornerRadius;
  final double height;

  const ConvexTopTabIndicator({
    required this.color,
    required this.cornerRadius,
    this.height = 6.0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _ConvexTopPainter(
      color: color,
      cornerRadius: cornerRadius,
      height: height,
    );
  }
}

class _ConvexTopPainter extends BoxPainter {
  final Color color;
  final double cornerRadius;
  final double height;

  _ConvexTopPainter({
    required this.color,
    required this.cornerRadius,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double width = configuration.size!.width;
    final double bottom = offset.dy + configuration.size!.height;
    final double top = bottom - height;
    final double radius = cornerRadius.clamp(0.0, width / 2);

    final Path path = Path();

    // Start from bottom-left
    path.moveTo(offset.dx, bottom);

    // Left rounded corner (convex)
    path.cubicTo(offset.dx, bottom, offset.dx, top, offset.dx + radius, top);

    // Line to right side, before right corner
    path.lineTo(offset.dx + width - radius, top);

    // Right rounded corner (convex)
    path.cubicTo(
      offset.dx + width,
      top,
      offset.dx + width,
      bottom,
      offset.dx + width,
      bottom,
    );

    path.close();

    canvas.drawPath(path, paint);
  }
}
