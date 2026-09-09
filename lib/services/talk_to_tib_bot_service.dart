import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';
import '../models/colour_analysis_result.dart';
import '../models/wardrobe_item.dart';
import 'tib_model_service.dart';

class TalkToTibReply {
  final String text;
  final bool isAiGenerated;
  final bool shouldEscalate;

  const TalkToTibReply({
    required this.text,
    this.isAiGenerated = false,
    this.shouldEscalate = false,
  });
}

class TalkToTibBotService {
  TalkToTibBotService._();

  static const Duration _timeout = Duration(seconds: 18);

  static Future<TalkToTibReply> reply(String input) async {
    final question = input.trim();
    if (question.isEmpty) {
      return const TalkToTibReply(text: 'Tell me what you would like help with, and we’ll start there.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ai = await _tryPersonalisedReply(user, question);
      if (ai != null) return ai;
    }

    final automated = automatedReply(question);
    if (automated != null) return TalkToTibReply(text: automated);

    return const TalkToTibReply(
      text: 'That sounds like something I should understand in more context before advising you. Tap “Chat with a Live Consultant” and our team can help with a personalised recommendation.',
      shouldEscalate: true,
    );
  }

  static Future<TalkToTibReply?> _tryPersonalisedReply(
    User user,
    String question,
  ) async {
    try {
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) return null;

      final uid = user.uid;
      final profileDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final profile = profileDoc.data() ?? <String, dynamic>{};

      final results = await Future.wait<dynamic>([
        _loadColour(uid),
        _loadPreferences(uid),
        _loadWardrobe(uid),
        TibModelService.loadForUser(uid),
      ], eagerError: false);

      final colour = results[0] is ColourAnalysisResult ? results[0] as ColourAnalysisResult : null;
      final preferences = results[1] is Map
          ? Map<String, dynamic>.from(results[1] as Map)
          : <String, dynamic>{};
      final wardrobe = results[2] is List<WardrobeItem>
          ? List<WardrobeItem>.from(results[2] as List<WardrobeItem>)
          : const <WardrobeItem>[];
      final tibModel = results[3] is TibModelProfile ? results[3] as TibModelProfile : null;

      final response = await http
          .post(
            Uri.parse(GoogleDriveConfig.uploadUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'talkToTib',
              'uid': uid,
              'idToken': token,
              'message': question,
              'profile': profile,
              'colourAnalysis': colour == null
                  ? null
                  : {
                      'season': colour.season,
                      'undertone': colour.undertone,
                      'brightness': colour.brightness,
                      'contrast': colour.contrast,
                      'colours': colour.colours.take(12).toList(),
                      'colourReasons': colour.colourReasons.take(8).toList(),
                      'faceShape': colour.faceShape,
                      'faceShapeDescription': colour.faceShapeDescription,
                      'faceStylingGuidance': colour.faceStylingGuidance.take(8).toList(),
                    },
              'tibModel': tibModel == null
                  ? null
                  : {
                      'faceShape': tibModel.faceShape,
                      'bodyShape': tibModel.bodyShape,
                      'weightKg': tibModel.weight,
                      'heightCm': tibModel.height,
                      'bustCm': tibModel.bust,
                      'waistCm': tibModel.waist,
                      'hipsCm': tibModel.hips,
                    },
              'styles': _cleanStrings(preferences['styles']),
              'preferences': _cleanStrings(preferences['preferences']),
              'wardrobe': wardrobe
                  .where((item) => item.userId.isEmpty || item.userId == uid)
                  .take(60)
                  .map((item) => {
                        'id': item.id,
                        'name': item.name,
                        'category': item.category,
                        'colour': item.colour,
                        'style': item.style,
                        'season': item.season,
                        'isFavourite': item.isFavourite,
                      })
                  .toList(),
            }),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'] as Map)
          : decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : null;
      if (data == null) return null;

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != uid) return null;

      final text = (data['reply'] ?? data['message'] ?? data['text'] ?? data['response'] ?? '').toString().trim();
      if (text.isEmpty) return null;

      return TalkToTibReply(
        text: text,
        isAiGenerated: true,
        shouldEscalate: data['shouldEscalate'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<ColourAnalysisResult?> _loadColour(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('analysis')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      return ColourAnalysisResult(
        season: (data['season'] ?? '').toString(),
        undertone: (data['undertone'] ?? '').toString(),
        brightness: (data['brightness'] ?? '').toString(),
        contrast: (data['contrast'] ?? '').toString(),
        imageUrl: (data['imageUrl'] ?? '').toString(),
        colours: _stringList(data['colours']),
        faceShape: (data['faceShape'] ?? 'Unknown').toString(),
        faceShapeDescription: (data['faceShapeDescription'] ?? '').toString(),
        faceMeasurements: _doubleMap(data['faceMeasurements']),
        faceStylingGuidance: _stringList(data['faceStylingGuidance']),
        colourReasons: _stringList(data['colourReasons']),
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, double> _doubleMap(dynamic value) {
    if (value is! Map) return const {};
    final output = <String, double>{};
    value.forEach((key, raw) {
      if (raw is num) output[key.toString()] = raw.toDouble();
    });
    return output;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList(growable: false);
  }

  static Future<Map<String, dynamic>> _loadPreferences(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('preferences')
          .doc('style')
          .get();
      return snapshot.data() ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<List<WardrobeItem>> _loadWardrobe(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('wardrobe')
          .get();
      return snapshot.docs
          .map(WardrobeItem.fromFirestore)
          .where((item) => item.userId.isEmpty || item.userId == uid)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<String> _cleanStrings(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(8)
        .toList(growable: false);
  }

  static String? automatedReply(String input) {
    final q = _normalise(input);
    if (q.isEmpty) return null;

    if (_matches(q, ['which outfit is better', 'which dress is better', 'which one should i wear', 'which one suits me better', 'does this outfit suit me', 'does this dress suit me', 'should i buy this', 'should i buy this outfit', 'does this fit me', 'why does this outfit look wrong', 'i hate how this looks', 'i need a second opinion', 'i need personal advice', 'personalised advice', 'personalized advice', 'difficult styling decision'])) {
      return 'That sounds like a personal styling decision where context really matters. I don’t want to give you a generic answer 🤍 Tap “Chat with a Live Consultant” and our team can look at your situation and give you a personalised recommendation.';
    }

    if (_matches(q, ['hello', 'hi', 'hey', 'good morning', 'good afternoon', 'good evening'])) {
      return 'Hi! I’m TiB 🤍 I can help with your colour profile, wardrobe, proportions and styling. Tell me what you are getting dressed for, or ask me anything about how TiB works.';
    }

    if (_matches(q, ['what is tib', 'what can tib do', 'what does tib do', 'how does tib work', 'tell me about tib'])) {
      return 'TiB is your AI personal styling companion. It can use the personal information you build in the app — including colour analysis, style preferences, Personal TiB and wardrobe — to make styling guidance more relevant to you.';
    }

    if (_matches(q, ['colour analysis', 'color analysis', 'colour season', 'color season', 'season analysis', 'undertone', 'what colours suit me', 'what colors suit me', 'best colours', 'best colors', 'my colours', 'my colors'])) {
      return 'Your Colour Analysis gives TiB a picture of your colouring, including season, undertone, brightness and contrast. That information can then be used as part of your styling context.';
    }

    if (_matches(q, ['body shape', 'body type', 'body proportion', 'body proportions', 'my proportions', 'my measurements', 'height', 'bust', 'waist', 'hips', 'shoulder', 'inseam'])) {
      return 'Your measurements and proportions help TiB understand fit and silhouette considerations. Keeping your Personal TiB profile complete gives styling recommendations more useful context.';
    }

    if (_matches(q, ['wardrobe', 'my wardrobe', 'add clothes', 'add clothing', 'upload clothes', 'my clothes', 'clothing items', 'wardrobe items'])) {
      return 'My Wardrobe is where you keep the pieces you actually own. That gives TiB something real to work with when creating outfits instead of relying only on generic suggestions.';
    }

    if (_matches(q, ['outfit', 'outfits', 'style an outfit', 'create an outfit', 'build a look', 'build an outfit', 'what should i wear', 'what can i wear'])) {
      return 'Tell me the moment you are dressing for — such as work, dinner, a date, travel or a weekend plan — and TiB can use your personal styling context to guide the look.';
    }

    if (_matches(q, ['work outfit', 'office outfit', 'business outfit', 'interview outfit', 'workwear'])) {
      return 'For workwear, tell me the type of workplace, dress code and what you already own. That gives TiB better context for a polished, realistic look.';
    }

    if (_matches(q, ['date outfit', 'dinner outfit', 'party outfit', 'wedding outfit', 'event outfit', 'special occasion', 'what to wear to a wedding'])) {
      return 'For an occasion, tell me the event, dress code and what you want to feel like. TiB can then shape the styling direction around your profile and wardrobe.';
    }

    if (_matches(q, ['style preference', 'style preferences', 'my style', 'style personality', 'fashion style', 'personal style'])) {
      return 'Your style preferences tell TiB what kinds of silhouettes, outfit directions and styling details feel like you. Keeping them updated helps recommendations stay personal.';
    }

    if (_matches(q, ['personal tib model', 'tib model', 'personal model', 'my model', 'real me', 'my virtual model'])) {
      return 'Your Personal TiB Model stores the personal reference information you choose to provide, so styling experiences can be more tailored than using a generic model.';
    }

    if (_matches(q, ['virtual try-on', 'virtual try on', 'ai fitting room', 'fitting room', 'try clothes on', 'try on clothes'])) {
      return 'Dress Your Model is the visual styling space for exploring how clothing can look with your personal model. Its exact availability depends on the feature and plan configuration.';
    }

    if (_matches(q, ['free', 'free user', 'is tib free', 'talk to tib free', 'cost to use tib', 'how much is tib'])) {
      return 'Talk to TiB is available to Free users. Some advanced AI experiences can have separate plan requirements.';
    }

    if (_matches(q, ['premium', 'subscription', 'premium plan', 'upgrade', 'paid plan'])) {
      return 'Some advanced TiB experiences can have plan requirements. Talk to a Live Consultant when you need help understanding a specific plan or feature.';
    }

    if (_matches(q, ['consultant', 'human', 'real person', 'live person', 'live consultant', 'human stylist', 'talk to someone', 'talk to a stylist', 'real stylist'])) {
      return 'Absolutely 🤍 Tap “Chat with a Live Consultant” to continue with a real TiB consultant when you want a human styling judgement.';
    }

    if (_matches(q, ['how do i', 'how can i', 'where can i', 'how to', 'help me', 'i cannot', 'i cant', 'does not work', 'doesnt work', 'not working'])) {
      return 'I can explain common TiB features, but I cannot diagnose a complex account or product issue here. Tap “Chat with a Live Consultant” and tell our team what happened.';
    }

    return null;
  }

  static String _normalise(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _matches(String value, List<String> keywords) => keywords.any(value.contains);
}
