// frontend/lib/features/groups/join_group_page.dart
import 'package:flutter/material.dart';
import 'package:mitron/services/auth_service.dart';

class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key});

  static const routeName = '/join-group';

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _groupIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _groupIdController.dispose();
    super.dispose();
  }

  Future<void> _joinGroup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await AuthService.instance.joinGroup(_groupIdController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully joined group!')),
          );
          Navigator.of(context).pop(); // Go back after joining
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
        title: const Text('Join Group'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _groupIdController,
                decoration: const InputDecoration(labelText: 'Group ID'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a Group ID';
                  }
                  // Basic validation for UUID format could be added here if needed
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_errorMessage != null)
                Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red))
              else
                ElevatedButton(
                  onPressed: _joinGroup,
                  child: const Text('Join Group'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
