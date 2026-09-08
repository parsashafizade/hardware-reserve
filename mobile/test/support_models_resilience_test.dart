import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/features/support/application/support_conversation_controller.dart';
import 'package:hardware_reserve/features/support/data/support_models.dart';

void main() {
  test('unknown support status is preserved as a fail-closed value', () {
    final conversation = SupportConversation.fromJson(<String, Object?>{
      'id': 'conversation-1',
      'title': 'Support',
      'category': null,
      'status': 'FUTURE_BACKEND_STATUS',
      'isAnonymous': false,
      'unreadCount': 0,
      'createdAt': '2026-08-22T10:00:00Z',
      'updatedAt': '2026-08-22T10:00:00Z',
      'resolvedAt': null,
      'closedAt': null,
      'lastMessage': null,
    });

    expect(conversation.status, SupportConversationStatus.unknown);
    expect(
      SupportConversationState(conversation: conversation).acceptsMessages,
      isFalse,
    );
    expect(
      SupportConversationStatus.fromWireValue('ADMIN_ACTIVE'),
      SupportConversationStatus.adminActive,
    );
  });

  test(
    'unknown support participant is never misattributed to a user or Admin',
    () {
      final message = SupportMessage.fromJson(<String, Object?>{
        'id': 'message-1',
        'conversationId': 'conversation-1',
        'sequenceNumber': 1,
        'senderType': 'SYSTEM_AUTOMATION',
        'senderDisplayName': 'System',
        'content': 'State updated.',
        'contentFormat': 'PLAIN_TEXT',
        'createdAt': '2026-08-22T10:00:00Z',
      });

      expect(message.senderType, SupportParticipantType.unknown);
      expect(message.senderType, isNot(SupportParticipantType.user));
      expect(message.senderType, isNot(SupportParticipantType.admin));
      expect(
        SupportParticipantType.fromWireValue('AI'),
        SupportParticipantType.ai,
      );
    },
  );
}
