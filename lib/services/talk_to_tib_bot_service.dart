class TalkToTibBotService {
  TalkToTibBotService._();

  static String? automatedReply(String input) {
    final q = input.trim().toLowerCase();
    if (q.isEmpty) return null;

    if (_matches(q, ['hello', 'hi', 'hey', 'good morning', 'good afternoon'])) {
      return 'Hi! I’m TiB 🤍 I can help with your colours, body proportions, wardrobe and everyday styling. What would you like to know?';
    }
    if (_matches(q, ['colour analysis', 'color analysis', 'season', 'undertone', 'what colours', 'what colors'])) {
      return 'Your Colour Analysis helps TiB understand your season, undertone, brightness and contrast. I use that profile when giving styling recommendations, so your suggestions are personal rather than generic.';
    }
    if (_matches(q, ['body shape', 'body type', 'proportion', 'measurements', 'height', 'bust', 'waist', 'hips'])) {
      return 'Your measurements and proportions help TiB understand your real fit and silhouette. You can update them in your Personal TiB Model so future styling advice is based on your own proportions.';
    }
    if (_matches(q, ['wardrobe', 'clothes', 'clothing', 'my clothes', 'outfit'])) {
      return 'Add your own pieces to My Wardrobe and TiB can style around what you actually own. You can also ask me to create a look for work, dinner, casual days or a specific occasion.';
    }
    if (_matches(q, ['virtual try-on', 'virtual try on', 'try on', 'fitting room'])) {
      return 'AI Fitting Room is designed to show your Personal TiB Model wearing selected wardrobe pieces. If you need help with a result or want a more personalised fit discussion, you can chat with a live consultant.';
    }
    if (_matches(q, ['premium', 'subscription', 'plan', 'free'])) {
      return 'Talk to TiB is available to Free users. Some advanced experiences may remain plan-based, but you can always use this chat to get styling guidance and ask for help.';
    }
    if (_matches(q, ['consultant', 'human', 'real person', 'live person', 'stylist', 'talk to someone'])) {
      return 'Absolutely. If you would like advice from a real TiB consultant, tap “Chat with a Live Consultant” and send us your question. A consultant can continue the conversation with you directly.';
    }
    if (_matches(q, ['how do i', 'how can i', 'where can i', 'can i change', 'help me'])) {
      return 'I can help with your TiB profile, colour analysis, body proportions, wardrobe and styling. If your question needs a human decision or personal consultation, you can switch to a live consultant at any time.';
    }

    return null;
  }

  static bool _matches(String value, List<String> keywords) {
    for (final keyword in keywords) {
      if (value.contains(keyword)) return true;
    }
    return false;
  }
}
