import 'package:flutter/material.dart';
import '../services/talkback_service.dart';

class TalkBackLongPress extends StatefulWidget {
  final Widget child;
  final String text;
  final VoidCallback? onLongPress;

  const TalkBackLongPress({
    Key? key,
    required this.child,
    required this.text,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<TalkBackLongPress> createState() => _TalkBackLongPressState();
}

class _TalkBackLongPressState extends State<TalkBackLongPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _borderAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _borderAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.green,
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleLongPress() {
    if (!TalkBackService.instance.isEnabled) return;

    // Start border animation
    _animationController.forward();

    // TalkBack speech
    TalkBackService.instance.speak(widget.text);

    // Execute custom onLongPress if provided
    widget.onLongPress?.call();

    // Remove highlight after delay
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _handleLongPress,
      child: AnimatedBuilder(
        animation: _borderAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                color: _borderAnimation.value ?? Colors.transparent,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}
