import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../models/poll.dart';
import '../../widgets/mitron_icons.dart';
import '../../widgets/poll_option_indicator.dart';

class PollMessageBubble extends StatelessWidget {
  const PollMessageBubble({
    super.key,
    required this.message,
    required this.poll,
    required this.isMe,
    required this.senderLabel,
    required this.onVote,
    this.isSelected = false,
    this.onLongPress,
  });

  final Message message;
  final MessagePoll poll;
  final bool isMe;
  final String senderLabel;
  final void Function(String optionId) onVote;
  final bool isSelected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalVotes = poll.totalVotes;

    final bubbleColor = scheme.surfaceContainerHighest;
    final primaryTextColor = scheme.onSurface;
    final secondaryTextColor = scheme.onSurfaceVariant;
    final accentColor = scheme.onSurface.withValues(alpha: 0.55);
    final optionFill = scheme.primary.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                senderLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.85,
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(MitronIcons.poll, size: 18, color: accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          poll.question,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: primaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (poll.isMultipleChoice)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Tap to select · tap again to remove',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  ...poll.options.map((option) {
                    final selected =
                        poll.myVoteOptionIds.contains(option.id);
                    final fraction = totalVotes == 0
                        ? 0.0
                        : option.voteCount / totalVotes;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onVote(option.id),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                Container(
                                  height: 40,
                                  color: scheme.surface.withValues(alpha: 0.5),
                                ),
                                FractionallySizedBox(
                                  widthFactor: fraction.clamp(0.0, 1.0),
                                  child: Container(
                                    height: 40,
                                    color: optionFill,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      PollOptionIndicator(
                                        selected: selected,
                                        multiple: poll.isMultipleChoice,
                                        color: accentColor,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          option.optionText,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: primaryTextColor,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${option.voteCount}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  Text(
                    '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CreatePollSheet extends StatefulWidget {
  const CreatePollSheet({super.key});

  @override
  State<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<CreatePollSheet> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _multipleChoice = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 8) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _submit() {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a poll question')),
      );
      return;
    }
    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least two options')),
      );
      return;
    }
    Navigator.pop(
      context,
      CreatePollRequest(
        question: question,
        options: options,
        isMultipleChoice: _multipleChoice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create poll',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'What should we decide?',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _optionControllers[index],
                  decoration: InputDecoration(
                    labelText: 'Option ${index + 1}',
                  ),
                ),
              );
            }),
            TextButton.icon(
              onPressed: _optionControllers.length < 8 ? _addOption : null,
              icon: const Icon(Icons.add),
              label: const Text('Add option'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow multiple choices'),
              value: _multipleChoice,
              onChanged: (v) => setState(() => _multipleChoice = v),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _submit, child: const Text('Post poll')),
          ],
        ),
      ),
    );
  }
}
