class Weather {
  final String city;
  final String country;
  final double tempC;
  final double feelsLikeC;
  final int humidity;
  final String description;

  Weather({
    required this.city,
    required this.country,
    required this.tempC,
    required this.feelsLikeC,
    required this.humidity,
    required this.description,
  });

  // Con units=metric ya viene en °C directo.
  factory Weather.fromOpenWeather(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString();
    final sys = json['sys'] as Map<String, dynamic>? ?? {};
    final main = json['main'] as Map<String, dynamic>? ?? {};
    final weatherArr = (json['weather'] as List?) ?? [];
    final desc = weatherArr.isNotEmpty
        ? (weatherArr.first['description'] ?? '').toString()
        : '';
    return Weather(
      city: name,
      country: (sys['country'] ?? '').toString(),
      tempC: (main['temp'] as num?)?.toDouble() ?? double.nan,
      feelsLikeC: (main['feels_like'] as num?)?.toDouble() ?? double.nan,
      humidity: (main['humidity'] as num?)?.toInt() ?? 0,
      description: desc,
    );
  }
}
