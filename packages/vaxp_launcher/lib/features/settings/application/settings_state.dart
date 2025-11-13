import 'package:equatable/equatable.dart';
import 'package:vaxp_launcher/features/settings/domain/models/launcher_settings.dart';

class SettingsState extends Equatable {
  const SettingsState({
    required this.settings,
    this.isLoading = false,
    this.error,
  });

  final LauncherSettings settings;
  final bool isLoading;
  final String? error;

  SettingsState copyWith({
    LauncherSettings? settings,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [settings, isLoading, error];
}

