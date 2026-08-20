import 'season_colour_guide.dart';

class ColourPsychologyCue {
  final String colour;
  final String impression;
  final String bestFor;
  final String note;

  const ColourPsychologyCue({
    required this.colour,
    required this.impression,
    required this.bestFor,
    required this.note,
  });
}

class ProfessionalStyleData {
  ProfessionalStyleData._();

  static const Map<String, List<String>> avoidColours = {
    'Winter': ['Warm Camel', 'Dusty Brown', 'Muted Orange', 'Yellow Beige'],
    'Summer': ['Very Warm Orange', 'Strong Mustard', 'Yellow-Beige', 'Hard Neon Contrast'],
    'Spring': ['Icy Grey', 'Blue-Black', 'Dusty Mauve', 'Very Cool Charcoal'],
    'Autumn': ['Icy White', 'Cool Lavender', 'Blue-Pink', 'Very Cool Silver Grey'],
  };

  static const List<ColourPsychologyCue> colourPsychology = [
    ColourPsychologyCue(
      colour: 'Navy',
      impression: 'Trust • Calm • Professional',
      bestFor: 'Meetings, interviews, presentations',
      note: 'A polished alternative to wearing black from head to toe.',
    ),
    ColourPsychologyCue(
      colour: 'Red',
      impression: 'Confidence • Energy • Authority',
      bestFor: 'Presentations, leadership moments, social events',
      note: 'Use as an intentional accent when you want stronger visual energy.',
    ),
    ColourPsychologyCue(
      colour: 'Soft Pink',
      impression: 'Friendly • Approachable • Gentle',
      bestFor: 'Networking, client-facing moments, everyday styling',
      note: 'Soft pink can keep a professional look warm and approachable.',
    ),
    ColourPsychologyCue(
      colour: 'Green',
      impression: 'Natural • Balanced • Calm',
      bestFor: 'Creative work, casual business, everyday outfits',
      note: 'Choose a depth and temperature that stays inside your personal season.',
    ),
    ColourPsychologyCue(
      colour: 'White / Ivory',
      impression: 'Clean • Fresh • Clear',
      bestFor: 'Professional basics, presentations, polished casual',
      note: 'Use your season-friendly version of white for the most harmonious effect.',
    ),
    ColourPsychologyCue(
      colour: 'Black',
      impression: 'Strong • Formal • Dramatic',
      bestFor: 'Formal events, high-contrast styling, evening looks',
      note: 'It communicates strength, but your seasonal palette may suggest a softer dark instead.',
    ),
  ];

  static const List<String> professionalOccasions = [
    'Interview',
    'Office Day',
    'Client Meeting',
    'Presentation',
    'Business Dinner',
    'Networking',
    'Corporate Event',
    'Executive Look',
  ];

  static const Map<String, List<String>> occasionGuidance = {
    'Interview': ['Clean silhouette', 'Low-distraction colours', 'Polished shoes', 'Simple accessories'],
    'Office Day': ['Comfortable tailoring', 'Easy neutrals', 'Layer-friendly pieces', 'Refined basics'],
    'Client Meeting': ['Structured outer layer', 'Confident colour accent', 'Neat grooming', 'Balanced accessories'],
    'Presentation': ['Clear visual focal point', 'Strong contrast control', 'Comfortable movement', 'Camera-friendly colours'],
    'Business Dinner': ['Polished smart-casual', 'Intentional accent colour', 'Elegant accessories', 'Easy transition from work'],
    'Networking': ['Approachable palette', 'Recognisable signature piece', 'Comfortable footwear', 'Conversational detail'],
    'Corporate Event': ['Event-appropriate structure', 'Cohesive colour story', 'One elevated detail', 'Professional grooming'],
    'Executive Look': ['Strong silhouette', 'Deeper tonal range', 'Minimal visual clutter', 'Confident finishing pieces'],
  };

  static SeasonColourProfile profile(String season) => SeasonColourGuide.forSeason(season);
}
