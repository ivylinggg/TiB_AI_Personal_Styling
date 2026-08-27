import 'tib_model_service.dart';

/// Canonical identity contract for TiB's personal AI fitting room.
///
/// Product rule: TiB dresses the same real person represented by the user's
/// references and measurements. It must never silently substitute a generic
/// fashion model.
class PersonalVirtualYouService {
  const PersonalVirtualYouService._();

  static Map<String, dynamic> buildContract(TibModelProfile model) {
    final proportions = {
      'waistToBust': _ratio(model.waist, model.bust),
      'waistToHips': _ratio(model.waist, model.hips),
      'hipsToBust': _ratio(model.hips, model.bust),
      'bustToHeight': _ratio(model.bust, model.height),
      'waistToHeight': _ratio(model.waist, model.height),
      'hipsToHeight': _ratio(model.hips, model.height),
    };

    return {
      'contract': 'tib_personal_virtual_you_v2',
      'modelType': 'real_person_fashion_fitting_model',
      'identity': {
        'type': 'real_user',
        'rule': 'dress_this_person_not_a_generic_model',
        'faceReference': 'primary_identity_anchor',
        'fullBodyReference': 'primary_silhouette_anchor',
        'referenceOrder': ['full_body', 'face', 'measurements'],
      },
      'body': {
        'heightCm': model.height,
        'weightKg': model.weight,
        'bustCm': model.bust,
        'waistCm': model.waist,
        'hipsCm': model.hips,
        'bodyShape': model.bodyShape,
        'faceShape': model.faceShape,
        'proportions': proportions,
      },
      'fitFingerprint': {
        'heightCm': model.height,
        'bustCm': model.bust,
        'waistCm': model.waist,
        'hipsCm': model.hips,
        'bodyShape': model.bodyShape,
        'proportions': proportions,
        'purpose': 'hard_fit_context_not_aesthetic_scoring',
      },
      'fitRules': [
        'preserve_real_identity',
        'preserve_real_body_proportions',
        'preserve_real_height_impression',
        'preserve_real_shoulder_waist_hip_relationship',
        'adapt_garments_to_real_body',
        'keep_natural_body_shape',
        'do_not_slim_body',
        'do_not_enlarge_body',
        'do_not_lengthen_body',
        'do_not_shorten_body',
        'do_not_replace_person',
        'do_not_generate_a_generic_model',
        'show_head_to_toe_when_possible',
      ],
      'garmentRules': [
        'use_only_selected_wardrobe_references',
        'preserve_garment_category',
        'preserve_garment_colour',
        'preserve_garment_pattern_and_material_when_visible',
        'fit_garments_to_the_reference_body',
        'do_not_invent_unselected_clothing',
      ],
      'outputRules': {
        'format': 'photorealistic_fashion_photo',
        'coverage': 'head_to_toe_full_body',
        'pose': 'natural_standing_pose',
        'identityPriority': 'highest',
        'bodyPriority': 'highest',
        'wardrobePriority': 'selected_items_only',
      },
    };
  }

  static double? _ratio(double numerator, double denominator) {
    if (numerator <= 0 || denominator <= 0) return null;
    return double.parse((numerator / denominator).toStringAsFixed(4));
  }
}
