import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/issue_categories.dart';
import '../providers/auth_provider.dart';
import '../providers/issue_provider.dart';
import '../providers/language_provider.dart';
import '../services/location_service.dart';
import '../services/watermark_service.dart';

class IssueFormScreen extends StatefulWidget {
  const IssueFormScreen({super.key});

  @override
  State<IssueFormScreen> createState() => _IssueFormScreenState();
}

class _IssueFormScreenState extends State<IssueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _category = 'street_lights';
  String _gpsCoordinates = '0,0';
  String _readableAddress = 'Fetching address...';

  final List<String> _localPhotoPaths = [];

  bool _fetchingGps = false;
  bool _processingPhoto = false;
  bool _isSubmitting = false;

  final LocationService _locationService = LocationService();
  final WatermarkService _watermarkService = WatermarkService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Auto-capture GPS on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureGps();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    setState(() {
      _fetchingGps = true;
      _readableAddress = 'Fetching coordinates...';
    });

    try {
      final loc = await _locationService.getCurrentLocation();
      setState(() {
        _gpsCoordinates = loc['coordinates'] ?? '0,0';
        _readableAddress = loc['address'] ?? 'Addu City, Maldives';
        if (_titleController.text.trim().isEmpty) {
          final nearestPlace = loc['place']?.trim() ?? '';
          if (nearestPlace.isNotEmpty) {
            _titleController.text = nearestPlace;
          }
        }
        _fetchingGps = false;
      });
    } catch (e) {
      debugPrint('GPS capture error: $e');
      if (!mounted) return;
      setState(() {
        _fetchingGps = false;
        _readableAddress = 'Location unavailable';
      });

      // Show snackbar error
      final t = Provider.of<LanguageProvider>(context, listen: false).t;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('formGpsError'), style: const TextStyle()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85, // Optimizes photo size
      );

      if (image == null) return;

      if (!mounted) return;
      setState(() {
        _processingPhoto = true;
      });

      final languageProvider = Provider.of<LanguageProvider>(
        context,
        listen: false,
      );
      final String titleText = _titleController.text.trim();
      final String finalTitle = titleText.isEmpty
          ? 'Untitled issue'
          : titleText;

      // Generate watermark on canvas
      final String watermarkedPath = await _watermarkService.addWatermark(
        imagePath: image.path,
        issueTitle: finalTitle,
        gpsCoordinates: _gpsCoordinates,
        readableAddress: _readableAddress,
        isDhivehi: languageProvider.isRtl,
      );
      final String compressedPath = watermarkedPath.replaceFirst(
        RegExp(r'\.png$'),
        '.jpg',
      );
      final compressed = await FlutterImageCompress.compressAndGetFile(
        watermarkedPath,
        compressedPath,
        minWidth: 1440,
        minHeight: 1440,
        quality: 78,
        format: CompressFormat.jpeg,
      );
      final uploadPath = compressed?.path ?? watermarkedPath;
      if (compressed != null) {
        try {
          await File(watermarkedPath).delete();
        } catch (_) {
          // The compressed copy is already ready for upload.
        }
      }

      setState(() {
        _localPhotoPaths.add(uploadPath);
        _processingPhoto = false;
      });
    } catch (e) {
      debugPrint('Photo picking/watermarking error: $e');
      setState(() {
        _processingPhoto = false;
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _localPhotoPaths.removeAt(index);
    });
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final issueProvider = Provider.of<IssueProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final t = languageProvider.t;

    // Trigger submission
    final isOnline = await issueProvider.submitIssue(
      title: _titleController.text.trim(),
      category: _category,
      description: _descriptionController.text.trim(),
      gpsLocation: _gpsCoordinates,
      localPhotoPaths: _localPhotoPaths,
      currentUserId: authProvider.currentUser?.id ?? '',
    );

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      // Show confirmation dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Image.asset(
                'assets/images/nala_addu_logo.jpg',
                height: 36,
                width: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('council'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                size: 54,
                color: Color(0xFF0D9488),
              ),
              const SizedBox(height: 16),
              Text(
                isOnline
                    ? (languageProvider.locale == 'dv'
                          ? 'މައްސަލަ ކާމިޔާބުކަމާއެކު ހުށަހެޅިއްޖެއެވެ.'
                          : 'Issue successfully reported to the council!')
                    : (languageProvider.locale == 'dv'
                          ? 'މައްސަލަ އޮފްލައިންކޮށް ރައްކާކުރެވިއްޖެއެވެ. އޮންލައިންވުމުން ސިންކް ކުރެވޭނެއެވެ.'
                          : 'Saved as draft offline! It will sync automatically when online.'),
                style: const TextStyle(fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Back to dashboard
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D9488),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final t = languageProvider.t;
    final isRtl = languageProvider.isRtl;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          title: Text(
            t('addIssue'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: _formKey,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // GPS Section
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Color(0xFF0D9488),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      t('formGps'),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Coordinates: $_gpsCoordinates',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _readableAddress,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xFF0D9488,
                                    ).withValues(alpha: 0.1),
                                    foregroundColor: const Color(0xFF0D9488),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onPressed: _fetchingGps ? null : _captureGps,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_fetchingGps)
                                        const SizedBox(
                                          height: 14,
                                          width: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Color(0xFF0D9488),
                                            ),
                                          ),
                                        )
                                      else
                                        const Icon(Icons.gps_fixed, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        _fetchingGps
                                            ? t('formCapturing')
                                            : t('formCaptureGps'),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Short issue title
                          Text(
                            t('formRoadName'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText: isRtl
                                  ? 'މައްސަލައިގެ ކުރު ސުރުޚީއެއް ލިޔުއްވާ'
                                  : 'Enter a short issue title...',
                              hintStyle: const TextStyle(fontSize: 13),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return isRtl
                                    ? 'މައްސަލައިގެ ސުރުޚީ ލިޔުއްވާ'
                                    : 'Please enter an issue title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Category
                          Text(
                            t('formCategory'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: issueCategories
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(t('cat_$category')),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _category = val;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Description
                          Text(
                            t('formDescription'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: isRtl
                                  ? 'މައްސަލައިގެ ތަފްސީލް ބަޔާން ކުރައްވާ...'
                                  : 'Describe the issue in detail...',
                              hintStyle: const TextStyle(fontSize: 13),
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return isRtl
                                    ? 'މި ބައި ފުރިހަމަކުރައްވާ'
                                    : 'Please provide description';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Photos
                          Text(
                            t('formPhotos'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Photo Selection Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _pickImage(ImageSource.camera),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.camera_alt),
                                      const SizedBox(width: 8),
                                      Text(
                                        isRtl ? 'ކެމެރާ' : 'Camera',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _pickImage(ImageSource.gallery),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.photo_library),
                                      const SizedBox(width: 8),
                                      Text(
                                        isRtl ? 'ގެލަރީ' : 'Gallery',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Photos Grid Review
                          if (_localPhotoPaths.isNotEmpty) ...[
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _localPhotoPaths.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                              itemBuilder: (context, index) {
                                final path = _localPhotoPaths[index];
                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(path),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removePhoto(index),
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.black
                                              .withValues(alpha: 0.6),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Overlay Watermarked watermark logo indicator
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF0D9488,
                                          ).withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'WATERMARKED',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 6,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Submit Button
                          ElevatedButton(
                            onPressed:
                                (_isSubmitting ||
                                    _processingPhoto ||
                                    _fetchingGps)
                                ? null
                                : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    t('save'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Photo processing overlay
            if (_processingPhoto)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: Card(
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(
                              Color(0xFF0D9488),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Adding watermarks...',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
