import 'message.dart';

class MessagePageResult {
  const MessagePageResult({
    required this.messages,
    required this.hasMore,
  });

  final List<Message> messages;
  final bool hasMore;
}
