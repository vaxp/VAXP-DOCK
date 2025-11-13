import 'package:flutter/material.dart';

class SlidersServicePanel extends StatelessWidget {
  const SlidersServicePanel({
    required this.brightness,
    required this.volume,
    required this.onBrightnessChanged,
    required this.onVolumeChanged,
    super.key,
  });

  final double brightness;
  final double volume;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(88, 2, 2, 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ServiceSliderTile(
            icon: Icons.wb_sunny_rounded,
            value: brightness,
            activeColor: Colors.orangeAccent,
            onChanged: onBrightnessChanged,
          ),
          const SizedBox(height: 6),
          _ServiceSliderTile(
            icon: Icons.volume_up_rounded,
            value: volume,
            activeColor: Colors.tealAccent,
            onChanged: onVolumeChanged,
          ),
        ],
      ),
    );
  }
}

class _ServiceSliderTile extends StatelessWidget {
  const _ServiceSliderTile({
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: activeColor,
                inactiveTrackColor: Colors.white10,
              ),
              child: Slider(
                value: value.clamp(0.0, 100.0),
                min: 0,
                max: 100,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

