import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../data/notification_repository.dart';
import 'activity_controller.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(authenticatedDioProvider)),
);

final activityControllerProvider =
    StateNotifierProvider.autoDispose<ActivityController, ActivityState>((ref) {
      final controller = ActivityController(
        ref.watch(notificationRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });
