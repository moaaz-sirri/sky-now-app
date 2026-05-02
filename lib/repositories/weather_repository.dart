import '../models/forecast_model.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';

class WeatherRepository {
  WeatherRepository({WeatherService? service})
    : _service = service ?? WeatherService(apiKey: apiKey);

  final WeatherService _service;

  Future<WeatherModel> getCurrentWeatherByCity(
    String city, {
    String? countryCode,
    String? language,
  }) {
    return _service.fetchCurrentWeatherByCity(
      city: _cityQuery(city, countryCode),
      language: language,
    );
  }

  Future<WeatherModel> getCurrentWeatherByCoordinates({
    required double latitude,
    required double longitude,
    String? language,
  }) {
    return _service.fetchCurrentWeatherByCoordinates(
      latitude: latitude,
      longitude: longitude,
      language: language,
    );
  }

  Future<ForecastModel> getFiveDayForecastByCity(
    String city, {
    String? countryCode,
    String? language,
  }) {
    return _service.fetchFiveDayForecastByCity(
      city: _cityQuery(city, countryCode),
      language: language,
    );
  }

  String _cityQuery(String city, String? countryCode) {
    final trimmedCity = city.trim();
    final trimmedCountryCode = countryCode?.trim();

    if (trimmedCountryCode == null || trimmedCountryCode.isEmpty) {
      return trimmedCity;
    }

    return '$trimmedCity,${trimmedCountryCode.toUpperCase()}';
  }
}
