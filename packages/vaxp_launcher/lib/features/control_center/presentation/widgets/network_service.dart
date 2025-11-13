import 'package:flutter/material.dart';

import 'package:vaxp_launcher/con/widgets/bluetoothmanagerdialog.dart';
import 'package:vaxp_launcher/con/widgets/wifi_manager_dialog.dart';

class NetworkServicePanel extends StatelessWidget {
  const NetworkServicePanel({
    required this.isWifiEnabled,
    required this.isNetworkingEnabled,
    required this.isBluetoothEnabled,
    required this.onWifiToggle,
    required this.onNetworkingToggle,
    required this.onBluetoothToggle,
    required this.onOpenWifiManager,
    required this.onOpenBluetoothManager,
    super.key,
  });

  final bool isWifiEnabled;
  final bool isNetworkingEnabled;
  final bool isBluetoothEnabled;
  final ValueChanged<bool> onWifiToggle;
  final ValueChanged<bool> onNetworkingToggle;
  final ValueChanged<bool> onBluetoothToggle;
  final VoidCallback onOpenWifiManager;
  final VoidCallback onOpenBluetoothManager;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(88, 2, 2, 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ServiceIconToggle(
            icon: Icons.wifi_rounded,
            isActive: isWifiEnabled,
            tooltip: 'Wi‑Fi',
            onTap: () => onWifiToggle(!isWifiEnabled),
            onLongPress: onOpenWifiManager,
          ),
          const SizedBox(height: 6),
          _ServiceIconToggle(
            icon: Icons.lan_rounded,
            isActive: isNetworkingEnabled,
            tooltip: 'Ethernet',
            onTap: () => onNetworkingToggle(!isNetworkingEnabled),
          ),
          const SizedBox(height: 6),
          _ServiceIconToggle(
            icon: Icons.bluetooth_rounded,
            isActive: isBluetoothEnabled,
            tooltip: 'Bluetooth',
            onTap: () => onBluetoothToggle(!isBluetoothEnabled),
            onLongPress: onOpenBluetoothManager,
          ),
        ],
      ),
    );
  }
}

void showBluetoothManager(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => const BluetoothManagerDialog(),
  );
}

void showWiFiManager(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => const WiFiManagerDialog(),
  );
}

class _ServiceIconToggle extends StatelessWidget {
  const _ServiceIconToggle({
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.tooltip,
    this.onLongPress,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.tealAccent.withOpacity(0.16)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

