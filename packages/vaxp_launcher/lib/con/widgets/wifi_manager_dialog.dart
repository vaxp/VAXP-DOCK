import 'package:flutter/material.dart';
import 'package:dbus/dbus.dart';
import 'package:uuid/uuid.dart';

class WiFiNetwork {
  final String ssid;
  final int strength;
  final bool isSecure;
  final bool isConnected;
  final bool isSaved;

  const WiFiNetwork({
    required this.ssid,
    required this.strength,
    required this.isSecure,
    this.isConnected = false,
    this.isSaved = false,
  });
}

class WiFiManagerDialog extends StatefulWidget {
  const WiFiManagerDialog({super.key});

  @override
  State<WiFiManagerDialog> createState() => _WiFiManagerDialogState();
}

class _WiFiManagerDialogState extends State<WiFiManagerDialog> {
  late DBusClient _bus;
  List<WiFiNetwork> _networks = [];
  bool _isScanning = false;
  bool _isLoading = true;
  String? _connectingTo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bus = DBusClient.system();
    _initNetworks();
  }

  @override
  void dispose() {
    _bus.close();
    super.dispose();
  }

  Future<void> _initNetworks() async {
    try {
      await _fetchNetworks();
      await _startScanning();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchNetworks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final nm = DBusRemoteObject(
        _bus,
        name: 'org.freedesktop.NetworkManager',
        path: DBusObjectPath('/org/freedesktop/NetworkManager'),
      );

      // Get all devices
      final devices = await nm.callMethod(
        'org.freedesktop.NetworkManager',
        'GetDevices',
        [],
        replySignature: DBusSignature('ao'),
      );

      final List<WiFiNetwork> networks = [];
      final devicePaths = (devices.values[0] as DBusArray).children;

      for (final devicePath in devicePaths) {
        final device = DBusRemoteObject(
          _bus,
          name: 'org.freedesktop.NetworkManager',
          path: DBusObjectPath((devicePath as DBusObjectPath).value),
        );

        // Check if it's a WiFi device
        final deviceType = await device.getProperty(
          'org.freedesktop.NetworkManager.Device',
          'DeviceType',
        );

        // DeviceType 2 is WiFi
        if ((deviceType as DBusUint32).value != 2) continue;

        // Get access points
        final aps = await device.callMethod(
          'org.freedesktop.NetworkManager.Device.Wireless',
          'GetAccessPoints',
          [],
          replySignature: DBusSignature('ao'),
        );

        final activeAp = await device.getProperty(
          'org.freedesktop.NetworkManager.Device.Wireless',
          'ActiveAccessPoint',
        );
        final activeApPath = (activeAp as DBusObjectPath).value;

        // Get saved connections
        final settings = DBusRemoteObject(
          _bus,
          name: 'org.freedesktop.NetworkManager',
          path: DBusObjectPath('/org/freedesktop/NetworkManager/Settings'),
        );

        final conns = await settings.callMethod(
          'org.freedesktop.NetworkManager.Settings',
          'ListConnections',
          [],
          replySignature: DBusSignature('ao'),
        );
        final savedConns = <String>{};

        for (final conn in (conns.values[0] as DBusArray).children) {
          final connObj = DBusRemoteObject(
            _bus,
            name: 'org.freedesktop.NetworkManager',
            path: DBusObjectPath((conn as DBusObjectPath).value),
          );

          final settingsMap = await connObj.callMethod(
            'org.freedesktop.NetworkManager.Settings.Connection',
            'GetSettings',
            [],
            replySignature: DBusSignature('a{sa{sv}}'),
          );

          final wirelessSettings =
              // ignore: collection_methods_unrelated_type
              (settingsMap.values[0] as DBusDict).children['802-11-wireless'];
          if (wirelessSettings != null) {
            final ssid =
                // ignore: collection_methods_unrelated_type
                ((wirelessSettings as DBusDict).children['ssid'] as DBusArray)
                    .children;
            final ssidStr = String.fromCharCodes(
              ssid.map((e) => (e as DBusByte).value),
            );
            savedConns.add(ssidStr);
          }
        }

        for (final ap in (aps.values[0] as DBusArray).children) {
          final apPath = (ap as DBusObjectPath).value;
          final apObj = DBusRemoteObject(
            _bus,
            name: 'org.freedesktop.NetworkManager',
            path: DBusObjectPath(apPath),
          );

          final ssidBytes = await apObj.getProperty(
            'org.freedesktop.NetworkManager.AccessPoint',
            'Ssid',
          );
          final strength = await apObj.getProperty(
            'org.freedesktop.NetworkManager.AccessPoint',
            'Strength',
          );
          final flags = await apObj.getProperty(
            'org.freedesktop.NetworkManager.AccessPoint',
            'Flags',
          );
          final wpaFlags = await apObj.getProperty(
            'org.freedesktop.NetworkManager.AccessPoint',
            'WpaFlags',
          );
          final rsnFlags = await apObj.getProperty(
            'org.freedesktop.NetworkManager.AccessPoint',
            'RsnFlags',
          );

          final ssid = String.fromCharCodes(
            (ssidBytes as DBusArray).children.map((e) => (e as DBusByte).value),
          );

          // Skip hidden networks
          if (ssid.isEmpty) continue;

          final isSecure =
              (flags as DBusUint32).value > 0 ||
              (wpaFlags as DBusUint32).value > 0 ||
              (rsnFlags as DBusUint32).value > 0;

          networks.add(
            WiFiNetwork(
              ssid: ssid,
              strength: (strength as DBusByte).value,
              isSecure: isSecure,
              isConnected: apPath == activeApPath,
              isSaved: savedConns.contains(ssid),
            ),
          );
        }
      }

      // Sort networks: Connected > Saved > Signal Strength
      networks.sort((a, b) {
        if (a.isConnected != b.isConnected) {
          return a.isConnected ? -1 : 1;
        }
        if (a.isSaved != b.isSaved) {
          return a.isSaved ? -1 : 1;
        }
        return b.strength.compareTo(a.strength);
      });

      if (mounted) {
        setState(() {
          _networks = networks;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to fetch networks: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startScanning() async {
    try {
      if (_isScanning) return;
      setState(() => _isScanning = true);

      final nm = DBusRemoteObject(
        _bus,
        name: 'org.freedesktop.NetworkManager',
        path: DBusObjectPath('/org/freedesktop/NetworkManager'),
      );

      final devices = await nm.callMethod(
        'org.freedesktop.NetworkManager',
        'GetDevices',
        [],
        replySignature: DBusSignature('ao'),
      );

      for (final devicePath in (devices.values[0] as DBusArray).children) {
        final device = DBusRemoteObject(
          _bus,
          name: 'org.freedesktop.NetworkManager',
          path: DBusObjectPath((devicePath as DBusObjectPath).value),
        );

        final deviceType = await device.getProperty(
          'org.freedesktop.NetworkManager.Device',
          'DeviceType',
        );

        if ((deviceType as DBusUint32).value == 2) {
          await device.callMethod(
            'org.freedesktop.NetworkManager.Device.Wireless',
            'RequestScan',
            [DBusDict.stringVariant({})],
          );
        }
      }

      // Refresh after a short delay to allow scan to complete
      await Future.delayed(const Duration(seconds: 2));
      await _fetchNetworks();
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToNetwork(WiFiNetwork network) async {
    if (_connectingTo != null) return;
    setState(() {
      _connectingTo = network.ssid;
      _error = null;
    });

    try {
      final nm = DBusRemoteObject(
        _bus,
        name: 'org.freedesktop.NetworkManager',
        path: DBusObjectPath('/org/freedesktop/NetworkManager'),
      );

      if (!network.isSaved) {
        // Show password dialog for secure networks
        if (network.isSecure) {
          final password = await _showPasswordDialog();
          if (password == null) {
            setState(() => _connectingTo = null);
            return;
          }

          // Create new connection
          final conn = {
            'connection': {
              'type': const DBusString('802-11-wireless'),
              'id': DBusString(network.ssid),
              'uuid': DBusString(const Uuid().v4()),
              'autoconnect': const DBusBoolean(true),
            },
            '802-11-wireless': {
              'ssid': DBusArray.byte(network.ssid.codeUnits),
              'mode': const DBusString('infrastructure'),
              'security': const DBusString('802-11-wireless-security'),
            },
            '802-11-wireless-security': {
              'key-mgmt': const DBusString('wpa-psk'),
              'auth-alg': const DBusString('open'),
              'psk': DBusString(password),
            },
            'ipv4': {
              'method': const DBusString('auto'),
            },
            'ipv6': {
              'method': const DBusString('auto'),
            },
          };

          // Get the Settings object first
          final nmSettings = DBusRemoteObject(
            _bus,
            name: 'org.freedesktop.NetworkManager',
            path: DBusObjectPath('/org/freedesktop/NetworkManager/Settings'),
          );

          final connectionData = DBusDict(
            DBusSignature('s'),
            DBusSignature('a{sv}'),
            conn.map((key, value) => MapEntry(
              DBusString(key),
              DBusDict(
                DBusSignature('s'),
                DBusSignature('v'),
                value.map(
                  (k, v) => MapEntry(DBusString(k), DBusVariant(v)),
                ),
              ),
            )),
          );

          await nmSettings.callMethod(
            'org.freedesktop.NetworkManager.Settings',
            'AddConnection',
            [connectionData],
            replySignature: DBusSignature('o'),
          );
        }
      }

      // Get all connections through Settings interface
      final settings = DBusRemoteObject(
        _bus,
        name: 'org.freedesktop.NetworkManager',
        path: DBusObjectPath('/org/freedesktop/NetworkManager/Settings'),
      );
      
      final conns = await settings.callMethod(
        'org.freedesktop.NetworkManager.Settings',
        'ListConnections',
        [],
        replySignature: DBusSignature('ao'),
      );

      // Find matching connection
      String? connPath;
      for (final conn in (conns.values[0] as DBusArray).children) {
        final settings = DBusRemoteObject(
          _bus,
          name: 'org.freedesktop.NetworkManager',
          path: DBusObjectPath((conn as DBusObjectPath).value),
        );

        final settingsMap = await settings.callMethod(
          'org.freedesktop.NetworkManager.Settings.Connection',
          'GetSettings',
          [],
          replySignature: DBusSignature('a{sa{sv}}'),
        );

        final wirelessSettings =
            // ignore: collection_methods_unrelated_type
            (settingsMap.values[0] as DBusDict).children['802-11-wireless'];
        if (wirelessSettings != null) {
          final ssid =
              // ignore: collection_methods_unrelated_type
              ((wirelessSettings as DBusDict).children['ssid'] as DBusArray)
                  .children;
          final ssidStr = String.fromCharCodes(
            ssid.map((e) => (e as DBusByte).value),
          );
          if (ssidStr == network.ssid) {
            connPath = conn.value;
            break;
          }
        }
      }

      if (connPath != null) {
        // Activate the connection
        await nm.callMethod(
          'org.freedesktop.NetworkManager',
          'ActivateConnection',
          [DBusObjectPath(connPath), DBusObjectPath('/'), DBusObjectPath('/')],
          replySignature: DBusSignature('o'),
        );

        await _fetchNetworks();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to connect: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _connectingTo = null);
      }
    }
  }

  Future<void> _forgetNetwork(WiFiNetwork network) async {
    try {
      final nm = DBusRemoteObject(
        _bus,
        name: 'org.freedesktop.NetworkManager',
        path: DBusObjectPath('/org/freedesktop/NetworkManager'),
      );

      final conns = await nm.callMethod(
        'org.freedesktop.NetworkManager',
        'GetConnections',
        [],
        replySignature: DBusSignature('ao'),
      );

      for (final conn in (conns.values[0] as DBusArray).children) {
        final settings = DBusRemoteObject(
          _bus,
          name: 'org.freedesktop.NetworkManager',
          path: DBusObjectPath((conn as DBusObjectPath).value),
        );

        final settingsMap = await settings.callMethod(
          'org.freedesktop.NetworkManager.Settings.Connection',
          'GetSettings',
          [],
          replySignature: DBusSignature('a{sa{sv}}'),
        );

        final wirelessSettings =
            // ignore: collection_methods_unrelated_type
            (settingsMap.values[0] as DBusDict).children['802-11-wireless'];
        if (wirelessSettings != null) {
          final ssid =
              // ignore: collection_methods_unrelated_type
              ((wirelessSettings as DBusDict).children['ssid'] as DBusArray)
                  .children;
          final ssidStr = String.fromCharCodes(
            ssid.map((e) => (e as DBusByte).value),
          );
          if (ssidStr == network.ssid) {
            await settings.callMethod(
              'org.freedesktop.NetworkManager.Settings.Connection',
              'Delete',
              [],
            );
            break;
          }
        }
      }

      await _fetchNetworks();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to forget network: $e');
      }
    }
  }

  Future<String?> _showPasswordDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) {
        String? password;
        bool obscureText = true;

        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 45, 45, 45),
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Enter Password',
            style: TextStyle(color: Colors.white),
          ),
          content: StatefulBuilder(
            builder: (context, setState) => TextField(
              onChanged: (value) => password = value,
              obscureText: obscureText,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Network Password',
                hintStyle: const TextStyle(color: Colors.white54),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white54,
                  ),
                  onPressed: () => setState(() => obscureText = !obscureText),
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.tealAccent),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, password),
              child: const Text(
                'Connect',
                style: TextStyle(color: Colors.tealAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color.fromARGB(255, 35, 35, 35),
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Wi-Fi Networks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_isScanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.tealAccent),
                    ),
                  )
                else
                  IconButton(
                    onPressed: _startScanning,
                    icon: const Icon(Icons.refresh_rounded),
                    color: Colors.white54,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  // ignore: deprecated_member_use
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red.shade300,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.tealAccent),
                  ),
                ),
              )
            else if (_networks.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.wifi_find_rounded,
                        size: 48,
                        // ignore: deprecated_member_use
                        color: Colors.white.withOpacity(0.1),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No networks found',
                        style: TextStyle(
                          // ignore: deprecated_member_use
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _networks.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final network = _networks[index];
                    final isConnecting = _connectingTo == network.ssid;

                    return ListTile(
                      onTap: isConnecting
                          ? null
                          : () => _connectToNetwork(network),
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        network.strength > 80
                            ? Icons.wifi_rounded
                            : network.strength > 60
                            ? Icons.network_wifi_3_bar_rounded
                            : network.strength > 40
                            ? Icons.network_wifi_2_bar_rounded
                            : Icons.network_wifi_1_bar_rounded,
                        color: network.isConnected
                            ? Colors.tealAccent
                            : Colors.white54,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              network.ssid,
                              style: TextStyle(
                                color: network.isConnected
                                    ? Colors.white
                                    : Colors.white70,
                                fontWeight: network.isConnected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (network.isSecure)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.lock_rounded,
                                size: 16,
                                // ignore: deprecated_member_use
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        network.isConnected
                            ? 'Connected'
                            : network.isSaved
                            ? 'Saved'
                            : '${network.strength}% signal',
                        style: TextStyle(
                          color: network.isConnected
                              ? Colors.tealAccent
                              : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      trailing: isConnecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.tealAccent,
                                ),
                              ),
                            )
                          : network.isSaved
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              color: Colors.white38,
                              onPressed: () => _forgetNetwork(network),
                            )
                          : null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
