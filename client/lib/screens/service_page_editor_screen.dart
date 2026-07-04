import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/gig.dart';
import '../models/service_page.dart';
import '../services/gig_repository.dart';

class ServicePageEditorScreen extends StatefulWidget {
  const ServicePageEditorScreen({
    super.key,
    required this.initialPage,
    required this.repository,
  });

  final ServicePage initialPage;
  final GigRepository repository;

  @override
  State<ServicePageEditorScreen> createState() =>
      _ServicePageEditorScreenState();
}

class _ServicePageEditorScreenState extends State<ServicePageEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _availableCategories = const [
    'Pets',
    'Auto',
    'Home',
    'Tutoring',
    'Moving',
    'Cleaning',
    'Tech',
    'Childcare',
    'Handyman',
    'Yard Work',
    'Senior Care',
    'Event Help',
  ];
  final List<String> _themeColorOptions = const [
    '#ffffff',
    '#F7FAFF',
    '#FFF5F0',
    '#EDF7F2',
    '#F8E7FF',
    '#FDF6E7',
    '#1D3557',
  ];
  late final TextEditingController _titleController;
  late final TextEditingController _aboutController;
  late final TextEditingController _cityController;
  late final TextEditingController _slugController;
  late final TextEditingController _heroHeadlineController;
  late final TextEditingController _announcementController;
  late final TextEditingController _logoController;
  late final TextEditingController _backgroundColorController;
  final TextEditingController _customCategoryController =
      TextEditingController();
  final List<TextEditingController> _imageControllers =
      <TextEditingController>[];
  late final Set<String> _selectedCategories;
  late String _storefrontStyle;
  late String _listingLayout;
  late bool _showCategoriesFirst;
  late bool _showTrustHighlights;

  String? _selectedLogoBase64;
  String? _selectedBackgroundImageBase64;
  bool _removeBackgroundImage = false;
  final List<String> _selectedServicePhotosBase64 = <String>[];

  List<Gig> get _providerGigs => widget.repository.gigs
      .where((gig) => gig.providerUid == widget.initialPage.ownerUid)
      .toList();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialPage.title);
    _aboutController = TextEditingController(text: widget.initialPage.about);
    _cityController = TextEditingController(text: widget.initialPage.city);
    _slugController = TextEditingController(text: widget.initialPage.shareSlug);
    _heroHeadlineController =
        TextEditingController(text: widget.initialPage.heroHeadline);
    _announcementController =
        TextEditingController(text: widget.initialPage.announcement);
    _logoController = TextEditingController(text: widget.initialPage.logoUrl);
    _backgroundColorController = TextEditingController(
      text: _initialBackgroundColorText(widget.initialPage.backgroundColor),
    );
    _removeBackgroundImage = false;
    _selectedCategories = widget.initialPage.categories.toSet();
    _storefrontStyle = widget.initialPage.storefrontStyle;
    _listingLayout = widget.initialPage.listingLayout;
    _showCategoriesFirst = widget.initialPage.showCategoriesFirst;
    _showTrustHighlights = widget.initialPage.showTrustHighlights;

    final images = widget.initialPage.imageUrls.isEmpty
        ? <String>['']
        : widget.initialPage.imageUrls;
    for (final image in images) {
      _imageControllers.add(TextEditingController(text: image));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _aboutController.dispose();
    _cityController.dispose();
    _slugController.dispose();
    _heroHeadlineController.dispose();
    _announcementController.dispose();
    _logoController.dispose();
    _backgroundColorController.dispose();
    _customCategoryController.dispose();
    for (final controller in _imageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addCustomCategory() {
    final value = _customCategoryController.text.trim();
    if (value.isEmpty) {
      return;
    }
    setState(() {
      _selectedCategories.add(value);
      _customCategoryController.clear();
    });
  }

  Future<void> _pickLogoImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUrl =
          'data:image/${image.name.split('.').last};base64,$base64String';

      setState(() {
        _selectedLogoBase64 = dataUrl;
        _logoController.text = dataUrl;
      });
    }
  }

  Future<void> _pickServicePhotos() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      for (final image in images) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final dataUrl =
            'data:image/${image.name.split('.').last};base64,$base64String';
        setState(() {
          _selectedServicePhotosBase64.add(dataUrl);
        });
      }
    }
  }

  Future<void> _pickBackgroundImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUrl =
          'data:image/${image.name.split('.').last};base64,$base64String';
      setState(() {
        _selectedBackgroundImageBase64 = dataUrl;
      });
    }
  }

  Color? _parseHexColor(String colorText) {
    final normalized = colorText.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    final namedColors = <String, Color>{
      'black': Colors.black,
      'white': Colors.white,
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
      'yellow': Colors.yellow,
      'orange': Colors.orange,
      'purple': Colors.purple,
      'pink': Colors.pink,
      'brown': Colors.brown,
      'grey': Colors.grey,
      'gray': Colors.grey,
      'teal': Colors.teal,
      'cyan': Colors.cyan,
    };
    if (namedColors.containsKey(normalized)) {
      return namedColors[normalized];
    }

    final hex = normalized.replaceAll('#', '');
    if (hex.length == 6 || hex.length == 8) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) {
        return Color(hex.length == 6 ? 0xFF000000 | value : value);
      }
    }
    return null;
  }

  String _initialBackgroundColorText(String colorText) {
    final normalized = colorText.trim().toLowerCase();
    if (normalized == '#ffffff' ||
        normalized == 'ffffff' ||
        normalized == '#ffffffff' ||
        normalized == 'ffffffff') {
      return '';
    }
    return colorText.trim();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one service category.')),
      );
      return;
    }

    final imageUrls = _selectedServicePhotosBase64.isNotEmpty
        ? _selectedServicePhotosBase64
        : _imageControllers
            .map((controller) => controller.text.trim())
            .where((value) => value.isNotEmpty)
            .toList();

    final updated = widget.initialPage.copyWith(
      title: _titleController.text.trim(),
      about: _aboutController.text.trim(),
      city: _cityController.text.trim(),
      categories: _selectedCategories.toList(),
      imageUrls: imageUrls,
      shareSlug: _slugController.text.trim(),
      logoUrl: _logoController.text.trim(),
      backgroundColor: _backgroundColorController.text.trim(),
      backgroundImage: _removeBackgroundImage
          ? ''
          : _selectedBackgroundImageBase64 ??
              widget.initialPage.backgroundImage,
      heroHeadline: _heroHeadlineController.text.trim(),
      announcement: _announcementController.text.trim(),
      storefrontStyle: _storefrontStyle,
      listingLayout: _listingLayout,
      showCategoriesFirst: _showCategoriesFirst,
      showTrustHighlights: _showTrustHighlights,
    );

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              const SizedBox(height: 12),
              Text(
                'Edit Page',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 34,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'service page name',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter page title',
                    hintStyle: TextStyle(color: Colors.black45),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'about services',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextFormField(
                  controller: _aboutController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Describe your services',
                    hintStyle: TextStyle(color: Colors.black45),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Logo',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _selectedLogoBase64 != null ||
                          _logoController.text.isNotEmpty
                      ? Image.network(
                          _selectedLogoBase64 ?? _logoController.text,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.image,
                            size: 48,
                            color: Colors.white70,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: FilledButton(
                  onPressed: _pickLogoImage,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('upload from gallery'),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'background & theme',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme color',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 220,
                      child: Center(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.color_lens),
                          label: const Text('Open color wheel'),
                          onPressed: () async {
                            final initial = _parseHexColor(
                                    _backgroundColorController.text) ??
                                theme.scaffoldBackgroundColor;
                            final picked = await showDialog<Color>(
                              context: context,
                              builder: (_) =>
                                  _ColorPickerDialog(initialColor: initial),
                            );
                            if (picked != null) {
                              final hex =
                                  '#${picked.value.toRadixString(16).padLeft(8, '0').substring(2)}';
                              setState(
                                  () => _backgroundColorController.text = hex);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _backgroundColorController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText:
                            'Enter hex or named color (e.g. #f4f4f4 or blue)',
                        labelText: 'Primary page background color',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Background image',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _pickBackgroundImage,
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text('upload background'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_selectedBackgroundImageBase64 != null ||
                            (widget.initialPage.backgroundImage.isNotEmpty &&
                                !_removeBackgroundImage))
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedBackgroundImageBase64 = null;
                                _removeBackgroundImage = true;
                              });
                            },
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear background image',
                          ),
                      ],
                    ),
                    if (_selectedBackgroundImageBase64 != null ||
                        (widget.initialPage.backgroundImage.isNotEmpty &&
                            !_removeBackgroundImage))
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 140,
                            color: Colors.black12,
                            child: _selectedBackgroundImageBase64 != null
                                ? Image.network(
                                    _selectedBackgroundImageBase64!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 36,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    widget.initialPage.backgroundImage,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 36,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'service categories',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = _availableCategories[index];
                    final selected = _selectedCategories.contains(category);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedCategories.remove(category);
                          } else {
                            _selectedCategories.add(category);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: selected ? 0 : 1.5,
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Save Service Page',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorWheel extends StatelessWidget {
  const _ColorWheel({
    required this.colors,
    required this.selectedColor,
    required this.onSelected,
  });

  final List<Color> colors;
  final Color selectedColor;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    const diameter = 220.0;
    const circleSize = 44.0;
    final center = diameter / 2;
    return SizedBox(
      height: diameter,
      width: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: diameter,
            width: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
          for (var index = 0; index < colors.length; index++)
            Positioned(
              left: center +
                  math.cos(2 * math.pi * index / colors.length) *
                      (center - circleSize / 2) -
                  circleSize / 2,
              top: center +
                  math.sin(2 * math.pi * index / colors.length) *
                      (center - circleSize / 2) -
                  circleSize / 2,
              child: GestureDetector(
                onTap: () => onSelected(colors[index]),
                child: Container(
                  height: circleSize,
                  width: circleSize,
                  decoration: BoxDecoration(
                    color: colors[index],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedColor.value == colors[index].value
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                      width: selectedColor.value == colors[index].value ? 4 : 2,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pick theme',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: selectedColor == Colors.transparent
                        ? Colors.grey.shade200
                        : selectedColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor hsv;
  late TextEditingController hexController;

  @override
  void initState() {
    super.initState();
    hsv = HSVColor.fromColor(widget.initialColor);
    hexController = TextEditingController(
        text:
            '#${widget.initialColor.value.toRadixString(16).padLeft(8, '0').substring(2)}');
  }

  @override
  void dispose() {
    hexController.dispose();
    super.dispose();
  }

  void _updateFromHex(String input) {
    final cleaned = input.trim().replaceAll('#', '');
    if (cleaned.length == 6 || cleaned.length == 8) {
      final val = int.tryParse(cleaned, radix: 16);
      if (val != null) {
        final color = Color(cleaned.length == 6 ? 0xFF000000 | val : val);
        setState(() => hsv = HSVColor.fromColor(color));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = hsv.toColor();
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Color wheel', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            // SV box
            GestureDetector(
              onPanDown: (e) {
                final box = context.findRenderObject() as RenderBox;
                final local = box.globalToLocal(e.globalPosition);
                _handleSvTap(local, box.size);
              },
              onPanUpdate: (e) {
                final box = context.findRenderObject() as RenderBox;
                final local = box.globalToLocal(e.globalPosition);
                _handleSvTap(local, box.size);
              },
              child: Container(
                width: 240,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                    ],
                  ),
                ),
                child: CustomPaint(
                  painter: _SvOverlayPainter(hsv.hue),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Hue slider
            SizedBox(
              width: 240,
              child: Slider(
                value: hsv.hue,
                min: 0,
                max: 360,
                onChanged: (v) => setState(() => hsv = hsv.withHue(v)),
                activeColor: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hexController,
                    decoration: const InputDecoration(labelText: 'Hex color'),
                    onChanged: _updateFromHex,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: currentColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(hsv.toColor());
                  },
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleSvTap(Offset local, Size size) {
    final dx = (local.dx).clamp(0.0, size.width);
    final dy = (local.dy).clamp(0.0, size.height);
    final s = dx / size.width;
    final v = 1 - (dy / size.height);
    setState(() => hsv = hsv.withSaturation(s).withValue(v));
    hexController.text =
        '#${hsv.toColor().value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}

class _SvOverlayPainter extends CustomPainter {
  _SvOverlayPainter(this.hue);
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();

    // Saturation gradient (left -> right)
    paint.shader = LinearGradient(
            colors: [Colors.white, HSVColor.fromAHSV(1, hue, 1, 1).toColor()])
        .createShader(rect);
    canvas.drawRect(rect, paint);

    // Value gradient (top -> bottom)
    paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black]).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _SvOverlayPainter old) => old.hue != hue;
}
