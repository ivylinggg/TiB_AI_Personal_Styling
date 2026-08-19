import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../services/mlkit_service.dart';

/// Guided face capture for Colour Analysis.
///
/// The scan is deliberately strict: exactly one face must be visible and the
/// requested head pose must be detected before a step can pass. The centre
/// frame is returned to the colour-analysis pipeline; the other four poses
/// act as quality/coverage checks and make the experience feel like a real
/// biometric-style scan rather than a plain image picker.
class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

enum _Pose { center, left, right, up, down }

class _FaceScanStep {
  final _Pose pose;
  final String title;
  final String instruction;
  final IconData icon;

  const _FaceScanStep({
    required this.pose,
    required this.title,
    required this.instruction,
    required this.icon,
  });
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  static const _steps = [
    _FaceScanStep(
      pose: _Pose.center,
      title: 'Look straight ahead',
      instruction: 'Keep your face inside the frame and look at the screen.',
      icon: Icons.face_retouching_natural_rounded,
    ),
    _FaceScanStep(
      pose: _Pose.left,
      title: 'Turn left',
      instruction: 'Slowly turn your head to your left.',
      icon: Icons.rotate_left_rounded,
    ),
    _FaceScanStep(
      pose: _Pose.right,
      title: 'Turn right',
      instruction: 'Slowly turn your head to your right.',
      icon: Icons.rotate_right_rounded,
    ),
    _FaceScanStep(
      pose: _Pose.up,
      title: 'Look up',
      instruction: 'Gently tilt your chin upward.',
      icon: Icons.keyboard_arrow_up_rounded,
    ),
    _FaceScanStep(
      pose: _Pose.down,
      title: 'Look down',
      instruction: 'Gently tilt your chin downward.',
      icon: Icons.keyboard_arrow_down_rounded,
    ),
  ];

  CameraController? _controller;
  int _stepIndex = 0;
  bool _initialising = true;
  bool _checking = false;
  bool _stepPassed = false;
  String _status = 'Position your face inside the guide.';
  File? _centrePhoto;
  String? _cameraError;

  _FaceScanStep get _step => _steps[_stepIndex];
  double get _progress => (_stepIndex + (_stepPassed ? 1 : 0)) / _steps.length;

  @override
  void initState() {
    super.initState();
    _initialiseCamera();
  }

  Future<void> _initialiseCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera is available on this device.');
      }

      final front = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      final selected = front.isNotEmpty ? front.first : cameras.first;

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initialising = false;
        _cameraError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initialising = false;
        _cameraError = 'Camera could not be started. ${error.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureStep() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _checking) {
      return;
    }

    setState(() {
      _checking = true;
      _stepPassed = false;
      _status = 'Scanning your face…';
    });

    try {
      final captured = await controller.takePicture();
      final file = File(captured.path);
      final faces = await MlKitService.detectFace(file);

      if (!mounted) return;

      if (faces.length != 1) {
        setState(() {
          _checking = false;
          _status = faces.isEmpty
              ? 'No face detected. Move closer and try again.'
              : 'More than one face detected. Please scan alone.';
        });
        return;
      }

      final face = faces.first;
      if (!_matchesPose(face, _step.pose)) {
        setState(() {
          _checking = false;
          _status = 'Face found, but the pose is not quite right. Try again.';
        });
        return;
      }

      if (_step.pose == _Pose.center) {
        _centrePhoto = file;
      }

      setState(() {
        _checking = false;
        _stepPassed = true;
        _status = 'Great — pose captured.';
      });

      await Future<void>.delayed(const Duration(milliseconds: 420));

      if (!mounted) return;

      if (_stepIndex == _steps.length - 1) {
        if (_centrePhoto != null) {
          Navigator.pop(context, _centrePhoto);
        }
        return;
      }

      setState(() {
        _stepIndex += 1;
        _stepPassed = false;
        _status = 'Next pose ready.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _status = 'The scan could not be completed. Please try again.';
      });
    }
  }

  bool _matchesPose(dynamic face, _Pose pose) {
    final y = (face.headEulerAngleY as double?) ?? 0;
    final x = (face.headEulerAngleX as double?) ?? 0;

    switch (pose) {
      case _Pose.center:
        return y.abs() < 12 && x.abs() < 12;
      case _Pose.left:
        return y > 15;
      case _Pose.right:
        return y < -15;
      case _Pose.up:
        return x < -12;
      case _Pose.down:
        return x > 12;
    }
  }

  Future<void> _useGalleryPhoto() async {
    if (_checking) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1800,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _checking = true;
      _status = 'Checking the photo…';
    });

    try {
      final file = File(picked.path);
      final faces = await MlKitService.detectFace(file);

      if (!mounted) return;

      if (faces.length == 1) {
        Navigator.pop(context, file);
      } else {
        setState(() {
          _checking = false;
          _status = faces.isEmpty
              ? 'That photo does not contain a detectable face.'
              : 'Please choose a photo with only one visible face.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _status = 'This photo could not be checked. Try another one.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Face Scan'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _checking ? null : () => Navigator.pop(context),
        ),
      ),
      body: _initialising
          ? const Center(child: CircularProgressIndicator())
          : _cameraError != null || controller == null
          ? _buildCameraError()
          : SafeArea(
              child: Column(
                children: [
                  _buildProgress(),
                  Expanded(child: _buildCamera(controller)),
                  _buildControls(),
                ],
              ),
            ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'FACE COVERAGE',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${_stepIndex + 1} / ${_steps.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: _progress.clamp(0, 1),
              backgroundColor: AppColors.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation(AppColors.eggYolk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCamera(CameraController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 245,
                  height: 320,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(120),
                    border: Border.all(
                      color: _stepPassed ? AppColors.eggYolk : Colors.white,
                      width: _stepPassed ? 5 : 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 22,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              right: 18,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(_step.icon, color: AppColors.eggYolk, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _step.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _step.instruction,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              _status,
              key: ValueKey(_status),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _checking ? null : _captureStep,
              icon: _checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryDark,
                      ),
                    )
                  : Icon(_stepPassed ? Icons.check_rounded : Icons.camera_alt_rounded),
              label: Text(_checking ? 'Checking…' : 'Capture ${_step.title}'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.eggYolk,
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _checking ? null : _useGalleryPhoto,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Use a face photo from Gallery'),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 34),
            ),
            const SizedBox(height: 18),
            const Text(
              'Camera scan unavailable',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _cameraError ?? 'You can still choose a clear face photo from your gallery.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _useGalleryPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose a Face Photo'),
            ),
          ],
        ),
      ),
    );
  }
}
