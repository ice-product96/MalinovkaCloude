class DeviceCommand {
  const DeviceCommand({
    required this.id,
    required this.name,
    required this.transport,
    required this.template,
    required this.description,
    required this.schema,
  });

  final int id;
  final String name;
  final String transport;
  final String template;
  final String description;
  final Map<String, dynamic> schema;

  factory DeviceCommand.fromJson(Map<String, dynamic> json) {
    return DeviceCommand(
      id: json['id'] as int,
      name: json['name'] as String,
      transport: json['transport'] as String,
      template: json['template'] as String,
      description: json['description'] as String? ?? '',
      schema: Map<String, dynamic>.from(json['schema'] as Map? ?? const {}),
    );
  }
}

class AppConfig {
  const AppConfig({required this.homeBackgroundUrl});

  final String homeBackgroundUrl;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(homeBackgroundUrl: json['home_background_url'] as String);
  }
}

class FirmwareInfo {
  const FirmwareInfo({
    required this.version,
    required this.url,
    this.updateAvailable,
  });

  final String version;
  final String url;
  final bool? updateAvailable;

  factory FirmwareInfo.fromJson(Map<String, dynamic> json) {
    return FirmwareInfo(
      version: json['version'] as String,
      url: json['url'] as String,
      updateAvailable: json['update_available'] as bool?,
    );
  }
}

class DeviceType {
  const DeviceType({
    required this.id,
    required this.displayName,
    required this.manufacturer,
    required this.description,
    required this.imageUrl,
    required this.bleProfile,
    required this.capabilities,
    required this.commands,
  });

  final String id;
  final String displayName;
  final String manufacturer;
  final String description;
  final String imageUrl;
  final Map<String, dynamic> bleProfile;
  final Map<String, dynamic> capabilities;
  final List<DeviceCommand> commands;

  String get scanNamePrefix => bleProfile['scan_name_prefix'] as String? ?? '';
  String get writeCharacteristicUuid {
    final characteristics = bleProfile['characteristics'] as Map? ?? const {};
    return characteristics['write'] as String? ?? '';
  }

  DeviceCommand? command(String name) {
    for (final command in commands) {
      if (command.name == name) return command;
    }
    return null;
  }

  factory DeviceType.fromJson(Map<String, dynamic> json) {
    return DeviceType(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      manufacturer: json['manufacturer'] as String,
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String,
      bleProfile: Map<String, dynamic>.from(
        json['ble_profile'] as Map? ?? const {},
      ),
      capabilities: Map<String, dynamic>.from(
        json['capabilities'] as Map? ?? const {},
      ),
      commands: (json['commands'] as List? ?? const [])
          .map(
            (item) =>
                DeviceCommand.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

class Device {
  const Device({
    required this.id,
    required this.roomId,
    required this.deviceTypeId,
    required this.externalId,
    required this.name,
    required this.connectionMode,
    required this.lastState,
    this.deviceType,
  });

  final int id;
  final int roomId;
  final String deviceTypeId;
  final String externalId;
  final String name;
  final String connectionMode;
  final Map<String, dynamic> lastState;
  final DeviceType? deviceType;

  Device copyWith({
    String? connectionMode,
    Map<String, dynamic>? lastState,
    DeviceType? deviceType,
  }) {
    return Device(
      id: id,
      roomId: roomId,
      deviceTypeId: deviceTypeId,
      externalId: externalId,
      name: name,
      connectionMode: connectionMode ?? this.connectionMode,
      lastState: lastState ?? this.lastState,
      deviceType: deviceType ?? this.deviceType,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      roomId: json['room_id'] as int,
      deviceTypeId: json['device_type_id'] as String,
      externalId: json['external_id'] as String,
      name: json['name'] as String,
      connectionMode: json['connection_mode'] as String,
      lastState: Map<String, dynamic>.from(
        json['last_state'] as Map? ?? const {},
      ),
      deviceType: json['device_type'] == null
          ? null
          : DeviceType.fromJson(
              Map<String, dynamic>.from(json['device_type'] as Map),
            ),
    );
  }
}

class Room {
  const Room({required this.id, required this.name, required this.devices});

  final int id;
  final String name;
  final List<Device> devices;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as int,
      name: json['name'] as String,
      devices: (json['devices'] as List? ?? const [])
          .map(
            (item) => Device.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

class CookingProgram {
  const CookingProgram({
    required this.id,
    required this.name,
    required this.mode,
    required this.volumeGroup,
    required this.dishCategory,
    required this.durationMinutes,
    required this.temperatureCelsius,
    required this.modeCode,
  });

  final int id;
  final String name;
  final String mode;
  final String volumeGroup;
  final String dishCategory;
  final int durationMinutes;
  final int temperatureCelsius;
  final int modeCode;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mode': mode,
      'volume_group': volumeGroup,
      'dish_category': dishCategory,
      'duration_minutes': durationMinutes,
      'temperature_celsius': temperatureCelsius,
      'mode_code': modeCode,
    };
  }

  factory CookingProgram.fromJson(Map<String, dynamic> json) {
    return CookingProgram(
      id: json['id'] as int,
      name: json['name'] as String,
      mode: json['mode'] as String,
      volumeGroup: json['volume_group'] as String,
      dishCategory: json['dish_category'] as String,
      durationMinutes: json['duration_minutes'] as int,
      temperatureCelsius: json['temperature_celsius'] as int,
      modeCode: json['mode_code'] as int,
    );
  }
}

class ProgramCategoryGroup {
  const ProgramCategoryGroup({required this.category, required this.programs});

  final String category;
  final List<CookingProgram> programs;

  factory ProgramCategoryGroup.fromJson(Map<String, dynamic> json) {
    return ProgramCategoryGroup(
      category: json['category'] as String,
      programs: (json['programs'] as List? ?? const [])
          .map(
            (item) =>
                CookingProgram.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

class ProgramVolumeGroup {
  const ProgramVolumeGroup({
    required this.volumeGroup,
    required this.categories,
  });

  final String volumeGroup;
  final List<ProgramCategoryGroup> categories;

  factory ProgramVolumeGroup.fromJson(Map<String, dynamic> json) {
    return ProgramVolumeGroup(
      volumeGroup: json['volume_group'] as String,
      categories: (json['categories'] as List? ?? const [])
          .map(
            (item) => ProgramCategoryGroup.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class ProgramModeGroup {
  const ProgramModeGroup({required this.mode, required this.volumes});

  final String mode;
  final List<ProgramVolumeGroup> volumes;

  factory ProgramModeGroup.fromJson(Map<String, dynamic> json) {
    return ProgramModeGroup(
      mode: json['mode'] as String,
      volumes: (json['volumes'] as List? ?? const [])
          .map(
            (item) => ProgramVolumeGroup.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
