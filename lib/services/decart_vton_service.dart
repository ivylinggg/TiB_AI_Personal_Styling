import 'package:cloud_functions/cloud_functions.dart';

class DecartVtonService {
  DecartVtonService._();

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  static Future<String> fetchClientToken() async {
    final callable = _functions.httpsCallable(
      'mintDecartClientToken',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 20),
      ),
    );

    final result = await callable.call(<String, dynamic>{});
    final data = result.data;

    if (data is! Map) {
      throw StateError('The realtime try-on token response was invalid.');
    }

    final token = data['apiKey'];
    if (token is! String || token.trim().isEmpty) {
      throw StateError('The realtime try-on token was not returned.');
    }

    return token.trim();
  }
}
