import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/gig_repository.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    super.key,
    required this.repository,
    required this.onAuthenticated,
  });

  final GigRepository repository;
  final VoidCallback onAuthenticated;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dobController = TextEditingController();
  bool _isLoading = false;
  DateTime? _selectedDateOfBirth;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _parentEmailController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  int? get _computedAge {
    final dob = _selectedDateOfBirth;
    if (dob == null) {
      return null;
    }

    final now = DateTime.now();
    var age = now.year - dob.year;
    final birthdayThisYear = DateTime(now.year, dob.month, dob.day);
    if (now.isBefore(birthdayThisYear)) {
      age -= 1;
    }
    return age;
  }

  bool get _isTeenSigner {
    final age = _computedAge;
    return age != null && age >= 13 && age <= 17;
  }

  String? get _formattedDob {
    final dob = _selectedDateOfBirth;
    if (dob == null) {
      return null;
    }
    final mm = dob.month.toString().padLeft(2, '0');
    final dd = dob.day.toString().padLeft(2, '0');
    return '$mm/$dd/${dob.year}';
  }

  Future<void> _pickDateOfBirth() async {
    final initialDate = _selectedDateOfBirth ??
        DateTime.now().subtract(const Duration(days: 365 * 18));
    var draftDate = initialDate;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedDateOfBirth = draftDate;
                          _dobController.text = _formattedDob ?? '';
                        });
                        Navigator.of(context).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  maximumDate: DateTime.now(),
                  minimumDate: DateTime(1900),
                  onDateTimeChanged: (value) => draftDate = value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final result = await widget.repository.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      dateOfBirth: _selectedDateOfBirth!,
      parentEmail: _isTeenSigner ? _parentEmailController.text.trim() : null,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);

    if (result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage!)),
      );
      return;
    }

    if (result.infoMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.infoMessage!),
          duration: const Duration(seconds: 8),
        ),
      );
    }

    if (result.requiresParentApproval && result.childUid != null) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Parent approval needed'),
            content: SelectableText(
              'Share this account ID with your parent:\n\n${result.childUid}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }

    if (!mounted) {
      return;
    }

    if (!result.requiresParentApproval) {
      widget.onAuthenticated();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create your Giggo account',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty || !text.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    readOnly: true,
                    onTap: _pickDateOfBirth,
                    controller: _dobController,
                    decoration: InputDecoration(
                      labelText: 'Date of birth',
                      hintText: 'Select your birth date',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                      errorText: _selectedDateOfBirth == null
                          ? null
                          : ((_computedAge ?? 0) < 13
                              ? 'Minimum age is 13'
                              : null),
                    ),
                    validator: (_) {
                      final age = _computedAge;
                      if (_selectedDateOfBirth == null || age == null) {
                        return 'Select your date of birth';
                      }
                      if (age < 13) {
                        return 'Minimum age is 13';
                      }
                      return null;
                    },
                  ),
                  if (_computedAge != null) ...[
                    const SizedBox(height: 6),
                    Text('Calculated age: $_computedAge'),
                  ],
                  if (_isTeenSigner) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _parentEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Parent email (required for ages 13–17)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (!_isTeenSigner) {
                          return null;
                        }
                        final text = value?.trim() ?? '';
                        if (text.isEmpty || !text.contains('@')) {
                          return 'Enter a valid parent email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'A parent approval request will be sent before account activation.',
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if ((value ?? '').length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: Text(_isLoading ? 'Creating account...' : 'Sign up'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
