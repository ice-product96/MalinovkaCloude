String deviceStatusText(Object? rawStatus) {
  final raw = '$rawStatus'.trim();
  final status = raw.toLowerCase();
  if (raw.isEmpty || status == 'null') return 'Нет данных';
  if (_hasCyrillic(raw)) return raw;

  return switch (status) {
    'work' || 'working' || 'run' || 'running' => 'Работает',
    'stop' || 'stopped' => 'Остановлено',
    'idle' => 'Ожидает',
    'ready' => 'Готово',
    'done' || 'finished' || 'complete' || 'completed' => 'Завершено',
    'pause' || 'paused' => 'Пауза',
    'wait' || 'waiting' => 'Ожидание',
    'heat' || 'heating' || 'preheat' || 'preheating' || 'warmup' => 'Нагрев',
    'blow' || 'blowing' || 'purge' || 'purging' => 'Продувка',
    'cool' || 'cooling' => 'Остывание',
    'error' || 'failed' || 'failure' => 'Ошибка',
    'offline' || 'disconnected' => 'Нет связи',
    'online' || 'connected' => 'На связи',
    'on' => 'Включено',
    'off' => 'Выключено',
    _ => 'Неизвестное состояние',
  };
}

bool isDeviceStatusActive(Object? rawStatus) {
  final status = '$rawStatus'.trim().toLowerCase();
  if (status.contains('разогрев') ||
      status.contains('нагрев') ||
      status.contains('работ') ||
      status.contains('продув')) {
    return true;
  }
  return status == 'work' ||
      status == 'working' ||
      status == 'run' ||
      status == 'running' ||
      status == 'heat' ||
      status == 'heating' ||
      status == 'preheat' ||
      status == 'preheating' ||
      status == 'warmup' ||
      status == 'blow' ||
      status == 'blowing' ||
      status == 'purge' ||
      status == 'purging';
}

bool _hasCyrillic(String value) {
  return RegExp('[А-Яа-яЁё]').hasMatch(value);
}
