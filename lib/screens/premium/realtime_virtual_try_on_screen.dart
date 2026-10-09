import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:decart_vton_flutter/decart_vton_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/wardrobe_item.dart';
import '../../services/decart_vton_service.dart';
import '../../services/firestore_service.dart';
import '../../services/tib_model_service.dart';

class RealtimeVirtualTryOnScreen extends StatefulWidget {
  const RealtimeVirtualTryOnScreen({super.key});

  @override
  State<RealtimeVirtualTryOnScreen> createState() =>
      _RealtimeVirtualTryOnScreenState();
}

class _RealtimeVirtualTryOnScreenState extends State<RealtimeVirtualTryOnScreen> {
  static const int _maxGarmentBytes = 5 * 1024 * 1024;

  final DecartVton _vton = DecartVton();
  final List<StreamSubscription<Object?>> _subscriptions = <StreamSubscription<Object?>>[];
  VtonLifecycleObserver? _lifecycle;
  TibModelProfile? _model;
  List<WardrobeItem> _wardrobe = const [];
  WardrobeItem? _selectedItem;
  bool _loading = true;
  bool _busy = false;
  String _status = 'Ready for live try-on.';
  String? _loadingItemId;

  @override
  void initState() {
    super.initState();
    _attachObservers();
    _load();
  }

