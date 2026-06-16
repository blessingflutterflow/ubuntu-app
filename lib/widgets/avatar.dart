import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class UbuntuAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final double borderWidth;
  final Color? borderColor;

  const UbuntuAvatar({
    super.key,
    this.url,
    this.size = 36,
    this.borderWidth = 0,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape:  BoxShape.circle,
        color:  UbuntuColors.input,
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? UbuntuColors.divider, width: borderWidth)
            : null,
      ),
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl:    url!,
                fit:         BoxFit.cover,
                placeholder: (_, __) => Container(color: UbuntuColors.input),
                errorWidget: (_, __, ___) => Container(color: UbuntuColors.input),
              )
            : Container(color: UbuntuColors.input),
      ),
    );
  }
}
