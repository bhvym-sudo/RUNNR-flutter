import 'package:flutter/material.dart';
import '../widgets/mini_player.dart';

/// Wrapper for screens that need to show the mini player at the bottom
/// Use this when navigating to new screens to maintain consistent layout
class ScreenWithMiniPlayer extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;

  const ScreenWithMiniPlayer({super.key, required this.child, this.appBar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: appBar,
      body: Stack(
        children: [
          // Main content with bottom padding for mini player
          Positioned.fill(
            bottom: 70, // Height of mini player
            child: child,
          ),
          // Mini player at bottom
          const Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
        ],
      ),
    );
  }
}
