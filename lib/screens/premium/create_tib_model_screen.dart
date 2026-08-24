import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../services/image_picker_service.dart';
import '../../services/mlkit_service.dart';

class CreateTibModelScreen extends StatefulWidget {
  const CreateTibModelScreen({super.key});

  @override
  State<CreateTibModelScreen> createState() => _CreateTibModelScreenState();
}

class _CreateTibModelScreenState extends State<CreateTibModelScreen> {
  static const _faceKey = 'tib_model_face_path';
  static const _bodyKey = 'tib_model_body_path';
  static const _heightKey = 'tib_model_height';
  static const _shapeKey = 'tib_model_body_shape';

  File? _facePhoto;
  File? _bodyPhoto;
  double _height = 165;
  String _bodyShape = 'Balanced';
  bool _busy = false;
  String _status = '';

  static const _shapes = [
    'Balanced',
    'Pear',
    'Hourglass',
    'Rectangle',
    'Inverted Triangle',
    'Apple',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final face = prefs.getString(_faceKey);
    final body = prefs.getString(_bodyKey);
    if (!mounted) return;
    setState(() {
      _facePhoto = face != null && File(face).existsSync() ? File(face) : null;
      _bodyPhoto = body != null && File(body).existsSync() ? File(body) : null;
      _height = prefs.getDouble(_heightKey) ?? 165;
      _bodyShape = prefs.getString(_shapeKey) ?? 'Balanced';
    });
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
        '${directory.path}/${face ? 'tib_model_face' : 'tib_model_body'}.jpg',
      );
      await image.copy(target.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(face ? _faceKey : _bodyKey, target.path);

      if (!mounted) return;
      setState(() {
        if (face) {
          _facePhoto = target;
          _status = 'Face profile ready.';
        } else {
          _bodyPhoto = target;
          _status = 'Model photo ready.';
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
    if (_facePhoto == null) {
      setState(() => _status = 'Add your face photo first.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_heightKey, _height);
    await prefs.setString(_shapeKey, _bodyShape);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your TiB Model profile is saved.')),
    );
    Navigator.pop(context, true);
  }

  Widget _photoCard({required bool face}) {
    final photo = face ? _facePhoto : _bodyPhoto;
    return Expanded(
      child: InkWell(
        onTap: () => _showPhotoOptions(face),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 210,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: photo == null ? AppColors.border : AppColors.primary),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                              face ? Icons.face_retouching_natural_rounded : Icons.accessibility_new_rounded,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          )
                        : Image.file(photo, fit: BoxFit.cover, width: double.infinity),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                child: Text(
                  face ? 'Face photo' : 'Full-body photo',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final ready = _facePhoto != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create My TiB Model')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppGradients.premium,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR VIRTUAL MODEL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                SizedBox(height: 8),
                Text('Create a model\nthat feels like you.', style: TextStyle(fontSize: 27, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -1)),
                SizedBox(height: 9),
                Text('Add your face and, optionally, a full-body photo. Your photos stay stored locally on this device.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [_photoCard(face: true), const SizedBox(width: 10), _photoCard(face: false)]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Model details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('These details help TiB understand proportions when styling you.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.35)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Height', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('${_height.round()} cm', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                  ],
                ),
                Slider(
                  value: _height,
                  min: 140,
                  max: 200,
                  divisions: 60,
                  onChanged: (value) => setState(() => _height = value),
                ),
                const SizedBox(height: 8),
                const Text('Body shape', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: _shapes.map((shape) => ChoiceChip(label: Text(shape), selected: _bodyShape == shape, onSelected: (_) => setState(() => _bodyShape = shape))).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('TiB uses the photos only for your model on this device. A future photorealistic AI provider can be connected when you are ready.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy || !ready ? null : _saveProfile,
            icon: const Icon(Icons.check_rounded),
            label: Text(_busy ? 'Preparing…' : 'Save My TiB Model'),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_status, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
