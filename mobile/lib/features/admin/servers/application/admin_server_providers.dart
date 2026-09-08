import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_providers.dart';
import '../../../catalog/data/server_model.dart';
import '../data/admin_server_contracts.dart';
import '../data/admin_server_repository.dart';

final adminServerRepositoryProvider = Provider<AdminServerRepository>(
  (ref) => AdminServerRepository(ref.watch(authenticatedDioProvider)),
);

final adminServersProvider = FutureProvider.autoDispose<List<ServerModel>>(
  (ref) => ref.watch(adminServerRepositoryProvider).getServers(),
);

final adminServerProvider = FutureProvider.autoDispose.family<ServerModel, int>(
  (ref, serverId) =>
      ref.watch(adminServerRepositoryProvider).getServer(serverId),
);

final adminServerMaintenanceProvider = FutureProvider.autoDispose
    .family<List<AdminMaintenanceWindow>, int>(
      (ref, serverId) =>
          ref.watch(adminServerRepositoryProvider).getMaintenance(serverId),
    );
