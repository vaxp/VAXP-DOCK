import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../widgets/color_picker_dialog.dart';
import 'glass_components.dart';

class LauncherSettingsDialog extends StatefulWidget {
  const LauncherSettingsDialog({
    super.key,
    required this.initialBackgroundColor,
    required this.initialOpacity,
    required this.initialBackgroundImagePath,
    required this.initialIconThemePath,
    required this.onApply,
  });

  final Color initialBackgroundColor;
  final double initialOpacity;
  final String? initialBackgroundImagePath;
  final String? initialIconThemePath;
  final Function(Color, double, String?, String?) onApply;

  @override
  State<LauncherSettingsDialog> createState() => _LauncherSettingsDialogState();
}

class _LauncherSettingsDialogState extends State<LauncherSettingsDialog> {
  late Color _tempColor;
  late double _tempOpacity;
  late String? _tempBackgroundImage;
  late String? _tempIconTheme;

  @override
  void initState() {
    super.initState();
    _tempColor = widget.initialBackgroundColor;
    _tempOpacity = widget.initialOpacity;
    _tempBackgroundImage = widget.initialBackgroundImagePath;
    _tempIconTheme = widget.initialIconThemePath;
  }

  static final List<Color> _presetColors = [
    Colors.black,
    Colors.grey[900]!,
    Colors.grey[800]!,
    Colors.blue[900]!,
    Colors.purple[900]!,
    Colors.indigo[900]!,
    Colors.teal[900]!,
    Colors.green[900]!,
    Colors.orange[900]!,
    Colors.red[900]!,
    Colors.pink[900]!,
    Colors.amber[900]!,
    Colors.cyan[900]!,
    Colors.deepPurple[900]!,
    Colors.lime[900]!,
    Colors.brown[900]!,
  ];

  Future<String?> _pickBackgroundImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        return result.files.single.path;
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
    return null;
  }

  Future<String?> _pickIconThemeDirectory() async {
    try {
      final dir = await FilePicker.platform.getDirectoryPath();
      return dir;
    } catch (e) {
      debugPrint('Error picking icon theme directory: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GlassDialogShell(
        width: 540,
        title: 'Launcher Settings',
        onClose: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassSection(
                  title: 'Background appearance',
                  subtitle:
                      'Blend the launcher with your desktop using color, opacity, and wallpaper.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Color presets',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1,
                            ),
                        itemCount: _presetColors.length,
                        itemBuilder: (context, index) {
                          final color = _presetColors[index];
                          final isSelected = _tempColor == color;
                          return GestureDetector(
                            onTap: () => setState(() => _tempColor = color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.45),
                                    blurRadius: isSelected ? 12 : 6,
                                    spreadRadius: isSelected ? 2 : 0,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      GlassButton(
                        icon: Icons.colorize,
                        label: 'Custom color',
                        onPressed: () async {
                          final picked = await showDialog<Color>(
                            context: context,
                            builder: (c) => CustomColorPickerDialog(
                              initialColor: _tempColor,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _tempColor = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Transparency',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.blueAccent,
                                inactiveTrackColor: Colors.white24,
                                trackHeight: 4,
                                thumbColor: Colors.blueAccent,
                                overlayColor: Colors.blueAccent.withOpacity(
                                  0.2,
                                ),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16,
                                ),
                              ),
                              child: Slider(
                                value: _tempOpacity,
                                min: 0.0,
                                max: 1.0,
                                divisions: 100,
                                onChanged: (value) =>
                                    setState(() => _tempOpacity = value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.white.withOpacity(0.08),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.14),
                              ),
                            ),
                            child: Text(
                              '${(_tempOpacity * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Wallpaper',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GlassButton(
                              icon: Icons.image_outlined,
                              label: 'Select image',
                              onPressed: () async {
                                final imagePath = await _pickBackgroundImage();
                                if (imagePath != null) {
                                  setState(
                                    () => _tempBackgroundImage = imagePath,
                                  );
                                }
                              },
                            ),
                          ),
                          if (_tempBackgroundImage != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: GlassButton(
                                icon: Icons.delete_outline,
                                label: 'Remove wallpaper',
                                onPressed: () =>
                                    setState(() => _tempBackgroundImage = null),
                                destructive: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_tempBackgroundImage != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            height: 140,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(_tempBackgroundImage!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.black54,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.white54,
                                        ),
                                      ),
                                ),
                                BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: Container(
                                    color: _tempColor.withOpacity(_tempOpacity),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Wallpaper preview',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GlassSection(
                  title: 'Icon theme',
                  subtitle:
                      'Select a folder containing themed icons to restyle your apps.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GlassButton(
                              icon: Icons.folder_open_outlined,
                              label: 'Select icon theme directory',
                              onPressed: () async {
                                final dir = await _pickIconThemeDirectory();
                                if (dir != null) {
                                  setState(() => _tempIconTheme = dir);
                                }
                              },
                            ),
                          ),
                          if (_tempIconTheme != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: GlassButton(
                                icon: Icons.clear_outlined,
                                label: 'Clear selection',
                                onPressed: () =>
                                    setState(() => _tempIconTheme = null),
                                destructive: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Text(
                          _tempIconTheme ?? 'No icon theme selected',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        icon: Icons.close_rounded,
                        label: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                        accent: Colors.white70,
                        filled: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassButton(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Apply settings',
                        onPressed: () {
                          widget.onApply(
                            _tempColor,
                            _tempOpacity,
                            _tempBackgroundImage,
                            _tempIconTheme,
                          );
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
