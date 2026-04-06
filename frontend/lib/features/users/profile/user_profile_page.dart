// frontend/lib/features/users/profile/user_profile_page.dart
import 'package:flutter/material.dart';
import 'package:mitron/models/profile.dart';
import 'package:mitron/services/auth_service.dart';

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
      final profile = await AuthService.instance.getUserProfile(widget.username);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.displayName ?? widget.username),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _profile == null
                  ? const Center(child: Text('Profile not found.'))
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _profile!.avatarUrl != null
                                ? NetworkImage(_profile!.avatarUrl!)
                                : null,
                            child: _profile!.avatarUrl == null
                                ? const Icon(Icons.person, size: 50)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _profile!.displayName.isEmpty ? _profile!.username : _profile!.displayName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            '@${_profile!.username}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                          ),
                          if (_profile!.bio.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              _profile!.bio,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const Spacer(),
                          // Add Friend button logic here
                          if (AuthService.instance.currentUser?.id != _profile?.id) // Don't show "Add Friend" for own profile
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  await AuthService.instance.addFriend(_profile!.username);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Friend request sent to ${_profile!.username}')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error sending friend request: ${e.toString()}')),
                                    );
                                  }
                                }
                              },
                              child: const Text('Add Friend'),
                            ),
                        ],
                      ),
                    ),
    );
  }
}
