import 'package:flutter/material.dart';

/// App page transition: fade + slight scale.
Route<T> appPageRoute<T>({
  required Widget page,
  RouteSettings? settings,
  Duration duration = const Duration(milliseconds: 280),
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const curve = Curves.easeOutCubic;
      final fade = CurvedAnimation(parent: animation, curve: curve);
      final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: curve),
      );
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: scale,
          child: child,
        ),
      );
    },
  );
}

/// Wraps a list item with staggered fade + slide-up animation.
/// Parent must provide [controller] (forward when list is ready) and [itemCount].
class StaggeredListItem extends StatelessWidget {
  const StaggeredListItem({
    super.key,
    required this.index,
    required this.itemCount,
    required this.controller,
    required this.child,
    this.intervalStart = 0.06,
    this.intervalLength = 0.22,
  });

  final int index;
  final int itemCount;
  final AnimationController controller;
  final Widget child;
  final double intervalStart;
  final double intervalLength;

  @override
  Widget build(BuildContext context) {
    final start = (index * intervalStart).clamp(0.0, 1.0);
    final end = (start + intervalLength).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    final slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(anim);
    final opacity = Tween<double>(begin: 0, end: 1).animate(anim);
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: slide,
        child: child,
      ),
    );
  }
}

/// Duration constants for consistent animation timing.
class AppAnimDurations {
  AppAnimDurations._();
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 380);
}

/// Snappy count-up animation for balance/amounts.
class AnimatedCount extends StatefulWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 420),
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.fractionDigits = 2,
  });

  final double value;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int fractionDigits;

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _prevValue = 0;

  @override
  void initState() {
    super.initState();
    _prevValue = widget.value;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: _prevValue, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _prevValue = widget.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final s = _animation.value.toStringAsFixed(widget.fractionDigits);
        return Text(
          '${widget.prefix}$s${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}
