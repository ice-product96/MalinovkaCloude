import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class UserProgramStore {
  UserProgramStore(this._preferences);

  final SharedPreferences _preferences;

  String _key(String deviceTypeId) => 'user_programs_$deviceTypeId';

  List<CookingProgram> read(String deviceTypeId) {
    final raw = _preferences.getString(_key(deviceTypeId));
    if (raw == null || raw.isEmpty) return const [];
    final items = jsonDecode(raw) as List;
    return items
        .map(
          (item) =>
              CookingProgram.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> save(String deviceTypeId, List<CookingProgram> programs) {
    return _preferences.setString(
      _key(deviceTypeId),
      jsonEncode(programs.map((program) => program.toJson()).toList()),
    );
  }
}
