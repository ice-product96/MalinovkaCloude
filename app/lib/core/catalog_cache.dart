import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class CatalogCache {
  CatalogCache(this._preferences);

  static const _deviceTypesKey = 'device_types_cache';

  final SharedPreferences _preferences;

  Future<void> saveDeviceTypes(List<dynamic> rawJson) async {
    await _preferences.setString(_deviceTypesKey, jsonEncode(rawJson));
  }

  List<DeviceType> readDeviceTypes() {
    final value = _preferences.getString(_deviceTypesKey);
    if (value == null) return const [];
    final decoded = jsonDecode(value) as List<dynamic>;
    return decoded
        .map(
          (item) => DeviceType.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }
}
