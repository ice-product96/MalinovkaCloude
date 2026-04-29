import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'catalog_cache.dart';
import 'models.dart';
import 'user_program_store.dart';
import 'wifi_credentials_store.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final catalogCacheProvider = FutureProvider<CatalogCache>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return CatalogCache(preferences);
});

final wifiCredentialsStoreProvider = FutureProvider<WifiCredentialsStore>((
  ref,
) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return WifiCredentialsStore(preferences);
});

final userProgramStoreProvider = FutureProvider<UserProgramStore>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return UserProgramStore(preferences);
});

final deviceTypesProvider = FutureProvider<List<DeviceType>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final cache = await ref.watch(catalogCacheProvider.future);
  try {
    final raw = await api.fetchDeviceTypesJson();
    await cache.saveDeviceTypes(raw);
    return raw
        .map(
          (item) => DeviceType.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  } catch (_) {
    final cached = cache.readDeviceTypes();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});

final appConfigProvider = FutureProvider<AppConfig>((ref) {
  return ref.watch(apiClientProvider).fetchAppConfig();
});

final roomsProvider = FutureProvider<List<Room>>((ref) {
  return ref.watch(apiClientProvider).fetchRooms();
});

final programsProvider = FutureProvider.family<List<ProgramModeGroup>, String>((
  ref,
  deviceTypeId,
) {
  return ref.watch(apiClientProvider).fetchPrograms(deviceTypeId);
});
