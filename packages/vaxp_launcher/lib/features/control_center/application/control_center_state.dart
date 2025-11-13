import 'package:equatable/equatable.dart';
import 'package:vaxp_launcher/con/widgets/notification_service.dart';

class ControlCenterState extends Equatable {
  const ControlCenterState({
    required this.batteryLevel,
    required this.isCharging,
    required this.currentVolume,
    required this.currentBrightness,
    required this.isWifiEnabled,
    required this.isNetworkingEnabled,
    required this.wifiStatus,
    required this.isBluetoothEnabled,
    required this.activePowerProfile,
    required this.notifications,
  });

  factory ControlCenterState.initial() => const ControlCenterState(
        batteryLevel: 0,
        isCharging: false,
        currentVolume: 0,
        currentBrightness: 0,
        isWifiEnabled: false,
        isNetworkingEnabled: true,
        wifiStatus: 'Unknown',
        isBluetoothEnabled: false,
        activePowerProfile: 'balanced',
        notifications: [],
      );

  final double batteryLevel;
  final bool isCharging;
  final double currentVolume;
  final double currentBrightness;
  final bool isWifiEnabled;
  final bool isNetworkingEnabled;
  final String wifiStatus;
  final bool isBluetoothEnabled;
  final String activePowerProfile;
  final List<VenomNotification> notifications;

  ControlCenterState copyWith({
    double? batteryLevel,
    bool? isCharging,
    double? currentVolume,
    double? currentBrightness,
    bool? isWifiEnabled,
    bool? isNetworkingEnabled,
    String? wifiStatus,
    bool? isBluetoothEnabled,
    String? activePowerProfile,
    List<VenomNotification>? notifications,
  }) {
    return ControlCenterState(
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      currentVolume: currentVolume ?? this.currentVolume,
      currentBrightness: currentBrightness ?? this.currentBrightness,
      isWifiEnabled: isWifiEnabled ?? this.isWifiEnabled,
      isNetworkingEnabled: isNetworkingEnabled ?? this.isNetworkingEnabled,
      wifiStatus: wifiStatus ?? this.wifiStatus,
      isBluetoothEnabled: isBluetoothEnabled ?? this.isBluetoothEnabled,
      activePowerProfile: activePowerProfile ?? this.activePowerProfile,
      notifications: notifications ?? this.notifications,
    );
  }

  @override
  List<Object?> get props => [
        batteryLevel,
        isCharging,
        currentVolume,
        currentBrightness,
        isWifiEnabled,
        isNetworkingEnabled,
        wifiStatus,
        isBluetoothEnabled,
        activePowerProfile,
        notifications,
      ];
}

