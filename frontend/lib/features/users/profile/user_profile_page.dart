// frontend/lib/features/users/profile/user_profile_page.dart
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
                      future: CacheService.instance.getCachedUserAvatar(
                        _profile!.id,
                      ),
                      builder: (context, snapshot) {
                        final avatarUrl = snapshot.data ?? _profile!.avatarUrl;
                        final isValid = CacheService.instance.isValidUrl(
                          avatarUrl,
                        );
                        return CircleAvatar(
                          radius: 60,
                          backgroundImage: isValid
                              ? NetworkImage(avatarUrl!)
                              : null,
                          child: !isValid
                              ? const Icon(Icons.person, size: 60)
                              : null,
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
                    // Add Friend button logic
                    if (!isOwnProfile && !_profile!.isFriend)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _profile!.friendStatus == 'pending'
                              ? null
                              : () async {
                                  try {
                                    await AuthService.instance.addFriend(
                                      _profile!.username,
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Friend request sent to ${_profile!.username}',
                                        ),
                                      ),
                                    );
                                    _fetchProfile(); // Refresh to show pending status
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                      ),
                                    );
                                  }
                                },
                          icon: Icon(
                            _profile!.friendStatus == 'pending'
                                ? Icons.access_time_rounded
                                : Icons.person_add_rounded,
                          ),
                          label: Text(
                            _profile!.friendStatus == 'pending'
                                ? 'Request Pending'
                                : 'Add Friend',
                          ),
                        ),
                      ),
                    if (!isOwnProfile && _profile!.isFriend)
                      const Chip(
                        avatar: Icon(
                          Icons.check_circle_outline_rounded,
                          size: 20,
                          color: Colors.green,
                        ),
                        label: Text('Friends'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
