import 'package:flutter/material.dart';

import '../models/gig.dart';

class PostGigScreen extends StatefulWidget {
  const PostGigScreen({super.key});

  @override
  State<PostGigScreen> createState() => _PostGigScreenState();
}

class _PostGigScreenState extends State<PostGigScreen> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final providerController = TextEditingController();
  final locationController = TextEditingController();
  final priceController = TextEditingController();

  String category = 'Home';
  bool requiresAdult = false;
  bool lateNight = false;
  bool requiresBackgroundCheck = false;

  final List<String> categories = const [
    'Pets',
    'Auto',
    'Home',
    'Tutoring',
    'Moving',
    'Cleaning',
    'Tech',
  ];

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    providerController.dispose();
    locationController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final gig = Gig(
      id: 'g${DateTime.now().millisecondsSinceEpoch}',
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      category: category,
      price: double.parse(priceController.text.trim()),
      providerName: providerController.text.trim(),
      location: locationController.text.trim(),
      minAge: requiresAdult ? 18 : 13,
      isLateNight: lateNight,
      requiresBackgroundCheck: requiresBackgroundCheck,
    );

    Navigator.of(context).pop(gig);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a Gig')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Create a local task for nearby workers',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Service title'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 2,
              maxLines: 4,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: categories
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => category = value);
                }
              },
            ),
            SwitchListTile.adaptive(
              title: const Text('18+ only'),
              subtitle: const Text('Restrict this gig to adult workers.'),
              value: requiresAdult,
              onChanged: (value) => setState(() => requiresAdult = value),
            ),
            SwitchListTile.adaptive(
              title: const Text('Late-night task'),
              subtitle: const Text('Teens cannot accept late-night gigs.'),
              value: lateNight,
              onChanged: (value) => setState(() => lateNight = value),
            ),
            SwitchListTile.adaptive(
              title: const Text('Require background check'),
              subtitle: const Text(
                  'Recommended for childcare and private-home gigs.'),
              value: requiresBackgroundCheck,
              onChanged: (value) =>
                  setState(() => requiresBackgroundCheck = value),
            ),
            TextFormField(
              controller: providerController,
              decoration: const InputDecoration(labelText: 'Your name'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Location'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Price (USD)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: submit,
              child: const Text('Publish Gig'),
            ),
          ],
        ),
      ),
    );
  }
}
