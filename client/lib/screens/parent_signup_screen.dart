import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/gig_repository.dart';

class ParentSignUpScreen extends StatefulWidget {
  const ParentSignUpScreen({
    super.key,
    required this.repository,
    required this.parentEmail,
    required this.approvalToken,
    required this.childName,
    required this.onAuthenticated,
  });

  final GigRepository repository;
  final String parentEmail;
  final String approvalToken;
  final String childName;
  final VoidCallback onAuthenticated;

  @override
  State<ParentSignUpScreen> createState() => _ParentSignUpScreenState();
}

class _ParentSignUpScreenState extends State<ParentSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dobController = TextEditingController();
  bool _isLoading = false;
  bool _useExistingAccount = false;
  DateTime? _selectedDateOfBirth;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.parentEmail;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
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
        DateTime.now().subtract(const Duration(days: 365 * 30));
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

    String? authError;
    if (_useExistingAccount) {
      authError = await widget.repository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      final result = await widget.repository.signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        dateOfBirth: _selectedDateOfBirth!,
        isBusinessAccount: false,
      );
      authError = result.errorMessage;
    }

    if (!mounted) {
      return;
    }

    if (authError != null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authError)),
      );
      return;
    }

    final approvalError = await widget.repository.approveTeenAccount(
      approvalToken: widget.approvalToken,
      parentEmail: _emailController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    if (approvalError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approvalError)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.childName} is linked to your parent account.',
        ),
      ),
    );
    widget.onAuthenticated();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _useExistingAccount ? 'Parent log in' : 'Parent account setup';

    return Scaffold(
      appBar: AppBar(title: const Text('Parent setup')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pass the phone to a parent. They need their own account to approve services for ${widget.childName} and can also search/book services for themselves.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Create parent account'),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Log in parent'),
                      ),
                    ],
                    selected: {_useExistingAccount},
                    onSelectionChanged: _isLoading
                        ? null
                        : (value) {
                            setState(
                              () => _useExistingAccount = value.first,
                            );
                          },
                  ),
                  const SizedBox(height: 16),
                  if (!_useExistingAccount) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Parent full name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (_useExistingAccount) {
                          return null;
                        }
                        if ((value ?? '').trim().isEmpty) {
                          return 'Parent name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Parent email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim().toLowerCase() ?? '';
                      if (text.isEmpty || !text.contains('@')) {
                        return 'Enter a valid parent email';
                      }
                      if (text != widget.parentEmail.trim().toLowerCase()) {
                        return 'Use the same parent email entered for the child';
                      }
                      return null;
                    },
                  ),
                  if (!_useExistingAccount) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      readOnly: true,
                      onTap: _pickDateOfBirth,
                      controller: _dobController,
                      decoration: const InputDecoration(
                        labelText: 'Parent date of birth',
                        hintText: 'Select birth date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      validator: (_) {
                        if (_useExistingAccount) {
                          return null;
                        }
                        final age = _computedAge;
                        if (_selectedDateOfBirth == null || age == null) {
                          return 'Select parent date of birth';
                        }
                        if (age < 18) {
                          return 'Parent account must be 18+';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: _useExistingAccount
                          ? 'Parent password'
                          : 'Create parent password',
                      border: const OutlineInputBorder(),
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
                    child: Text(
                      _isLoading
                          ? 'Setting up...'
                          : _useExistingAccount
                              ? 'Log in & link child'
                              : 'Create parent account & link child',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).popUntil(
                              (route) => route.isFirst,
                            );
                          },
                    child: const Text('Parent will do this later'),
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
