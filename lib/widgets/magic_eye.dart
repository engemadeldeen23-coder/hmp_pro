import 'package:flutter/material.dart';

enum MagicEyeState {
  off,
  selfTest,
  red,
  blue,
  green,
}

class MagicEye extends StatelessWidget {
  final MagicEyeState state;
  final double size;

  const MagicEye({super.key, required this.state, this.size = 80});

  Color get _color {
    switch (state) {
      case MagicEyeState.off:
        return Colors.grey.shade800;
      case MagicEyeState.selfTest:
        return Colors.orangeAccent;
      case MagicEyeState.red:
        return Colors.redAccent;
      case MagicEyeState.blue:
        return const Color(0xFF1E88E5);
      case MagicEyeState.green:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _color,
            _color.withOpacity(0.5),
            _color.withOpacity(0.1),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _color.withOpacity(0.6),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.35,
          height: size * 0.35,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.9),
          ),
          child: Icon(
            _iconForState(state),
            color: _color,
            size: size * 0.22,
          ),
        ),
      ),
    );
  }

  IconData _iconForState(MagicEyeState s) {
    switch (s) {
      case MagicEyeState.off:
        return Icons.power_settings_new;
      case MagicEyeState.selfTest:
        return Icons.autorenew;
      case MagicEyeState.red:
        return Icons.close;
      case MagicEyeState.blue:
        return Icons.bluetooth_connected;
      case MagicEyeState.green:
        return Icons.play_arrow;
    }
  }
}