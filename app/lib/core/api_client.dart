import 'dart:convert';

import 'package:dio/dio.dart';

import 'models.dart';

const defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api',
);

class ApiClient {
  ApiClient({Dio? dio, this.baseUrl = defaultApiBaseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  final Dio _dio;
  final String baseUrl;

  String absoluteUrl(String path) {
    final normalized = path.trim().replaceAll(r'\', '/');
    if (normalized.startsWith('http')) return normalized;
    final uri = Uri.parse(baseUrl);
    final root = '${uri.scheme}://${uri.authority}';
    final cleanPath = normalized.startsWith('/') ? normalized : '/$normalized';
    return '$root$cleanPath';
  }

  Future<List<dynamic>> fetchDeviceTypesJson() async {
    final response = await _dio.get<List<dynamic>>('/device-types');
    return response.data ?? const [];
  }

  Future<List<DeviceType>> fetchDeviceTypes() async {
    final data = await fetchDeviceTypesJson();
    return data
        .map(
          (item) => DeviceType.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<AppConfig> fetchAppConfig() async {
    final response = await _dio.get<Map<String, dynamic>>('/app-config');
    return AppConfig.fromJson(response.data!);
  }

  Future<FirmwareInfo> fetchLatestFirmware({String? currentVersion}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/firmware/latest',
      queryParameters: {
        if (currentVersion != null && currentVersion.isNotEmpty)
          'current_version': currentVersion,
      },
    );
    return FirmwareInfo.fromJson(response.data!);
  }

  Future<List<Room>> fetchRooms() async {
    final response = await _dio.get<List<dynamic>>('/rooms');
    return (response.data ?? const [])
        .map((item) => Room.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Room> createRoom(String name) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/rooms',
      data: {'name': name},
    );
    return Room.fromJson(response.data!);
  }

  Future<Room> updateRoom(int roomId, String name) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/rooms/$roomId',
      data: {'name': name},
    );
    return Room.fromJson(response.data!);
  }

  Future<void> deleteRoom(int roomId) async {
    await _dio.delete<void>('/rooms/$roomId');
  }

  Future<Device> createDevice({
    required int roomId,
    required String deviceTypeId,
    required String externalId,
    required String name,
    String connectionMode = 'ble',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/devices',
      data: {
        'room_id': roomId,
        'device_type_id': deviceTypeId,
        'external_id': externalId,
        'name': name,
        'connection_mode': connectionMode,
      },
    );
    return Device.fromJson(response.data!);
  }

  Future<Device> updateDeviceRoom(int deviceId, int roomId) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/devices/$deviceId',
      data: {'room_id': roomId},
    );
    return Device.fromJson(response.data!);
  }

  Future<Device> fetchDevice(int deviceId) async {
    final response = await _dio.get<Map<String, dynamic>>('/devices/$deviceId');
    return Device.fromJson(response.data!);
  }

  Future<void> deleteDevice(int deviceId) async {
    await _dio.delete<void>('/devices/$deviceId');
  }

  Future<Map<String, dynamic>> requestFirmwareUpdate(int deviceId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/devices/$deviceId/firmware-update',
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> sendCommand(
    int deviceId,
    String name,
    Map<String, dynamic> params,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/devices/$deviceId/commands',
      data: {'name': name, 'params': params},
    );
    return response.data!;
  }

  Future<List<ProgramModeGroup>> fetchPrograms(String deviceTypeId) async {
    final response = await _dio.get<List<dynamic>>(
      '/device-types/$deviceTypeId/programs',
    );
    return (response.data ?? const [])
        .map(
          (item) =>
              ProgramModeGroup.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<CookingProgram>> fetchUserPrograms(String deviceTypeId) async {
    final response = await _dio.get<List<dynamic>>(
      '/device-types/$deviceTypeId/user-programs',
    );
    return (response.data ?? const [])
        .map(
          (item) =>
              CookingProgram.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<CookingProgram> saveUserProgram(
    String deviceTypeId,
    CookingProgram program,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/device-types/$deviceTypeId/user-programs',
      data: program.toJson()..remove('id'),
    );
    return CookingProgram.fromJson(response.data!);
  }

  Future<void> deleteUserProgram(int programId) async {
    await _dio.delete<void>('/device-types/user-programs/$programId');
  }

  String commandPreview(DeviceCommand command, Map<String, dynamic> params) {
    var rendered = command.template;
    for (final entry in params.entries) {
      rendered = rendered.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return rendered;
  }

  String encodeForCache(Object value) => jsonEncode(value);
}
