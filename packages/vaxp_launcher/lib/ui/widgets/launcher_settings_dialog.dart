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
        width: 600,
        title: 'Launcher Settings',
        onClose: () => Navigator.of(context).pop(),
        child: DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Appearance'),
                      Tab(text: 'Icons'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 400,
                child: TabBarView(
                  children: [
                    // Appearance Tab
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GlassSection(
                            title: 'Color',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 80,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 10,
                                    ),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _presetColors.length + 1,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        return GestureDetector(
                                          onTap: () async {
                                            final picked =
                                                await showDialog<Color>(
                                                  context: context,
                                                  builder: (c) =>
                                                      CustomColorPickerDialog(
                                                        initialColor:
                                                            _tempColor,
                                                      ),
                                                );
                                            if (picked != null) {
                                              setState(
                                                () => _tempColor = picked,
                                              );
                                            }
                                          },
                                          child: Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.colorize,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        );
                                      }
                                      final color = _presetColors[index - 1];
                                      final isSelected = _tempColor == color;
                                      return GestureDetector(
                                        onTap: () =>
                                            setState(() => _tempColor = color),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          width: 50,
                                          height: 50,
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
                                                color: Colors.black.withOpacity(
                                                  0.45,
                                                ),
                                                blurRadius: isSelected ? 12 : 6,
                                                spreadRadius: isSelected
                                                    ? 2
                                                    : 0,
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
                                ),
                                const SizedBox(height: 20),
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
                                          overlayColor: Colors.blueAccent
                                              .withOpacity(0.2),
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 8,
                                              ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 16,
                                              ),
                                        ),
                                        child: Slider(
                                          value: _tempOpacity,
                                          min: 0.0,
                                          max: 1.0,
                                          divisions: 100,
                                          onChanged: (value) => setState(
                                            () => _tempOpacity = value,
                                          ),
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          GlassSection(
                            title: 'Wallpaper',
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: GlassButton(
                                        icon: Icons.image_outlined,
                                        label: 'Select image',
                                        onPressed: () async {
                                          final imagePath =
                                              await _pickBackgroundImage();
                                          if (imagePath != null) {
                                            setState(
                                              () => _tempBackgroundImage =
                                                  imagePath,
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
                                          label: 'Remove',
                                          onPressed: () => setState(
                                            () => _tempBackgroundImage = null,
                                          ),
                                          destructive: true,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (_tempBackgroundImage != null) ...[
                                  const SizedBox(height: 16),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      height: 120,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.file(
                                            File(_tempBackgroundImage!),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) => Container(
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
                                              color: _tempColor.withOpacity(
                                                _tempOpacity,
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'Preview',
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
                        ],
                      ),
                    ),
                    // Icons Tab
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      physics: const BouncingScrollPhysics(),
                      child: GlassSection(
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
                                    label: 'Select folder',
                                    onPressed: () async {
                                      final dir =
                                          await _pickIconThemeDirectory();
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
                                      label: 'Clear',
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
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.folder_outlined,
                                    color: Colors.white.withOpacity(0.5),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _tempIconTheme ?? 'No theme selected',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
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
                        label: 'Apply',
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
