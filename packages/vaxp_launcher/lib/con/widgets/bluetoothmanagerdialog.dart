import 'dart:async' ;
import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';

class BluetoothManagerDialog extends StatefulWidget {
  const BluetoothManagerDialog({super.key});

  @override
  State<BluetoothManagerDialog> createState() => _BluetoothManagerDialogState();
}

class _BluetoothManagerDialogState extends State<BluetoothManagerDialog> {
  late DBusClient _sysbus;
  bool _isScanning = false;
  bool _isInitializing = true;
  String? _adapterPath;
  List<Map<String, dynamic>> _devices = [];
  Timer? _scanTimer;
  final List<StreamSubscription> _bluezSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _sysbus = DBusClient.system();
    _initBluetooth();
  }

  @override
  void dispose() {
    _stopScan();
    for (final s in _bluezSubscriptions) {
      s.cancel();
    }
    _sysbus.close();
    super.dispose();
  }

  // ====== تهيئة البلوتوث ======
  Future<void> _initBluetooth() async {
    if (!mounted) return;
    setState(() => _isInitializing = true);
    try {
      await _findAdapter();
      if (_adapterPath != null) {
        await _ensureAdapterPowered();
        _listenBluezSignals();
        await _startScan();
      }
    } catch (e) {
      debugPrint("Bluetooth Init Error: $e");
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _findAdapter() async {
    try {
      final root = DBusRemoteObject(
        _sysbus,
        name: 'org.bluez',
        path: DBusObjectPath.root,
      );
      final resp = await root.callMethod(
        'org.freedesktop.DBus.ObjectManager',
        'GetManagedObjects',
        [],
      );
      final returned = resp.returnValues.first as DBusDict;

      for (final entry in returned.children.entries) {
        final path = entry.key as DBusObjectPath;
        final interfaces = entry.value as DBusDict;
        if (interfaces.children.containsKey(DBusString('org.bluez.Adapter1'))) {
          _adapterPath = path.value;
          return;
        }
      }
    } catch (e) {
      debugPrint("Find Adapter Error: $e");
    }
  }

  Future<void> _ensureAdapterPowered() async {
    if (_adapterPath == null) return;
    try {
      final adapter = DBusRemoteObject(
        _sysbus,
        name: 'org.bluez',
        path: DBusObjectPath(_adapterPath!),
      );
      var poweredVal = await adapter.getProperty(
        'org.bluez.Adapter1',
        'Powered',
      );

      bool isPowered = false;
      if (poweredVal is DBusVariant) {
        isPowered = (poweredVal.value as DBusBoolean).value;
      } else if (poweredVal is DBusBoolean) {
        isPowered = poweredVal.value;
      }

      if (!isPowered) {
        await adapter.setProperty(
          'org.bluez.Adapter1',
          'Powered',
          DBusBoolean(true),
        );
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      debugPrint("Power On Error: $e");
    }
  }

  // ====== عمليات الفحص ======
  Future<void> _startScan() async {
    if (!mounted) return;
    if (_adapterPath == null || _isScanning) return;

    if (mounted) setState(() => _isScanning = true);
    try {
      final adapter = DBusRemoteObject(
        _sysbus,
        name: 'org.bluez',
        path: DBusObjectPath(_adapterPath!),
      );
      await adapter.callMethod('org.bluez.Adapter1', 'StartDiscovery', []);

      _fetchDevices();
      _scanTimer?.cancel();
      _scanTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _fetchDevices(),
      );
    } catch (e) {
      if (!e.toString().contains('InProgress')) {
        debugPrint("Start Scan Error: $e");
        if (mounted) setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _stopScan() async {
    _scanTimer?.cancel();
    if (_adapterPath != null) {
      try {
        final adapter = DBusRemoteObject(
          _sysbus,
          name: 'org.bluez',
          path: DBusObjectPath(_adapterPath!),
        );
        await adapter.callMethod('org.bluez.Adapter1', 'StopDiscovery', []);
      } catch (_) {}
    }
    if (mounted) setState(() => _isScanning = false);
  }

  // ====== جلب الأجهزة (مصحح) ======
  Future<void> _fetchDevices() async {
    if (!mounted) return;
    try {
      final root = DBusRemoteObject(
        _sysbus,
        name: 'org.bluez',
        path: DBusObjectPath.root,
      );
      final resp = await root.callMethod(
        'org.freedesktop.DBus.ObjectManager',
        'GetManagedObjects',
        [],
      );
      final returned = resp.returnValues.first as DBusDict;

      final List<Map<String, dynamic>> newDevices = [];

      // helper to unwrap a DBusValue -> DBusX and return the typed value
      // ignore: no_leading_underscores_for_local_identifiers
      DBusValue? _unwrap(DBusValue? v) {
        if (v == null) return null;
        if (v is DBusVariant) return v.value;
        return v;
      }

      for (final entry in returned.children.entries) {
        final key = entry.key;
        final value = entry.value;

        if (key is! DBusObjectPath || value is! DBusDict) continue;
        final pathStr = key.value;
        final interfaces = value;

        final deviceIface =
            interfaces.children[DBusString('org.bluez.Device1')];
        if (deviceIface == null || deviceIface is! DBusDict) continue;

        final props = deviceIface.children;

        String name = 'Unknown Device';
        final aliasV = _unwrap(props[DBusString('Alias')]);
        final nameV = _unwrap(props[DBusString('Name')]);
        if (aliasV is DBusString) {
          name = aliasV.value;
        } else if (nameV is DBusString)
          // ignore: curly_braces_in_flow_control_structures
          name = nameV.value;

        String address = '??:??:??:??:??:??';
        final addrV = _unwrap(props[DBusString('Address')]);
        if (addrV is DBusString) address = addrV.value;

        bool connected = false;
        final connV = _unwrap(props[DBusString('Connected')]);
        if (connV is DBusBoolean) connected = connV.value;

        bool paired = false;
        final pairV = _unwrap(props[DBusString('Paired')]);
        if (pairV is DBusBoolean) paired = pairV.value;

        int rssi = -100;
        final rssiV = _unwrap(props[DBusString('RSSI')]);
        if (rssiV is DBusInt16) rssi = rssiV.value;

        newDevices.add({
          'path': pathStr,
          'name': name,
          'address': address,
          'connected': connected,
          'paired': paired,
          'rssi': rssi,
        });
      }

      // sort: connected first, then paired, then by RSSI
      newDevices.sort((a, b) {
        if (a['connected'] != b['connected']) return a['connected'] ? -1 : 1;
        if (a['paired'] != b['paired']) return a['paired'] ? -1 : 1;
        return (b['rssi'] as int).compareTo(a['rssi'] as int);
      });

      if (mounted) setState(() => _devices = newDevices);
    } catch (e, st) {
      debugPrint('Fetch Devices Error: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _listenBluezSignals() {
    _bluezSubscriptions.add(
      DBusSignalStream(
        _sysbus,
        interface: 'org.freedesktop.DBus.Properties',
        name: 'PropertiesChanged',
      ).listen((signal) {
        if (signal.path.value.contains('bluez')) _fetchDevices();
      }),
    );
    _bluezSubscriptions.add(
      DBusSignalStream(
        _sysbus,
        interface: 'org.freedesktop.DBus.ObjectManager',
        name: 'InterfacesAdded',
      ).listen((_) => _fetchDevices()),
    );
    _bluezSubscriptions.add(
      DBusSignalStream(
        _sysbus,
        interface: 'org.freedesktop.DBus.ObjectManager',
        name: 'InterfacesRemoved',
      ).listen((_) => _fetchDevices()),
    );
  }

  Future<void> _connectDevice(String path) async {
    try {
      if (_isScanning) await _stopScan();
      final device = DBusRemoteObject(
        _sysbus,
        name: 'org.bluez',
        path: DBusObjectPath(path),
      );
      await device.callMethod('org.bluez.Device1', 'Connect', []);
      _startScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: ${e.toString().split(']').last.trim()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _startScan();
    }
  }

  Future<void> _disconnectDevice(String path) async {
    try {
      final device = DBusRemoteObject(
        _sysbus,
        name: 'org.bluez',
        path: DBusObjectPath(path),
      );
      await device.callMethod('org.bluez.Device1', 'Disconnect', []);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color.fromARGB(172, 0, 0, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bluetooth_audio_rounded,
                  color: Colors.blueAccent,
                  size: 32,
                ),
                const SizedBox(width: 16),
                const Text(
                  "Bluetooth Manager",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_adapterPath == null && !_isInitializing)
                  const Tooltip(
                    message: "No Adapter",
                    child: Icon(Icons.error_outline, color: Colors.redAccent),
                  ),
                IconButton(
                  onPressed: (_isInitializing || _adapterPath == null)
                      ? null
                      : (_isScanning ? _stopScan : _startScan),
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.blueAccent,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white70,
                        ),
                  tooltip: _isScanning ? "Stop Scanning" : "Start Scanning",
                ),
              ],
            ),
            const Divider(color: Color.fromARGB(78, 255, 255, 255), height: 30),
            Expanded(
              child: _isInitializing
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                      ),
                    )
                  : _devices.isEmpty
                  ? Center(
                      child: Text(
                        "No devices found",
                        // ignore: deprecated_member_use
                        style: TextStyle(color: Colors.white.withOpacity(0.3)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final dev = _devices[index];
                        final isConnected = dev['connected'] as bool;
                        final isPaired = dev['paired'] as bool;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isConnected
                                // ignore: deprecated_member_use
                                ? Colors.blueAccent.withOpacity(0.15)
                                // ignore: deprecated_member_use
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Icon(
                              isConnected
                                  ? Icons.bluetooth_connected
                                  : Icons.bluetooth,
                              color: isConnected
                                  ? Colors.blue
                                  : (isPaired ? Colors.white : Colors.white54),
                            ),
                            title: Text(
                              dev['name'],
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isConnected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              "${dev['address']} ${dev['rssi'] > -100 ? '(${dev['rssi']} dBm)' : ''}",
                              style: TextStyle(
                                // ignore: deprecated_member_use
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                            trailing: isConnected
                                ? TextButton(
                                    onPressed: () =>
                                        _disconnectDevice(dev['path']),
                                    child: const Text(
                                      "Disconnect",
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  )
                                : OutlinedButton(
                                    onPressed: () =>
                                        _connectDevice(dev['path']),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blueAccent,
                                      side: const BorderSide(
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                    child: Text(isPaired ? "Connect" : "Pair"),
                                  ),
                          ),
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
