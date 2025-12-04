import 'package:flutter/material.dart';
import 'dart:async';

class TypingAnimation extends StatefulWidget {
  final List<String> texts;
  final TextStyle? textStyle;
  final Duration typingSpeed;
  final Duration deletingSpeed;
  final Duration pauseDuration;

  const TypingAnimation({
    super.key,
    required this.texts,
    this.textStyle,
    this.typingSpeed = const Duration(milliseconds: 100),
    this.deletingSpeed = const Duration(milliseconds: 50),
    this.pauseDuration = const Duration(seconds: 2),
  });

  @override
  State<TypingAnimation> createState() => _TypingAnimationState();
}

class _TypingAnimationState extends State<TypingAnimation> {
  String _displayedText = '';
  int _currentTextIndex = 0;
  bool _isDeleting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;

      setState(() {
        final currentText = widget.texts[_currentTextIndex];

        if (!_isDeleting) {
          // Typing forward
          if (_displayedText.length < currentText.length) {
            _displayedText = currentText.substring(
              0,
              _displayedText.length + 1,
            );
          } else {
            // Finished typing, pause then start deleting
            timer.cancel();
            Future.delayed(widget.pauseDuration, () {
              if (mounted) {
                _isDeleting = true;
                _startTyping();
              }
            });
          }
        } else {
          // Deleting backward
          if (_displayedText.isNotEmpty) {
            _displayedText = _displayedText.substring(
              0,
              _displayedText.length - 1,
            );
          } else {
            // Finished deleting, move to next text
            _isDeleting = false;
            _currentTextIndex = (_currentTextIndex + 1) % widget.texts.length;
            timer.cancel();
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _startTyping();
              }
            });
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_displayedText, style: widget.textStyle),
        // Blinking cursor
        AnimatedOpacity(
          opacity: _displayedText.isEmpty ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 500),
          child: Container(
            width: 2,
            height: widget.textStyle?.fontSize ?? 16,
            color: widget.textStyle?.color ?? Colors.white,
            margin: const EdgeInsets.only(left: 2),
          ),
        ),
      ],
    );
  }
}
