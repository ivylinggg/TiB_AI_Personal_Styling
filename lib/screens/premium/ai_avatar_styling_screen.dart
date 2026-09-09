import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../services/ai_styling_service.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../services/tib_model_service.dart';
import '../../services/virtual_try_on_result_service.dart';

class AiAvatarStylingScreen extends StatefulWidget {
  const AiAvatarStylingScreen({super.key});
  @override
  State<AiAvatarStylingScreen> createState() => _AiAvatarStylingScreenState();
}

class _AiAvatarStylingScreenState extends State<AiAvatarStylingScreen> {
  static const _occasions = ['Dinner', 'Work', 'Casual', 'Date', 'Travel', 'Event'];
  bool _loading = true;
  bool _busy = false;
  TibModelProfile? _model;
  ColourAnalysisResult? _analysis;
  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];
  List<WardrobeItem> _look = const [];
  AiStylingResult? _recommendation;
  String _occasion = 'Dinner';
  String _status = '';
  String? _imageUrl;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { if (mounted) setState(() => _loading = false); return; }
    try {
      final results = await Future.wait<dynamic>([
        TibModelService.load(),
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
        FirestoreService.getLatestColourAnalysis(uid),
      ]);
      if (!mounted) return;
      final prefs = results[2] as Map<String, dynamic>?;
      setState(() {
        _model = results[0] as TibModelProfile;
        _wardrobe = results[1] as List<WardrobeItem>;
        _styles = List<String>.from(prefs?['styles'] ?? const []);
        _preferences = List<String>.from(prefs?['preferences'] ?? const []);
        _analysis = results[3] as ColourAnalysisResult?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _status = 'Could not load your styling profile. Please try again.'; });
    }
  }

  Future<void> _createAvatarLook() async {
    if (_busy) return;
    final model = _model;
    final analysis = _analysis;
    if (model == null || !model.isComplete || model.faceFile == null || model.bodyFile == null) { setState(() => _status = 'Complete your face scan, full-body reference and TiB Model first.'); return; }
    if (_wardrobe.isEmpty) { setState(() => _status = 'Add some clothes and shoes to your wardrobe first.'); return; }
    if (analysis == null) { setState(() => _status = 'Complete Colour Analysis first so TiB can choose your best colours.'); return; }
    setState(() { _busy = true; _imageUrl = null; _recommendation = null; _look = const []; _status = 'TiB is finding the best outfit for you…'; });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Your session has ended.');
      final recommendation = await AiStylingService.getRecommendation(uid: uid, profile: analysis, wardrobe: _wardrobe, styles: _styles, preferences: _preferences, occasion: _occasion);
      if (!mounted) return;
      if (recommendation == null) { setState(() { _busy = false; _status = 'TiB could not find a complete match. Try adding more wardrobe pieces.'; }); return; }
      final ids = <String?>[recommendation.topId, recommendation.bottomId, recommendation.dressId, recommendation.suitId, recommendation.jacketId, recommendation.shoesId, recommendation.accessoryId];
      final selected = ids.whereType<String>().map(_find).whereType<WardrobeItem>().toList();
      if (selected.isEmpty) { setState(() { _busy = false; _recommendation = recommendation; _status = 'TiB found styling guidance, but no wardrobe match was returned.'; }); return; }
      setState(() { _recommendation = recommendation; _look = selected; _status = 'Your personal TiB model is trying on the recommended look…'; });
      final tryOn = await VirtualTryOnResultService.generate(VirtualTryOnRequest(model: model, items: selected, occasion: _occasion, stylingBrief: _buildStylingBrief(recommendation)));
      if (!mounted) return;
      setState(() { _imageUrl = tryOn.imageUrl; _status = tryOn.status; _busy = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _busy = false; _status = 'Could not create your virtual look right now. Please try again.'; });
    }
  }

  String _buildStylingBrief(AiStylingResult recommendation) {
    final model = _model!;
    final reason = recommendation.explanation.trim().isEmpty ? 'Choose the combination that best fits the user’s colour, body-shape and style context.' : recommendation.explanation.trim();
    return '''TI B PERSONAL VIRTUAL YOU — NON-NEGOTIABLE GENERATION BRIEF

PERSON IDENTITY:
- This is the real user, not a generic fashion model.
- Reference A is the user's FULL-BODY reference photo. It is the primary geometry, silhouette, height impression and body-proportion anchor.
- Reference B is the user's FACE reference photo. It is the primary facial identity anchor.
- The same person must be maintained from head to toe.
- Do not replace the person with a prettier, slimmer, taller, younger, or more model-like person.

MEASURED PERSONAL BODY DATA — HARD FIT CONTEXT:
- Height: ${model.height.toStringAsFixed(1)} cm
- Weight: ${model.weight.toStringAsFixed(1)} kg
- Bust: ${model.bust.toStringAsFixed(1)} cm
- Waist: ${model.waist.toStringAsFixed(1)} cm
- Hips: ${model.hips.toStringAsFixed(1)} cm
- Body shape: ${model.bodyShape}
- Face shape: ${model.faceShape}
- Waist/Bust ratio: ${model.measurementData['proportionRatios']['waistToBust'] ?? 'unknown'}
- Waist/Hips ratio: ${model.measurementData['proportionRatios']['waistToHips'] ?? 'unknown'}
- Hips/Bust ratio: ${model.measurementData['proportionRatios']['hipsToBust'] ?? 'unknown'}

BODY FIDELITY:
- Use the full-body reference photo as the primary source of the person's actual body geometry.
- Use the measurements to validate and preserve the proportions visible in that photo.
- Preserve shoulder width, torso length, waist placement, hip width, leg length, body scale and natural posture.
- Clothing must be fitted TO THIS BODY, not the body redesigned to fit the clothing.
- Never slim, enlarge, lengthen, shorten, reshape, smooth, idealize or otherwise alter the body.
- Never turn the user into a mannequin or generic runway model.

FACE FIDELITY:
- Preserve recognizable facial structure, eyes, nose, lips, jaw, skin tone, hair and natural appearance from the face reference.
- Do not beautify or replace facial identity.
- Integrate the real face naturally with the full-body reference.

WARDROBE FIDELITY:
- Use ONLY the selected wardrobe reference images supplied in this request.
- Preserve each selected item's category, colour, pattern, material, texture, silhouette, neckline, sleeves, seams, hem and visible construction.
- Do not invent replacement clothing.
- Do not add unselected bags, jewellery, jackets, shoes or accessories.
- If shoes are selected, show those exact shoes on the user.

OUTPUT:
- Generate ONE photorealistic fashion photograph of THIS USER wearing the selected outfit.
- The composition MUST be head-to-toe full body: entire head, torso, both legs and both feet visible in frame.
- Use a natural standing pose and realistic camera perspective.
- Keep the person centred and large enough that body proportions and garment fit can be evaluated.
- Show realistic garment folds, contact shadows, fabric behaviour and lighting.
- Use a clean editorial background without distracting objects.
- The result should feel like a premium AI fitting-room photograph of the user's own body, not an avatar illustration.

OCCASION: $_occasion

WHY TIB SELECTED THIS LOOK:
$reason

FINAL PRIORITY ORDER:
1. Same real person and face identity.
2. Same real full-body silhouette and measured proportions.
3. Exact selected wardrobe items.
4. Natural garment fit.
5. Head-to-toe composition.
6. Editorial presentation.''';
  }

  WardrobeItem? _find(String id) { for (final item in _wardrobe) { if (item.id == id) return item; } return null; }

  Future<void> _saveLook() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _look.isEmpty) return;
    try {
      await FirestoreService.saveOutfitLook(uid: uid, occasion: _occasion, itemIds: _look.map((item) => item.id).toList(), matchScore: _recommendation?.matchScore ?? 0, season: _analysis?.season ?? 'Unknown', title: _recommendation?.displayTitle, notes: _recommendation?.stylingNotes.join(' • '));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your TiB look was saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save this look right now.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final model = _model;
    final ready = model?.isComplete == true;
    return Scaffold(backgroundColor: AppColors.background, appBar: AppBar(title: const Text('TiB AI Avatar')), body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 34), children: [
      _buildHero(model, ready), const SizedBox(height: 16), _buildOccasion(), const SizedBox(height: 14), _buildHowItWorks(), const SizedBox(height: 16), if (_look.isNotEmpty) ...[_buildRecommendedLook(), const SizedBox(height: 14)],
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _createAvatarLook, icon: _busy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.auto_awesome_rounded), label: Text(_busy ? 'Creating Your Virtual Look…' : 'Find My Best Look')),
      if (_status.isNotEmpty) ...[const SizedBox(height:12),Text(_status,textAlign:TextAlign.center,style:const TextStyle(color:AppColors.textSecondary,fontSize:11.5,height:1.45))],
      if (_imageUrl != null) ...[const SizedBox(height:18),_buildResult()],
    ]));
  }

  Widget _buildHero(TibModelProfile? model, bool ready) { final face=model?.faceFile; final body=model?.bodyFile; return Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:AppGradients.premium,borderRadius:BorderRadius.circular(30)),child:Column(children:[Row(mainAxisAlignment:MainAxisAlignment.center,children:[Container(width:92,height:112,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.58),borderRadius:BorderRadius.circular(24),border:Border.all(color:Colors.white.withValues(alpha:.7))),clipBehavior:Clip.antiAlias,child:face!=null&&face.existsSync()?Image.file(face,fit:BoxFit.cover):const Icon(Icons.face_retouching_natural_rounded,size:44,color:AppColors.primary)),const SizedBox(width:10),Container(width:92,height:112,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.58),borderRadius:BorderRadius.circular(24),border:Border.all(color:Colors.white.withValues(alpha:.7))),clipBehavior:Clip.antiAlias,child:body!=null&&body.existsSync()?Image.file(body,fit:BoxFit.cover):const Icon(Icons.accessibility_new_rounded,size:44,color:AppColors.primary))]),const SizedBox(height:15),Text(ready?'Meet your AI styling model':'Create your TiB Model first',textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,height:1.08)),const SizedBox(height:8),const Text('Your scanned face + full-body reference + real measurements become one persistent Personal TiB Model. TiB then dresses that same person using your own wardrobe.',textAlign:TextAlign.center,style:TextStyle(color:AppColors.textSecondary,fontSize:11.5,height:1.45)),const SizedBox(height:14),Wrap(alignment:WrapAlignment.center,spacing:7,runSpacing:7,children:[_chip(Icons.face_rounded,'Face identity'),_chip(Icons.accessibility_new_rounded,model?.bodyShape??'Body shape'),_chip(Icons.straighten_rounded,model!=null&&model.height>0?'${model.height.toStringAsFixed(0)} cm':'Measurements'),_chip(Icons.palette_outlined,_analysis?.season??'Colour profile'),_chip(Icons.checkroom_rounded,'Your wardrobe')]) ])); }
  Widget _chip(IconData icon,String label)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.65),borderRadius:BorderRadius.circular(14)),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:13,color:AppColors.primaryDark),const SizedBox(width:5),Text(label,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800))]));
  Widget _buildOccasion()=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(22),border:Border.all(color:AppColors.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('WHAT ARE YOU DRESSING FOR?',style:TextStyle(fontSize:9,letterSpacing:1.2,fontWeight:FontWeight.w900,color:AppColors.textMuted)),const SizedBox(height:9),Wrap(spacing:7,runSpacing:7,children:_occasions.map((value)=>ChoiceChip(label:Text(value),selected:_occasion==value,onSelected:_busy?null:(_)=>setState(()=>{_occasion=value;_imageUrl=null;_look=const[];_recommendation=null;_status='';})).toList())]));
  Widget _buildHowItWorks(){const steps=<({String number,String title,String description})>[(number:'01',title:'Scan & understand you',description:'Your face scan and TiB measurements become the identity and fit context.'),(number:'02',title:'Find your best outfit',description:'TiB considers your colour profile, body shape, style preferences and wardrobe.'),(number:'03',title:'Create your virtual person',description:'Your full-body reference anchors the same real person while the selected clothes are fitted onto them.')]; return Column(children:steps.map((step)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(20),border:Border.all(color:AppColors.border)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:36,height:36,alignment:Alignment.center,decoration:const BoxDecoration(color:AppColors.primarySoft,shape:BoxShape.circle),child:Text(step.number,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900,color:AppColors.primaryDark))),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(step.title,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(step.description,style:const TextStyle(color:AppColors.textSecondary,fontSize:11.5,height:1.4))]))]))).toList()); }
  Widget _buildRecommendedLook(){ return Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(22),border:Border.all(color:AppColors.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Expanded(child:Text('TIB SELECTED',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.1))),Text('${_recommendation?.matchScore??0}% MATCH',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900,color:AppColors.success))]),const SizedBox(height:11),SizedBox(height:140,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:_look.length,separatorBuilder:(_,__)=>const SizedBox(width:9),itemBuilder:(_,index){final item=_look[index];return SizedBox(width:105,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(14),child:item.imageUrl.isEmpty?Container(color:AppColors.surfaceMuted,child:const Icon(Icons.checkroom_outlined,color:AppColors.primary)):CachedNetworkImage(imageUrl:item.imageUrl,fit:BoxFit.cover,width:105))),const SizedBox(height:6),Text(item.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700))]));}))]); }
  Widget _buildResult(){return Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(22),border:Border.all(color:AppColors.border)),child:Column(children:[if(_imageUrl!=null)ClipRRect(borderRadius:BorderRadius.circular(18),child:Image.network(_imageUrl!,fit:BoxFit.cover,width:double.infinity)),const SizedBox(height:12),Row(children:[Expanded(child:Text(_recommendation?.displayTitle??'Your virtual look',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800))),IconButton(onPressed:_saveLook,icon:const Icon(Icons.bookmark_border_rounded))]),if(_recommendation?.explanation.isNotEmpty==true)...[const SizedBox(height:7),Text(_recommendation!.explanation,style:const TextStyle(color:AppColors.textSecondary,fontSize:11.5,height:1.4))]]) ); }
}