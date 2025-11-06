import 'package:flutter/material.dart';

class CustomColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const CustomColorPickerDialog({super.key, required this.initialColor});

  @override
  State<CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<CustomColorPickerDialog> {
  late HSVColor _hsvColor;
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _hsvColor = HSVColor.fromColor(_currentColor);
  }

  void _updateColor(HSVColor hsv) {
    setState(() {
      _hsvColor = hsv;
      _currentColor = hsv.toColor();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick a Color'),
      backgroundColor: Colors.grey[900],
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Hue:', style: TextStyle(color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _hsvColor.hue,
                    min: 0.0,
                    max: 360.0,
                    divisions: 360,
                    label: '${_hsvColor.hue.round()}°',
                    onChanged: (v) => _updateColor(_hsvColor.withHue(v)),
                    activeColor: Colors.blue,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Saturation:', style: TextStyle(color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _hsvColor.saturation,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    label: '${(_hsvColor.saturation * 100).round()}%',
                    onChanged: (v) => _updateColor(_hsvColor.withSaturation(v)),
                    activeColor: Colors.blue,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Brightness:', style: TextStyle(color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _hsvColor.value,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    label: '${(_hsvColor.value * 100).round()}%',
                    onChanged: (v) => _updateColor(_hsvColor.withValue(v)),
                    activeColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_currentColor),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Select'),
        ),
      ],
    );
  }
}


