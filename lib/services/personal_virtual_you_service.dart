import 'tib_model_service.dart';

/// Canonical identity contract for TiB's Virtual You fitting room.
///
/// This keeps the product rule explicit: the AI is dressing a real person,
/// not selecting a generic fashion model. It is intentionally derived from
/// the existing Personal TiB Model so older features keep their data model.
class PersonalVirtualYouService {
  const PersonalVirtualYouService._();

  static Map<String, dynamic> buildContract(TibModelProfile model) {
    return {
      'contract': 'tib_personal_virtual_you_v1',
      'identity': {
        'type': 'real_user',
        'rule': 'dress_this_person_not_a_generic_model',
        'faceReference': 'primary_identity_anchor',
        'fullBodyReference': 'primary_silhouette_anchor',
      },
      'body': {
        'heightCm': model.height,
        'weightKg': model.weight,
        'bustCm': model.bust,
        'waistCm': model.waist,
        'hipsCm': model.hips,
        'bodyShape': model.bodyShape,
        'faceShape': model.faceShape,
        'proportions': {
          'waistToBust': _ratio(model.waist, model.bust),
          'waistToHips': _ratio(model.waist, model.hips),
          'hipsToBust': _ratio(model.hips, model.bust),
          'bustToHeight': _ratio(model.bust, model.height),
          'waistToHeight': _ratio(model.waist, model.height),
          'hipsToHeight': _ratio(model.hips, model.height),
        },
      },
      'fitRules': [
        'preserve_real_identity',
        'preserve_real_body_proportions',
        'preserve_real_height_impression',
        'adapt_garments_to_real_body',
        'do_not_slim_body',
        'do_not_lengthen_body',
        'do_not_replace_person',
        'show_head_to_toe_when_possible',
      ],
    };
  }

  static double? _ratio(double numerator, double denominator) {
    if (numerator <= 0 || denominator <= 0) return null;
    return double.parse((numerator / denominator).toStringAsFixed(4));
  }
}
