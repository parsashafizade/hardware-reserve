import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_providers.dart';
import '../realtime/support_realtime_service.dart';
import 'support_conversation_controller.dart';
import 'support_history_controller.dart';

final supportRealtimeServiceProvider =
    Provider.autoDispose<SupportRealtimeService>((ref) {
      final sessionIdentity = ref.watch(
        authControllerProvider.select(
          (state) =>
              (state.phase, state.session?.user.id, state.session?.user.role),
        ),
      );
      final auth = ref.watch(authControllerProvider.notifier);
      final service = SupportRealtimeService(
        hubUrl: '${AppConfig.apiBaseUrl}/hubs/support',
        accessTokenFactory: () => sessionIdentity.$2 == null
            ? Future<String?>.value()
            : auth.validAccessToken(),
      );

      ref.onDispose(() => unawaited(service.dispose()));
      return service;
    });

final supportHistoryControllerProvider =
    StateNotifierProvider.autoDispose<
      SupportHistoryController,
      SupportHistoryState
    >((ref) {
      final controller = SupportHistoryController(
        ref.watch(supportRepositoryProvider),
        ref.watch(supportRealtimeServiceProvider),
        receivesAdminBroadcasts: ref.watch(
          authControllerProvider.select(
            (state) => state.session?.user.isAdmin ?? false,
          ),
        ),
      );
      unawaited(controller.initialize());
      return controller;
    });

final supportConversationControllerProvider = StateNotifierProvider.autoDispose
    .family<SupportConversationController, SupportConversationState, String>((
      ref,
      conversationId,
    ) {
      final controller = SupportConversationController(
        conversationId: conversationId,
        repository: ref.watch(supportRepositoryProvider),
        realtime: ref.watch(supportRealtimeServiceProvider),
        createClientMessageId: const Uuid().v4,
      );
      unawaited(controller.initialize());
      return controller;
    });
