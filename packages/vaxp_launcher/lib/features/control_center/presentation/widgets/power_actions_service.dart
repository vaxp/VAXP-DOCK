import 'package:flutter/material.dart';

class PowerActionsServicePanel extends StatelessWidget {
  const PowerActionsServicePanel({
    required this.onShutdown,
    required this.onReboot,
    required this.onSuspend,
    required this.onLogout,
    super.key,
  });

  final VoidCallback onShutdown;
  final VoidCallback onReboot;
  final VoidCallback onSuspend;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 170,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(88, 2, 2, 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PowerActionButton(
                icon: Icons.power_settings_new_rounded,
                color: Colors.redAccent,
                onTap: onShutdown,
              ),
              _PowerActionButton(
                icon: Icons.restart_alt_rounded,
                color: Colors.orangeAccent,
                onTap: onReboot,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PowerActionButton(
                icon: Icons.bedtime_rounded,
                color: Colors.blueAccent,
                onTap: onSuspend,
              ),
              _PowerActionButton(
                icon: Icons.logout_rounded,
                color: Colors.purpleAccent,
                onTap: onLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PowerActionButton extends StatelessWidget {
  const _PowerActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: color,
          size: 18,
        ),
      ),
    );
  }
}

