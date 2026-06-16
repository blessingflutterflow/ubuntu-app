import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class UbuntuAvatar extends StatelessWidget {
  final String? url;
  final String? name;
  final double size;
  final double borderWidth;
  final Color? borderColor;

  const UbuntuAvatar({
    super.key,
    this.url,
    this.name,
    this.size = 36,
    this.borderWidth = 0,
    this.borderColor,
  });

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
    final hasUrl = url != null && url!.trim().isNotEmpty;
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape:  BoxShape.circle,
        color:  hasUrl ? UbuntuColors.input : UbuntuColors.primary,
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? UbuntuColors.divider, width: borderWidth)
            : null,
      ),
      child: ClipOval(
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl:    url!,
                fit:         BoxFit.cover,
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) => _fallback(),
              )
            : _fallback(),
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
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
