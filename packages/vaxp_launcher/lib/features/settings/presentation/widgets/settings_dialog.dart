import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vaxp_launcher/features/settings/application/settings_cubit.dart';
import 'package:vaxp_launcher/features/settings/application/settings_state.dart';
import 'package:vaxp_launcher/widgets/color_picker_dialog.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({required this.cubit, super.key});

  final SettingsCubit cubit;

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

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: _GlassDialogShell(
          width: 540,
          title: 'Launcher Settings',
          onClose: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SingleChildScrollView(
              child: BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, state) {
                  final cubit = context.read<SettingsCubit>();
                  Color tempColor = state.settings.backgroundColor;
                  double tempOpacity = state.settings.opacity;
                  String? tempBackgroundImage = state.settings.backgroundImagePath;
                  String? tempIconTheme = state.settings.iconThemePath;

                  return StatefulBuilder(
                    builder: (context, setDialogState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GlassSection(
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
                                  final isSelected = tempColor == color;
                                  return GestureDetector(
                                    onTap: () =>
                                        setDialogState(() => tempColor = color),
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
                              _GlassButton(
                                icon: Icons.colorize,
                                label: 'Custom color',
                                onPressed: () async {
                                  final picked = await showDialog<Color>(
                                    context: context,
                                    builder: (c) => CustomColorPickerDialog(
                                      initialColor: tempColor,
                                    ),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => tempColor = picked);
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
                                        value: tempOpacity,
                                        min: 0.0,
                                        max: 1.0,
                                        divisions: 100,
                                        onChanged: (value) => setDialogState(
                                          () => tempOpacity = value,
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
                                      '${(tempOpacity * 100).round()}%',
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
                                    child: _GlassButton(
                                      icon: Icons.image_outlined,
                                      label: 'Select image',
                                      onPressed: () async {
                                        final imagePath =
                                            await _pickBackgroundImage(context);
                                        if (imagePath != null) {
                                          setDialogState(
                                            () => tempBackgroundImage = imagePath,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  if (tempBackgroundImage != null) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _GlassButton(
                                        icon: Icons.delete_outline,
                                        label: 'Remove wallpaper',
                                        onPressed: () => setDialogState(
                                          () => tempBackgroundImage = null,
                                        ),
                                        destructive: true,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (tempBackgroundImage != null) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: SizedBox(
                                    height: 140,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(
                                          File(tempBackgroundImage!),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
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
                                            color: tempColor.withOpacity(
                                              tempOpacity,
                                            ),
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
                        _GlassSection(
                          title: 'Icon theme',
                          subtitle:
                              'Select a folder containing themed icons to restyle your apps.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _GlassButton(
                                      icon: Icons.folder_open_outlined,
                                      label: 'Select icon theme directory',
                                      onPressed: () async {
                                        final dir =
                                            await _pickIconThemeDirectory(context);
                                        if (dir != null) {
                                          setDialogState(() => tempIconTheme = dir);
                                        }
                                      },
                                    ),
                                  ),
                                  if (tempIconTheme != null) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _GlassButton(
                                        icon: Icons.clear_outlined,
                                        label: 'Clear selection',
                                        onPressed: () => setDialogState(
                                          () => tempIconTheme = null,
                                        ),
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
                                  tempIconTheme ?? 'No icon theme selected',
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
                              child: _GlassButton(
                                icon: Icons.close_rounded,
                                label: 'Cancel',
                                onPressed: () => Navigator.of(context).pop(),
                                accent: Colors.white70,
                                filled: false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GlassButton(
                                icon: Icons.check_circle_outline_rounded,
                                label: 'Apply settings',
                                onPressed: () {
                                  cubit.updateBackgroundColor(tempColor);
                                  cubit.updateOpacity(tempOpacity);
                                  cubit.updateBackgroundImage(tempBackgroundImage);
                                  cubit.updateIconTheme(tempIconTheme);
                                  cubit.saveCurrentSettings();
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<String?> _pickBackgroundImage(BuildContext context) async {
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

  static Future<String?> _pickIconThemeDirectory(BuildContext context) async {
    try {
      final dir = await FilePicker.platform.getDirectoryPath();
      return dir;
    } catch (e) {
      debugPrint('Error picking icon theme directory: $e');
    }
    return null;
  }
}

// Glass UI Components
class _GlassDialogShell extends StatelessWidget {
  const _GlassDialogShell({
    required this.child,
    required this.title,
    required this.onClose,
    this.width = 520,
  });

  final Widget child;
  final String title;
  final VoidCallback onClose;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.18),
                const Color(0xFF0E141F).withOpacity(0.88),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 36,
                spreadRadius: -18,
                offset: const Offset(0, 28),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    _GlassIconButton(icon: Icons.close_rounded, onTap: onClose),
                  ],
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  const _GlassSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.black.withOpacity(0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 26,
            spreadRadius: -16,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _GlassButton extends StatefulWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = const Color(0xFF2D9CFF),
    this.destructive = false,
    this.filled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color accent;
  final bool destructive;
  final bool filled;

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color baseAccent = widget.destructive
        ? Colors.redAccent
        : widget.accent;
    final bool filled = widget.filled || widget.destructive;

    final gradientColors = filled
        ? [
            baseAccent.withOpacity(_hovered ? 0.94 : 0.82),
            baseAccent.withOpacity(_hovered ? 0.62 : 0.46),
          ]
        : [
            Colors.white.withOpacity(_hovered ? 0.18 : 0.12),
            Colors.white.withOpacity(_hovered ? 0.06 : 0.02),
          ];

    final borderColor = filled
        ? baseAccent.withOpacity(_hovered ? 0.42 : 0.3)
        : Colors.white.withOpacity(_hovered ? 0.28 : 0.18);

    final textColor = filled ? Colors.white : Colors.white.withOpacity(0.9);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: filled
                    ? baseAccent.withOpacity(0.28)
                    : Colors.black.withOpacity(0.2),
                blurRadius: filled ? 22 : 18,
                spreadRadius: -10,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: textColor),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatefulWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(_hovered ? 0.22 : 0.12),
            border: Border.all(
              color: Colors.white.withOpacity(_hovered ? 0.35 : 0.18),
              width: 0.9,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ),
    );
  }
}

