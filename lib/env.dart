import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get openWeatherKey {
    final k = dotenv.env['OPENWEATHER_API_KEY'];
    if (k == null || k.isEmpty) {
      throw StateError('Falta OPENWEATHER_API_KEY en .env');
    }
    return k;
  }
}
