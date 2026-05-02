class ForecastModel {
  const ForecastModel({
    required this.cityName,
    required this.country,
    required this.items,
  });

  final String cityName;
  final String country;
  final List<ForecastItemModel> items;

  String get locationName {
    if (country.isEmpty) {
      return cityName;
    }

    return '$cityName, $country';
  }

  factory ForecastModel.fromJson(Map<String, dynamic> json) {
    final city = json['city'] as Map<String, dynamic>? ?? const {};
    final rawItems = json['list'] as List<dynamic>? ?? const [];

    return ForecastModel(
      cityName: (city['name'] as String?)?.trim().isNotEmpty == true
          ? city['name'] as String
          : 'Unknown city',
      country: city['country'] as String? ?? '',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(ForecastItemModel.fromJson)
          .toList(growable: false),
    );
  }
}

class ForecastItemModel {
  const ForecastItemModel({
    required this.dateTime,
    required this.temperature,
    required this.iconCode,
    required this.description,
  });

  final DateTime? dateTime;
  final double temperature;
  final String iconCode;
  final String description;

  String get iconUrl => 'https://openweathermap.org/img/wn/$iconCode@4x.png';

  factory ForecastItemModel.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>? ?? const {};
    final weatherItems = json['weather'] as List<dynamic>? ?? const [];
    final weather =
        weatherItems.isNotEmpty && weatherItems.first is Map<String, dynamic>
        ? weatherItems.first as Map<String, dynamic>
        : const <String, dynamic>{};

    return ForecastItemModel(
      dateTime: _toDateTime(json['dt']),
      temperature: _toDouble(main['temp']),
      iconCode: weather['icon'] as String? ?? '01d',
      description: _sentenceCase(weather['description'] as String? ?? ''),
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return 0;
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
      return 'Forecast conditions';
    }

    return value[0].toUpperCase() + value.substring(1);
  }
}
