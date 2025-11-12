import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dbus/dbus.dart';
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
            final filePath = '${Directory.current.path}/assets/Sound/notification.mp3';
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
    return Scaffold(
      backgroundColor: const Color.fromARGB(0, 0, 0, 0),
      body: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 400,
          height: _showNotifications ? 600 : 740,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color.fromARGB(220, 28, 32, 44),
                Color.fromARGB(180, 18, 20, 30),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.02),
                blurRadius: 2,
                offset: const Offset(0, 1),
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header & Switcher
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Venom Nexus",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      StreamBuilder(
                        stream: Stream.periodic(const Duration(seconds: 1)),
                        builder: (context, _) {
                          final now = DateTime.now();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(
                          "Controls",
                          Icons.tune_rounded,
                          !_showNotifications,
                          badgeCount: 0,
                        ),
                        const SizedBox(width: 8),
                        _buildTabButton(
                          "Notifs",
                          Icons.notifications_rounded,
                          _showNotifications,
                          badgeCount: _realNotifications.length,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // زر اختبار الصوت
              
              // Content Area
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _showNotifications
                      ? _buildNotificationsView()
                      : _buildControlsView(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(
    String label,
    IconData icon,
    bool isActive, {
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: () => setState(() => _showNotifications = label == "Notifs"),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.teal.withOpacity(0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Icon with optional badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive ? Colors.tealAccent : Colors.white54,
                ),
                if (badgeCount > 0) ...[
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Controls View ---
  Widget _buildControlsView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildToggleTile(
                icon: Icons.wifi_rounded,
                label: "Wi-Fi",
                status: _wifiStatus,
                isActive: _isWifiEnabled,
                onTap: () => _toggleWifi(!_isWifiEnabled),
                onLongPress: () => showWiFiManager(context),
                activeColor: Colors.tealAccent,
              ),
              const SizedBox(width: 12),
              _buildToggleTile(
                icon: Icons.lan_rounded,
                label: "Ethernet",
                status: _isNetworkingEnabled ? "On" : "Off",
                isActive: _isNetworkingEnabled,
                onTap: () => _toggleNetworking(!_isNetworkingEnabled),
                activeColor: Colors.orangeAccent,
              ),
              const SizedBox(width: 12),
              _buildToggleTile(
                label: "Bluetooth",
                status: _isBluetoothEnabled ? "On" : "Off",
                isActive: _isBluetoothEnabled,
                onTap: () => _toggleBluetooth(!_isBluetoothEnabled),
                onLongPress: () => showBluetoothManager(context),
                activeColor: Colors.blueAccent,
                icon: Icons.bluetooth_rounded,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            "Performance",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.fromARGB(12, 255, 255, 255), Color.fromARGB(10, 255, 255, 255)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildProfileBtn(
                  "Saver",
                  Icons.eco_rounded,
                  "power-saver",
                  Colors.greenAccent,
                ),
                _buildProfileBtn(
                  "Balanced",
                  Icons.balance_rounded,
                  "balanced",
                  Colors.blueAccent,
                ),
                _buildProfileBtn(
                  "Boost",
                  Icons.speed_rounded,
                  "performance",
                  Colors.redAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSliderTile(
            Icons.wb_sunny_rounded,
            _currentBrightness,
            _setBrightness,
            Colors.orangeAccent,
          ),
          const SizedBox(height: 16),
          _buildSliderTile(
            Icons.volume_up_rounded,
            _currentVolume,
            _setVolume,
            Colors.tealAccent,
          ),
          const SizedBox(height: 24),
          _buildBatteryTile(),
          const SizedBox(height: 32),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPowerButton(
                Icons.power_settings_new_rounded,
                Colors.redAccent,
                () => _powerAction('shutdown'),
              ),
              _buildPowerButton(
                Icons.restart_alt_rounded,
                Colors.orangeAccent,
                () => _powerAction('reboot'),
              ),
              _buildPowerButton(
                Icons.bedtime_rounded,
                Colors.blueAccent,
                () => _powerAction('suspend'),
              ),
              _buildPowerButton(
                Icons.logout_rounded,
                Colors.grey,
                () => _powerAction('logout'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Notifications View ---
  Widget _buildNotificationsView() {
    if (_realNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(-0.05)
                ..rotateY(0.04),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.fromARGB(40, 255, 255, 255), Color.fromARGB(8, 255, 255, 255)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.04),
                      blurRadius: 2,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_off_rounded,
                  size: 46,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No New Notifications",
              style: TextStyle(
                // ignore: deprecated_member_use
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
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateX(-0.03),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.transparent,
                ),
                onPressed: () => setState(() => _realNotifications.clear()),
                icon: const Icon(
                  Icons.clear_all_rounded,
                  size: 16,
                ),
                label: const Text(
                  "Clear All",
                ),
              ),
            ),
          ),
        ),
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
                onDismissed: (_) =>
                    setState(() => _realNotifications.removeAt(index)),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(-0.03)
                    ..rotateY(0.02),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color.fromARGB(30, 255, 255, 255), Color.fromARGB(6, 255, 255, 255)],
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.02)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 10),
                        ),
                      ],
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
                          Text(
                            notif.appName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            timeStr,
                            style: TextStyle(
                              // ignore: deprecated_member_use
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
                        const SizedBox(height: 4),
                        Text(
                          notif.body,
                          style: TextStyle(
                            // ignore: deprecated_member_use
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ), ),
              );
            },
          ),
        ),
      ],
    );
  }

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
            color: isActive ? color.withOpacity(0.14) : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isActive ? color.withOpacity(0.35) : Colors.transparent),
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
                            colors: [color.withOpacity(0.28), color.withOpacity(0.06)],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color.fromARGB(36, 255, 255, 255), Color.fromARGB(8, 255, 255, 255)],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isActive ? 0.22 : 0.08),
                        blurRadius: isActive ? 14 : 6,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 18, color: isActive ? Colors.white : Colors.white54),
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
            color: isActive ? activeColor.withOpacity(0.18) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? activeColor.withOpacity(0.45) : Colors.transparent,
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
                colors: [activeColor.withOpacity(0.2), activeColor.withOpacity(0.05)],
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
}

void showBluetoothManager(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const BluetoothManagerDialog(),
  );
}

void showWiFiManager(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const WiFiManagerDialog(),
  );
}
