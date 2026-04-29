import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/models.dart';

class BleUnavailableException implements Exception {
  const BleUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DiscoveredDevice {
  const DiscoveredDevice({
    required this.device,
    required this.name,
    required this.externalId,
  });

  final BluetoothDevice device;
  final String name;
  final String externalId;
}

class BleProvisioningService {
  static const _scanCooldown = Duration(seconds: 7);
  static DateTime? _lastScanStartedAt;
  static Future<void> _scanStartQueue = Future<void>.value();

  Future<void> ensureBluetoothReady() async {
    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) {
      throw const BleUnavailableException(
        'Устройство не поддерживает подключение по Bluetooth',
      );
    }

    final state = await FlutterBluePlus.adapterState.first.timeout(
      const Duration(seconds: 2),
      onTimeout: () => FlutterBluePlus.adapterStateNow,
    );
    if (state == BluetoothAdapterState.on) return;
    if (state == BluetoothAdapterState.turningOn) {
      try {
        await FlutterBluePlus.adapterState
            .where((state) => state == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 5));
        return;
      } on TimeoutException {
        throw const BleUnavailableException(
          'Bluetooth включается слишком долго. Проверьте его и повторите.',
        );
      }
    }

    throw BleUnavailableException(_bluetoothStateMessage(state));
  }

  Stream<List<DiscoveredDevice>> scan(DeviceType deviceType) async* {
    await _startScanWithCooldown(const Duration(seconds: 8));
    try {
      await for (final results in FlutterBluePlus.scanResults) {
        final devices = <String, DiscoveredDevice>{};
        for (final result in results) {
          final advertisedName = result.advertisementData.advName.isNotEmpty
              ? result.advertisementData.advName
              : result.device.platformName;
          if (!advertisedName.startsWith(deviceType.scanNamePrefix)) continue;
          devices[result.device.remoteId.str] = DiscoveredDevice(
            device: result.device,
            name: advertisedName,
            externalId: advertisedName,
          );
        }
        yield devices.values.toList();
      }
    } finally {
      await FlutterBluePlus.stopScan();
    }
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<void> provisionWifi({
    required DiscoveredDevice discoveredDevice,
    required DeviceType deviceType,
    required String serverUrl,
    required String ssid,
    required String password,
  }) async {
    await ensureBluetoothReady();
    await discoveredDevice.device.connect(
      license: License.commercial,
      timeout: const Duration(seconds: 15),
    );
    try {
      final characteristic = await _findWriteCharacteristic(
        discoveredDevice.device,
        deviceType,
      );
      await _writeCommand(
        characteristic,
        _render(deviceType.command('set_server')!, {'server_url': serverUrl}),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _writeCommand(
        characteristic,
        _render(deviceType.command('set_wifi')!, {
          'ssid': ssid,
          'password': password,
        }),
      );
    } finally {
      await discoveredDevice.device.disconnect();
    }
  }

  Future<void> provisionKnownDeviceWifi({
    required Device device,
    required String serverUrl,
    required String ssid,
    required String password,
  }) async {
    final deviceType = device.deviceType;
    if (deviceType == null) {
      throw StateError('Device type is required for Wi-Fi provisioning');
    }
    final discoveredDevice = await findDevice(device);
    await provisionWifi(
      discoveredDevice: discoveredDevice,
      deviceType: deviceType,
      serverUrl: serverUrl,
      ssid: ssid,
      password: password,
    );
  }

  Future<void> sendCommand({
    required Device device,
    required String commandName,
    required Map<String, dynamic> params,
  }) async {
    final deviceType = device.deviceType;
    if (deviceType == null) {
      throw StateError('Не удалось определить тип устройства');
    }
    final command = deviceType.command(commandName);
    if (command == null) {
      throw StateError('Команда для устройства не найдена: $commandName');
    }

    final discoveredDevice = await findDevice(device);
    await discoveredDevice.device.connect(
      license: License.commercial,
      timeout: const Duration(seconds: 15),
    );
    try {
      final characteristic = await _findWriteCharacteristic(
        discoveredDevice.device,
        deviceType,
      );
      await _writeCommand(
        characteristic,
        _render(command, _commandParams(params)),
      );
    } finally {
      await discoveredDevice.device.disconnect();
    }
  }

  Future<Map<String, dynamic>> readState(Device device) async {
    final deviceType = device.deviceType;
    if (deviceType == null) {
      throw StateError('Не удалось определить тип устройства');
    }

    final discoveredDevice = await findDevice(device);
    await discoveredDevice.device.connect(
      license: License.commercial,
      timeout: const Duration(seconds: 15),
    );
    try {
      final characteristic = await _findReadCharacteristic(
        discoveredDevice.device,
        deviceType,
      );
      final raw = await characteristic.read();
      final jsonText = utf8.decode(raw);
      return Map<String, dynamic>.from(jsonDecode(jsonText) as Map);
    } finally {
      await discoveredDevice.device.disconnect();
    }
  }

  Future<DiscoveredDevice> findDevice(Device device) async {
    final deviceType = device.deviceType;
    if (deviceType == null) {
      throw StateError('Не удалось определить тип устройства');
    }

    final completer = Completer<DiscoveredDevice>();
    final candidates = <String>{};
    StreamSubscription<List<ScanResult>>? subscription;
    await _startScanWithCooldown(const Duration(seconds: 10));
    try {
      subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          if (completer.isCompleted) return;
          final advertisedName = _nameFromScanResult(result);
          if (!advertisedName.startsWith(deviceType.scanNamePrefix)) continue;

          candidates.add(advertisedName);
          if (!_isExpectedDevice(result, advertisedName, device)) continue;

          completer.complete(
            DiscoveredDevice(
              device: result.device,
              name: advertisedName,
              externalId: device.externalId,
            ),
          );
        }
      });
      return await completer.future.timeout(
        const Duration(seconds: 11),
        onTimeout: () {
          final found = candidates.join(', ');
          throw StateError(
            'Устройство ${device.externalId} не найдено рядом. '
            'Найдено рядом: ${found.isEmpty ? 'нет подходящих устройств' : found}',
          );
        },
      );
    } finally {
      await subscription?.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  bool _isExpectedDevice(
    ScanResult result,
    String advertisedName,
    Device device,
  ) {
    final expected = device.externalId.trim();
    if (expected.isEmpty) return false;
    if (advertisedName == expected) return true;
    if (result.device.remoteId.str == expected) return true;

    final prefix = device.deviceType?.scanNamePrefix ?? '';
    if (prefix.isEmpty) return false;
    return advertisedName == '$prefix$expected';
  }

  String _nameFromScanResult(ScanResult result) {
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }
    return result.advertisementData.localName;
  }

  Future<void> _startScanWithCooldown(Duration timeout) {
    final request = _scanStartQueue.then((_) async {
      await ensureBluetoothReady();
      await FlutterBluePlus.stopScan();
      final lastScanStartedAt = _lastScanStartedAt;
      if (lastScanStartedAt != null) {
        final elapsed = DateTime.now().difference(lastScanStartedAt);
        if (elapsed < _scanCooldown) {
          await Future<void>.delayed(_scanCooldown - elapsed);
        }
      }
      await ensureBluetoothReady();
      _lastScanStartedAt = DateTime.now();
      await FlutterBluePlus.startScan(timeout: timeout);
    });
    _scanStartQueue = request.catchError((_) {});
    return request;
  }

  Future<BluetoothCharacteristic> _findWriteCharacteristic(
    BluetoothDevice device,
    DeviceType deviceType,
  ) async {
    final services = await device.discoverServices();
    final writeUuid = deviceType.writeCharacteristicUuid.toLowerCase();
    final fallback = <BluetoothCharacteristic>[];
    final discoveredUuids = <String>[];
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        discoveredUuids.add(characteristic.uuid.str);
        if (_uuidMatches(characteristic.uuid.str, writeUuid)) {
          return characteristic;
        }
        if (characteristic.properties.write ||
            characteristic.properties.writeWithoutResponse) {
          fallback.add(characteristic);
        }
      }
    }
    if (fallback.length == 1) return fallback.single;
    throw StateError(
      'Write characteristic not found: $writeUuid. '
      'Discovered: ${discoveredUuids.join(', ')}',
    );
  }

  Future<BluetoothCharacteristic> _findReadCharacteristic(
    BluetoothDevice device,
    DeviceType deviceType,
  ) async {
    final services = await device.discoverServices();
    final characteristics =
        deviceType.bleProfile['characteristics'] as Map? ?? const {};
    final stateUuid = (characteristics['state'] as String? ?? '').toLowerCase();
    final fallback = <BluetoothCharacteristic>[];
    final discoveredUuids = <String>[];
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        discoveredUuids.add(characteristic.uuid.str);
        if (_uuidMatches(characteristic.uuid.str, stateUuid)) {
          return characteristic;
        }
        if (characteristic.properties.read) {
          fallback.add(characteristic);
        }
      }
    }
    if (fallback.isNotEmpty) return fallback.first;
    throw StateError(
      'State characteristic not found: $stateUuid. '
      'Discovered: ${discoveredUuids.join(', ')}',
    );
  }

  bool _uuidMatches(String discoveredUuid, String expectedUuid) {
    final discovered = discoveredUuid.toLowerCase();
    final expected = expectedUuid.toLowerCase();
    if (discovered == expected) return true;
    if (expected.startsWith('0000') && expected.length >= 8) {
      return discovered == expected.substring(4, 8);
    }
    if (discovered.startsWith('0000') && discovered.length >= 8) {
      return discovered.substring(4, 8) == expected;
    }
    return false;
  }

  String _bluetoothStateMessage(BluetoothAdapterState state) {
    return switch (state) {
      BluetoothAdapterState.off =>
        'Включите Bluetooth для локального подключения',
      BluetoothAdapterState.turningOff =>
        'Bluetooth выключается. Включите Bluetooth и повторите.',
      BluetoothAdapterState.unauthorized =>
        'Нет разрешения на Bluetooth. Разрешите Bluetooth для приложения.',
      BluetoothAdapterState.unavailable =>
        'Bluetooth недоступен на этом устройстве',
      BluetoothAdapterState.unknown =>
        'Не удалось определить состояние Bluetooth. Проверьте Bluetooth и повторите.',
      BluetoothAdapterState.turningOn =>
        'Bluetooth включается. Повторите через несколько секунд.',
      BluetoothAdapterState.on => '',
    };
  }

  Future<void> _writeCommand(
    BluetoothCharacteristic characteristic,
    String command,
  ) {
    return characteristic.write(utf8.encode(command), withoutResponse: false);
  }

  Map<String, String> _commandParams(Map<String, dynamic> params) {
    final result = params.map((key, value) => MapEntry(key, '$value'));
    final duration = int.tryParse(result['duration_minutes'] ?? '');
    if (duration != null) {
      result.putIfAbsent('hours', () => '${duration ~/ 60}');
      result.putIfAbsent('minutes', () => '${duration % 60}');
    }
    return result;
  }

  String _render(DeviceCommand command, Map<String, String> params) {
    var rendered = command.template;
    for (final entry in params.entries) {
      rendered = rendered.replaceAll('{${entry.key}}', entry.value);
    }
    return rendered;
  }
}
