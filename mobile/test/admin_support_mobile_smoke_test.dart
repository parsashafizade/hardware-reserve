import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/localization/app_localizations.dart';
import 'package:hardware_reserve/core/theme/app_theme.dart';
import 'package:hardware_reserve/features/admin/support/application/admin_support_providers.dart';
import 'package:hardware_reserve/features/admin/support/data/admin_support_models.dart';
import 'package:hardware_reserve/features/admin/support/data/admin_support_repository.dart';
import 'package:hardware_reserve/features/admin/support/presentation/admin_support_conversation_screen.dart';
import 'package:hardware_reserve/features/support/application/support_providers.dart';
import 'package:hardware_reserve/features/support/data/support_models.dart';
import 'package:hardware_reserve/features/support/realtime/support_realtime_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Admin support composer fits a compact Persian view with keyboard and AI draft',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);

      final repository = _SupportSmokeRepository();
      final realtime = _SupportSmokeRealtimeService();
      addTearDown(realtime.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminSupportRepositoryProvider.overrideWithValue(repository),
            supportRealtimeServiceProvider.overrideWithValue(realtime),
          ],
          child: MaterialApp(
            locale: const Locale('fa', 'IR'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.light(const Locale('fa', 'IR')),
            home: const AdminSupportConversationScreen(
              conversationId: 'conversation-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('پیشنهاد پاسخ'));
      await tester.pumpAndSettle();
      expect(find.text('پیشنهاد دستیار هوشمند'), findsOneWidget);
      expect(find.text(_suggestion), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();

      expect(find.text('این متن خودکار ارسال نمی‌شود.'), findsOneWidget);
      expect(find.text('انتقال به ویرایشگر'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

const _suggestion =
    'لطفاً reservation ID: HR-20491 و IP 192.168.1.20 را بررسی کنید.';

class _SupportSmokeRepository extends AdminSupportRepository {
  _SupportSmokeRepository() : super(Dio());

  @override
  Future<AdminSupportMessageHistory> getMessages(
    String conversationId, {
    String? cursor,
    int pageSize = 50,
  }) async {
    return AdminSupportMessageHistory(
      conversation: _conversation,
      messages: const CursorPage<SupportMessage>(
        items: <SupportMessage>[],
        nextCursor: null,
        hasMore: false,
      ),
    );
  }

  @override
  Future<CursorPage<AdminSupportConversationEvent>> getEvents(
    String conversationId, {
    String? cursor,
    int pageSize = 30,
  }) async {
    return const CursorPage<AdminSupportConversationEvent>(
      items: <AdminSupportConversationEvent>[],
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<AdminSupportSuggestedReply> generateSuggestedReply(
    String conversationId,
  ) async {
    return AdminSupportSuggestedReply(
      draft: _suggestion,
      generatedAt: DateTime.utc(2026, 8, 22),
    );
  }
}

class _SupportSmokeRealtimeService extends SupportRealtimeService {
  _SupportSmokeRealtimeService()
    : super(
        hubUrl: 'https://api.example.com/hubs/support',
        accessTokenFactory: () async => 'access-token',
      );

  @override
  bool get isConnected => true;

  @override
  Future<void> start() async {}

  @override
  Future<void> subscribeToConversation(String conversationId) async {}

  @override
  Future<void> unsubscribeFromConversation(String conversationId) async {}
}

final _conversation = AdminSupportConversation(
  summary: SupportConversation(
    id: 'conversation-1',
    title: 'پیگیری رزرو HR-20491',
    category: 'Technical',
    status: SupportConversationStatus.adminActive,
    isAnonymous: false,
    unreadCount: 0,
    createdAt: DateTime.utc(2026, 8, 22, 8),
    updatedAt: DateTime.utc(2026, 8, 22, 8, 5),
    resolvedAt: null,
    closedAt: null,
    lastMessage: null,
  ),
  owner: const AdminSupportOwner(
    type: AdminSupportOwnerType.user,
    userId: 42,
    fullName: 'کاربر تست',
    email: 'user@example.com',
  ),
  isAssignedToCurrentAdmin: true,
  isAssigned: true,
  aiHandoffSummary: null,
  aiHandoffReason: null,
  aiHandoffGeneratedAt: null,
);
