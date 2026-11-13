import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

enum UnitSystem { metric, imperial }

class WeightLogSettings {
  const WeightLogSettings({
    this.themeMode = ThemeMode.system,
    this.unitSystem = UnitSystem.metric,
    this.cloudBackupEnabled = true,
  });

  final ThemeMode themeMode;
  final UnitSystem unitSystem;
  final bool cloudBackupEnabled;

  bool get usesMetric => unitSystem == UnitSystem.metric;

  WeightLogSettings copyWith({
    ThemeMode? themeMode,
    UnitSystem? unitSystem,
    bool? cloudBackupEnabled,
  }) {
    return WeightLogSettings(
      themeMode: themeMode ?? this.themeMode,
      unitSystem: unitSystem ?? this.unitSystem,
      cloudBackupEnabled: cloudBackupEnabled ?? this.cloudBackupEnabled,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'themeMode': themeMode.name,
      'unitSystem': unitSystem.name,
      'cloudBackupEnabled': cloudBackupEnabled,
    };
  }

  factory WeightLogSettings.fromJson(Map<String, Object?> json) {
    return WeightLogSettings(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      unitSystem: UnitSystem.values.firstWhere(
        (unit) => unit.name == json['unitSystem'],
        orElse: () => UnitSystem.metric,
      ),
      cloudBackupEnabled: json['cloudBackupEnabled'] as bool? ?? true,
    );
  }
}

class AppSettingsController extends StateNotifier<WeightLogSettings> {
  AppSettingsController() : super(const WeightLogSettings()) {
    _load();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _save();
  }

  Future<void> setUnitSystem(UnitSystem unitSystem) async {
    state = state.copyWith(unitSystem: unitSystem);
    await _save();
  }

  Future<void> setCloudBackupEnabled(bool enabled) async {
    state = state.copyWith(cloudBackupEnabled: enabled);
    await _save();
  }

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/weightlog_settings.json');
  }

  Future<void> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      state = WeightLogSettings.fromJson(json);
    } catch (_) {
      state = const WeightLogSettings();
    }
  }

  Future<void> _save() async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(state.toJson()));
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, WeightLogSettings>(
  (ref) => AppSettingsController(),
);

String unitLabel(UnitSystem unitSystem) {
  return unitSystem == UnitSystem.metric ? 'kg' : 'lb';
}

double displayWeight(double kilograms, UnitSystem unitSystem) {
  return unitSystem == UnitSystem.metric ? kilograms : kilograms * 2.2046226218;
}

double kilogramsFromDisplay(double value, UnitSystem unitSystem) {
  return unitSystem == UnitSystem.metric ? value : value / 2.2046226218;
}

String formatDisplayWeight(double kilograms, UnitSystem unitSystem) {
  final value = displayWeight(kilograms, unitSystem);
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
