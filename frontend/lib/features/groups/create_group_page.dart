// frontend/lib/features/groups/create_group_page.dart
import 'package:flutter/material.dart';
import 'package:mitron/services/auth_service.dart';
import 'package:mitron/models/group.dart'; // Import Group model

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  static const routeName = '/create-group';

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final group = await AuthService.instance.createGroup(
          _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Group "${group.name}" created successfully!')),
          );
          Navigator.of(context).pop(group); // Return the created group
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Group Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (Optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_errorMessage != null)
                Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red))
              else
                ElevatedButton(
                  onPressed: _createGroup,
                  child: const Text('Create Group'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
