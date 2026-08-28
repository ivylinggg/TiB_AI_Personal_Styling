class TalkToTibBotService {
  TalkToTibBotService._();

  /// Lightweight, deterministic FAQ layer for Free users.
  ///
  /// The bot answers predictable questions about features that already exist
  /// in TiB. Questions that require a personalised judgement, account review,
  /// troubleshooting, or a human stylist are deliberately escalated to Live
  /// Consultancy instead of pretending that the FAQ bot can solve them.
  static String? automatedReply(String input) {
    final q = _normalise(input);
    if (q.isEmpty) return null;

    if (_matches(q, [
      'hello',
      'hi',
      'hey',
      'good morning',
      'good afternoon',
      'good evening',
    ])) {
      return 'Hi! I’m TiB 🤍 I can answer common questions about your colour profile, body proportions, wardrobe, styling features and how TiB works. If your question needs a personal stylist’s judgement, you can switch to a live consultant anytime.';
    }

    if (_matches(q, [
      'what is tib',
      'what can tib do',
      'what does tib do',
      'how does tib work',
      'tell me about tib',
    ])) {
      return 'TiB is your AI personal styling companion. It uses the information you build in your TiB profile — such as colour analysis, measurements, style preferences and wardrobe items — to make more personalised styling suggestions.';
    }

    if (_matches(q, [
      'colour analysis',
      'color analysis',
      'colour season',
      'color season',
      'season analysis',
      'undertone',
      'what colours suit me',
      'what colors suit me',
      'best colours',
      'best colors',
      'my colours',
      'my colors',
    ])) {
      return 'Your Colour Analysis helps TiB understand your colour season, undertone, brightness and contrast. TiB can use that profile when giving styling suggestions, so the advice is based on your own colour information rather than a generic palette.';
    }

    if (_matches(q, [
      'body shape',
      'body type',
      'body proportion',
      'body proportions',
      'my proportions',
      'my measurements',
      'height',
      'bust',
      'waist',
      'hips',
      'shoulder',
      'inseam',
    ])) {
      return 'Your measurements and proportions help TiB understand your real silhouette and fit considerations. You can keep your personal measurements in your TiB profile so future styling guidance can be more relevant to your proportions.';
    }

    if (_matches(q, [
      'wardrobe',
      'my wardrobe',
      'add clothes',
      'add clothing',
      'upload clothes',
      'my clothes',
      'clothing items',
      'wardrobe items',
    ])) {
      return 'My Wardrobe is where you can keep the clothing pieces you want TiB to work with. Adding your real pieces lets TiB suggest outfits around what you actually own instead of only giving generic shopping advice.';
    }

    if (_matches(q, [
      'outfit',
      'outfits',
      'style an outfit',
      'create an outfit',
      'build a look',
      'build an outfit',
      'what should i wear',
      'what can i wear',
    ])) {
      return 'You can ask TiB for outfit ideas based on your wardrobe and styling profile. For example, try “What should I wear for work?” or “Create a casual weekend look.” For a very specific event or difficult styling decision, a live consultant can give a human recommendation.';
    }

    if (_matches(q, [
      'work outfit',
      'office outfit',
      'business outfit',
      'interview outfit',
      'workwear',
    ])) {
      return 'For workwear, TiB can help you build a polished look around your wardrobe, colour profile and style preferences. Tell me the type of workplace or occasion and I can suggest a direction. If there are dress-code constraints you are unsure about, a live consultant can review them with you.';
    }

    if (_matches(q, [
      'date outfit',
      'dinner outfit',
      'party outfit',
      'wedding outfit',
      'event outfit',
      'special occasion',
      'what to wear to a wedding',
    ])) {
      return 'TiB can help you plan an occasion look using your existing wardrobe and personal style profile. For a specific dress code, cultural expectation, modesty requirement or event where the choice is difficult, tap “Chat with a Live Consultant” for a human opinion.';
    }

    if (_matches(q, [
      'style preference',
      'style preferences',
      'my style',
      'style personality',
      'fashion style',
      'personal style',
    ])) {
      return 'Your style preferences help TiB understand the look you enjoy, such as the types of silhouettes, colours and outfit directions you prefer. Keeping these preferences updated helps make future recommendations feel more like you.';
    }

    if (_matches(q, [
      'personal tib model',
      'tib model',
      'personal model',
      'my model',
      'real me',
      'my virtual model',
    ])) {
      return 'Your Personal TiB Model is intended to represent you using the personal information and proportions you provide. It is designed to make future styling and fitting experiences more personal than using a generic model.';
    }

    if (_matches(q, [
      'virtual try-on',
      'virtual try on',
      'ai fitting room',
      'fitting room',
      'try clothes on',
      'try on clothes',
    ])) {
      return 'AI Fitting Room is designed to let your Personal TiB Model wear selected clothing pieces. The feature is separate from this free chat, and its availability or usage may depend on the plan and current AI service limits.';
    }

    if (_matches(q, [
      'free',
      'free user',
      'is tib free',
      'talk to tib free',
      'cost to use tib',
      'how much is tib',
    ])) {
      return 'Talk to TiB is available to Free users. Some advanced AI experiences may remain plan-based, but you can use this conversation to get general styling guidance and feature help.';
    }

    if (_matches(q, [
      'premium',
      'subscription',
      'premium plan',
      'upgrade',
      'paid plan',
    ])) {
      return 'Talk to TiB is available to Free users. Other advanced experiences can have separate plan requirements. If you want to understand exactly what is included in a particular plan, a live consultant can help explain your options.';
    }

    if (_matches(q, [
      'consultant',
      'human',
      'real person',
      'live person',
      'live consultant',
      'human stylist',
      'talk to someone',
      'talk to a stylist',
      'real stylist',
    ])) {
      return 'Absolutely 🤍 Tap “Chat with a Live Consultant” to continue with a real TiB consultant. This is the better option when you want a personalised human judgement rather than an automated answer.';
    }

    if (_matches(q, [
      'how do i',
      'how can i',
      'where can i',
      'how to',
      'help me',
      'i cannot',
      'i cant',
      'does not work',
      'doesnt work',
      'not working',
    ])) {
      return 'I can explain common TiB features, but I cannot inspect your account or diagnose a complex problem from this automated chat. Tap “Chat with a Live Consultant” and tell our team what happened so a real consultant can help you.';
    }

    // Unknown or high-context questions intentionally go to a human.
    return null;
  }

  static String _normalise(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\\s-]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }

  static bool _matches(String value, List<String> keywords) {
    for (final keyword in keywords) {
      if (value.contains(keyword)) return true;
    }
    return false;
  }
}
