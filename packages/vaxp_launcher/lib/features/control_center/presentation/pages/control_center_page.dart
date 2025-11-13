import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glassmorphism/glassmorphism.dart';

import 'package:vaxp_launcher/features/control_center/application/control_center_cubit.dart';
import 'package:vaxp_launcher/features/control_center/application/control_center_state.dart';
import 'package:vaxp_launcher/features/control_center/presentation/widgets/network_service.dart';
import 'package:vaxp_launcher/features/control_center/presentation/widgets/notifications_service.dart';
import 'package:vaxp_launcher/features/control_center/presentation/widgets/power_actions_service.dart';
import 'package:vaxp_launcher/features/control_center/presentation/widgets/power_profiles_service.dart';
import 'package:vaxp_launcher/features/control_center/presentation/widgets/sliders_service.dart';

class ControlCenterPage extends StatelessWidget {
  const ControlCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ControlCenterCubit(),
      child: const _ControlCenterView(),
    );
  }
}

class _ControlCenterView extends StatelessWidget {
  const _ControlCenterView();

  static const double _headerWidth = 70.0;
  static const double _gap = 8.0;
  static const double _dividerWidth = 8.0;
  static const double _networkWidth = 100.0;
  static const double _profilesWidth = 200.0;
  static const double _slidersWidth = 200.0;
  static const double _rightWidth = 170.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(0, 0, 0, 0),
      body: GlassmorphicContainer(
        width: double.infinity,
        height: 200,
        borderRadius: 20,
        linearGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(0, 0, 0, 0),
            Color.fromARGB(0, 0, 0, 0),
          ],
        ),
        border: 1.2,
        blur: 26,
        borderGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [],
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 800,
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
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
            child: BlocBuilder<ControlCenterCubit, ControlCenterState>(
              builder: (context, state) {
                final cubit = context.read<ControlCenterCubit>();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: _headerWidth,
                      child: NotificationServicePanel(
                        notifications: state.notifications,
                        onPressed: () => showNotificationsDialog(context),
                      ),
                    ),
                    const VerticalDivider(
                      width: _dividerWidth,
                      color: Colors.transparent,
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 180,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: _networkWidth,
                                child: NetworkServicePanel(
                                  isWifiEnabled: state.isWifiEnabled,
                                  isNetworkingEnabled: state.isNetworkingEnabled,
                                  isBluetoothEnabled: state.isBluetoothEnabled,
                                  onWifiToggle: cubit.toggleWifi,
                                  onNetworkingToggle: cubit.toggleNetworking,
                                  onBluetoothToggle: cubit.toggleBluetooth,
                                  onOpenWifiManager: () => showWiFiManager(context),
                                  onOpenBluetoothManager: () =>
                                      showBluetoothManager(context),
                                ),
                              ),
                              SizedBox(width: _gap),
                              SizedBox(
                                width: _profilesWidth,
                                child: PowerProfilesServicePanel(
                                  batteryLevel: state.batteryLevel,
                                  isCharging: state.isCharging,
                                  activePowerProfile: state.activePowerProfile,
                                  onSelectProfile: cubit.setPowerProfile,
                                ),
                              ),
                              SizedBox(width: _gap),
                              SizedBox(
                                width: _slidersWidth,
                                child: SlidersServicePanel(
                                  brightness: state.currentBrightness,
                                  volume: state.currentVolume,
                                  onBrightnessChanged: cubit.setBrightness,
                                  onVolumeChanged: cubit.setVolume,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const VerticalDivider(
                      width: _dividerWidth,
                      color: Colors.transparent,
                    ),
                    SizedBox(
                      width: _rightWidth,
                      child: Center(
                        child: PowerActionsServicePanel(
                          onShutdown: () => cubit.powerAction('shutdown'),
                          onReboot: () => cubit.powerAction('reboot'),
                          onSuspend: () => cubit.powerAction('suspend'),
                          onLogout: () => cubit.powerAction('logout'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

