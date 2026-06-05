import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';

const int kFlairNameMaxLength = 50;
const String kAdminFlairName = 'Admin';

bool isAdminFlair(Flair flair) =>
    flair.name.toLowerCase() == kAdminFlairName.toLowerCase();

/// Bottom sheet for toggling flairs and creating new group flairs.
class GroupFlairsSheet extends StatefulWidget {
  const GroupFlairsSheet({
    super.key,
    required this.groupId,
    required this.member,
    required this.availableFlairs,
    required this.onUpdated,
  });

  final String groupId;
  final Profile member;
  final List<Flair> availableFlairs;
  final VoidCallback onUpdated;

  @override
  State<GroupFlairsSheet> createState() => _GroupFlairsSheetState();
}

class _GroupFlairsSheetState extends State<GroupFlairsSheet> {
  late Set<String> _myFlairIds;
  late List<Flair> _flairs;
  bool _showCreateField = false;
  bool _isCreating = false;
  final _createController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _flairs = List<Flair>.from(widget.availableFlairs);
    _myFlairIds = widget.member.flairs.map((f) => f.id).toSet();
  }

  Future<void> _refreshFlairs() async {
    final flairs = await AuthService.instance.getGroupFlairs(widget.groupId);
    final members = await AuthService.instance.getGroupMembers(widget.groupId);
    final me = members.firstWhere(
      (m) => m.id == widget.member.id,
      orElse: () => widget.member,
    );
    if (!mounted) return;
    setState(() {
      _flairs = flairs;
      _myFlairIds = me.flairs.map((f) => f.id).toSet();
    });
    widget.onUpdated();
  }

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  List<Flair> get _assignableFlairs =>
      _flairs.where((f) => !isAdminFlair(f)).toList();

  List<Flair> get _adminFlairs =>
      widget.member.flairs.where(isAdminFlair).toList();

  Future<void> _toggleFlair(Flair flair, bool assign) async {
    try {
      if (assign) {
        await AuthService.instance.assignGroupFlair(
          groupId: widget.groupId,
          flairId: flair.id,
        );
        _myFlairIds.add(flair.id);
      } else {
        await AuthService.instance.removeGroupFlair(
          groupId: widget.groupId,
          flairId: flair.id,
        );
        _myFlairIds.remove(flair.id);
      }
      if (mounted) {
        await _refreshFlairs();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _createFlair() async {
    final name = _createController.text.trim();
    if (name.isEmpty) return;
    if (name.length > kFlairNameMaxLength) return;

    setState(() => _isCreating = true);
    try {
      final flair = await AuthService.instance.addGroupFlair(
        widget.groupId,
        name,
      );
      await AuthService.instance.assignGroupFlair(
        groupId: widget.groupId,
        flairId: flair.id,
      );
      _myFlairIds.add(flair.id);
      _createController.clear();
      if (mounted) {
        setState(() {
          _showCreateField = false;
          _isCreating = false;
        });
        await _refreshFlairs();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = kFlairNameMaxLength - _createController.text.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your flairs',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Create flair',
                  onPressed: _isCreating
                      ? null
                      : () => setState(
                          () => _showCreateField = !_showCreateField,
                        ),
                  icon: Icon(
                    _showCreateField ? Icons.close : Icons.add,
                  ),
                ),
              ],
            ),
            if (_showCreateField) ...[
              TextField(
                controller: _createController,
                maxLength: kFlairNameMaxLength,
                decoration: InputDecoration(
                  labelText: 'New flair',
                  hintText: 'e.g. Photographer',
                  counterText: '$remaining characters left',
                ),
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _isCreating ? null : _createFlair,
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create & wear'),
              ),
              const SizedBox(height: 16),
            ],
            if (_adminFlairs.isNotEmpty) ...[
              Text(
                'Auto-assigned',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ..._adminFlairs.map(
                (flair) => ListTile(
                  enabled: false,
                  leading: Icon(
                    Icons.shield_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(flair.name),
                  subtitle: const Text('Cannot be changed manually'),
                  trailing: const Icon(Icons.lock_outline, size: 18),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_assignableFlairs.isEmpty && _adminFlairs.isEmpty)
              const Text('No flairs yet. Tap + to create one.')
            else
              ..._assignableFlairs.map((flair) {
                final selected = _myFlairIds.contains(flair.id);
                return CheckboxListTile(
                  value: selected,
                  title: Text(flair.name),
                  subtitle: flair.groupId == null
                      ? const Text('Global flair')
                      : const Text('Group flair'),
                  onChanged: (checked) {
                    if (checked == null) return;
                    _toggleFlair(flair, checked);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}
