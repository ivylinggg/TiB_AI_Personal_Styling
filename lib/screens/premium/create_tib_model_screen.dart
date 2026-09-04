import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _faceKey = TibModelService.faceKey;
  static const _bodyKey = TibModelService.bodyKey;

  File? _facePhoto;
  File? _bodyPhoto;
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
    for (final controller in [_weightController, _heightController, _bustController, _waistController, _hipsController]) {
      controller.addListener(_updateBodyShapePreview);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _bustController.dispose();
    _waistController.dispose();
    _hipsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await TibModelService.load();
    final face = prefs.getString(_faceKey);
    final body = prefs.getString(_bodyKey);
    if (!mounted) return;
    setState(() {
      _facePhoto = face != null && File(face).existsSync() ? File(face) : null;
      _bodyPhoto = body != null && File(body).existsSync() ? File(body) : null;
      if (profile.weight > 0) _weightController.text = _format(profile.weight);
      if (profile.height > 0) _heightController.text = _format(profile.height);
      if (profile.bust > 0) _bustController.text = _format(profile.bust);
      if (profile.waist > 0) _waistController.text = _format(profile.waist);
      if (profile.hips > 0) _hipsController.text = _format(profile.hips);
      _calculatedShape = profile.bodyShape;
      _calculatedFaceShape = profile.faceShape;
    });
  }

  String _format(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
  double? _number(TextEditingController controller) => double.tryParse(controller.text.trim());

  void _updateBodyShapePreview() {
    final bust = _number(_bustController);
    final waist = _number(_waistController);
    final hips = _number(_hipsController);
    if (bust == null || waist == null || hips == null || bust <= 0 || waist <= 0 || hips <= 0) {
      if (_calculatedShape != 'Not measured' && mounted) setState(() => _calculatedShape = 'Not measured');
      return;
    }
    final shape = TibModelService.calculateBodyShape(bust: bust, waist: waist, hips: hips);
    if (shape != _calculatedShape && mounted) setState(() => _calculatedShape = shape);
  }

  Future<void> _pickPhoto({required bool face, required bool camera}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = face ? 'Checking your face photo…' : 'Preparing your model photo…';
    });
    try {
      final image = camera ? await ImagePickerService.pickCamera() : await ImagePickerService.pickGallery();
      if (image == null) return;
      if (face) {
        final faces = await MlKitService.detectFace(image);
        if (faces.length != 1) {
          throw Exception(faces.isEmpty ? 'No face detected. Use a clear front-facing photo.' : 'Please use a photo with one clearly visible face.');
        }
      }
      final directory = await getApplicationDocumentsDirectory();
      final target = File('${directory.path}/${face ? 'tib_model_face' : 'tib_model_body'}.jpg');
      await image.copy(target.path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(face ? _faceKey : _bodyKey, target.path);
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
      await TibModelService.save(facePath: _facePhoto!.path, bodyPath: _bodyPhoto?.path, weight: weight, height: height, bust: bust, waist: waist, hips: hips);
      final profile = await TibModelService.load();
      if (!mounted) return;
      setState(() {
        _calculatedShape = profile.bodyShape;
        _calculatedFaceShape = profile.faceShape;
        _status = 'Your TiB Model profile is ready · ${profile.bodyShape} · ${profile.faceShape}.';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('TiB Model saved · ${profile.bodyShape} · ${profile.faceShape}')));
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
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Use camera'), onTap: () { Navigator.pop(context); _pickPhoto(face: face, camera: true); }),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () { Navigator.pop(context); _pickPhoto(face: face, camera: false); }),
        ]),
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
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: photo == null ? AppColors.border : AppColors.primary, width: photo == null ? 1 : 1.4)),
          child: Column(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: photo == null
                      ? Container(width: double.infinity, color: AppColors.surfaceMuted, child: Icon(face ? Icons.face_retouching_natural_rounded : Icons.accessibility_new_rounded, size: 46, color: AppColors.primary))
                      : Image.file(photo, fit: BoxFit.cover, width: double.infinity),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 12), child: Row(children: [Icon(face ? Icons.face_retouching_natural_rounded : Icons.accessibility_new_rounded, size: 15, color: AppColors.primary), const SizedBox(width: 6), Expanded(child: Text(face ? 'Face photo' : 'Full-body reference', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))), const Icon(Icons.add_a_photo_outlined, size: 15, color: AppColors.textMuted)])),
          ]),
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

  Widget _measurementField({required String label, required String hint, required String unit, required TextEditingController controller, required IconData icon}) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: _requiredMeasurement,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: unit,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  Widget _shapeCard() {
    final measured = _calculatedShape != 'Not measured';
    final icon = switch (_calculatedShape) {
      'Apple' => '🍎',
      'Pear' => '🍐',
      'Hourglass' => '⌛',
      'Rectangle' => '▭',
      'Inverted Triangle' => '🔻',
      _ => '◌',
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: measured ? AppGradients.soft : null, color: measured ? null : AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: measured ? AppColors.primarySoft : AppColors.border)),
      child: Row(children: [
        Container(width: 46, height: 46, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: Center(child: Text(icon, style: const TextStyle(fontSize: 22)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('YOUR BODY SHAPE', style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted)), const SizedBox(height: 5), Text(measured ? _calculatedShape : 'Complete your measurements', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(measured ? 'Calculated from Bust, Waist and Hips.' : 'TiB will classify your shape automatically.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35))])),
      ]),
    );
  }

  Widget _faceShapeCard() {
    final scanned = _calculatedFaceShape != 'Not scanned';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: scanned ? AppGradients.soft : null, color: scanned ? null : AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: scanned ? AppColors.primarySoft : AppColors.border)),
      child: Row(children: [
        Container(width: 46, height: 46, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: const Icon(Icons.face_retouching_natural_rounded, size: 23, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('YOUR FACE SHAPE', style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted)), const SizedBox(height: 5), Text(scanned ? _calculatedFaceShape : 'Scan your face photo', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(scanned ? 'Detected automatically from your face scan.' : 'One clear face is scanned when you save your model.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35))])),
      ]),
    );
  }

  Widget _modelReadyPreview() {
    final profile = TibModelProfile(facePath: _facePhoto?.path, bodyPath: _bodyPhoto?.path, weight: _number(_weightController) ?? 0, height: _number(_heightController) ?? 0, bust: _number(_bustController) ?? 0, waist: _number(_waistController) ?? 0, hips: _number(_hipsController) ?? 0, bodyShape: _calculatedShape, faceShape: _calculatedFaceShape, isComplete: _facePhoto != null && _calculatedFaceShape != 'Not scanned' && (_number(_weightController) ?? 0) > 0 && (_number(_heightController) ?? 0) > 0 && (_number(_bustController) ?? 0) > 0 && (_number(_waistController) ?? 0) > 0 && (_number(_hipsController) ?? 0) > 0);
    if (!profile.isComplete) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('YOUR 3D VYEA MODEL', style: TextStyle(fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
      const SizedBox(height: 9),
      TibVirtualModelPreview(model: profile, height: 430),
      const SizedBox(height: 12),
      TibAvatarGenerationCard(profile: profile),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: const Row(children: [Icon(Icons.threesixty_rounded, size: 17, color: AppColors.primary), SizedBox(width: 9), Expanded(child: Text('Rotate and zoom the model to preview your proportions before styling.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4)))])),
      const SizedBox(height: 18),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _facePhoto != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create My VYEA Model')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 23),
              decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(28)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('VYEA  /  PERSONAL MODEL', style: TextStyle(color: AppColors.peach, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                SizedBox(height: 16),
                Text('Create a model\nthat feels like you.', style: TextStyle(color: Colors.white, fontSize: 29, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1)),
                SizedBox(height: 9),
                Text('Add your face and body reference. VYEA uses your measurements and detected features to personalise styling and virtual try-on.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
              ]),
            ),
            const SizedBox(height: 18),
            const Text('START WITH YOUR PHOTOS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.25, color: AppColors.textMuted)),
            const SizedBox(height: 9),
            Row(children: [_photoCard(face: true), const SizedBox(width: 10), _photoCard(face: false)]),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('MEASURE YOUR CURRENT FIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.15, color: AppColors.textMuted)),
                const SizedBox(height: 5),
                const Text('Use your current measurements so recommendations match your proportions.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
                const SizedBox(height: 16),
                Row(children: [Expanded(child: _measurementField(label: 'Weight', hint: '55', unit: 'kg', controller: _weightController, icon: Icons.monitor_weight_outlined)), const SizedBox(width: 10), Expanded(child: _measurementField(label: 'Height', hint: '165', unit: 'cm', controller: _heightController, icon: Icons.height_rounded))]),
                const SizedBox(height: 11),
                Row(children: [Expanded(child: _measurementField(label: 'Bust', hint: '86', unit: 'cm', controller: _bustController, icon: Icons.straighten_rounded)), const SizedBox(width: 10), Expanded(child: _measurementField(label: 'Waist', hint: '68', unit: 'cm', controller: _waistController, icon: Icons.straighten_rounded))]),
                const SizedBox(height: 11),
                _measurementField(label: 'Hips', hint: '92', unit: 'cm', controller: _hipsController, icon: Icons.straighten_rounded),
              ]),
            ),
            const SizedBox(height: 14),
            _faceShapeCard(),
            const SizedBox(height: 10),
            _shapeCard(),
            const SizedBox(height: 18),
            _modelReadyPreview(),
            Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.shield_outlined, color: AppColors.primary, size: 18), SizedBox(width: 10), Expanded(child: Text('Your model photos and measurements are kept locally and used to personalise styling and virtual try-on experiences.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4)))])),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy || !ready ? null : _saveProfile, icon: _busy ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded), label: Text(_busy ? 'Building your model…' : 'Save My VYEA Model'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))))),
            if (_status.isNotEmpty) ...[const SizedBox(height: 12), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14)), child: Text(_status, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)))],
          ],
        ),
      ),
    );
  }
}
