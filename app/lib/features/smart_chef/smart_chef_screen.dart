import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/wifi_credentials_store.dart';
import '../../shared/device_status_text.dart';
import '../../shared/loading_skeleton.dart';
import '../../shared/wifi_credentials_dialog.dart';
import '../provisioning/ble_provisioning_service.dart';

class SmartChefScreen extends ConsumerStatefulWidget {
  const SmartChefScreen({super.key, required this.device});

  final Device device;

  @override
  ConsumerState<SmartChefScreen> createState() => _SmartChefScreenState();
}

class _SmartChefScreenState extends ConsumerState<SmartChefScreen>
    with WidgetsBindingObserver {
  final _name = TextEditingController(text: 'Моя программа');
  final _ble = BleProvisioningService();
  late Device _currentDevice;
  CookingProgram? _selectedProgram;
  Timer? _stateTimer;
  var _modeCode = 0;
  var _duration = 60.0;
  var _temperature = 100.0;
  var _isSending = false;
  var _isStopping = false;
  var _isFirmwareUpdating = false;
  var _page = _ChefSheetPage.menu;
  String? _selectedMode;
  String? _selectedVolume;
  String? _selectedCategory;
  final List<CookingProgram> _myPrograms = [];
  final _sheetController = DraggableScrollableController();
  var _isRefreshingState = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentDevice = widget.device;
    _stateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshDeviceState();
    });
    _loadMyPrograms();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDeviceState();
      if (mounted && _sheetController.isAttached) {
        _sheetController.animateTo(
          0.42,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateTimer?.cancel();
    _sheetController.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDeviceState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final programs = ref.watch(programsProvider(_currentDevice.deviceTypeId));
    final deviceType = _currentDevice.deviceType;
    final isConnected = _isDeviceConnected;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_currentDevice.name),
        leading: _HeaderIconAction(icon: Icons.arrow_back, onTap: _goBack),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 98, 18, 310),
            children: [
              _DeviceHeroCard(
                title: widget.device.name,
                subtitle: _currentDevice.externalId,
                imageUrl: deviceType == null
                    ? null
                    : api.absoluteUrl(deviceType.imageUrl),
              ),
              const SizedBox(height: 16),
              if (_selectedProgram != null) ...[
                _SelectedProgramCard(
                  program: _selectedProgram,
                  isConnected: isConnected,
                  isSending: _isSending,
                  onStart: _startSelectedProgram,
                ),
                const SizedBox(height: 16),
              ],
              _StatusCard(
                state: _currentDevice.lastState,
                isRefreshing: _isRefreshingState,
                isStopping: _isStopping,
                onStop: _sendStop,
              ),
            ],
          ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.42,
            minChildSize: 0.08,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.08, 0.42, 0.9],
            builder: (context, scrollController) {
              return _ChefMenuSheet(
                page: _page,
                scrollController: scrollController,
                isSending: _isSending || _isFirmwareUpdating,
                onBack: _sheetBack,
                onOpenPage: _openSheetPage,
                selectedMode: _selectedMode,
                selectedVolume: _selectedVolume,
                selectedCategory: _selectedCategory,
                onModeSelected: (mode) {
                  setState(() {
                    _selectedMode = mode;
                    _selectedVolume = null;
                    _selectedCategory = null;
                    _page = _ChefSheetPage.readyVolumes;
                  });
                },
                onVolumeSelected: (volume) {
                  setState(() {
                    _selectedVolume = volume;
                    _selectedCategory = null;
                    _page = _ChefSheetPage.readyCategories;
                  });
                },
                onCategorySelected: (category) {
                  setState(() {
                    _selectedCategory = category;
                    _page = _ChefSheetPage.readyDishes;
                  });
                },
                onConfigureWifi: _configureWifi,
                customProgram: _CustomProgramCard(
                  name: _name,
                  modeCode: _modeCode,
                  duration: _duration,
                  temperature: _temperature,
                  isSending: _isSending,
                  onModeChanged: (value) => setState(() => _modeCode = value),
                  onDurationChanged: (value) =>
                      setState(() => _duration = value),
                  onTemperatureChanged: (value) =>
                      setState(() => _temperature = value),
                  onSave: () => _saveCustomProgram(),
                ),
                myPrograms: _myPrograms,
                programs: programs,
                onSelectProgram: _selectProgram,
                onDeleteProgram: _deleteMyProgram,
                onFirmwareUpdate: _requestFirmwareUpdate,
              );
            },
          ),
        ],
      ),
    );
  }

  bool get _isDeviceConnected {
    return _currentDevice.connectionMode == 'wifi' ||
        _currentDevice.connectionMode == 'ble';
  }

  Future<void> _refreshDeviceState() async {
    if (_isRefreshingState || _isSending || _isStopping) return;
    if (mounted) {
      setState(() => _isRefreshingState = true);
    } else {
      _isRefreshingState = true;
    }
    try {
      if (_currentDevice.connectionMode == 'wifi') {
        try {
          final device = await ref
              .read(apiClientProvider)
              .fetchDevice(_currentDevice.id);
          if (!mounted) return;
          setState(() => _currentDevice = device);
          return;
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Не удалось обновить с сервера: $error')),
            );
          }
          return;
        }
      }

      try {
        final state = await _ble.readState(_currentDevice);
        if (!mounted) return;
        setState(() {
          _currentDevice = _currentDevice.copyWith(
            lastState: {..._currentDevice.lastState, ...state},
          );
        });
      } catch (_) {
        // Keep the last known state visible if both transports are unavailable.
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingState = false);
      } else {
        _isRefreshingState = false;
      }
    }
  }

  Future<void> _goBack() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _openSheetPage(_ChefSheetPage page) {
    setState(() => _page = page);
    if (_sheetController.isAttached && _sheetController.size < 0.42) {
      _sheetController.animateTo(
        0.42,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _sheetBack() {
    setState(() {
      switch (_page) {
        case _ChefSheetPage.menu:
          break;
        case _ChefSheetPage.myPrograms:
        case _ChefSheetPage.readyModes:
        case _ChefSheetPage.createProgram:
          _page = _ChefSheetPage.menu;
        case _ChefSheetPage.readyVolumes:
          _page = _ChefSheetPage.readyModes;
          _selectedVolume = null;
          _selectedCategory = null;
        case _ChefSheetPage.readyCategories:
          _page = _ChefSheetPage.readyVolumes;
          _selectedCategory = null;
        case _ChefSheetPage.readyDishes:
          _page = _ChefSheetPage.readyCategories;
      }
    });
  }

  Future<void> _collapseMenu() async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      0.08,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadMyPrograms() async {
    final store = await ref.read(userProgramStoreProvider.future);
    final localPrograms = store.read(_currentDevice.deviceTypeId);
    if (mounted) setState(() => _myPrograms.addAll(localPrograms));

    try {
      final api = ref.read(apiClientProvider);
      final remotePrograms = await api.fetchUserPrograms(
        _currentDevice.deviceTypeId,
      );
      final uploadedPrograms = <CookingProgram>[];
      for (final program in localPrograms) {
        final existsOnServer = remotePrograms.any(
          (item) => item.name == program.name,
        );
        if (!existsOnServer) {
          uploadedPrograms.add(
            await api.saveUserProgram(_currentDevice.deviceTypeId, program),
          );
        }
      }
      final merged = _mergePrograms([
        ...localPrograms,
        ...remotePrograms,
        ...uploadedPrograms,
      ]);
      await store.save(_currentDevice.deviceTypeId, merged);
      if (mounted) {
        setState(() {
          _myPrograms
            ..clear()
            ..addAll(merged);
        });
      }
    } catch (_) {
      // Local programs remain available when the server is offline.
    }
  }

  List<CookingProgram> _mergePrograms(List<CookingProgram> programs) {
    final byName = <String, CookingProgram>{};
    for (final program in programs) {
      byName[program.name] = program;
    }
    return byName.values.toList()..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<void> _saveCustomProgram() async {
    const modes = ['На воде', 'На пару', 'Ретро-пакет', 'Су-вид'];
    var program = CookingProgram(
      id: -DateTime.now().millisecondsSinceEpoch,
      name: _name.text.trim().isEmpty ? 'Моя программа' : _name.text.trim(),
      mode: modes[_modeCode],
      volumeGroup: 'Пользовательская',
      dishCategory: 'Мои программы',
      durationMinutes: _duration.round(),
      temperatureCelsius: _temperature.round(),
      modeCode: _modeCode,
    );

    setState(() {
      _myPrograms.insert(0, program);
      _page = _ChefSheetPage.myPrograms;
      _name.text = 'Моя программа';
      _modeCode = 0;
      _duration = 60;
      _temperature = 100;
    });

    final store = await ref.read(userProgramStoreProvider.future);
    await store.save(_currentDevice.deviceTypeId, _mergePrograms(_myPrograms));

    try {
      program = await ref
          .read(apiClientProvider)
          .saveUserProgram(_currentDevice.deviceTypeId, program);
      final merged = _mergePrograms([program, ..._myPrograms]);
      await store.save(_currentDevice.deviceTypeId, merged);
      if (mounted) {
        setState(() {
          _myPrograms
            ..clear()
            ..addAll(merged);
        });
      }
    } catch (_) {
      // The program is saved locally and will be uploaded on the next sync.
    }

    if (_sheetController.isAttached && _sheetController.size < 0.42) {
      _sheetController.animateTo(
        0.42,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _deleteMyProgram(CookingProgram program) async {
    setState(
      () => _myPrograms.removeWhere((item) => item.name == program.name),
    );
    final store = await ref.read(userProgramStoreProvider.future);
    await store.save(_currentDevice.deviceTypeId, _myPrograms);
    if (program.id <= 0) return;
    try {
      await ref.read(apiClientProvider).deleteUserProgram(program.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить на сервере: $error')),
        );
      }
    }
  }

  void _selectProgram(CookingProgram program) {
    setState(() {
      _selectedProgram = program;
      _page = _ChefSheetPage.menu;
    });
    _collapseMenu();
  }

  Future<void> _configureWifi() async {
    final store = await ref.read(wifiCredentialsStoreProvider.future);
    final credentials = await _showWifiSetupDialog(store.readAll());
    if (credentials == null) return;

    setState(() => _isSending = true);
    try {
      final api = ref.read(apiClientProvider);
      final serverUrl = api.absoluteUrl(
        '/api/device/link/${_currentDevice.externalId}',
      );
      await _ble.provisionKnownDeviceWifi(
        device: _currentDevice,
        serverUrl: serverUrl,
        ssid: credentials.ssid,
        password: credentials.password,
      );
      await store.save(credentials);
      final updated = await api.createDevice(
        roomId: _currentDevice.roomId,
        deviceTypeId: _currentDevice.deviceTypeId,
        externalId: _currentDevice.externalId,
        name: _currentDevice.name,
        connectionMode: 'wifi',
      );
      if (!mounted) return;
      setState(() {
        _currentDevice = updated.copyWith(
          deviceType: updated.deviceType ?? _currentDevice.deviceType,
        );
      });
      ref.invalidate(roomsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wi-Fi настройки переданы устройству')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка Wi-Fi: $error')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _requestFirmwareUpdate() async {
    if (_isFirmwareUpdating) return;
    if (_currentDevice.connectionMode != 'wifi') {
      _showMessage('Обновление доступно только после настройки Wi-Fi.');
      return;
    }

    final statusText = deviceStatusText(_currentDevice.lastState['status']);
    if (isDeviceStatusActive(_currentDevice.lastState['status']) ||
        statusText != 'Ожидает') {
      _showMessage(
        'Обновление можно запускать только когда устройство ожидает команду.',
      );
      return;
    }

    setState(() => _isFirmwareUpdating = true);
    try {
      final api = ref.read(apiClientProvider);
      final currentVersion = _currentFirmwareVersion;
      final latest = await api.fetchLatestFirmware(
        currentVersion: currentVersion,
      );
      if (!_isVersionOlder(currentVersion, latest.version)) {
        _showMessage('Устройство уже обновлено до версии ${latest.version}.');
        return;
      }

      await api.requestFirmwareUpdate(_currentDevice.id);
      _showMessage(
        'Запрос на обновление до версии ${latest.version} отправлен. Устройство обновится по Wi-Fi.',
      );
      await _refreshDeviceState();
    } catch (error) {
      _showMessage('Не удалось запросить обновление: $error');
    } finally {
      if (mounted) setState(() => _isFirmwareUpdating = false);
    }
  }

  String get _currentFirmwareVersion {
    return '${_currentDevice.lastState['firmware_version'] ?? _currentDevice.lastState['version'] ?? '0.0.0'}';
  }

  bool _isVersionOlder(String current, String latest) {
    final currentParts = _versionParts(current);
    final latestParts = _versionParts(latest);
    final length = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;
    for (var i = 0; i < length; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      if (currentPart < latestPart) return true;
      if (currentPart > latestPart) return false;
    }
    return false;
  }

  List<int> _versionParts(String version) {
    return version
        .replaceAll('-', '.')
        .split('.')
        .map(
          (part) => int.tryParse(RegExp(r'^\d+').stringMatch(part) ?? '0') ?? 0,
        )
        .toList();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<WifiCredentials?> _showWifiSetupDialog(
    List<WifiCredentials> savedNetworks,
  ) {
    return showWifiCredentialsDialog(
      context: context,
      title: 'Настроить Wi-Fi',
      savedNetworks: savedNetworks,
      helperText:
          'Выберите сеть рядом или введите SSID вручную. Сохранённые сети подставят пароль автоматически.',
    );
  }

  Future<void> _startSelectedProgram() async {
    final program = _selectedProgram;
    if (program == null || !_isDeviceConnected) return;
    final sent = await _sendCommand('start_program', {
      'name': program.name,
      'mode_code': program.modeCode,
      'duration_minutes': program.durationMinutes,
      'temperature': program.temperatureCelsius,
    });
    if (sent && mounted) {
      setState(() => _selectedProgram = null);
    }
    await _refreshDeviceState();
  }

  Future<void> _sendStop() async {
    if (_isStopping) return;
    setState(() => _isStopping = true);
    try {
      final sent = await _sendCommand('stop', {}, showSuccessMessage: false);
      if (!sent) return;
      final stopped = await _waitForStopConfirmation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stopped
                ? 'Устройство остановлено'
                : 'Команда отправлена, но устройство пока не подтвердило остановку',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isStopping = false);
    }
  }

  Future<bool> _waitForStopConfirmation() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (mounted && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final state = await _fetchLatestDeviceState();
      if (state == null) continue;
      if (!isDeviceStatusActive(state['status'])) return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> _fetchLatestDeviceState() async {
    try {
      if (_currentDevice.connectionMode == 'wifi') {
        final device = await ref
            .read(apiClientProvider)
            .fetchDevice(_currentDevice.id);
        if (mounted) setState(() => _currentDevice = device);
        return device.lastState;
      }

      final state = await _ble.readState(_currentDevice);
      if (mounted) {
        setState(() {
          _currentDevice = _currentDevice.copyWith(
            lastState: {..._currentDevice.lastState, ...state},
          );
        });
      }
      return state;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _sendCommand(
    String name,
    Map<String, dynamic> params, {
    bool showSuccessMessage = true,
  }) async {
    setState(() => _isSending = true);
    try {
      var transport = 'локальное подключение';
      if (_currentDevice.connectionMode == 'wifi') {
        await ref
            .read(apiClientProvider)
            .sendCommand(_currentDevice.id, name, params);
        transport = 'интернет';
      } else {
        await _ble.sendCommand(
          device: _currentDevice,
          commandName: name,
          params: params,
        );
      }
      if (mounted && showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Команда отправлена через $transport')),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Не удалось отправить: $error')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

class _HeaderIconAction extends StatelessWidget {
  const _HeaderIconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

enum _ChefSheetPage {
  menu('Меню устройства'),
  myPrograms('Мои программы'),
  readyModes('Готовые программы'),
  readyVolumes('Выберите объём'),
  readyCategories('Категория блюда'),
  readyDishes('Выберите блюдо'),
  createProgram('Создать программу');

  const _ChefSheetPage(this.title);

  final String title;
}

class _DeviceHeroCard extends StatelessWidget {
  const _DeviceHeroCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF302631), Color(0xFF181C24)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: imageUrl == null
                  ? Icon(
                      Icons.kitchen,
                      size: 180,
                      color: Colors.white.withValues(alpha: 0.1),
                    )
                  : Container(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 92),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.contain,
                        errorWidget: (context, url, error) => Icon(
                          Icons.kitchen,
                          size: 180,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA6228),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Автоклав',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.state,
    required this.isRefreshing,
    required this.isStopping,
    required this.onStop,
  });

  final Map<String, dynamic> state;
  final bool isRefreshing;
  final bool isStopping;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final status = state['status'];
    final isActive = isDeviceStatusActive(status);
    final statusText = deviceStatusText(status);
    return Container(
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2F3526) : const Color(0xFF262B35),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isActive ? const Color(0xFF9BD45A) : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isActive ? 'Состояние: $statusText' : 'Состояние',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (isRefreshing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (isActive) ...[
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: isStopping ? null : onStop,
                    icon: isStopping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.stop),
                    label: Text(isStopping ? 'Останавливаем...' : 'Остановить'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              padding: EdgeInsets.zero,
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.7,
              children: [
                _Metric(
                  label: 'Температура',
                  value: '${state['temperature'] ?? '--'} C',
                ),
                _Metric(
                  label: 'Цель',
                  value: isActive
                      ? '${state['settemperature'] ?? '--'} C'
                      : '--',
                ),
                _Metric(label: 'Статус', value: statusText),
                _Metric(
                  label: 'Осталось',
                  value: isActive ? '${state['timeend'] ?? '--'}' : '--',
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Metric(
              label: 'Программа',
              value: isActive ? '${state['nameprog'] ?? '--'}' : '--',
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedProgramCard extends StatelessWidget {
  const _SelectedProgramCard({
    required this.program,
    required this.isConnected,
    required this.isSending,
    required this.onStart,
  });

  final CookingProgram? program;
  final bool isConnected;
  final bool isSending;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final selected = program;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF262B35),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Выбранная программа',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (selected == null) ...[
            Text(
              'Выберите программу в меню устройства.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.64)),
            ),
          ] else ...[
            Text(
              selected.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ProgramChip(label: selected.mode),
                _ProgramChip(label: '${selected.durationMinutes} мин'),
                _ProgramChip(label: '${selected.temperatureCelsius} C'),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isConnected && !isSending ? onStart : null,
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('Старт'),
              ),
            ),
            if (!isConnected) ...[
              const SizedBox(height: 10),
              Text(
                'Запуск доступен после подключения устройства к Wi-Fi.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.58)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ProgramChip extends StatelessWidget {
  const _ProgramChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEA6228).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEA6228)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFFA37D),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C212B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ChefMenuSheet extends StatelessWidget {
  const _ChefMenuSheet({
    required this.page,
    required this.scrollController,
    required this.customProgram,
    required this.myPrograms,
    required this.programs,
    required this.isSending,
    required this.onBack,
    required this.onOpenPage,
    required this.selectedMode,
    required this.selectedVolume,
    required this.selectedCategory,
    required this.onModeSelected,
    required this.onVolumeSelected,
    required this.onCategorySelected,
    required this.onSelectProgram,
    required this.onDeleteProgram,
    required this.onConfigureWifi,
    required this.onFirmwareUpdate,
  });

  final _ChefSheetPage page;
  final ScrollController scrollController;
  final Widget customProgram;
  final List<CookingProgram> myPrograms;
  final AsyncValue<List<ProgramModeGroup>> programs;
  final bool isSending;
  final VoidCallback onBack;
  final ValueChanged<_ChefSheetPage> onOpenPage;
  final String? selectedMode;
  final String? selectedVolume;
  final String? selectedCategory;
  final ValueChanged<String> onModeSelected;
  final ValueChanged<String> onVolumeSelected;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<CookingProgram> onSelectProgram;
  final ValueChanged<CookingProgram> onDeleteProgram;
  final VoidCallback onConfigureWifi;
  final VoidCallback onFirmwareUpdate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1D222C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
          children: [
            Center(
              child: Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (page != _ChefSheetPage.menu)
                  _SheetIconButton(icon: Icons.arrow_back, onTap: onBack),
                if (page != _ChefSheetPage.menu) const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    page.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _buildPage(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    return switch (page) {
      _ChefSheetPage.menu => _SheetPage(
        key: const ValueKey('menu'),
        children: [
          _MenuOption(
            title: 'Мои программы',
            icon: Icons.favorite_border,
            onTap: () => onOpenPage(_ChefSheetPage.myPrograms),
          ),
          _MenuOption(
            title: 'Готовые программы',
            icon: Icons.restaurant_menu,
            onTap: () => onOpenPage(_ChefSheetPage.readyModes),
          ),
          _MenuOption(
            title: 'Создать программу',
            icon: Icons.add_circle_outline,
            onTap: () => onOpenPage(_ChefSheetPage.createProgram),
          ),
          _MenuOption(
            title: 'Настроить Wi-Fi',
            icon: Icons.wifi,
            onTap: onConfigureWifi,
          ),
          _MenuOption(
            title: 'Обновить прошивку',
            icon: Icons.system_update,
            onTap: onFirmwareUpdate,
            enabled: !isSending,
          ),
        ],
      ),
      _ChefSheetPage.myPrograms => _MyProgramsPage(
        programs: myPrograms,
        onSelectProgram: onSelectProgram,
        onDeleteProgram: onDeleteProgram,
      ),
      _ChefSheetPage.createProgram => customProgram,
      _ChefSheetPage.readyModes => programs.when(
        data: (groups) => _SheetPage(
          key: const ValueKey('ready-modes'),
          children: [
            for (final group in groups)
              _MenuOption(
                title: group.mode,
                icon: Icons.restaurant_menu,
                onTap: () => onModeSelected(group.mode),
              ),
          ],
        ),
        error: (error, _) => Text('Ошибка программ: $error'),
        loading: () => const _ProgramsLoading(),
      ),
      _ChefSheetPage.readyVolumes => programs.when(
        data: (groups) {
          final group = groups
              .where((item) => item.mode == selectedMode)
              .firstOrNull;
          return _SheetPage(
            key: ValueKey('volumes-$selectedMode'),
            children: [
              for (final volume
                  in group?.volumes ?? const <ProgramVolumeGroup>[])
                _MenuOption(
                  title: volume.volumeGroup,
                  icon: Icons.inventory_2_outlined,
                  onTap: () => onVolumeSelected(volume.volumeGroup),
                ),
            ],
          );
        },
        error: (error, _) => Text('Ошибка программ: $error'),
        loading: () => const _ProgramsLoading(),
      ),
      _ChefSheetPage.readyCategories => programs.when(
        data: (groups) {
          final group = groups
              .where((item) => item.mode == selectedMode)
              .firstOrNull;
          final volume = group?.volumes
              .where((item) => item.volumeGroup == selectedVolume)
              .firstOrNull;
          return _SheetPage(
            key: ValueKey('categories-$selectedMode-$selectedVolume'),
            children: [
              for (final category
                  in volume?.categories ?? const <ProgramCategoryGroup>[])
                _MenuOption(
                  title: category.category,
                  icon: Icons.category_outlined,
                  onTap: () => onCategorySelected(category.category),
                ),
            ],
          );
        },
        error: (error, _) => Text('Ошибка программ: $error'),
        loading: () => const _ProgramsLoading(),
      ),
      _ChefSheetPage.readyDishes => programs.when(
        data: (groups) {
          final group = groups
              .where((item) => item.mode == selectedMode)
              .firstOrNull;
          final volume = group?.volumes
              .where((item) => item.volumeGroup == selectedVolume)
              .firstOrNull;
          final category = volume?.categories
              .where((item) => item.category == selectedCategory)
              .firstOrNull;
          return _SheetPage(
            key: ValueKey(
              'dishes-$selectedMode-$selectedVolume-$selectedCategory',
            ),
            children: [
              for (final program
                  in category?.programs ?? const <CookingProgram>[])
                _ProgramRow(
                  program: program,
                  onSelect: () => onSelectProgram(program),
                ),
            ],
          );
        },
        error: (error, _) => Text('Ошибка программ: $error'),
        loading: () => const _ProgramsLoading(),
      ),
    };
  }
}

class _MenuOption extends StatelessWidget {
  const _MenuOption({
    required this.title,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFF2A303B)
                : const Color(0xFF2A303B).withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(icon, color: enabled ? Colors.white : Colors.white38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: enabled ? Colors.white : Colors.white38,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: enabled ? Colors.white : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetIconButton extends StatelessWidget {
  const _SheetIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _SheetPage extends StatelessWidget {
  const _SheetPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}

class _MyProgramsPage extends StatelessWidget {
  const _MyProgramsPage({
    required this.programs,
    required this.onSelectProgram,
    required this.onDeleteProgram,
  });

  final List<CookingProgram> programs;
  final ValueChanged<CookingProgram> onSelectProgram;
  final ValueChanged<CookingProgram> onDeleteProgram;

  @override
  Widget build(BuildContext context) {
    if (programs.isNotEmpty) {
      return _SheetPage(
        key: const ValueKey('my-programs-list'),
        children: [
          for (final program in programs)
            _ProgramRow(
              program: program,
              onSelect: () => onSelectProgram(program),
              onDelete: () => onDeleteProgram(program),
            ),
        ],
      );
    }

    return Container(
      key: const ValueKey('my-programs'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2A303B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite_border, color: Color(0xFFEA6228)),
          const SizedBox(height: 12),
          const Text(
            'Мои программы',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Здесь появятся программы, которые вы сохраните через пункт “Создать программу”.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.64)),
          ),
        ],
      ),
    );
  }
}

class _CustomProgramCard extends StatelessWidget {
  const _CustomProgramCard({
    required this.name,
    required this.modeCode,
    required this.duration,
    required this.temperature,
    required this.isSending,
    required this.onModeChanged,
    required this.onDurationChanged,
    required this.onTemperatureChanged,
    required this.onSave,
  });

  final TextEditingController name;
  final int modeCode;
  final double duration;
  final double temperature;
  final bool isSending;
  final ValueChanged<int> onModeChanged;
  final ValueChanged<double> onDurationChanged;
  final ValueChanged<double> onTemperatureChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    const modes = ['На воде', 'На пару', 'Ретро-пакет', 'Су-вид'];
    return Card(
      key: const ValueKey('create-program'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Своя программа',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: modeCode,
              decoration: const InputDecoration(
                labelText: 'Режим приготовления',
              ),
              items: [
                for (var i = 0; i < modes.length; i++)
                  DropdownMenuItem(value: i, child: Text(modes[i])),
              ],
              onChanged: (value) {
                if (value != null) onModeChanged(value);
              },
            ),
            const SizedBox(height: 18),
            Text('Время: ${duration.round()} мин'),
            Slider(
              value: duration,
              min: 0,
              max: 120,
              divisions: 120,
              onChanged: onDurationChanged,
            ),
            const SizedBox(height: 8),
            Text('Температура: ${temperature.round()} C'),
            Slider(
              value: temperature,
              min: 20,
              max: 120,
              divisions: 100,
              onChanged: onTemperatureChanged,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSending ? null : onSave,
                icon: const Icon(Icons.save),
                label: const Text('Сохранить программу'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramRow extends StatelessWidget {
  const _ProgramRow({
    required this.program,
    required this.onSelect,
    this.onDelete,
  });

  final CookingProgram program;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A303B),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${program.durationMinutes} мин · ${program.temperatureCelsius} C',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
                ),
              ],
            ),
          ),
          if (onDelete != null) ...[
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              color: Colors.white70,
            ),
            const SizedBox(width: 8),
          ],
          FilledButton(onPressed: onSelect, child: const Text('Выбрать')),
        ],
      ),
    );
  }
}

class _ProgramsLoading extends StatelessWidget {
  const _ProgramsLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        LoadingSkeleton(height: 58),
        SizedBox(height: 10),
        LoadingSkeleton(height: 58),
        SizedBox(height: 10),
        LoadingSkeleton(height: 58),
      ],
    );
  }
}
