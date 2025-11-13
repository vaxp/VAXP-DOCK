import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dbus/dbus.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:vaxp_launcher/con/widgets/bluetoothmanagerdialog.dart';
import 'package:vaxp_launcher/con/widgets/wifi_manager_dialog.dart';
import 'widgets/notification_service.dart';
import 'package:audioplayers/audioplayers.dart';

class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({super.key});

  @override
  State<ControlCenterPage> createState() => _ControlCenterPageState();
}

class _ControlCenterPageState extends State<ControlCenterPage> {
  late DBusClient _sysbus;
  Timer? _updateTimer;

  // --- System States ---
  double _batteryLevel = 0.0;
  bool _isCharging = false;
  double _currentVolume = 0.0;
  double _currentBrightness = 0.0;
  bool _isWifiEnabled = false;
  bool _isNetworkingEnabled = true;
  String _wifiStatus = "Unknown";
  bool _isBluetoothEnabled = false;
  String _activePowerProfile = 'balanced';

  // --- UI States ---
  bool _showNotifications = false;
  final List<VenomNotification> _realNotifications = [];
  StreamSubscription? _notifSub;

  @override
  void initState() {
    super.initState();
    _sysbus = DBusClient.system();
    _initInitialStates();
    _startNotificationServer();
    _updateTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshAllStates(),
    );
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _updateTimer?.cancel();
    _sysbus.close();
    super.dispose();
  }

  Future<void> _initInitialStates() async {
    await _refreshAllStates();
  }

  Future<void> _refreshAllStates() async {
    await Future.wait([
      _getBatteryInfo(),
      _getNetworkInfo(),
      _getBluetoothInfo(),
      _getPowerProfile(),
      _getVolumeAndBrightness(),
    ]);
  }

  // --- Notification Server Setup ---
  Future<void> _startNotificationServer() async {
    try {
      final server = await startNotificationServer();
      _notifSub = server.onNotification.listen((notif) async {
        if (mounted) {
          setState(() {
            _realNotifications.insert(0, notif);
          });
          // Play notification sound using UrlSource and full path
          try {
            final player = AudioPlayer();
            final filePath =
                '${Directory.current.path}/assets/Sound/notification.mp3';
            await player.play(UrlSource('file://$filePath'));
          } catch (e) {
            debugPrint('Failed to play notification sound: $e');
          }
        }
      });
    } catch (e) {
      debugPrint("Notification Server Error: $e");
    }
  }

  // --- DBus Getters ---
  Future<void> _getNetworkInfo() async {
    try {
      final nm = DBusRemoteObject(
        _sysbus,
        name: 'org.freedesktop.NetworkManager',
        path: DBusObjectPath('/org/freedesktop/NetworkManager'),
      );
      final netEnabled =
          (await nm.getProperty(
                'org.freedesktop.NetworkManager',
                'NetworkingEnabled',
              ))
              as DBusBoolean;
      final wifiEnabled =
          (await nm.getProperty(
                'org.freedesktop.NetworkManager',
                'WirelessEnabled',
              ))
              as DBusBoolean;
      final connectivity =
          (await nm.callMethod(
                'org.freedesktop.NetworkManager',
                'CheckConnectivity',
                [],
                replySignature: DBusSignature('u'),
              )).returnValues[0]
              as DBusUint32;

      if (mounted) {
        setState(() {
          _isNetworkingEnabled = netEnabled.value;
          _isWifiEnabled = wifiEnabled.value;
          _wifiStatus = wifiEnabled.value
              ? (connectivity.value == 4 ? "Connected" : "On")
              : "Off";
        });
      }
    } catch (_) {}
  }

  Future<void> _getBluetoothInfo() async {
    try {
      final adapter = DBusRemoteObject(
        _sysbus,
        name: 'org.bluez',
        path: DBusObjectPath('/org/bluez/hci0'),
      );
      final powered =
          (await adapter.getProperty('org.bluez.Adapter1', 'Powered'))
              as DBusBoolean;
      if (mounted) setState(() => _isBluetoothEnabled = powered.value);
    } catch (_) {
      if (mounted) setState(() => _isBluetoothEnabled = false);
    }
  }

  Future<void> _getBatteryInfo() async {
    try {
      final object = DBusRemoteObject(
        _sysbus,
        name: 'org.freedesktop.UPower',
        path: DBusObjectPath('/org/freedesktop/UPower/devices/DisplayDevice'),
      );
      final percent =
          (await object.getProperty(
                'org.freedesktop.UPower.Device',
                'Percentage',
              ))
              as DBusDouble;
      final state =
          (await object.getProperty('org.freedesktop.UPower.Device', 'State'))
              as DBusUint32;
      if (mounted) {
        setState(() {
          _batteryLevel = percent.value;
          _isCharging = state.value == 1;
        });
      }
    } catch (_) {}
  }

  Future<void> _getPowerProfile() async {
    try {
      final ppd = DBusRemoteObject(
        _sysbus,
        name: 'org.freedesktop.UPower.PowerProfiles',
        path: DBusObjectPath('/org/freedesktop/UPower/PowerProfiles'),
      );
      final active =
          (await ppd.getProperty(
                'org.freedesktop.UPower.PowerProfiles',
                'ActiveProfile',
              ))
              as DBusString;
      if (mounted) setState(() => _activePowerProfile = active.value);
    } catch (_) {}
  }

  Future<void> _getVolumeAndBrightness() async {
    if (!mounted) return;
    try {
      final volResult = await Process.run('sh', [
        '-c',
        "pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\\d+%' | head -1 | tr -d '%'",
      ]);
      if (volResult.exitCode == 0) {
        setState(
          () => _currentVolume =
              double.tryParse(volResult.stdout.toString().trim()) ?? 0,
        );
      }

      final briResult = await Process.run('brightnessctl', ['g']);
      final maxBri = await Process.run('brightnessctl', ['m']);
      if (briResult.exitCode == 0 && maxBri.exitCode == 0) {
        final cur = double.tryParse(briResult.stdout.toString().trim()) ?? 0;
        final max = double.tryParse(maxBri.stdout.toString().trim()) ?? 1;
        if (max > 0) setState(() => _currentBrightness = (cur / max) * 100);
      }
    } catch (_) {}
  }

  // --- System Actions ---
  Future<void> _toggleWifi(bool enable) async {
    try {
      final nm = DBusRemoteObject(
        _sysbus,
        name: 'org.freedesktop.NetworkManager',
        path: DBusObjectPath('/org/freedesktop/NetworkManager'),
      );
      await nm.setProperty(
        'org.freedesktop.NetworkManager',
        'WirelessEnabled',
        DBusBoolean(enable),
      );
      await _getNetworkInfo();
    } catch (_) {}
  }

  Future<void> _toggleNetworking(bool enable) async {
    await Process.run('nmcli', ['networking', enable ? 'on' : 'off']);
    await _getNetworkInfo();
  }

  Future<void> _toggleBluetooth(bool enable) async {
    try {
      // محاولة استخدام rfkill إذا فشل DBus المباشر (أكثر موثوقية أحياناً)
      await Process.run('rfkill', [enable ? 'unblock' : 'block', 'bluetooth']);
      await _getBluetoothInfo();
    } catch (_) {}
  }

  Future<void> _setPowerProfile(String profile) async {
    try {
      final ppd = DBusRemoteObject(
        _sysbus,
        name: 'org.freedesktop.UPower.PowerProfiles',
        path: DBusObjectPath('/org/freedesktop/UPower/PowerProfiles'),
      );
      await ppd.setProperty(
        'org.freedesktop.UPower.PowerProfiles',
        'ActiveProfile',
        DBusString(profile),
      );
      await _getPowerProfile();
    } catch (_) {}
  }

  Future<void> _setVolume(double value) async {
    setState(() => _currentVolume = value);
    await Process.run('pactl', [
      'set-sink-volume',
      '@DEFAULT_SINK@',
      '${value.toInt()}%',
    ]);
  }

  Future<void> _setBrightness(double value) async {
    setState(() => _currentBrightness = value);
    await Process.run('brightnessctl', ['s', '${value.toInt()}%']);
  }

  void _powerAction(String action) {
    switch (action) {
      case 'shutdown':
        Process.run('systemctl', ['poweroff']);
        break;
      case 'reboot':
        Process.run('systemctl', ['reboot']);
        break;
      case 'suspend':
        Process.run('systemctl', ['suspend']);
        break;
      case 'logout':
        final user = Platform.environment['USER'];
        if (user != null) Process.run('loginctl', ['terminate-user', user]);
        break;
    }
  }

  // === UI Build ===
  @override
  Widget build(BuildContext context) {
    // Compact horizontal layout optimized for 800x200 container
    // Available space after padding (12px each side): 776w x 176h
    // Layout proportions:
    const double headerWidth = 70.0; // 8.7% - time & notifications
    const double vDivider = 8.0;
    const double gap = 8.0;
    const double networkWidth = 100.0; // 12.3% - wifi, ethernet, bluetooth
    const double profilesWidth = 120.0; // 14.8% - power profiles
    const double slidersWidth = 240.0; // 29.5% - brightness & volume
    const double rightWidth = 170.0; // battery & power actions
    // Total: 70 + 8 + 100 + 8 + 120 + 8 + 240 + 8 + 250 = 812px

    return Scaffold(
      backgroundColor: const Color.fromARGB(0, 0, 0, 0),
      body: GlassmorphicContainer(
        width: double.infinity,
        height: 200,
        borderRadius: 1,
        linearGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(0, 0, 0, 0),
            const Color.fromARGB(0, 0, 0, 0),
          ],
        ),
        border: 1.2,
        blur: 26,
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // borderColor.withOpacity(0.1),
            // borderColor.withOpacity(0.05),
          ],
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 800,
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // gradient: const LinearGradient(
              //   colors: [
              //     Color.fromARGB(220, 28, 32, 44),
              //     Color.fromARGB(180, 18, 20, 30),
              //   ],
              //   begin: Alignment.topLeft,
              //   end: Alignment.bottomRight,
              // ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color.fromARGB(31, 255, 255, 255),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(19, 0, 0, 0),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: compact header (time + notifications button)
                SizedBox(
                  width: headerWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 1)),
                          builder: (context, _) {
                            final now = DateTime.now();
                            return Text(
                              "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color.fromARGB(226, 255, 255, 255),
                              ),
                            );
                          },
                        ),
                      ),
                      // Notifications button (opens full notifications dialog)
                      GestureDetector(
                        onTap: _showNotificationsDialog,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(88, 2, 2, 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.notifications_rounded,
                                size: 26,
                                color: Color.fromARGB(255, 255, 255, 255),
                              ),
                              if (_realNotifications.isNotEmpty)
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 12,
                                      minHeight: 12,
                                    ),
                                    child: Center(
                                      child: Text(
                                        _realNotifications.length > 99
                                            ? '99+'
                                            : _realNotifications.length
                                                  .toString(),
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(
                  width: vDivider,
                  color: Colors.transparent,
                ),

                // Middle: controls area (horizontally scrollable if needed)
                Expanded(
                  child: SizedBox(
                    height: 180,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Grouped compact containers: network, profiles, sliders
                          _buildNetworkContainer(width: networkWidth),
                          SizedBox(width: gap),
                          _buildProfilesContainer(width: profilesWidth),
                          SizedBox(width: gap),
                          _buildSlidersContainer(width: slidersWidth),
                        ],
                      ),
                    ),
                  ),
                ),

                const VerticalDivider(
                  width: vDivider,
                  color: Colors.transparent,
                ),

                // Right: battery + grouped power actions container
                SizedBox(
                  width: rightWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // const SizedBox(height: 8),
                      _buildPowerActionsContainer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tab buttons removed in compact layout (not used)

  // --- Controls View ---
  // Full controls view removed in compact redesign (not referenced)

  // --- Notifications View ---
  // Notifications view removed in compact redesign (not referenced)

  // --- Helper Widgets ---
  Widget _buildProfileBtn(
    String label,
    IconData icon,
    String profileID,
    Color color,
  ) {
    final isActive = _activePowerProfile == profileID;
    return Expanded(
      child: InkWell(
        onTap: () => _setPowerProfile(profileID),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isActive
                ? color.withOpacity(0.14)
                : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? color.withOpacity(0.35) : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isActive ? 0.18 : 0.06),
                blurRadius: isActive ? 14 : 4,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(-0.04)
                  ..rotateY(0.03),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withOpacity(0.28),
                              color.withOpacity(0.06),
                            ],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.fromARGB(36, 255, 255, 255),
                              Color.fromARGB(8, 255, 255, 255),
                            ],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isActive ? 0.22 : 0.08),
                        blurRadius: isActive ? 14 : 6,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isActive ? Colors.white : Colors.white54,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? Colors.white : Colors.white54,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatteryTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _isCharging
                ? Icons.battery_charging_full_rounded
                : Icons.battery_std_rounded,
            color: _isCharging ? Colors.greenAccent : Colors.white70,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Battery",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _batteryLevel / 100,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    color: _isCharging
                        ? Colors.greenAccent
                        : (_batteryLevel <= 20
                              ? Colors.redAccent
                              : Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            "${_batteryLevel.toInt()}%",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    VoidCallback? onLongPress,
    required IconData icon,
    required String label,
    required String status,
    required bool isActive,
    required VoidCallback onTap,
    Color activeColor = Colors.tealAccent,
  }) {
    return Expanded(
      child: InkWell(
        onLongPress: onLongPress,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withOpacity(0.18)
                : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? activeColor.withOpacity(0.45)
                  : Colors.transparent,
              width: isActive ? 1.0 : 0.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isActive ? 0.25 : 0.12),
                blurRadius: isActive ? 18 : 6,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(-0.06)
                  ..rotateY(0.04),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              activeColor.withOpacity(0.30),
                              activeColor.withOpacity(0.08),
                            ],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.fromARGB(40, 255, 255, 255),
                              Color.fromARGB(8, 255, 255, 255),
                            ],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isActive ? 0.36 : 0.18),
                        blurRadius: isActive ? 18 : 10,
                        offset: const Offset(0, 10),
                        spreadRadius: isActive ? 1 : 0,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.06),
                        blurRadius: 2,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: isActive ? Colors.white : Colors.white70,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                status,
                style: TextStyle(
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderTile(
    IconData icon,
    double value,
    ValueChanged<double> onChanged,
    Color activeColor,
  ) {
    return Row(
      children: [
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(-0.04)
            ..rotateY(0.03),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  activeColor.withOpacity(0.2),
                  activeColor.withOpacity(0.05),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: activeColor,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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
    );
  }

  Widget _buildPowerButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }

  // Full-size compact toggle removed — network uses icon-only toggles now.

  Widget _buildProfileBtnCompact(
    String label,
    IconData icon,
    String profileID,
    Color color,
  ) {
    final isActive = _activePowerProfile == profileID;
    return InkWell(
      onTap: () => _setPowerProfile(profileID),
      borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildSliderTileCompact(
    IconData icon,
    double value,
    ValueChanged<double> onChanged,
    Color activeColor,
  ) {
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

  Widget _buildBatteryCompact() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _isCharging
              ? Icons.battery_charging_full_rounded
              : Icons.battery_std_rounded,
          color: _isCharging ? Colors.greenAccent : Colors.white70,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          "${_batteryLevel.toInt()}%",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Icon-only toggle button used inside small grouped containers
  Widget _buildIconToggle({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    Color activeColor = Colors.tealAccent,
    String? tooltip,
  }) {
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
              ? activeColor.withOpacity(0.16)
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

  Widget _buildNetworkContainer({double width = 200.0}) {
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
          _buildIconToggle(
            icon: Icons.wifi_rounded,
            isActive: _isWifiEnabled,
            onTap: () => _toggleWifi(!_isWifiEnabled),
            onLongPress: () => showWiFiManager(context),
            tooltip: 'Wi‑Fi',
          ),
          const SizedBox(height: 6),
          _buildIconToggle(
            icon: Icons.lan_rounded,
            isActive: _isNetworkingEnabled,
            onTap: () => _toggleNetworking(!_isNetworkingEnabled),
            tooltip: 'Ethernet',
          ),
          const SizedBox(height: 6),
          _buildIconToggle(
            icon: Icons.bluetooth_rounded,
            isActive: _isBluetoothEnabled,
            onTap: () => _toggleBluetooth(!_isBluetoothEnabled),
            onLongPress: () => showBluetoothManager(context),
            tooltip: 'Bluetooth',
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesContainer({double width = 96.0}) {
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
          _buildBatteryCompact(),
          const SizedBox(height: 25),
          Text(
            'Power Profiles',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 255, 255, 255),
            ),
          ),

          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProfileBtnCompact(
                'Saver',
                Icons.eco_rounded,
                'power-saver',
                Colors.greenAccent,
              ),
              _buildProfileBtnCompact(
                'Bal',
                Icons.balance_rounded,
                'balanced',
                Colors.blueAccent,
              ),
              _buildProfileBtnCompact(
                'Boost',
                Icons.speed_rounded,
                'performance',
                Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersContainer({double width = 150.0}) {
    return Container(
      width: 200,
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(88, 2, 2, 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSliderTileCompact(
            Icons.wb_sunny_rounded,
            _currentBrightness,
            _setBrightness,
            Colors.orangeAccent,
          ),
          const SizedBox(height: 6),
          _buildSliderTileCompact(
            Icons.volume_up_rounded,
            _currentVolume,
            _setVolume,
            Colors.tealAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildPowerActionsContainer() {
    return Container(
      width: 250,
      height: 180,
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
              InkWell(
                onTap: () => _powerAction('shutdown'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.power_settings_new_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _powerAction('reboot'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.restart_alt_rounded,
                    color: Colors.orangeAccent,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              InkWell(
                onTap: () => _powerAction('suspend'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bedtime_rounded,
                    color: Colors.blueAccent,
                    size: 18,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _powerAction('logout'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.purpleAccent,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Show notifications in a dialog (restores notifications feature)
  void _showNotificationsDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 520,
                height: 360,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(220, 28, 32, 44),
                      Color.fromARGB(180, 18, 20, 30),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: _notificationsDialogContent(setDialogState),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _notificationsDialogContent(
    void Function(void Function())? setDialogState,
  ) {
    if (_realNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(40, 255, 255, 255),
                    Color.fromARGB(8, 255, 255, 255),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 46,
                color: const Color.fromARGB(255, 27, 167, 167),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No New Notifications",
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white54,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.transparent,
              ),
              onPressed: () {
                setState(() => _realNotifications.clear());
                // Update dialog UI as well
                if (setDialogState != null) setDialogState(() {});
              },
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text("Clear All"),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: _realNotifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notif = _realNotifications[index];
              final timeStr =
                  "${notif.time.hour.toString().padLeft(2, '0')}:${notif.time.minute.toString().padLeft(2, '0')}";
              return Dismissible(
                key: ValueKey(notif.id),
                onDismissed: (_) {
                  setState(() => _realNotifications.removeAt(index));
                  if (setDialogState != null) setDialogState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromARGB(30, 255, 255, 255),
                        Color.fromARGB(6, 255, 255, 255),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.02)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Colors.tealAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              notif.appName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notif.summary,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (notif.body.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          notif.body,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            height: 1.3,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

void showBluetoothManager(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const BluetoothManagerDialog(),
  );
}

void showWiFiManager(BuildContext context) {
  showDialog(context: context, builder: (ctx) => const WiFiManagerDialog());
}
