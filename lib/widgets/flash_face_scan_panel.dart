import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';
import '../services/mlkit_service.dart';

/// Single-photo face scan UI used by the flash-profile onboarding step.
///
/// It intentionally does not ask the user to turn left/right/up/down.
/// The user only needs one clear, straight-on face photo.
class FlashFaceScanPanel extends StatefulWidget {
  final ValueChanged<File> onCaptured;
  final bool busy;

  const FlashFaceScanPanel({
    super.key,
    required this.onCaptured,
    this.busy = false,
  });

  @override
  State<FlashFaceScanPanel> createState() => _FlashFaceScanPanelState();
}

class _FlashFaceScanPanelState extends State<FlashFaceScanPanel> {
  CameraController? _controller;
  bool _initialising = true;
  bool _capturing = false;
  String? _error;
  String _status = 'Position your face inside the guide.';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void didUpdateWidget(covariant FlashFaceScanPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy && !oldWidget.busy && mounted) {
      setState(() => _status = 'Creating your colour profile…');
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera is available.');

      final front = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      final selected = front.isNotEmpty ? front.first : cameras.first;
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
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
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initialising = false;
        _error = 'Camera could not be started.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturing ||
        widget.busy) {
      return;
    }

    setState(() {
      _capturing = true;
      _status = 'Scanning your face…';
    });

    try {
      final photo = await controller.takePicture();
      final file = File(photo.path);
      final faces = await MlKitService.detectFace(file);

      if (!mounted) return;

      if (faces.length != 1) {
        setState(() {
          _capturing = false;
          _status = faces.isEmpty
              ? 'No face detected. Move closer and try again.'
              : 'Please scan alone with only one face visible.';
        });
        return;
      }

      final face = faces.first;
      final size = controller.value.previewSize;
      final imageWidth = size?.height ?? 1;
      final imageHeight = size?.width ?? 1;
      final box = face.boundingBox;
      final faceCenterX = box.center.dx / imageWidth;
      final faceCenterY = box.center.dy / imageHeight;
      final faceWidthRatio = box.width / imageWidth;

      final centered =
          faceCenterX > .34 && faceCenterX < .66 && faceCenterY > .25 && faceCenterY < .72;
      final usableSize = faceWidthRatio > .20 && faceWidthRatio < .72;

      if (!centered || !usableSize) {
        setState(() {
          _capturing = false;
          _status = 'Keep your face centred inside the guide and try again.';
        });
        return;
      }

      setState(() {
        _capturing = false;
        _status = 'Face detected. Analysing your natural colouring…';
      });
      widget.onCaptured(file);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _status = 'The scan could not be completed. Please try again.';
      });
    }
  }

  Future<void> _gallery() async {
    if (_capturing || widget.busy) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1800,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _capturing = true;
      _status = 'Checking your photo…';
    });

    try {
      final file = File(picked.path);
      final faces = await MlKitService.detectFace(file);

      if (!mounted) return;
      if (faces.length != 1) {
        setState(() {
          _capturing = false;
          _status = faces.isEmpty
              ? 'No face detected in that photo.'
              : 'Please choose a photo with only one visible face.';
        });
        return;
      }

      setState(() => _status = 'Face detected. Analysing your natural colouring…');
      widget.onCaptured(file);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _status = 'This photo could not be checked. Try another one.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_initialising) {
      return _panelShell(
        const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_error != null || controller == null) {
      return _panelShell(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_outlined, size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                const Text('Camera unavailable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                const Text('You can still choose a clear face photo from your gallery.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)),
                const SizedBox(height: 14),
                OutlinedButton.icon(onPressed: widget.busy ? null : _gallery, icon: const Icon(Icons.photo_library_outlined), label: const Text('Choose Photo')),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: _cameraView(controller)),
        const SizedBox(height: 10),
        Text(
          _status,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Material(
              color: AppColors.surface,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Choose from gallery',
                onPressed: _capturing || widget.busy ? null : _gallery,
                icon: const Icon(Icons.photo_outlined, size: 22),
              ),
            ),
            const SizedBox(width: 22),
            GestureDetector(
              onTap: _capturing || widget.busy ? null : _capture,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _capturing || widget.busy ? AppColors.primarySoft : AppColors.primary,
                  border: Border.all(color: Colors.white, width: 5),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, 6))],
                ),
                child: Icon(
                  _capturing || widget.busy ? Icons.hourglass_top_rounded : Icons.camera_alt_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
      ],
    );
  }

  Widget _panelShell(Widget child) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFF1E8FA), Color(0xFFFFF1EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }

  Widget _cameraView(CameraController controller) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          CustomPaint(painter: _FaceGuidePainter(active: _capturing || widget.busy)),
          Positioned(
            top: 14,
            right: 12,
            child: Column(
              children: const [
                _Tip(icon: Icons.wb_sunny_outlined, text: 'Good\nlighting'),
                SizedBox(height: 13),
                _Tip(icon: Icons.face_retouching_natural_outlined, text: 'No makeup\nor filters'),
                SizedBox(height: 13),
                _Tip(icon: Icons.person_outline_rounded, text: 'Hair tied\nback'),
                SizedBox(height: 13),
                _Tip(icon: Icons.sentiment_satisfied_alt_outlined, text: 'Look\nstraight'),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBEFF6).withValues(alpha: .94),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✦ Tips for best results', style: TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Use natural lighting and remove\nmakeup & glasses.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35)),
                ],
              ),
            ),
          ),
          if (_capturing || widget.busy)
            Container(
              color: Colors.black.withValues(alpha: .24),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .18), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(height: 4),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 8.5, height: 1.1, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _FaceGuidePainter extends CustomPainter {
  final bool active;

  const _FaceGuidePainter({required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: .12);
    canvas.drawRect(Offset.zero & size, overlay);

    final centre = Offset(size.width * .43, size.height * .47);
    final ovalRect = Rect.fromCenter(
      center: centre,
      width: size.width * .55,
      height: size.height * .74,
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = active ? AppColors.primary : Colors.white;
    canvas.drawOval(ovalRect, stroke);

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.1
      ..color = Colors.white;

    const length = 28.0;
    final l = ovalRect.left - 1;
    final r = ovalRect.right + 1;
    final t = ovalRect.top - 1;
    final b = ovalRect.bottom + 1;

    canvas
      ..drawLine(Offset(l, t + length), Offset(l, t), cornerPaint)
      ..drawLine(Offset(l, t), Offset(l + length, t), cornerPaint)
      ..drawLine(Offset(r, t + length), Offset(r, t), cornerPaint)
      ..drawLine(Offset(r, t), Offset(r - length, t), cornerPaint)
      ..drawLine(Offset(l, b - length), Offset(l, b), cornerPaint)
      ..drawLine(Offset(l, b), Offset(l + length, b), cornerPaint)
      ..drawLine(Offset(r, b - length), Offset(r, b), cornerPaint)
      ..drawLine(Offset(r, b), Offset(r - length, b), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) => oldDelegate.active != active;
}
