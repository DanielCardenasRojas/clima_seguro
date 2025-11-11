// lib/services/weather_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../env.dart';
import '../models/weather.dart';

class _CacheEntry<T> {
  final T value;
  final DateTime exp;
  _CacheEntry(this.value, this.exp);
  bool get isExpired => DateTime.now().isAfter(exp);
}

class WeatherService {
  final _client = http.Client();
  final _cache = <String, _CacheEntry<Weather>>{};

  static const _base = 'https://api.openweathermap.org/data/2.5/weather';
  static const _timeout = Duration(seconds: 8);
  static const _ttl = Duration(minutes: 5); // cache defensiva

  // AQUÍ se define 'city'
  Future<Weather?> getWeatherByCity(String city) async {
    final keyCache = "city:$city".toLowerCase();
    final cached = _cache[keyCache];
    if (cached != null && !cached.isExpired) return cached.value;

    // Usa city DENTRO de la función
    final uri = Uri.parse(
      "$_base?q=$city&units=metric&lang=es&appid=${Uri.encodeComponent(Env.openWeatherKey)}",
    );

    final jsonMap = await _getWithRetry(uri);
    if (jsonMap == null) return null;

    final code = (jsonMap['cod'] ?? 200).toString();
    if (code != '200') {
      final msg = jsonMap['message']?.toString() ?? 'Error API ($code)';
      throw Exception('OpenWeather: $msg');
    }

    final data = Weather.fromOpenWeather(jsonMap);
    _cache[keyCache] = _CacheEntry(data, DateTime.now().add(_ttl));
    return data;
  }

  Future<Map<String, dynamic>?> _getWithRetry(Uri uri) async {
    const maxAttempts = 3;
    int attempt = 0;
    final rand = Random();

    while (true) {
      attempt++;
      try {
        final resp = await _client.get(uri).timeout(_timeout);

        if (uri.scheme != 'https') {
          throw Exception('Conexión insegura. Usa HTTPS.');
        }

        if (resp.statusCode == 200) {
          return jsonDecode(resp.body) as Map<String, dynamic>;
        }

        if (resp.statusCode == 429) {
          if (attempt >= maxAttempts) {
            throw Exception('Límite de peticiones (429). Intenta más tarde.');
          }
          await _backoff(attempt, rand);
          continue;
        }

        if (resp.statusCode >= 500 && resp.statusCode < 600) {
          if (attempt >= maxAttempts) {
            throw Exception('Error del servidor (${resp.statusCode}).');
          }
          await _backoff(attempt, rand);
          continue;
        }

        throw Exception('HTTP ${resp.statusCode}: ${resp.reasonPhrase ?? "Error"}');

      } on TimeoutException {
        if (attempt >= maxAttempts) throw Exception('Timeout de red.');
        await _backoff(attempt, rand);
      } on http.ClientException catch (e) {
        if (attempt >= maxAttempts) throw Exception('Falla de red: ${e.message}');
        await _backoff(attempt, rand);
      }
    }
  }

  Future<void> _backoff(int attempt, Random rand) async {
    final baseMs = 500 * pow(2, attempt - 1);
    final jitter = rand.nextInt(250);
    final wait = Duration(milliseconds: baseMs.toInt() + jitter);
    await Future.delayed(wait);
  }
}
