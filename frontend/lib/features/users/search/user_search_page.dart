// frontend/lib/features/users/search/user_search_page.dart
import 'package:flutter/material.dart';
import 'package:mitron/core/utils/platform_image_provider.dart';
import 'package:mitron/models/profile.dart';
import 'package:mitron/services/auth_service.dart';
import 'package:mitron/services/cache_service.dart';
import '../profile/user_profile_page.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  static const routeName = '/user-search';

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Profile> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profiles = await AuthService.instance.searchUsers(query);
      setState(() {
        _searchResults = profiles;
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

  Widget _buildProfileCard(Profile profile) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: FutureBuilder<String?>(
          future: CacheService.instance.getUserAvatarLocalPath(profile.id),
          builder: (context, snapshot) {
            final localPath = snapshot.data;
            if (localPath != null && localPath.isNotEmpty) {
              return CircleAvatar(
                backgroundImage: platformImageProvider(localPath),
                child: null,
              );
            }
            return CircleAvatar(child: const Icon(Icons.person));
          },
        ),
        title: Text(
          profile.displayName.isEmpty ? profile.username : profile.displayName,
        ),
        subtitle: Text('@${profile.username}\n${profile.bio}'),
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(UserProfilePage.routeName, arguments: profile.username);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by username or name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch(); // Clear results when text is cleared
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                // Trigger search on text change, maybe with debounce in a real app
                _performSearch();
              },
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Center(child: Text('Error: $_errorMessage'))
          else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
            const Center(child: Text('No users found.'))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  return _buildProfileCard(_searchResults[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}
