class WeatherModel {
  const WeatherModel({
    required this.cityName,
    required this.country,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.pressure,
    required this.windSpeed,
    required this.condition,
    required this.description,
    required this.iconCode,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
  });

  final String cityName;
  final String country;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final int pressure;
  final double windSpeed;
  final String condition;
  final String description;
  final String iconCode;
  final int? visibility;
  final DateTime? sunrise;
  final DateTime? sunset;

  String get locationName {
    if (country.isEmpty) {
      return cityName;
    }

    return '$cityName, $country';
  }

  String get iconUrl => 'https://openweathermap.org/img/wn/$iconCode@4x.png';

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>? ?? const {};
    final wind = json['wind'] as Map<String, dynamic>? ?? const {};
    final sys = json['sys'] as Map<String, dynamic>? ?? const {};
    final weatherItems = json['weather'] as List<dynamic>? ?? const [];
    final weather =
        weatherItems.isNotEmpty && weatherItems.first is Map<String, dynamic>
        ? weatherItems.first as Map<String, dynamic>
        : const <String, dynamic>{};

    return WeatherModel(
      cityName: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Unknown city',
      country: sys['country'] as String? ?? '',
      temperature: _toDouble(main['temp']),
      feelsLike: _toDouble(main['feels_like']),
      humidity: _toInt(main['humidity']),
      pressure: _toInt(main['pressure']),
      windSpeed: _toDouble(wind['speed']),
      condition: weather['main'] as String? ?? 'Weather',
      description: _sentenceCase(weather['description'] as String? ?? ''),
      iconCode: weather['icon'] as String? ?? '01d',
      visibility: _toNullableInt(json['visibility']),
      sunrise: _toDateTime(sys['sunrise']),
      sunset: _toDateTime(sys['sunset']),
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }

  static int _toInt(Object? value) {
    if (value is num) {
      return value.round();
    }

    return 0;
  }

  static int? _toNullableInt(Object? value) {
    if (value is num) {
      return value.round();
    }

    return null;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is! num) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      value.round() * 1000,
      isUtc: true,
    );
  }

  static String _sentenceCase(String value) {
    if (value.isEmpty) {
      return 'Current conditions';
    }

    return value[0].toUpperCase() + value.substring(1);
  }
}
