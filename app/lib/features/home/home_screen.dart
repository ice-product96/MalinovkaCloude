import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/device_status_text.dart';
import '../../shared/loading_skeleton.dart';
import '../devices/add_device_screen.dart';
import '../smart_chef/smart_chef_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(roomsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomsProvider);
    final appConfig = ref.watch(appConfigProvider);
    final api = ref.watch(apiClientProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: rooms.when(
        data: (items) {
          final backgroundImageUrl = appConfig.when(
            data: (config) => api.absoluteUrl(config.homeBackgroundUrl),
            error: (error, stackTrace) => _firstDeviceImage(items, api),
            loading: () => _firstDeviceImage(items, api),
          );
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HomeHero(
                  backgroundImageUrl: backgroundImageUrl,
                  onAddRoom: () => _showRoomDialog(context, ref),
                  onAddDevice: () => _push(context, const AddDeviceScreen()),
                ),
              ),
              SliverToBoxAdapter(
                child: _QuickFilters(
                  roomsCount: items.length,
                  devicesCount: items.fold<int>(
                    0,
                    (value, room) => value + room.devices.length,
                  ),
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Создайте первое помещение')),
                )
              else
                SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 22),
                  itemBuilder: (context, index) {
                    final room = items[index];
                    return DragTarget<Device>(
                      onWillAcceptWithDetails: (details) =>
                          details.data.roomId != room.id,
                      onAcceptWithDetails: (details) =>
                          _moveDevice(context, ref, details.data, room.id),
                      builder: (context, candidateDevices, rejectedDevices) {
                        return _RoomSection(
                          roomName: room.name,
                          isDragTargetActive: candidateDevices.isNotEmpty,
                          onEdit: () =>
                              _showRoomDialog(context, ref, room: room),
                          onDelete: () => _deleteRoom(context, ref, room),
                          children: [
                            ...room.devices.map(
                              (device) => _DraggableDeviceTile(
                                device: device,
                                title: device.name,
                                subtitle: _deviceSubtitle(device),
                                imageUrl: device.deviceType?.imageUrl == null
                                    ? null
                                    : api.absoluteUrl(
                                        device.deviceType!.imageUrl,
                                      ),
                                onTap: () => _push(
                                  context,
                                  SmartChefScreen(device: device),
                                ),
                                onDelete: () =>
                                    _deleteDevice(context, ref, device),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
        error: (error, _) => Center(child: Text('Ошибка загрузки: $error')),
        loading: () => const _HomeLoadingState(),
      ),
    );
  }

  Future<void> _push(BuildContext context, Widget screen) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => screen));
    ref.invalidate(roomsProvider);
  }

  String _deviceSubtitle(Device device) {
    final state = device.lastState;
    final status = state['status'];
    final isActive = isDeviceStatusActive(status);
    if (isActive) {
      final temperature = state['temperature'];
      final timeEnd = state['timeend'];
      final parts = [
        'Работает',
        if (temperature != null) '$temperature C',
        if (timeEnd != null) 'осталось $timeEnd',
      ];
      return parts.join(' - ');
    }
    final statusText = deviceStatusText(status);
    if (statusText != 'Нет данных' && statusText != 'Ожидает') {
      return 'Статус: $statusText';
    }
    return device.connectionMode == 'wifi'
        ? 'Подключено через интернет'
        : 'Локальное подключение';
  }

  String? _firstDeviceImage(List<dynamic> rooms, dynamic api) {
    for (final room in rooms) {
      for (final device in room.devices) {
        final image = device.deviceType?.imageUrl;
        if (image != null) return api.absoluteUrl(image);
      }
    }
    return null;
  }

  Future<void> _showRoomDialog(
    BuildContext context,
    WidgetRef ref, {
    Room? room,
  }) async {
    final controller = TextEditingController(text: room?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF202631),
        title: Text(room == null ? 'Новое помещение' : 'Переименовать'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(room == null ? 'Создать' : 'Сохранить'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    if (room == null) {
      await ref.read(apiClientProvider).createRoom(name.trim());
    } else {
      await ref.read(apiClientProvider).updateRoom(room.id, name.trim());
    }
    ref.invalidate(roomsProvider);
  }

  Future<void> _deleteRoom(
    BuildContext context,
    WidgetRef ref,
    Room room,
  ) async {
    if (room.devices.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала перенесите устройства в другое помещение'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF202631),
        title: const Text('Удалить помещение?'),
        content: Text('Помещение "${room.name}" будет удалено.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(apiClientProvider).deleteRoom(room.id);
    ref.invalidate(roomsProvider);
  }

  Future<void> _moveDevice(
    BuildContext context,
    WidgetRef ref,
    Device device,
    int roomId,
  ) async {
    try {
      await ref.read(apiClientProvider).updateDeviceRoom(device.id, roomId);
      ref.invalidate(roomsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Устройство перенесено')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось перенести: $error')));
    }
  }

  Future<void> _deleteDevice(
    BuildContext context,
    WidgetRef ref,
    Device device,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF202631),
        title: const Text('Удалить устройство?'),
        content: Text('Устройство "${device.name}" будет удалено из дома.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(apiClientProvider).deleteDevice(device.id);
      ref.invalidate(roomsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Устройство удалено')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось удалить: $error')));
    }
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.backgroundImageUrl,
    required this.onAddRoom,
    required this.onAddDevice,
  });

  final String? backgroundImageUrl;
  final VoidCallback onAddRoom;
  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      padding: const EdgeInsets.fromLTRB(18, 52, 18, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF252130), Color(0xFF151922)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: backgroundImageUrl == null
                  ? const _AbstractRoomBackground()
                  : CachedNetworkImage(
                      key: ValueKey(backgroundImageUrl),
                      imageUrl: backgroundImageUrl!,
                      cacheKey: backgroundImageUrl,
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.35),
                      colorBlendMode: BlendMode.darken,
                      placeholder: (context, url) =>
                          const LoadingSkeleton(height: 266, borderRadius: 34),
                      errorWidget: (context, url, error) =>
                          const _AbstractRoomBackground(),
                    ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.66),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Мой дом',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _HeroActionChip(
                      icon: Icons.add_home,
                      label: 'Помещение',
                      onTap: onAddRoom,
                    ),
                    _HeroActionChip(
                      icon: Icons.bluetooth_searching,
                      label: 'Устройство',
                      onTap: onAddDevice,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AbstractRoomBackground extends StatelessWidget {
  const _AbstractRoomBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.15, -0.35),
          radius: 1.1,
          colors: [Color(0xFF4C3B48), Color(0xFF151922)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 34,
            top: 88,
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 30,
            top: 62,
            child: Icon(
              Icons.kitchen,
              size: 120,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 42,
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionChip extends StatelessWidget {
  const _HeroActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, color: const Color(0xFFEA6228), size: 20),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: const Color(0xFF2A303B),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}

class _QuickFilters extends StatelessWidget {
  const _QuickFilters({required this.roomsCount, required this.devicesCount});

  final int roomsCount;
  final int devicesCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterPill(
              icon: Icons.wifi_off,
              title: 'Не в сети',
              subtitle: '$devicesCount устр',
            ),
            const SizedBox(width: 10),
            _FilterPill(
              icon: Icons.lightbulb_outline,
              title: 'Помещения',
              subtitle: '$roomsCount комн',
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A303B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.56)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomSection extends StatelessWidget {
  const _RoomSection({
    required this.roomName,
    required this.children,
    required this.onEdit,
    required this.onDelete,
    required this.isDragTargetActive,
  });

  final String roomName;
  final List<Widget> children;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDragTargetActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDragTargetActive
            ? const Color(0xFFEA6228).withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDragTargetActive
              ? const Color(0xFFEA6228)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  roomName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                color: Colors.white70,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth > 540
                  ? (constraints.maxWidth - 36) / 4
                  : (constraints.maxWidth - 12) / 2;
              if (children.isEmpty) {
                return Container(
                  width: double.infinity,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A303B),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    'Перетащите устройство сюда',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final child in children)
                    SizedBox(width: itemWidth, height: 156, child: child),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A303B),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: imageUrl == null
                      ? Icon(
                          Icons.kitchen,
                          size: 54,
                          color: Colors.white.withValues(alpha: 0.72),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 62,
                            padding: const EdgeInsets.all(6),
                            color: Colors.white.withValues(alpha: 0.06),
                            alignment: Alignment.center,
                            child: CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.contain,
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.kitchen),
                            ),
                          ),
                        ),
                ),
                IconButton(
                  tooltip: 'Удалить устройство',
                  onPressed: onDelete,
                  icon: const Icon(Icons.close),
                  color: Colors.white70,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.56)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggableDeviceTile extends StatelessWidget {
  const _DraggableDeviceTile({
    required this.device,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
    required this.onDelete,
  });

  final Device device;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tile = _DeviceTile(
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      onTap: onTap,
      onDelete: onDelete,
    );
    return LongPressDraggable<Device>(
      data: device,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 170,
          height: 156,
          child: Opacity(opacity: 0.92, child: tile),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 52, 18, 22),
            child: LoadingSkeleton(height: 266, borderRadius: 34),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
            child: Row(
              children: const [
                LoadingSkeleton(width: 128, height: 62, borderRadius: 20),
                SizedBox(width: 10),
                LoadingSkeleton(width: 128, height: 62, borderRadius: 20),
                SizedBox(width: 10),
                LoadingSkeleton(width: 128, height: 62, borderRadius: 20),
              ],
            ),
          ),
        ),
        SliverList.separated(
          itemCount: 2,
          separatorBuilder: (context, index) => const SizedBox(height: 24),
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LoadingSkeleton(width: 150, height: 26, borderRadius: 10),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Expanded(child: LoadingSkeleton(height: 156)),
                    SizedBox(width: 12),
                    Expanded(child: LoadingSkeleton(height: 156)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
