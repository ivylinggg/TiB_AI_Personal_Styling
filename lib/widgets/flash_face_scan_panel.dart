import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_colors.dart';
import '../services/mlkit_service.dart';

/// Live face scan used by the fifth flash-profile step.
///
/// The user does not press a shutter button and does not take five photos.
/// The front camera stays live while TiB repeatedly checks temporary frames
/// until one clear, centred face has been stable for several checks.
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

class _FlashFaceScanPanelState extends State<FlashFaceScanPanel>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  Timer? _scanTimer;
  bool _initialising = true;
  bool _checkingFrame = false;
  bool _completed = false;
  String? _error;
  String _status = 'Look straight at the camera and hold still.';
  int _stableChecks = 0;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _initCamera();
  }

  @override
  void didUpdateWidget(covariant FlashFaceScanPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy && !oldWidget.busy && mounted) {
      _stopScanning();
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

      _startScanning();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initialising = false;
        _error = 'Camera could not be started.';
      });
    }
  }

  void _startScanning() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(
      const Duration(milliseconds: 750),
      (_) => _scanFrame(),
    );
    _scanFrame();
  }

  void _stopScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  @override
  void dispose() {
    _stopScanning();
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _scanFrame() async {
    final controller = _controller;
    if (!mounted ||
        widget.busy ||
        _completed ||
        _checkingFrame ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() => _checkingFrame = true);

    try {
      final photo = await controller.takePicture();
      final file = File(photo.path);
      final faces = await MlKitService.detectFace(file);

      if (!mounted || _completed) return;

      if (faces.length != 1) {
        _stableChecks = 0;
        setState(() {
          _checkingFrame = false;
          _status = faces.isEmpty
              ? 'Scanning… keep your face inside the frame.'
              : 'Please scan alone with only one face visible.';
        });
        return;
      }

      final face = faces.first;
      final previewSize = controller.value.previewSize;
      final imageWidth = previewSize?.height ?? 1;
      final imageHeight = previewSize?.width ?? 1;
      final box = face.boundingBox;
      final centerX = box.center.dx / imageWidth;
      final centerY = box.center.dy / imageHeight;
      final faceWidthRatio = box.width / imageWidth;

      final centred =
          centerX > .34 && centerX < .66 && centerY > .25 && centerY < .72;
      final usableSize = faceWidthRatio > .20 && faceWidthRatio < .72;
      final straight =
          ((face.headEulerAngleY ?? 0).abs() < 13) &&
          ((face.headEulerAngleX ?? 0).abs() < 13);

      if (!centred || !usableSize || !straight) {
        _stableChecks = 0;
        setState(() {
          _checkingFrame = false;
          _status = 'Centre your face and look straight at the camera.';
        });
        return;
      }

      _stableChecks += 1;
      if (_stableChecks >= 3) {
        _completed = true;
        _stopScanning();
        setState(() {
          _checkingFrame = false;
          _status = 'Face detected — analysing your colouring…';
        });
        widget.onCaptured(file);
        return;
      }

      setState(() {
        _checkingFrame = false;
        _status = 'Face detected. Hold still… ${3 - _stableChecks}';
      });
    } catch (_) {
      if (!mounted) return;
      _stableChecks = 0;
      setState(() {
        _checkingFrame = false;
        _status = 'Keep looking at the camera…';
      });
    }
  }

  Future<void> _gallery() async {
    if (_checkingFrame || widget.busy || _completed) return;

    _stopScanning();

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1800,
    );
    if (picked == null || !mounted) {
      if (mounted && !widget.busy && !_completed) _startScanning();
      return;
    }

    setState(() {
      _checkingFrame = true;
      _status = 'Checking your photo…';
    });

    try {
      final file = File(picked.path);
      final faces = await MlKitService.detectFace(file);

      if (!mounted) return;

      if (faces.length != 1) {
        setState(() {
          _checkingFrame = false;
          _status = faces.isEmpty
              ? 'No face detected in that photo.'
              : 'Please choose a photo with only one visible face.';
        });
        _startScanning();
        return;
      }

      _completed = true;
      setState(() {
        _checkingFrame = false;
        _status = 'Face detected — analysing your colouring…';
      });
      widget.onCaptured(file);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingFrame = false;
        _status = 'This photo could not be checked. Try again.';
      });
      _startScanning();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_initialising) {
      return _panelShell(
        const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
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
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Camera unavailable',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                const Text(
                  'You can still choose a clear face photo from your gallery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: widget.busy ? null : _gallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose Photo'),
                ),
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            _status,
            key: ValueKey(_status),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 9),
        Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Choose from gallery',
            onPressed: _checkingFrame || widget.busy ? null : _gallery,
            icon: const Icon(Icons.photo_outlined, size: 22),
          ),
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
          CustomPaint(
            painter: _FaceGuidePainter(
              active: _checkingFrame,
              pulse: _pulseController,
            ),
          ),
          Positioned(
            top: 14,
            right: 12,
            child: Column(
              children: const [
                _Tip(icon: Icons.wb_sunny_outlined, text: 'Good\nlighting'),
                SizedBox(height: 13),
                _Tip(
                  icon: Icons.face_retouching_natural_outlined,
                  text: 'No makeup\nor filters',
                ),
                SizedBox(height: 13),
                _Tip(icon: Icons.person_outline_rounded, text: 'Hair tied\nback'),
                SizedBox(height: 13),
                _Tip(
                  icon: Icons.sentiment_satisfied_alt_outlined,
                  text: 'Look\nstraight',
                ),
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
                  Text(
                    '✦ Tips for best results',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Use natural lighting and remove\nmakeup & glasses.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_checkingFrame || widget.busy)
            Container(
              color: Colors.black.withValues(alpha: .10),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
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
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8.5,
            height: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FaceGuidePainter extends CustomPainter {
  final bool active;
  final Animation<double> pulse;

  const _FaceGuidePainter({required this.active, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: .08);
    canvas.drawRect(Offset.zero & size, overlay);

    final center = Offset(size.width * .43, size.height * .47);
    final ovalRect = Rect.fromCenter(
      center: center,
      width: size.width * .55,
      height: size.height * .74,
    );

    final pulseValue = active ? pulse.value : 0.0;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 3.2 + pulseValue * 1.2 : 2.2
      ..color = active
          ? AppColors.primary.withValues(alpha: .80 + pulseValue * .20)
          : Colors.white;
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
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) {
    return oldDelegate.active != active || oldDelegate.pulse.value != pulse.value;
  }
}
