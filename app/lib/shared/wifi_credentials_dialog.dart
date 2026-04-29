import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../core/wifi_credentials_store.dart';

Future<WifiCredentials?> showWifiCredentialsDialog({
  required BuildContext context,
  required String title,
  required List<WifiCredentials> savedNetworks,
  required String helperText,
  bool allowEmptySsid = false,
  String confirmText = 'Сохранить',
}) {
  final initial = savedNetworks.firstOrNull;
  return showDialog<WifiCredentials>(
    context: context,
    builder: (context) => _WifiCredentialsDialog(
      title: title,
      savedNetworks: savedNetworks,
      initial: initial,
      helperText: helperText,
      allowEmptySsid: allowEmptySsid,
      confirmText: confirmText,
    ),
  );
}

class _WifiCredentialsDialog extends StatefulWidget {
  const _WifiCredentialsDialog({
    required this.title,
    required this.savedNetworks,
    required this.initial,
    required this.helperText,
    required this.allowEmptySsid,
    required this.confirmText,
  });

  final String title;
  final List<WifiCredentials> savedNetworks;
  final WifiCredentials? initial;
  final String helperText;
  final bool allowEmptySsid;
  final String confirmText;

  @override
  State<_WifiCredentialsDialog> createState() => _WifiCredentialsDialogState();
}

class _WifiCredentialsDialogState extends State<_WifiCredentialsDialog> {
  late final TextEditingController _ssid;
  late final TextEditingController _password;
  var _availableSsids = const <String>[];
  var _isScanning = true;
  String? _scanMessage;

  @override
  void initState() {
    super.initState();
    _ssid = TextEditingController(text: widget.initial?.ssid ?? '');
    _password = TextEditingController(text: widget.initial?.password ?? '');
    _loadAvailableNetworks();
  }

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkOptions =
        [
            ..._availableSsids,
            for (final network in widget.savedNetworks) network.ssid,
          ].where((ssid) => ssid.isNotEmpty).toSet().toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: networkOptions.contains(_ssid.text)
                  ? _ssid.text
                  : null,
              decoration: InputDecoration(
                labelText: 'Доступная Wi-Fi сеть',
                suffixIcon: _isScanning
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Обновить список',
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadAvailableNetworks,
                      ),
              ),
              items: [
                for (final ssid in networkOptions)
                  DropdownMenuItem(value: ssid, child: Text(ssid)),
              ],
              onChanged: (value) {
                if (value == null) return;
                _applySsid(value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ssid,
              decoration: const InputDecoration(
                labelText: 'SSID вручную',
                hintText: 'Можно выбрать из списка выше',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
            ),
            if (_scanMessage != null) ...[
              const SizedBox(height: 8),
              Text(_scanMessage!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(widget.helperText),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmText)),
      ],
    );
  }

  Future<void> _loadAvailableNetworks() async {
    setState(() {
      _isScanning = true;
      _scanMessage = null;
    });
    try {
      final canStart = await WiFiScan.instance.canStartScan(
        askPermissions: true,
      );
      if (canStart == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        await Future<void>.delayed(const Duration(milliseconds: 800));
      } else {
        _scanMessage = _messageForScanStatus(canStart);
      }

      final canGetResults = await WiFiScan.instance.canGetScannedResults(
        askPermissions: true,
      );
      if (canGetResults == CanGetScannedResults.yes) {
        final accessPoints = await WiFiScan.instance.getScannedResults();
        _availableSsids = accessPoints
            .map((accessPoint) => accessPoint.ssid)
            .where((ssid) => ssid.isNotEmpty)
            .toSet()
            .toList();
        if (_availableSsids.isEmpty && _scanMessage == null) {
          _scanMessage = 'Сети рядом не найдены. SSID можно ввести вручную.';
        }
      } else {
        _scanMessage ??= _messageForResultsStatus(canGetResults);
      }
    } catch (_) {
      _scanMessage =
          'Не удалось получить список Wi-Fi. SSID можно ввести вручную.';
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _applySsid(String ssid) {
    final saved = widget.savedNetworks
        .where((network) => network.ssid == ssid)
        .firstOrNull;
    setState(() {
      _ssid.text = ssid;
      if (saved != null) _password.text = saved.password;
    });
  }

  void _submit() {
    final ssid = _ssid.text.trim();
    if (!widget.allowEmptySsid && ssid.isEmpty) return;
    Navigator.pop(
      context,
      WifiCredentials(ssid: ssid, password: _password.text),
    );
  }

  String _messageForScanStatus(CanStartScan status) {
    return switch (status) {
      CanStartScan.notSupported =>
        'Сканирование Wi-Fi не поддерживается на этом устройстве.',
      CanStartScan.noLocationPermissionRequired ||
      CanStartScan.noLocationPermissionDenied =>
        'Разрешите геолокацию, чтобы увидеть доступные Wi-Fi сети.',
      CanStartScan.noLocationPermissionUpgradeAccuracy =>
        'Для списка Wi-Fi нужна точная геолокация.',
      CanStartScan.noLocationServiceDisabled =>
        'Включите геолокацию, чтобы увидеть доступные Wi-Fi сети.',
      CanStartScan.failed => 'Не удалось запустить сканирование Wi-Fi.',
      CanStartScan.yes => '',
    };
  }

  String _messageForResultsStatus(CanGetScannedResults status) {
    return switch (status) {
      CanGetScannedResults.notSupported =>
        'Список Wi-Fi не поддерживается на этом устройстве.',
      CanGetScannedResults.noLocationPermissionRequired ||
      CanGetScannedResults.noLocationPermissionDenied =>
        'Разрешите геолокацию, чтобы увидеть доступные Wi-Fi сети.',
      CanGetScannedResults.noLocationPermissionUpgradeAccuracy =>
        'Для списка Wi-Fi нужна точная геолокация.',
      CanGetScannedResults.noLocationServiceDisabled =>
        'Включите геолокацию, чтобы увидеть доступные Wi-Fi сети.',
      CanGetScannedResults.yes => '',
    };
  }
}