  void _attachObservers() {
    _subscriptions.add(_vton.errors.listen((error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = error.message;
      });
    }));
    _lifecycle = VtonLifecycleObserver(
      onError: (error) {
        if (!mounted) return;
        setState(() => _status = 'Live session recovery failed: ${error.message}');
      },
    )..attach();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() { _loading = false; _status = 'Please sign in again before starting live try-on.'; });
      return;
    }
    try {
      final results = await Future.wait<dynamic>([TibModelService.load(), FirestoreService.getWardrobeItems(uid)]);
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      final model = results[0] as TibModelProfile?;
      final items = results[1] is List<WardrobeItem> ? List<WardrobeItem>.from(results[1] as List<WardrobeItem>) : <WardrobeItem>[];
      setState(() {
        _model = model;
        _wardrobe = items.where((item) => item.userId.isEmpty || item.userId == uid).toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _status = 'Could not load your wardrobe. Please try again.'; });
    }
  }

  bool get _isLive => _vton.isConnected;

  Future<bool> _requestCameraPermission() async {
    final permission = await Permission.camera.request();
    if (permission.isGranted) return true;
    if (!mounted) return false;
    final permanentlyDenied = permission.isPermanentlyDenied;
    setState(() => _status = permanentlyDenied ? 'Camera access is disabled. Enable Camera for VYEA in Settings.' : 'Camera permission is required for live try-on.');
    if (permanentlyDenied) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Camera access needed'),
          content: const Text('VYEA needs your camera to show the real-time try-on. Please enable Camera permission in Settings.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Not now')),
            FilledButton(onPressed: () { Navigator.pop(dialogContext); openAppSettings(); }, child: const Text('Open Settings')),
          ],
        ),
      );
    }
    return false;
  }

  Future<void> _startLive() async {
    if (_busy || _isLive) return;
    if (_model?.isComplete != true) {
      setState(() => _status = 'Complete your Personal TiB Model first so VYEA can keep this experience personal.');
      return;
    }
    if (!await _requestCameraPermission()) return;
    setState(() { _busy = true; _status = 'Starting your live fitting room…'; });
    try {
      if (!_vton.isInitialized) {
        await _vton.initialize(clientTokenProvider: DecartVtonService.fetchClientToken);
      }
      await _vton.connect(
        model: VtonModel.lucyVtonLatest,
        resolution: VtonResolution.p720,
        camera: VtonCameraFacing.front,
        mirror: VtonMirrorMode.auto,
      );
      if (!mounted) return;
      setState(() { _busy = false; _status = 'LIVE — move naturally. Choose a wardrobe piece below to try it on.'; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _busy = false; _status = 'Could not start live try-on: ${error.toString()}'; });
    }
  }

  Future<void> _stopLive() async {
    if (_busy || !_isLive) return;
    setState(() { _busy = true; _status = 'Ending live try-on…'; });
    try { await _vton.disconnect(); } catch (_) {}
    if (!mounted) return;
    setState(() { _busy = false; _selectedItem = null; _status = 'Live try-on stopped.'; });
  }

  Future<void> _switchCamera() async {
    if (!_isLive || _busy) return;
    setState(() { _busy = true; _status = 'Switching camera…'; });
    try {
      final facing = await _vton.switchCamera();
      if (!mounted) return;
      setState(() { _busy = false; _status = 'Live — using the ${facing.name} camera.'; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _busy = false; _status = 'Could not switch camera: ${error.toString()}'; });
    }
  }

  Future<File> _downloadGarment(WardrobeItem item) async {
    final url = item.imageUrl.trim();
    if (url.isEmpty) throw const FormatException('This wardrobe item has no image.');
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw HttpException('Wardrobe image returned HTTP ${response.statusCode}.', uri: Uri.parse(url));
    if (response.bodyBytes.isEmpty) throw const FormatException('The wardrobe image is empty.');
    if (response.bodyBytes.length > _maxGarmentBytes) throw const FormatException('This wardrobe image is larger than 5 MB and cannot be used for live try-on.');
    final contentType = response.headers['content-type']?.split(';').first.toLowerCase();
    const supported = <String>{'image/jpeg', 'image/png', 'image/webp'};
    if (contentType != null && !supported.contains(contentType)) throw const FormatException('The wardrobe image must be JPEG, PNG, or WebP.');
    final extension = contentType == 'image/png' ? 'png' : contentType == 'image/webp' ? 'webp' : 'jpg';
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/vyea_vton_${item.id.trim()}.$extension');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  String _promptFor(WardrobeItem item) {
    final category = item.category.trim().isEmpty ? 'garment' : item.category.trim();
    final name = item.name.trim().isEmpty ? category : item.name.trim();
    final colour = item.colour.trim().isEmpty ? '' : ' ${item.colour.trim()}';
    final style = item.style.trim().isEmpty ? '' : ' ${item.style.trim()}';
    return 'Substitute the current $category with this exact$colour$style $name from the supplied wardrobe reference image. Keep the same real person, face, body proportions, pose and natural silhouette. Preserve the garment colour, material, construction and visible details. Do not replace the person with a generic model.';
  }

  Future<void> _selectWardrobeItem(WardrobeItem item) async {
    if (!_isLive || _busy) return;
    setState(() { _busy = true; _loadingItemId = item.id; _status = 'Preparing ${item.name} for live try-on…'; });
    try {
      final file = await _downloadGarment(item);
      await _vton.setOutfit(outfit: VtonOutfit(prompt: _promptFor(item), referenceImagePath: file.path, enhance: false));
      if (!mounted) return;
      setState(() { _selectedItem = item; _busy = false; _loadingItemId = null; _status = 'LIVE — ${item.name} is now on you.'; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _busy = false; _loadingItemId = null; _status = 'Could not apply ${item.name}: ${error.toString()}'; });
    }
  }

  @override
  void dispose() {
    _lifecycle?.detach();
    for (final subscription in _subscriptions) { unawaited(subscription.cancel()); }
    unawaited(_vton.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Live Virtual Try-On', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [if (_isLive) IconButton(tooltip: 'Switch camera', onPressed: _busy ? null : _switchCamera, icon: const Icon(Icons.cameraswitch_outlined))],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isLive) const VtonRemoteView(fit: VtonVideoFit.cover) else _idleView(),
          _topLiveBadge(),
          _bottomControls(),
        ],
      ),
    );
  }

  Widget _idleView() => Container(
    decoration: BoxDecoration(gradient: AppGradients.premium),
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.camera_front_rounded, size: 64, color: AppColors.primaryDark),
            const SizedBox(height: 18),
            const Text('See yourself wearing your own clothes — live.', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, height: 1.05, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('VYEA uses your live camera and your wardrobe reference image. There is no 3D avatar and no generated still photo.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45)),
            const SizedBox(height: 22),
            FilledButton.icon(onPressed: _busy ? null : _startLive, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow_rounded), label: Text(_busy ? 'Starting…' : 'Start Live Try-On'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
          ]),
        ),
      ),
    ),
  );

  Widget _topLiveBadge() {
    if (!_isLive) return const SizedBox.shrink();
    return Positioned(top: 14, left: 14, right: 14, child: Row(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .68), borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)), const SizedBox(width: 6), const Text('LIVE TRY-ON', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .9))])),
      const Spacer(),
      if (_selectedItem != null) Container(constraints: const BoxConstraints(maxWidth: 170), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .68), borderRadius: BorderRadius.circular(999)), child: Text(_selectedItem!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
    ]));
  }

  Widget _bottomControls() => Positioned(
    left: 12, right: 12, bottom: 12,
    child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (_status.isNotEmpty) Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .68), borderRadius: BorderRadius.circular(15)), child: Text(_status, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, height: 1.35, fontWeight: FontWeight.w600))),
      if (_isLive) _wardrobeTray(),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: FilledButton.icon(onPressed: _busy ? null : (_isLive ? _stopLive : _startLive), icon: Icon(_isLive ? Icons.stop_circle_outlined : Icons.play_arrow_rounded), label: Text(_isLive ? 'Stop Live' : 'Start Live'), style: FilledButton.styleFrom(backgroundColor: _isLive ? Colors.white : AppColors.primary, foregroundColor: _isLive ? Colors.black : Colors.white, minimumSize: const Size.fromHeight(48))))]),
    ])),
  );

  Widget _wardrobeTray() => Container(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .72), borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Row(children: [Icon(Icons.checkroom_outlined, color: Colors.white, size: 15), SizedBox(width: 6), Text('MY WARDROBE · TAP TO SWITCH LIVE', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: .8))])),
      const SizedBox(height: 8),
      SizedBox(height: 112, child: _wardrobe.isEmpty ? const Center(child: Text('Add clothes to My Wardrobe first.', style: TextStyle(color: Colors.white70, fontSize: 11))) : ListView.separated(scrollDirection: Axis.horizontal, itemCount: _wardrobe.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (context, index) {
        final item = _wardrobe[index];
        final selected = _selectedItem?.id == item.id;
        final loading = _loadingItemId == item.id;
        return GestureDetector(onTap: _busy ? null : () => _selectWardrobeItem(item), child: SizedBox(width: 82, child: Stack(children: [
          Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? AppColors.primary : Colors.white24, width: selected ? 2.2 : 1)), clipBehavior: Clip.antiAlias, child: Column(children: [Expanded(child: item.imageUrl.isEmpty ? const Icon(Icons.checkroom_outlined, color: AppColors.textMuted, size: 27) : CachedNetworkImage(imageUrl: item.imageUrl, width: double.infinity, fit: BoxFit.cover)), Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5), color: Colors.white, child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800)))])),
          if (loading) Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(14)), child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))),
        ])));
      })),
    ]),
  );
}