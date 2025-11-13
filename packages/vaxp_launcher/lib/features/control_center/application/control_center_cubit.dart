import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vaxp_launcher/con/widgets/notification_service.dart';

import 'control_center_state.dart';

class ControlCenterCubit extends Cubit<ControlCenterState> {
  ControlCenterCubit() : super(ControlCenterState.initial()) {
    unawaited(_init());
  }

  final DBusClient _sysbus = DBusClient.system();
  Timer? _updateTimer;
  StreamSubscription<VenomNotification>? _notifSub;

  Future<void> _init() async {
    await refreshAllStates();
    await _startNotificationServer();
    _updateTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => refreshAllStates(),
    );
  }

  Future<void> refreshAllStates() async {
    await Future.wait([
      _getBatteryInfo(),
      _getNetworkInfo(),
      _getBluetoothInfo(),
      _getPowerProfile(),
      _getVolumeAndBrightness(),
    ]);
  }

  Future<void> _startNotificationServer() async {
    try {
      final server = await startNotificationServer();
      _notifSub = server.onNotification.listen((notif) async {
        addNotification(notif);
        try {
          final player = AudioPlayer();
          final filePath =
              '${Directory.current.path}/assets/Sound/notification.mp3';
          await player.play(UrlSource('file://$filePath'));
        } catch (e) {
          debugPrint('Failed to play notification sound: $e');
        }
      });
    } catch (e) {
      debugPrint('Notification Server Error: $e');
    }
  }

  Future<void> _getNetworkInfo() async {
    try {
      final nm = DBusRemoteObject(
        _sysbus,
        name: 'org.freedesktop.NetworkManager',
        path: DBusObjectPath('/org/freedesktop/NetworkManager'),
      );

      final netEnabled =
          await nm.getProperty('org.freedesktop.NetworkManager', 'NetworkingEnabled')
              as DBusBoolean;
      final wifiEnabled =
          await nm.getProperty('org.freedesktop.NetworkManager', 'WirelessEnabled')
              as DBusBoolean;
      final connectivity =
          (await nm.callMethod(
            'org.freedesktop.NetworkManager',
            'CheckConnectivity',
            [],
            replySignature: DBusSignature('u'),
          ))
              .returnValues[0] as DBusUint32;

      final wifiStatus = wifiEnabled.value
          ? (connectivity.value == 4 ? 'Connected' : 'On')
          : 'Off';

      emit(
        state.copyWith(
          isNetworkingEnabled: netEnabled.value,
          isWifiEnabled: wifiEnabled.value,
          wifiStatus: wifiStatus,
        ),
      );
    } catch (_) {
      // Ignore errors and keep previous state.
    }
  }

  Future<void> _getBluetoothInfo() async {
    try {
      final adapter = DBusRemoteObject(
        _sysbus,
        name: 'org.bluez',
        path: DBusObjectPath('/org/bluez/hci0'),
      );
      final powered =
          await adapter.getProperty('org.bluez.Adapter1', 'Powered') as DBusBoolean;
      emit(state.copyWith(isBluetoothEnabled: powered.value));
    } catch (_) {
      emit(state.copyWith(isBluetoothEnabled: false));
    }
  }

  Future<void> _getBatteryInfo() async {
    try {
      final device = DBusRemoteObject(
        _sysbus,
        name: 'org.freedesktop.UPower',
        path: DBusObjectPath('/org/freedesktop/UPower/devices/DisplayDevice'),
      );
      final percent = await device.getProperty(
        'org.freedesktop.UPower.Device',
        'Percentage',
      ) as DBusDouble;
      final stateValue = await device.getProperty(
        'org.freedesktop.UPower.Device',
        'State',
      ) as DBusUint32;

      emit(
        state.copyWith(
          batteryLevel: percent.value,
          isCharging: stateValue.value == 1,
        ),
      );
    } catch (_) {
      // Ignore errors.
    }
  }

  Future<void> _getPowerProfile() async {
    try {
      final ppd = DBusRemoteObject(
        _sysbus,
        name: 'org.freedesktop.UPower.PowerProfiles',
        path: DBusObjectPath('/org/freedesktop/UPower/PowerProfiles'),
      );
      final active = await ppd.getProperty(
        'org.freedesktop.UPower.PowerProfiles',
        'ActiveProfile',
      ) as DBusString;
      emit(state.copyWith(activePowerProfile: active.value));
    } catch (_) {
      // Ignore errors.
    }
  }

  Future<void> _getVolumeAndBrightness() async {
    try {
      final volResult = await Process.run('sh', [
        '-c',
        "pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\\d+%' | head -1 | tr -d '%'",
      ]);
      double? volume;
      if (volResult.exitCode == 0) {
        volume = double.tryParse(volResult.stdout.toString().trim());
      }

      final currentBrightness = await Process.run('brightnessctl', ['g']);
      final maxBrightness = await Process.run('brightnessctl', ['m']);
      double? brightness;
      if (currentBrightness.exitCode == 0 && maxBrightness.exitCode == 0) {
        final cur = double.tryParse(currentBrightness.stdout.toString().trim());
        final max = double.tryParse(maxBrightness.stdout.toString().trim());
        if (cur != null && max != null && max > 0) {
          brightness = (cur / max) * 100;
        }
      }

      emit(
        state.copyWith(
          currentVolume: volume ?? state.currentVolume,
          currentBrightness: brightness ?? state.currentBrightness,
        ),
      );
    } catch (_) {
      // Ignore errors.
    }
  }

  Future<void> toggleWifi(bool enable) async {
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
      emit(state.copyWith(isWifiEnabled: enable));
      await _getNetworkInfo();
    } catch (_) {
      // Ignore errors.
    }
  }

  Future<void> toggleNetworking(bool enable) async {
    await Process.run('nmcli', ['networking', enable ? 'on' : 'off']);
    emit(state.copyWith(isNetworkingEnabled: enable));
    await _getNetworkInfo();
  }

  Future<void> toggleBluetooth(bool enable) async {
    try {
      await Process.run('rfkill', [enable ? 'unblock' : 'block', 'bluetooth']);
      emit(state.copyWith(isBluetoothEnabled: enable));
      await _getBluetoothInfo();
    } catch (_) {
      // Ignore errors.
    }
  }

  Future<void> setPowerProfile(String profile) async {
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
      emit(state.copyWith(activePowerProfile: profile));
      await _getPowerProfile();
    } catch (_) {
      // Ignore errors.
    }
  }

  Future<void> setVolume(double value) async {
    emit(state.copyWith(currentVolume: value));
    await Process.run(
      'pactl',
      ['set-sink-volume', '@DEFAULT_SINK@', '${value.toInt()}%'],
    );
  }

  Future<void> setBrightness(double value) async {
    emit(state.copyWith(currentBrightness: value));
    await Process.run('brightnessctl', ['s', '${value.toInt()}%']);
  }

  Future<void> powerAction(String action) async {
    switch (action) {
      case 'shutdown':
        await Process.run('systemctl', ['poweroff']);
        break;
      case 'reboot':
        await Process.run('systemctl', ['reboot']);
        break;
      case 'suspend':
        await Process.run('systemctl', ['suspend']);
        break;
      case 'logout':
        final user = Platform.environment['USER'];
        if (user != null) {
          await Process.run('loginctl', ['terminate-user', user]);
        }
        break;
    }
  }

  void addNotification(VenomNotification notification) {
    final updated = [
      notification,
      ...state.notifications,
    ];
    emit(state.copyWith(notifications: updated));
  }

  void clearNotifications() {
    if (state.notifications.isEmpty) return;
    emit(state.copyWith(notifications: const []));
  }

  void removeNotification(int id) {
    final updated =
        state.notifications.where((notif) => notif.id != id).toList(growable: false);
    emit(state.copyWith(notifications: updated));
  }

  @override
  Future<void> close() async {
    await _notifSub?.cancel();
    _updateTimer?.cancel();
    await _sysbus.close();
    return super.close();
  }
}

