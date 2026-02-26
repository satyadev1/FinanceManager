import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:indian_sms_filter/indian_sms_filter.dart';

/// Displays bank/fintech logo from remote URL or fallback avatar with initial.
class BankLogoWidget extends StatelessWidget {
  final BrandInfo? brandInfo;
  final double size;
  final bool showName;

  const BankLogoWidget({
    super.key,
    this.brandInfo,
    this.size = 40,
    this.showName = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = brandInfo?.name ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _colorForInitial(initial, theme);

    Widget logoWidget;
    if (brandInfo?.logoUrl != null && brandInfo!.logoUrl!.isNotEmpty) {
      logoWidget = ClipRRect(
        borderRadius: BorderRadius.circular(size / 4),
        child: CachedNetworkImage(
          imageUrl: brandInfo!.logoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildPlaceholder(size, initial, color),
          errorWidget: (_, __, ___) => _buildPlaceholder(size, initial, color),
        ),
      );
    } else {
      logoWidget = _buildPlaceholder(size, initial, color);
    }

    if (showName) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logoWidget,
          SizedBox(width: size * 0.35),
          Flexible(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return logoWidget;
  }

  Widget _buildPlaceholder(double sz, String initial, Color color) {
    return Container(
      width: sz,
      height: sz,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 180 / 255),
        borderRadius: BorderRadius.circular(sz / 4),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
          fontSize: sz * 0.45,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Color _colorForInitial(String initial, ThemeData theme) {
    final code = initial.codeUnitAt(0);
    const colors = [
      Color(0xFF1565C0), // blue
      Color(0xFF2E7D32), // green
      Color(0xFF6A1B9A), // purple
      Color(0xFFC62828), // red
      Color(0xFFE65100), // orange
      Color(0xFF00838F), // teal
      Color(0xFF455A64), // blue grey
    ];
    return colors[code % colors.length];
  }
}
