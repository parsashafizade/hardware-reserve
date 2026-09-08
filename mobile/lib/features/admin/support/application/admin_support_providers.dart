import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_providers.dart';
import '../../../support/application/support_providers.dart';
import '../data/admin_support_repository.dart';
import 'admin_support_conversation_controller.dart';
import 'admin_support_inbox_controller.dart';
import 'admin_support_quick_replies_controller.dart';

final adminSupportRepositoryProvider = Provider<AdminSupportRepository>(
  (ref) => AdminSupportRepository(ref.watch(authenticatedDioProvider)),
);

final adminSupportInboxControllerProvider =
    StateNotifierProvider.autoDispose<
      AdminSupportInboxController,
      AdminSupportInboxState
    >((ref) {
      final controller = AdminSupportInboxController(
        ref.watch(adminSupportRepositoryProvider),
        ref.watch(supportRealtimeServiceProvider),
      );
      unawaited(controller.initialize());
      return controller;
    });

final adminSupportConversationControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      AdminSupportConversationController,
      AdminSupportConversationState,
      String
    >((ref, conversationId) {
      final controller = AdminSupportConversationController(
        conversationId: conversationId,
        repository: ref.watch(adminSupportRepositoryProvider),
        realtime: ref.watch(supportRealtimeServiceProvider),
        createClientMessageId: const Uuid().v4,
      );
      unawaited(controller.initialize());
      return controller;
    });

final adminSupportQuickRepliesControllerProvider =
    StateNotifierProvider.autoDispose<
      AdminSupportQuickRepliesController,
      AdminSupportQuickRepliesState
    >((ref) {
      final controller = AdminSupportQuickRepliesController(
        ref.watch(adminSupportRepositoryProvider),
      );
      unawaited(controller.initialize());
      return controller;
    });
