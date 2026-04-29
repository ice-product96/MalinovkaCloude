import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WifiCredentials {
  const WifiCredentials({required this.ssid, required this.password});

  final String ssid;
  final String password;

  factory WifiCredentials.fromJson(Map<String, dynamic> json) {
    return WifiCredentials(
      ssid: json['ssid'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'ssid': ssid, 'password': password};
}

class WifiCredentialsStore {
  WifiCredentialsStore(this._preferences);

  static const _key = 'wifi_credentials';

  final SharedPreferences _preferences;

  List<WifiCredentials> readAll() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final items = jsonDecode(raw) as List;
    return items
        .map(
          (item) =>
              WifiCredentials.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .where((item) => item.ssid.isNotEmpty)
        .toList();
  }

  Future<void> save(WifiCredentials credentials) async {
    if (credentials.ssid.trim().isEmpty) return;
    final items = [
      credentials,
      ...readAll().where((item) => item.ssid != credentials.ssid),
    ];
    await _preferences.setString(
      _key,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}
