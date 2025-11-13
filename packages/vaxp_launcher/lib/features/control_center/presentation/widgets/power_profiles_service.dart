import 'package:flutter/material.dart';

class PowerProfilesServicePanel extends StatelessWidget {
  const PowerProfilesServicePanel({
    required this.batteryLevel,
    required this.isCharging,
    required this.activePowerProfile,
    required this.onSelectProfile,
    super.key,
  });

  final double batteryLevel;
  final bool isCharging;
  final String activePowerProfile;
  final ValueChanged<String> onSelectProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(88, 2, 2, 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _BatteryChip(
            batteryLevel: batteryLevel,
            isCharging: isCharging,
          ),
          const SizedBox(height: 25),
          const Text(
            'Power Profiles',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 255, 255, 255),
            ),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ProfileButton(
                label: 'Saver',
                icon: Icons.eco_rounded,
                profileId: 'power-saver',
                color: Colors.greenAccent,
                isActive: activePowerProfile == 'power-saver',
                onTap: () => onSelectProfile('power-saver'),
              ),
              _ProfileButton(
                label: 'Bal',
                icon: Icons.balance_rounded,
                profileId: 'balanced',
                color: Colors.blueAccent,
                isActive: activePowerProfile == 'balanced',
                onTap: () => onSelectProfile('balanced'),
              ),
              _ProfileButton(
                label: 'Boost',
                icon: Icons.speed_rounded,
                profileId: 'performance',
                color: Colors.redAccent,
                isActive: activePowerProfile == 'performance',
                onTap: () => onSelectProfile('performance'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BatteryChip extends StatelessWidget {
  const _BatteryChip({
    required this.batteryLevel,
    required this.isCharging,
  });

  final double batteryLevel;
  final bool isCharging;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isCharging
              ? Icons.battery_charging_full_rounded
              : Icons.battery_std_rounded,
          color: isCharging ? Colors.greenAccent : Colors.white70,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          '${batteryLevel.toInt()}%',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.label,
    required this.icon,
    required this.profileId,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String profileId;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: label,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? color.withOpacity(0.18)
                : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }
}

