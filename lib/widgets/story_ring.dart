import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class StoryRing extends StatelessWidget {
  final String? avatarUrl;
  final bool isUnread;
  final double size;

  const StoryRing({super.key, this.avatarUrl, required this.isUnread, this.size = 66});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(isUnread: isUnread),
        child: Center(
          child: ClipOval(
            child: SizedBox(
              width:  size - 7,
              height: size - 7,
              child: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl:    avatarUrl!,
                      fit:         BoxFit.cover,
                      placeholder: (_, __) => Container(color: UbuntuColors.input),
                      errorWidget: (_, __, ___) => Container(color: UbuntuColors.input),
                    )
                  : Container(color: UbuntuColors.input),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final bool isUnread;
  _RingPainter({required this.isUnread});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;

    if (isUnread) {
      final paint = Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap   = StrokeCap.round
        ..shader      = SweepGradient(
          colors:    storyGradientColors,
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    } else {
      final paint = Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color       = UbuntuColors.divider;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.isUnread != isUnread;
}
