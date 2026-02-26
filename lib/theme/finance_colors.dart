import 'package:flutter/material.dart';

/// Semantic colors for finance: gain (success) and loss (danger).
/// Use for balances, transaction amounts, and status chips.
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.successGain,
    required this.dangerLoss,
  });

  final Color successGain;
  final Color dangerLoss;

  @override
  FinanceColors copyWith({Color? successGain, Color? dangerLoss}) {
    return FinanceColors(
      successGain: successGain ?? this.successGain,
      dangerLoss: dangerLoss ?? this.dangerLoss,
    );
  }

  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) return this;
    return FinanceColors(
      successGain: Color.lerp(successGain, other.successGain, t)!,
      dangerLoss: Color.lerp(dangerLoss, other.dangerLoss, t)!,
    );
  }
}
