import 'package:flutter/material.dart';

import '../services/gig_repository.dart';

class ParentApprovalScreen extends StatefulWidget {
  const ParentApprovalScreen({super.key, required this.repository});

  final GigRepository repository;

  @override
  State<ParentApprovalScreen> createState() => _ParentApprovalScreenState();
}

class _ParentApprovalScreenState extends State<ParentApprovalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _approvalTokenController = TextEditingController();
  final _parentEmailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _approvalTokenController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final error = await widget.repository.approveTeenAccount(
      approvalToken: _approvalTokenController.text,
      parentEmail: _parentEmailController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Teen account approved successfully.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parent Approval')),
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
                  const Text(
                    'Approve a teen account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter the approval token from sign-up and the parent email used at registration.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _approvalTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Approval token',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Approval token is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _parentEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Parent email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty || !text.contains('@')) {
                        return 'Enter a valid parent email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(
                        _isSubmitting ? 'Approving...' : 'Approve account'),
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
