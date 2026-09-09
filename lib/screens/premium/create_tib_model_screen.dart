import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../services/image_picker_service.dart';
import '../../services/mlkit_service.dart';
import '../../services/tib_model_service.dart';
import '../../widgets/tib_avatar_generation_card.dart';
import '../../widgets/tib_virtual_model_preview.dart';

class CreateTibModelScreen extends StatefulWidget {
  const CreateTibModelScreen({super.key});

  @override
  State<CreateTibModelScreen> createState() => _CreateTibModelScreenState();
}

class _CreateTibModelScreenState extends State<CreateTibModelScreen> {
  File? _facePhoto;
  File? _bodyPhoto;
  TibModelProfile _profile = const TibModelProfile(
    facePath: null,
    bodyPath: null,
    weight: 0,
    height: 0,
    bust: 0,
    waist: 0,
    hips: 0,
    bodyShape: 'Not measured',
    faceShape: 'Not scanned',
    isComplete: false,
  );
  bool _busy = false;
  String _status = '';
  String _calculatedShape = 'Not measured';
  String _calculatedFaceShape = 'Not scanned';

  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bustController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    for (final controller in [
      _weightController,
      _heightController,
      _bustController,
      _waistController,
      _hipsController,
    ]) {
      controller.addListener(_updateBodyShapePreview);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _weightController,
      _heightController,
      _bustController,
      _waistController,
      _hipsController,
    ]) {
      controller.removeListener(_updateBodyShapePreview);
    }
    _weightController.dispose();
    _heightController.dispose();
    _bustController.dispose();
    _waistController.dispose();
    _hipsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await TibModelService.loadForUser();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _facePhoto = profile.faceFile;
      _bodyPhoto = profile.bodyFile;
      if (profile.weight > 0) _weightController.text = _format(profile.weight);
      if (profile.height > 0) _heightController.text = _format(profile.height);
      if (profile.bust > 0) _bustController.text = _format(profile.bust);
      if (profile.waist > 0) _waistController.text = _format(profile.waist);
      if (profile.hips > 0) _hipsController.text = _format(profile.hips);
      _calculatedShape = profile.bodyShape;
      _calculatedFaceShape = profile.faceShape;
    });
  }

  String _format(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  void _updateBodyShapePreview() {
    final bust = _number(_bustController);
    final waist = _number(_waistController);
    final hips = _number(_hipsController);
    if (bust == null || waist == null || hips == null || bust <= 0 || waist <= 0 || hips <= 0) {
      if (_calculatedShape != 'Not measured' && mounted) {
        setState(() => _calculatedShape = 'Not measured');
      }
      return;
    }
    final shape = TibModelService.calculateBodyShape(
      bust: bust,
      waist: waist,
      hips: hips,
    );
    if (shape != _calculatedShape && mounted) {
      setState(() => _calculatedShape = shape);
    }
  }

  Future<void> _pickPhoto({required bool face, required bool camera}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = face ? 'Checking your face photo…' : 'Preparing your model photo…';
    });
    try {
      final image = camera
          ? await ImagePickerService.pickCamera()
          : await ImagePickerService.pickGallery();
      if (image == null) return;
      if (face) {
        final faces = await MlKitService.detectFace(image);
        if (faces.length != 1) {
          throw Exception(
            faces.isEmpty
                ? 'No face detected. Use a clear front-facing photo.'
                : 'Please use a photo with one clearly visible face.',
          );
        }
      }
      final directory = await getApplicationDocumentsDirectory();
      final target = File(
        '${directory.path}/${face ? 'tib_model_face' : 'tib_model_body'}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await image.copy(target.path);
      if (!mounted) return;
      setState(() {
        if (face) {
          _facePhoto = target;
          _status = 'Face profile ready. Save to update your TiB Model.';
        } else {
          _bodyPhoto = target;
          _status = 'Full-body reference ready.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _status = 'Please complete all five body measurements.');
      return;
    }
    if (_facePhoto == null) {
      setState(() => _status = 'Add your face photo first.');
      return;
    }
    final uid = await TibModelService.currentUserId();
    if (uid == null) {
      setState(() => _status = 'Please log in before saving your TiB Model.');
      return;
    }
    final weight = _number(_weightController)!;
    final height = _number(_heightController)!;
    final bust = _number(_bustController)!;
    final waist = _number(_waistController)!;
    final hips = _number(_hipsController)!;
    setState(() {
      _busy = true;
      _status = 'Building your TiB Model…';
    });
    try {
      await TibModelService.save(
        uid: uid,
        facePath: _facePhoto!.path,
        bodyPath: _bodyPhoto?.path,
        weight: weight,
        height: height,
        bust: bust,
        waist: waist,
        hips: hips,
      );
      final profile = await TibModelService.loadForUser(uid);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _calculatedShape = profile.bodyShape;
        _calculatedFaceShape = profile.faceShape;
        _status = 'Your TiB Model profile is ready · ${profile.bodyShape} · ${profile.faceShape}.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TiB Model saved · ${profile.bodyShape} · ${profile.faceShape}')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Could not save your TiB Model: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPhotoOptions(bool face) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Use camera'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(face: face, camera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(face: face, camera: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoCard({required bool face}) {
    final photo = face ? _facePhoto : _bodyPhoto;
    return Expanded(
      child: InkWell(
        onTap: () => _showPhotoOptions(face),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 220,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: photo == null ? AppColors.border : AppColors.primary,
              width: photo == null ? 1 : 1.4,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: photo == null
                        ? Container(
                            width: double.infinity,
                            color: AppColors.surfaceMuted,
                            child: Icon(
                              face
                                  ? Icons.face_retouching_natural_rounded
                                  : Icons.accessibility_new_rounded,
                              size: 46,
                              color: AppColors.primary,
                            ),
                          )
                        : Image.file(photo, fit: BoxFit.cover, width: double.infinity),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                child: Row(
                  children: [
                    Icon(
                      face
                          ? Icons.face_retouching_natural_rounded
                          : Icons.accessibility_new_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        face ? 'Face photo' : 'Full-body reference',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                      ),
                    ),
                    const Icon(Icons.add_a_photo_outlined, size: 15, color: AppColors.textMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredMeasurement(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final number = double.tryParse(value.trim());
    if (number == null || number <= 0) return 'Enter a valid number';
    return null;
  }

  Widget _measurementField({
    required String label,
    required String hint,
    required String unit,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: _requiredMeasurement,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        suffixText: unit,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewProfile = TibModelProfile(
      facePath: _facePhoto?.path ?? _profile.facePath,
      bodyPath: _bodyPhoto?.path ?? _profile.bodyPath,
      weight: _number(_weightController) ?? _profile.weight,
      height: _number(_heightController) ?? _profile.height,
      bust: _number(_bustController) ?? _profile.bust,
      waist: _number(_waistController) ?? _profile.waist,
      hips: _number(_hipsController) ?? _profile.hips,
      bodyShape: _calculatedShape,
      faceShape: _calculatedFaceShape,
      isComplete: _facePhoto != null &&
          _bodyPhoto != null &&
          (_number(_weightController) ?? 0) > 0 &&
          (_number(_heightController) ?? 0) > 0 &&
          (_number(_bustController) ?? 0) > 0 &&
          (_number(_waistController) ?? 0) > 0 &&
          (_number(_hipsController) ?? 0) > 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Create Your TiB Model'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppGradients.soft,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR PERSONAL MODEL', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    SizedBox(height: 7),
                    Text('Build a TiB that stays yours.', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.7)),
                    SizedBox(height: 7),
                    Text('Use your own face, body reference and measurements so styling stays personalised to you.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.45)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('REFERENCE PHOTOS', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              const SizedBox(height: 9),
              Row(children: [_photoCard(face: true), const SizedBox(width: 10), _photoCard(face: false)]),
              const SizedBox(height: 18),
              const Text('BODY MEASUREMENTS', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              const SizedBox(height: 9),
              _measurementField(label: 'Weight', hint: 'e.g. 55', unit: 'kg', controller: _weightController, icon: Icons.monitor_weight_outlined),
              const SizedBox(height: 10),
              _measurementField(label: 'Height', hint: 'e.g. 165', unit: 'cm', controller: _heightController, icon: Icons.height_rounded),
              const SizedBox(height: 10),
              _measurementField(label: 'Bust', hint: 'e.g. 86', unit: 'cm', controller: _bustController, icon: Icons.straighten_outlined),
              const SizedBox(height: 10),
              _measurementField(label: 'Waist', hint: 'e.g. 66', unit: 'cm', controller: _waistController, icon: Icons.straighten_outlined),
              const SizedBox(height: 10),
              _measurementField(label: 'Hips', hint: 'e.g. 90', unit: 'cm', controller: _hipsController, icon: Icons.straighten_outlined),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.analytics_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Current shape reading', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('$_calculatedShape · $_calculatedFaceShape', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900))])),
                ]),
              ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_status, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _saveProfile,
                  icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background)) : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_busy ? 'Building your model…' : 'Save My TiB Model'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(52)),
                ),
              ),
              const SizedBox(height: 18),
              TibAvatarGenerationCard(profile: previewProfile),
              const SizedBox(height: 14),
              TibVirtualModelPreview(model: previewProfile),
            ],
          ),
        ),
      ),
    );
  }
}
