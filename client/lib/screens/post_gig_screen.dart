import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/gig.dart';
import '../services/gig_repository.dart';

class PostGigScreen extends StatefulWidget {
  const PostGigScreen({
    super.key,
    required this.repository,
    this.initialGig,
  });

  final GigRepository repository;
  final Gig? initialGig;

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
  final tagsController = TextEditingController();

  String category = 'Home';
  bool lateNight = false;
  bool isActive = true;
  final List<DateTime> _availableSlots = <DateTime>[];

  final List<String> categories = const [
    'Pets',
    'Auto',
    'Home',
    'Tutoring',
    'Moving',
    'Cleaning',
    'Tech',
  ];

  final List<String> tagSuggestions = const [
    'Dog Walking',
    'Pet Sitting',
    'House Cleaning',
    'Deep Cleaning',
    'Lawn Care',
    'Yard Work',
    'Car Detailing',
    'Car Wash',
    'Math Tutoring',
    'Homework Help',
    'Tech Setup',
    'Moving Help',
  ];

  @override
  void initState() {
    super.initState();
    final gig = widget.initialGig;
    if (gig == null) {
      providerController.text = widget.repository.profileForView.name;
      return;
    }

    titleController.text = gig.title;
    descriptionController.text = gig.description;
    providerController.text = gig.providerName;
    locationController.text = gig.location;
    priceController.text = gig.price.toStringAsFixed(2);
    tagsController.text = gig.tags.join(', ');
    category = gig.category;
    lateNight = gig.isLateNight;
    isActive = gig.isActive;
    _availableSlots.addAll(gig.availableSlots);
    _selectedPhotosBase64.addAll(gig.imageUrls);
  }

  final List<String> _selectedPhotosBase64 = <String>[];

  Future<void> _pickServicePhotos() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    for (final image in images) {
      if (_selectedPhotosBase64.length >= 7) break;
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUrl =
          'data:image/${image.name.split('.').last};base64,$base64String';
      setState(() => _selectedPhotosBase64.add(dataUrl));
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    providerController.dispose();
    locationController.dispose();
    priceController.dispose();
    tagsController.dispose();
    super.dispose();
  }

  List<String> _parseTags(String value) {
    final seen = <String>{};
    return value
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .where((tag) => seen.add(tag.toLowerCase()))
        .take(12)
        .toList();
  }

  void _addSuggestedTag(String tag) {
    final tags = _parseTags(tagsController.text);
    if (tags.any((item) => item.toLowerCase() == tag.toLowerCase())) {
      return;
    }
    tags.add(tag);
    tagsController.text = tags.take(12).join(', ');
    setState(() {});
  }

  String _formatSlot(DateTime value) {
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$m/$d/${value.year} $hh:$mm';
  }

  Future<void> _addAvailabilitySlot() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select available date',
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Select available time',
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    final slot = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      final alreadyExists = _availableSlots.any(
          (existing) => existing.toIso8601String() == slot.toIso8601String());
      if (!alreadyExists) {
        _availableSlots.add(slot);
        _availableSlots.sort((a, b) => a.compareTo(b));
      }
    });
  }

  void submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_availableSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one available date and time.')),
      );
      return;
    }

    final initialGig = widget.initialGig;
    final gig = Gig(
      id: initialGig?.id ?? 'g${DateTime.now().millisecondsSinceEpoch}',
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      category: category,
      price: double.parse(priceController.text.trim()),
      providerName: providerController.text.trim(),
      location: locationController.text.trim(),
      providerUid: initialGig?.providerUid ?? widget.repository.currentUserUid,
      minAge: initialGig?.minAge ?? 13,
      isLateNight: lateNight,
      requiresBackgroundCheck: initialGig?.requiresBackgroundCheck ?? false,
      availableSlots: _availableSlots,
      imageUrls: _selectedPhotosBase64,
      tags: _parseTags(tagsController.text),
      isActive: isActive,
    );

    Navigator.of(context).pop(gig);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialGig == null
              ? 'Create Service Listing'
              : 'Edit Service Listing',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Create a local service listing for nearby workers',
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
              value: category,
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
            TextFormField(
              controller: tagsController,
              decoration: const InputDecoration(
                labelText: 'Search tags',
                hintText: 'dog walking, pet sitting, yard work',
                helperText:
                    'Add keywords customers might search for, separated by commas.',
              ),
              minLines: 1,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tagSuggestions.map((tag) {
                return ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(tag),
                  onPressed: () => _addSuggestedTag(tag),
                );
              }).toList(),
            ),
            SwitchListTile.adaptive(
              title: const Text('Late-night task'),
              subtitle: const Text(
                  'Teens cannot accept late-night service listings.'),
              value: lateNight,
              onChanged: (value) => setState(() => lateNight = value),
            ),
            SwitchListTile.adaptive(
              title: const Text('Active listing'),
              subtitle: const Text(
                'Turn this off to pause the service without deleting it.',
              ),
              value: isActive,
              onChanged: (value) => setState(() => isActive = value),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Availability calendar',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addAvailabilitySlot,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: const Text('Add slot'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_availableSlots.isEmpty)
                      const Text(
                          'No slots added yet. Add dates and times you are available.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            List.generate(_availableSlots.length, (index) {
                          final slot = _availableSlots[index];
                          return InputChip(
                            label: Text(_formatSlot(slot)),
                            onDeleted: () {
                              setState(() => _availableSlots.removeAt(index));
                            },
                          );
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Optional photos (up to 7)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._selectedPhotosBase64.map((dataUrl) {
                  final index = _selectedPhotosBase64.indexOf(dataUrl);
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          dataUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 100,
                            height: 100,
                            color: Colors.black12,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: IconButton(
                          onPressed: () {
                            setState(
                                () => _selectedPhotosBase64.removeAt(index));
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  );
                }),
                if (_selectedPhotosBase64.length < 7)
                  GestureDetector(
                    onTap: _pickServicePhotos,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_a_photo_outlined),
                    ),
                  ),
              ],
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
              child: Text(
                widget.initialGig == null
                    ? 'Publish Service Listing'
                    : 'Save Service Listing',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
