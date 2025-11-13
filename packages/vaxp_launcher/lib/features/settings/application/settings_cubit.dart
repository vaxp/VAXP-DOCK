import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vaxp_launcher/features/settings/application/settings_state.dart';
import 'package:vaxp_launcher/features/settings/data/repositories/settings_repository.dart';
import 'package:vaxp_launcher/features/settings/domain/models/launcher_settings.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repository)
      : super(
          SettingsState(
            settings: const LauncherSettings(
              backgroundColor: Colors.black,
              opacity: 0.7,
            ),
            isLoading: true,
          ),
        ) {
    loadSettings();
  }

  final SettingsRepository _repository;

  Future<void> loadSettings() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final settings = await _repository.loadSettings();
      emit(state.copyWith(settings: settings, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to load settings: $e',
      ));
    }
  }

  Future<void> updateSettings(LauncherSettings settings) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await _repository.saveSettings(settings);
      emit(state.copyWith(settings: settings, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to save settings: $e',
      ));
    }
  }

  void updateBackgroundColor(Color color) {
    final newSettings = state.settings.copyWith(backgroundColor: color);
    emit(state.copyWith(settings: newSettings));
  }

  void updateOpacity(double opacity) {
    final newSettings = state.settings.copyWith(opacity: opacity);
    emit(state.copyWith(settings: newSettings));
  }

  void updateBackgroundImage(String? path) {
    final newSettings = state.settings.copyWith(backgroundImagePath: path);
    emit(state.copyWith(settings: newSettings));
  }

  void updateIconTheme(String? path) {
    final newSettings = state.settings.copyWith(iconThemePath: path);
    emit(state.copyWith(settings: newSettings));
  }

  Future<void> saveCurrentSettings() async {
    await updateSettings(state.settings);
  }
}

