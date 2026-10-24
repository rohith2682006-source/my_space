import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class AnimatedPurpleBackground extends StatefulWidget {
  final Widget child;

  const AnimatedPurpleBackground({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedPurpleBackground> createState() => _AnimatedPurpleBackgroundState();
}

class _AnimatedPurpleBackgroundState extends State<AnimatedPurpleBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A beautiful matte dark purple color scheme
    final bgColor = const Color(0xFF130B2A); // Very deep matte purple
    final blob1Color = const Color(0xFF6D28D9).withOpacity(0.5); 
    final blob2Color = const Color(0xFF4C1D95).withOpacity(0.6);

    return Stack(
      children: [
        // Base solid color
        Container(color: bgColor),
        
        // Animated blobs
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final size = MediaQuery.sizeOf(context);
            return Stack(
              children: [
                Positioned(
                  top: size.height * 0.2 + math.sin(_controller.value * 2 * math.pi) * 100,
                  left: size.width * 0.1 + math.cos(_controller.value * 2 * math.pi) * 100,
                  child: Container(
                    width: size.width * 0.6,
                    height: size.width * 0.6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [blob1Color, Colors.transparent],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: size.height * 0.1 + math.cos(_controller.value * 2 * math.pi + 1) * 80,
                  right: size.width * 0.1 + math.sin(_controller.value * 2 * math.pi + 1) * 80,
                  child: Container(
                    width: size.width * 0.5,
                    height: size.width * 0.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [blob2Color, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        
        Container(
          color: Colors.black.withOpacity(0.3),
        ),
        
        // The actual content
        widget.child,
      ],
    );
  }
}
