class PollOption {
  final String id;
  final String optionText;
  final int voteCount;

  PollOption({
    required this.id,
    required this.optionText,
    this.voteCount = 0,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'].toString(),
      optionText: (json['option_text'] ?? json['text'] ?? '') as String,
      voteCount: json['vote_count'] as int? ?? 0,
    );
  }
}

class MessagePoll {
  final String messageId;
  final String question;
  final bool isMultipleChoice;
  final List<PollOption> options;
  final List<String> myVoteOptionIds;

  MessagePoll({
    required this.messageId,
    required this.question,
    this.isMultipleChoice = false,
    this.options = const [],
    this.myVoteOptionIds = const [],
  });

  factory MessagePoll.fromJson(Map<String, dynamic> json) {
    final options =
        (json['options'] as List<dynamic>?)
            ?.map((o) => PollOption.fromJson(o as Map<String, dynamic>))
            .toList() ??
        [];
    final myVotes =
        (json['my_vote_option_ids'] as List<dynamic>?)
            ?.map((id) => id.toString())
            .toList() ??
        [];
    return MessagePoll(
      messageId: json['message_id']?.toString() ?? '',
      question: (json['question'] ?? '') as String,
      isMultipleChoice: json['is_multiple_choice'] == true,
      options: options,
      myVoteOptionIds: myVotes,
    );
  }

  int get totalVotes =>
      options.fold<int>(0, (sum, option) => sum + option.voteCount);
}

class CreatePollRequest {
  final String question;
  final List<String> options;
  final bool isMultipleChoice;

  const CreatePollRequest({
    required this.question,
    required this.options,
    this.isMultipleChoice = false,
  });
}
