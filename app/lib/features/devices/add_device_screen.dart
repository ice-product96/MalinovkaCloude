import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/wifi_credentials_store.dart';
import '../../shared/wifi_credentials_dialog.dart';
import '../provisioning/ble_provisioning_service.dart';

class AddDeviceScreen extends ConsumerStatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  ConsumerState<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends ConsumerState<AddDeviceScreen> {
  final _ble = BleProvisioningService();
  Stream<List<DiscoveredDevice>>? _scanStream;
  String? _scanDeviceTypeId;
  var _isProvisioning = false;

  @override
  void dispose() {
    _ble.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceTypes = ref.watch(deviceTypesProvider);
    final rooms = ref.watch(roomsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Добавить устройство')),
      body: deviceTypes.when(
        data: (types) {
          if (types.isEmpty) {
            return const Center(child: Text('Каталог устройств пуст'));
          }
          final smartChef = types.first;
          return rooms.when(
            data: (roomItems) {
              return StreamBuilder<List<DiscoveredDevice>>(
                stream: _scanStreamFor(smartChef),
                builder: (context, snapshot) {
                  final devices = snapshot.data ?? const <DiscoveredDevice>[];
                  final scanError = snapshot.error?.toString().replaceFirst(
                    'Bad state: ',
                    '',
                  );
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Поиск ${smartChef.displayName}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ищем устройство рядом с именем ${smartChef.scanNamePrefix}*',
                      ),
                      const SizedBox(height: 16),
                      if (_isProvisioning) const LinearProgressIndicator(),
                      if (scanError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(scanError, textAlign: TextAlign.center),
                          ),
                        )
                      else if (devices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Text('Устройства пока не найдены'),
                          ),
                        )
                      else
                        ...devices.map(
                          (device) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.bluetooth),
                              title: Text(device.name),
                              subtitle: Text(device.externalId),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _isProvisioning
                                  ? null
                                  : () => _configureDevice(device, roomItems),
                            ),
                          ),
                        ),
                      if (roomItems.isEmpty)
                        const Text('Помещений нет. Создадим при привязке.'),
                    ],
                  );
                },
              );
            },
            error: (error, _) =>
                Center(child: Text('Ошибка помещений: $error')),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
        },
        error: (error, _) => Center(child: Text('Ошибка каталога: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Stream<List<DiscoveredDevice>> _scanStreamFor(DeviceType deviceType) {
    if (_scanStream == null || _scanDeviceTypeId != deviceType.id) {
      _scanDeviceTypeId = deviceType.id;
      _scanStream = _ble.scan(deviceType);
    }
    return _scanStream!;
  }

  Future<void> _configureDevice(
    DiscoveredDevice discoveredDevice,
    List<Room> rooms,
  ) async {
    final deviceTypes = await ref.read(deviceTypesProvider.future);
    final deviceType = deviceTypes.first;
    final api = ref.read(apiClientProvider);
    final roomId = await _pickOrCreateRoom(rooms);
    if (roomId == null) return;
    final wifiStore = await ref.read(wifiCredentialsStoreProvider.future);
    final wifi = await _showWifiDialog(wifiStore.readAll());
    if (wifi == null) return;

    setState(() => _isProvisioning = true);
    try {
      if (wifi.ssid.isNotEmpty) {
        await api.createDevice(
          roomId: roomId,
          deviceTypeId: deviceType.id,
          externalId: discoveredDevice.externalId,
          name: deviceType.displayName,
          connectionMode: 'ble',
        );
        final serverUrl = api.absoluteUrl(
          '/api/device/link/${discoveredDevice.externalId}',
        );
        await _ble.provisionWifi(
          discoveredDevice: discoveredDevice,
          deviceType: deviceType,
          serverUrl: serverUrl,
          ssid: wifi.ssid,
          password: wifi.password,
        );
        await wifiStore.save(wifi);
      }

      await api.createDevice(
        roomId: roomId,
        deviceTypeId: deviceType.id,
        externalId: discoveredDevice.externalId,
        name: deviceType.displayName,
        connectionMode: wifi.ssid.isEmpty ? 'ble' : 'wifi',
      );
      ref.invalidate(roomsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Не удалось добавить: $error')));
      }
    } finally {
      await _ble.stopScan();
      if (mounted) setState(() => _isProvisioning = false);
    }
  }

  Future<int?> _pickOrCreateRoom(List<Room> rooms) async {
    if (rooms.isEmpty) {
      return _createRoomFromDialog(
        title: 'Создать помещение',
        helperText: 'Устройство сразу будет привязано к новому помещению.',
      );
    }

    final selectedRoomId = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF202631),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Выберите помещение',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final room in rooms)
              ListTile(
                leading: const Icon(Icons.meeting_room_outlined),
                title: Text(room.name),
                onTap: () => Navigator.pop(context, room.id),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_home),
              title: const Text('Создать новое помещение'),
              onTap: () => Navigator.pop(context, -1),
            ),
          ],
        ),
      ),
    );
    if (selectedRoomId == -1) {
      return _createRoomFromDialog(
        title: 'Новое помещение',
        helperText: 'Устройство будет добавлено сюда.',
      );
    }
    return selectedRoomId;
  }

  Future<int?> _createRoomFromDialog({
    required String title,
    required String helperText,
  }) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 8),
            Text(helperText),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return null;
    final room = await ref.read(apiClientProvider).createRoom(name.trim());
    ref.invalidate(roomsProvider);
    return room.id;
  }

  Future<WifiCredentials?> _showWifiDialog(
    List<WifiCredentials> savedNetworks,
  ) {
    return showWifiCredentialsDialog(
      context: context,
      title: 'Wi-Fi для устройства',
      savedNetworks: savedNetworks,
      helperText:
          'Оставьте SSID пустым, чтобы добавить устройство только для локального управления.',
      allowEmptySsid: true,
      confirmText: 'Добавить',
    );
  }
}
