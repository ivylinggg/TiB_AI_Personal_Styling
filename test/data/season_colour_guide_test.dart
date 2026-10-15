import 'package:flutter_test/flutter_test.dart';

import 'package:tib_ai_personal_styling/data/season_colour_guide.dart';

void main() {
  group('SeasonColourGuide', () {
    test('contains all four seasonal profiles', () {
      expect(SeasonColourGuide.profiles.keys, containsAll(<String>[
        'Spring',
        'Summer',
        'Autumn',
        'Winter',
      ]));
      expect(SeasonColourGuide.profiles, hasLength(4));
    });

    test('each profile has usable styling guidance', () {
      for (final profile in SeasonColourGuide.profiles.values) {
        expect(profile.name, isNotEmpty);
        expect(profile.dimension, isNotEmpty);
        expect(profile.description, isNotEmpty);
        expect(profile.bestColours, isNotEmpty);
        expect(profile.eyeShadowColours, isNotEmpty);
        expect(profile.blushColours, isNotEmpty);
        expect(profile.keywords, isNotEmpty);
      }
    });

    test('unknown seasons fall back safely to Autumn', () {
      expect(
        SeasonColourGuide.forSeason('Unknown').name,
        equals('Autumn'),
      );
    });
  });
}
