import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return MaterialApp(
      title: 'Clima',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: const Color(0xFF2563EB),
          secondary: const Color(0xFF22C55E),
        ),
        textTheme: base.textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.12),
          hintStyle: const TextStyle(color: Colors.white70),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white),
          ),
        ),
      ),
      home: const WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

enum UiState { empty, loading, error, data }

class _WeatherScreenState extends State<WeatherScreen> {
  final _controller = TextEditingController();
  UiState _state = UiState.empty;
  String? _error;

  // Datos mínimos
  String _city = '';
  String _country = '';
  double _temp = double.nan;
  double _feels = double.nan;
  int _humidity = 0;
  String _desc = '';

  final _cityReg = RegExp(r"^[A-Za-zÀ-ÿ\s\-]{1,40}$");

  Future<void> _search() async {
    final input = _controller.text.trim();
    if (input.isEmpty || !_cityReg.hasMatch(input)) {
      setState(() {
        _state = UiState.error;
        _error = "Ciudad inválida. Solo letras, espacios y guiones (máx. 40).";
      });
      return;
    }

    setState(() {
      _state = UiState.loading;
      _error = null;
    });

    try {
      final apiKey = dotenv.env['OPENWEATHER_API_KEY'] ?? '';
      if (apiKey.isEmpty) throw Exception('Falta OPENWEATHER_API_KEY en .env');

      final uri = Uri.parse(
        "https://api.openweathermap.org/data/2.5/weather"
        "?q=$input&units=metric&lang=es&appid=$apiKey",
      );

      final resp = await http.get(uri).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        if (resp.statusCode == 429) {
          throw Exception('Límite de peticiones (429). Intenta más tarde.');
        }
        throw Exception('HTTP ${resp.statusCode}: ${resp.reasonPhrase}');
      }

      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      final cod = (jsonMap['cod'] ?? 200).toString();
      if (cod != '200') {
        final msg = jsonMap['message']?.toString() ?? 'Error API ($cod)';
        throw Exception('OpenWeather: $msg');
      }

      final main = (jsonMap['main'] as Map?) ?? {};
      final sys = (jsonMap['sys'] as Map?) ?? {};
      final weatherArr = (jsonMap['weather'] as List?) ?? [];

      setState(() {
        _city = (jsonMap['name'] ?? '').toString().trim();
        _country = (sys['country'] ?? '').toString().trim();
        _temp = (main['temp'] as num?)?.toDouble() ?? double.nan;
        _feels = (main['feels_like'] as num?)?.toDouble() ?? double.nan;
        _humidity = (main['humidity'] as num?)?.toInt() ?? 0;
        _desc = weatherArr.isNotEmpty
            ? (weatherArr.first['description'] ?? '').toString()
            : '';
        _state = UiState.data;
      });
    } on TimeoutException {
      setState(() {
        _state = UiState.error;
        _error = 'Timeout de red. Revisa tu conexión.';
      });
    } catch (e) {
      setState(() {
        _state = UiState.error;
        _error = e.toString().replaceAll(RegExp(r'[\u0000-\u001F]'), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fondo degradado
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF2563EB), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Capa con “brillos” sutiles
        Positioned(
          top: -80,
          right: -60,
          child: _BlurCircle(size: 220, color: Colors.white.withOpacity(0.15)),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: _BlurCircle(size: 180, color: Colors.white.withOpacity(0.12)),
        ),
        // Contenido
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Clima',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Buscador
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Ciudad',
                            hintText: 'Ej. Querétaro',
                            prefixIcon: Icon(Icons.location_city, color: Colors.white70),
                          ),
                          onSubmitted: (_) => _search(),
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _RoundButton(
                        icon: Icons.search_rounded,
                        onTap: _search,
                        tooltip: 'Buscar',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Contenido con card “glass”
                  Expanded(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: switch (_state) {
                          UiState.empty => _HintCard(
                              key: const ValueKey('empty'),
                              title: 'Busca una ciudad',
                              subtitle: 'Escribe el nombre y presiona buscar',
                              icon: Icons.travel_explore_rounded,
                            ),
                          UiState.loading => const _LoadingCard(key: ValueKey('loading')),
                          UiState.error => _ErrorCard(
                              key: const ValueKey('error'),
                              message: _error ?? 'Error desconocido',
                            ),
                          UiState.data => _city.isEmpty
                              ? const _HintCard(
                                  key: ValueKey('nodata'),
                                  title: 'Sin datos',
                                  subtitle: 'Intenta con otra ciudad',
                                  icon: Icons.info_outline_rounded,
                                )
                              : _WeatherGlassCard(
                                  key: const ValueKey('data'),
                                  city: _city,
                                  country: _country,
                                  temp: _temp,
                                  feels: _feels,
                                  humidity: _humidity,
                                  desc: _desc,
                                ),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- UI widgets bonitos ----------

class _BlurCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _BlurCircle({required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(width: size, height: size, color: color),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _RoundButton({required this.icon, required this.onTap, this.tooltip});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: const Center(
            child: Icon(Icons.search_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Glass({required this.child, this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _HintCard({super.key, required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({super.key});
  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const CircularProgressIndicator.adaptive(),
          const SizedBox(height: 12),
          Text('Consultando clima…', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    final clean = message.replaceAll(RegExp(r'[\u0000-\u001F]'), '');
    return _Glass(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(clean, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _WeatherGlassCard extends StatelessWidget {
  final String city;
  final String country;
  final double temp;
  final double feels;
  final int humidity;
  final String desc;

  const _WeatherGlassCard({
    super.key,
    required this.city,
    required this.country,
    required this.temp,
    required this.feels,
    required this.humidity,
    required this.desc,
  });

  String _safeShort(String s, {int max = 100}) {
    final t = s.replaceAll(RegExp(r'[\u0000-\u001F]'), '').trim();
    return t.length <= max ? t : "${t.substring(0, max)}…";
  }

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado ciudad / país
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "$city • $country",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Temperatura grande
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                temp.isNaN ? '--' : temp.toStringAsFixed(1),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
              ),
              const SizedBox(width: 6),
              Text('°C', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Icon(
                Icons.wb_sunny_rounded,
                size: 36,
                color: Colors.yellow.shade300,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_safeShort(desc), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70)),

          const SizedBox(height: 16),

          // Chips de métricas
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(icon: Icons.thermostat_rounded, label: 'Sensación', value: "${feels.toStringAsFixed(1)} °C"),
              _MetricChip(icon: Icons.water_drop_rounded, label: 'Humedad', value: "$humidity %"),
            ],
          ),

          const SizedBox(height: 12),
          Text("Actualizado: ${DateTime.now()}",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetricChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
