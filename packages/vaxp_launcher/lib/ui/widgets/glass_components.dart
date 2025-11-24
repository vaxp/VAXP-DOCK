import 'dart:ui';
import 'package:flutter/material.dart';

class GlassDialogShell extends StatelessWidget {
  const GlassDialogShell({
    super.key,
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
                    GlassIconButton(icon: Icons.close_rounded, onTap: onClose),
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

class GlassSection extends StatelessWidget {
  const GlassSection({
    super.key,
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

class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
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
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
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

class GlassIconButton extends StatefulWidget {
  const GlassIconButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
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
