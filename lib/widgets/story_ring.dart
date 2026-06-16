import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class StoryRing extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final bool isUnread;
  final double size;

  const StoryRing({super.key, this.avatarUrl, this.name, required this.isUnread, this.size = 66});

  String get _initials {
    if (name == null || name!.trim().isEmpty) return '?';
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
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
              child: hasUrl
                  ? CachedNetworkImage(
                      imageUrl:    avatarUrl!,
                      fit:         BoxFit.cover,
                      placeholder: (_, __) => _fallback(),
                      errorWidget: (_, __, ___) => _fallback(),
                    )
                  : _fallback(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: UbuntuColors.primary,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: (size - 7) * 0.35,
          fontWeight: FontWeight.w600,
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
