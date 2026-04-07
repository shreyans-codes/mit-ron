import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/mitron_colors.dart';
import '../../models/auth_user.dart';
import '../../services/auth_service.dart';

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  static const String routeName = '/settings/update-profile';

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  late AuthUser _user;
  bool _initialized = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _bio;
  File? _imageFile;
  final _picker = ImagePicker();

  bool _updating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _user = AuthService.instance.currentUser!;
      _name = TextEditingController(text: _user.displayName);
      _bio = TextEditingController(text: _user.bio);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleUpdateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _updating = true);
    try {
      final updatedUser = await AuthService.instance.updateProfile(
        displayName: _name.text.trim(),
        bio: _bio.text.trim(),
        avatar: _imageFile,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.of(context).pop(updatedUser);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mc = MitronColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: mc.cardSurface,
                        backgroundImage: _imageFile != null 
                          ? FileImage(_imageFile!) 
                          : (_user.profilePictureUrl != null 
                              ? NetworkImage(_user.profilePictureUrl!) as ImageProvider
                              : null),
                        child: (_imageFile == null && _user.profilePictureUrl == null)
                          ? const Icon(Icons.person, size: 60)
                          : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter your name' : null,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _bio,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  prefixIcon: Icon(Icons.info_outline_rounded),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _updating ? null : _handleUpdateProfile,
                child: _updating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
