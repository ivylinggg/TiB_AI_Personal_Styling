import 'package:flutter_test/flutter_test.dart';

import '../models/colour_analysis_result.dart';
import '../models/wardrobe_item.dart';
import 'ai_styling_service.dart';

ColourAnalysisResult _profile() => const ColourAnalysisResult(
      season: 'Spring',
      undertone: 'Warm',
      brightness: 'Bright',
      contrast: 'Medium',
      chroma: 'Clear',
      clarity: 'Clear',
      colours: ['beige', 'coral', 'navy'],
      bestNeutrals: ['white', 'beige'],
      accentColours: ['coral'],
      lessIdealColours: ['black'],
      faceShape: 'Oval',
      faceStylingGuidance: [],
      colourReasons: [],
    );

WardrobeItem _item({
  required String id,
  required String name,
  required String category,
  required String colour,
  String style = 'casual',
}) {
  return WardrobeItem(
    id: id,
    userId: 'uid-1',
    name: name,
    category: category,
    colour: colour,
    style: style,
    season: 'All Seasons',
    occasion: 'Weekend',
    formality: 'Casual',
    pattern: 'Solid',
    material: 'Cotton',
    silhouette: 'Regular',
    fit: 'Regular',
    length: 'Regular',
    notes: '',
    imageUrl: '',
    isFavourite: false,
  );
}

void main() {
  group('AiStylingService.sanitizeLook', () {
    final top = _item(
      id: 'top-1',
      name: 'White Top',
      category: 'Tops',
      colour: 'white',
    );
    final bottom = _item(
      id: 'bottom-1',
      name: 'Navy Bottom',
      category: 'Bottoms',
      colour: 'navy',
    );
    final dress = _item(
      id: 'dress-1',
      name: 'Black Dress',
      category: 'Dresses',
      colour: 'black',
      style: 'elegant',
    );

    test('builds a valid two-piece look from owned items', () {
      final look = AiStylingService.sanitizeLook(
        [top, bottom],
        profile: _profile(),
        occasion: 'Weekend',
      );

      expect(look.map((item) => item.id), containsAll(<String>['top-1', 'bottom-1']));
      expect(look.length, 2);
    });

    test('respects explicit excluded look keys', () {
      final excludedKey = [top.id, bottom.id]..sort();
      final look = AiStylingService.sanitizeLook(
        [top, bottom, dress],
        profile: _profile(),
        occasion: 'Weekend',
        excludedLookKeys: {excludedKey.join('|')},
      );

      expect(look, isNotEmpty);
      expect(look.map((item) => item.id).toSet(), isNot(equals(<String>{'top-1', 'bottom-1'})));
    });

    test('does not mix dresses with separate tops or bottoms', () {
      final look = AiStylingService.sanitizeLook(
        [top, bottom, dress],
        profile: _profile(),
        occasion: 'Dinner',
        selectedItem: dress,
      );

      final categories = look.map((item) => item.category).toSet();
      expect(look, isNotEmpty);
      expect(categories, contains('Dresses'));
      expect(categories, isNot(contains('Tops')));
      expect(categories, isNot(contains('Bottoms')));
    });
  });

  group('AiStylingResult', () {
    test('itemIds removes duplicates and empty ids', () {
      const result = AiStylingResult(
        explanation: 'test',
        topId: 'top-1',
        bottomId: 'bottom-1',
        dressId: null,
        suitId: null,
        jacketId: null,
        shoesId: 'top-1',
        accessoryId: '',
      );

      expect(result.itemIds, <String>['top-1', 'bottom-1']);
    });
  });
}
