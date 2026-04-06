// frontend/lib/features/friends/friends_list_page.dart
import 'package:flutter/material.dart';
import 'package:mitron/models/friend.dart';
import 'package:mitron/models/profile.dart';
import 'package:mitron/services/auth_service.dart';
import '../users/search/user_search_page.dart';
import '../users/profile/user_profile_page.dart';

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({super.key});

  static const routeName = '/friends';

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  List<Profile> _friendProfiles = []; // Stores profiles of friends
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final friendProfiles = await AuthService.instance.getFriends(); // Call the new service method
      setState(() {
        _friendProfiles = friendProfiles;
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
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Navigate to a screen to search and add friends (likely UserSearchPage)
               Navigator.of(context).pushNamed(UserSearchPage.routeName);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _friendProfiles.isEmpty
                  ? const Center(child: Text('You have no friends yet. Add some!'))
                  : ListView.builder(
                      itemCount: _friendProfiles.length,
                      itemBuilder: (context, index) {
                        final profile = _friendProfiles[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                              child: profile.avatarUrl == null ? const Icon(Icons.person) : null,
                            ),
                            title: Text(profile.displayName.isEmpty ? profile.username : profile.displayName),
                            subtitle: Text('@${profile.username}'),
                            onTap: () {
                              // Navigate to friend's profile page
                              Navigator.of(context).pushNamed(
                                UserProfilePage.routeName,
                                arguments: profile.username, // Pass username to profile page
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
