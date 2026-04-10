// frontend/lib/features/users/profile/user_profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mitron/models/profile.dart';
import 'package:mitron/services/auth_service.dart';
import 'package:mitron/services/cache_service.dart';
import '../../settings/update_profile_page.dart';

class UserProfilePage extends StatefulWidget {
  final String username;
  const UserProfilePage({super.key, required this.username});

  static const routeName = '/user-profile';

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Profile? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await AuthService.instance.getUserProfile(
        widget.username,
      );
      setState(() {
        _profile = profile;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showRemoveFriendConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
          'Are you sure you want to remove @${_profile!.username} from your friends?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _removeFriend();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFriend() async {
    try {
      await AuthService.instance.removeFriend(_profile!.username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('@${_profile!.username} removed from friends')),
      );
      _fetchProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _respondToFriendRequest(bool accept) async {
    try {
      await AuthService.instance.respondToFriendRequest(
        initiatorId: _profile!.id,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Friend request accepted' : 'Friend request declined',
          ),
        ),
      );
      _fetchProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = AuthService.instance.currentUser?.id == _profile?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.displayName ?? widget.username),
        actions: [
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                final result = await Navigator.of(
                  context,
                ).pushNamed(UpdateProfilePage.routeName);
                if (result != null) {
                  _fetchProfile();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text('Error: $_errorMessage'))
          : _profile == null
          ? const Center(child: Text('Profile not found.'))
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<String?>(
                      future: CacheService.instance.getUserAvatarLocalPath(
                        _profile!.id,
                      ),
                      builder: (context, snapshot) {
                        final localPath = snapshot.data;
                        if (localPath != null && localPath.isNotEmpty) {
                          return CircleAvatar(
                            radius: 60,
                            backgroundImage: FileImage(File(localPath)),
                            child: null,
                          );
                        }
                        return CircleAvatar(
                          radius: 60,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: const Icon(Icons.person, size: 60),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _profile!.displayName.isEmpty
                          ? _profile!.username
                          : _profile!.displayName,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${_profile!.username}',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    if (_profile!.bio.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        _profile!.bio,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    const SizedBox(height: 40),
                    if (!isOwnProfile) _buildFriendButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAddFriendButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () async {
          try {
            await AuthService.instance.addFriend(_profile!.username);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Friend request sent to ${_profile!.username}'),
              ),
            );
            _fetchProfile();
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
          }
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Friend'),
      ),
    );
  }

  Widget _buildFriendButton() {
    if (_profile!.friendStatus == 'pending' && _profile!.isIncoming) {
      return _buildAcceptDeclineButtons();
    }
    if (_profile!.friendStatus == 'pending' && !_profile!.isIncoming) {
      return _buildRequestPendingButton();
    }
    if (_profile!.isFriend && _profile!.friendStatus != 'pending') {
      return _buildRemoveFriendButton();
    }
    return _buildAddFriendButton();
  }

  Widget _buildRequestPendingButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.access_time_rounded),
        label: const Text('Request Pending'),
      ),
    );
  }

  Widget _buildRemoveFriendButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showRemoveFriendConfirmation(),
        icon: Icon(
          Icons.person_remove_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        label: Text(
          'Remove Friend',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  Widget _buildAcceptDeclineButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _respondToFriendRequest(false),
            child: const Text('Decline'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: () => _respondToFriendRequest(true),
            child: const Text('Accept'),
          ),
        ),
      ],
    );
  }
}
