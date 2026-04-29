import 'package:go_router/go_router.dart';

import '../features/devices/add_device_screen.dart';
import '../features/home/home_screen.dart';
import '../features/smart_chef/smart_chef_screen.dart';
import 'models.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/add-device',
      builder: (context, state) => const AddDeviceScreen(),
    ),
    GoRoute(
      path: '/devices/:id',
      builder: (context, state) {
        final device = state.extra;
        if (device is Device) return SmartChefScreen(device: device);
        return const HomeScreen();
      },
    ),
  ],
);
