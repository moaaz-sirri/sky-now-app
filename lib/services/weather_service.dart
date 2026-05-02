import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/forecast_model.dart';
import '../models/weather_model.dart';

const String _missingApiKey = 'PUT_API_KEY_HERE';
const String apiKey = String.fromEnvironment(
  'WEATHER_API_KEY',
  defaultValue: _missingApiKey,
);

class WeatherService {
  WeatherService({
    required String apiKey,
    Dio? dio,
    Duration timeout = const Duration(seconds: 12),
  }) : _apiKey = apiKey.trim(),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: _baseUrl,
               connectTimeout: timeout,
               receiveTimeout: timeout,
               sendTimeout: timeout,
               headers: const {
                 'Accept': 'application/json',
                 'Content-Type': 'application/json',
               },
             ),
           ) {
    if (kDebugMode) {
      _dio.interceptors.add(const _WeatherLogInterceptor());
    }
  }

  static const String _baseUrl = 'https://api.openweathermap.org';
  static const String _units = 'metric';

  final String _apiKey;
  final Dio _dio;

  Future<WeatherModel> fetchWeather(String city) {
    return fetchCurrentWeatherByCity(city: city);
  }

  Future<WeatherModel> fetchCurrentWeatherByCity({
    required String city,
    String? language,
  }) async {
    final trimmedCity = city.trim();
    if (trimmedCity.isEmpty) {
      throw const WeatherException('Please enter a city name.');
    }

    final json = await _getJson(
      '/data/2.5/weather',
      queryParameters: {'q': trimmedCity},
      language: language,
    );

    return WeatherModel.fromJson(json);
  }

  Future<WeatherModel> fetchCurrentWeatherByCoordinates({
    required double latitude,
    required double longitude,
    String? language,
  }) async {
    final json = await _getJson(
      '/data/2.5/weather',
      queryParameters: {'lat': latitude, 'lon': longitude},
      language: language,
    );

    return WeatherModel.fromJson(json);
  }

  Future<ForecastModel> fetchFiveDayForecastByCity({
    required String city,
    String? language,
  }) async {
    final trimmedCity = city.trim();
    if (trimmedCity.isEmpty) {
      throw const WeatherException('Please enter a city name.');
    }

    final json = await _getJson(
      '/data/2.5/forecast',
      queryParameters: {'q': trimmedCity},
      language: language,
    );

    return ForecastModel.fromJson(json);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    required Map<String, dynamic> queryParameters,
    String? language,
  }) async {
    if (_isMissingApiKey) {
      if (kDebugMode) {
        debugPrint(
          _WeatherLogInterceptor.colorize(
            _WeatherLogInterceptor.yellow,
            '[API Skipped] Missing OpenWeatherMap API key. '
            'Run with --dart-define-from-file=stg_keys.json or pro_keys.json.',
          ),
        );
      }

      throw const WeatherException(
        'Missing OpenWeatherMap API key. Run with --dart-define-from-file=stg_keys.json or pro_keys.json.',
        statusCode: 401,
        type: WeatherExceptionType.invalidApiKey,
      );
    }

    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: {
          ...queryParameters,
          'appid': _apiKey,
          'units': _units,
          if (language != null && language.trim().isNotEmpty)
            'lang': language.trim(),
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }

      throw const WeatherException(
        'The weather service returned an unexpected response.',
        type: WeatherExceptionType.badResponse,
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw const WeatherException(
        'Something went wrong. Please try again.',
        type: WeatherExceptionType.unknown,
      );
    }
  }

  bool get _isMissingApiKey {
    return _apiKey.isEmpty ||
        _apiKey == _missingApiKey ||
        _apiKey.startsWith('YOUR_');
  }

  WeatherException _mapDioException(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const WeatherException(
        'The weather request timed out. Please try again.',
        type: WeatherExceptionType.timeout,
      ),
      DioExceptionType.connectionError => const WeatherException(
        'No internet connection. Please check your network and try again.',
        type: WeatherExceptionType.network,
      ),
      DioExceptionType.badResponse => _messageForStatus(error),
      DioExceptionType.cancel => const WeatherException(
        'The weather request was cancelled.',
        type: WeatherExceptionType.cancelled,
      ),
      DioExceptionType.badCertificate => const WeatherException(
        'Could not verify the weather service certificate.',
        type: WeatherExceptionType.network,
      ),
      DioExceptionType.unknown => const WeatherException(
        'Could not reach the weather service. Please try again.',
        type: WeatherExceptionType.network,
      ),
    };
  }

  WeatherException _messageForStatus(DioException error) {
    final statusCode = error.response?.statusCode;
    final apiMessage = _apiMessage(error.response?.data);

    if (statusCode != null && statusCode >= 500) {
      return WeatherException(
        apiMessage ?? 'OpenWeatherMap server error. Please try again later.',
        statusCode: statusCode,
        type: WeatherExceptionType.server,
      );
    }

    return switch (statusCode) {
      401 => const WeatherException(
        'Invalid OpenWeatherMap API key. Please check apiKey.',
        statusCode: 401,
        type: WeatherExceptionType.invalidApiKey,
      ),
      404 => const WeatherException(
        'City not found. Try another city name.',
        statusCode: 404,
        type: WeatherExceptionType.cityNotFound,
      ),
      429 => const WeatherException(
        'Too many requests. Please wait a moment and try again.',
        statusCode: 429,
        type: WeatherExceptionType.rateLimited,
      ),
      _ => WeatherException(
        apiMessage ?? 'Unable to load weather right now.',
        statusCode: statusCode,
        type: WeatherExceptionType.badResponse,
      ),
    };
  }

  String? _apiMessage(Object? data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    return null;
  }
}

enum WeatherExceptionType {
  invalidApiKey,
  cityNotFound,
  rateLimited,
  server,
  network,
  timeout,
  badResponse,
  cancelled,
  unknown,
}

class WeatherException implements Exception {
  const WeatherException(
    this.message, {
    this.statusCode,
    this.type = WeatherExceptionType.unknown,
  });

  final String message;
  final int? statusCode;
  final WeatherExceptionType type;

  @override
  String toString() => message;
}

class _WeatherLogInterceptor extends Interceptor {
  const _WeatherLogInterceptor();

  static const String cyan = '\x1B[36m';
  static const String green = '\x1B[32m';
  static const String red = '\x1B[31m';
  static const String yellow = '\x1B[33m';
  static const String _reset = '\x1B[0m';

  static const Set<String> _sensitiveQueryParams = {
    'appid',
    'api_key',
    'apikey',
    'key',
    'token',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint(
      colorize(
        cyan,
        '[API Request] ${options.method} ${_redactedUri(options)}',
      ),
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    debugPrint(
      colorize(
        green,
        '[API Response] ${response.statusCode} ${response.requestOptions.path}',
      ),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      colorize(
        red,
        '[API Error] ${err.response?.statusCode ?? err.type.name} '
        '${err.requestOptions.path}',
      ),
    );
    handler.next(err);
  }

  static String colorize(String color, String message) {
    return '$color$message$_reset';
  }

  String _redactedUri(RequestOptions options) {
    final redactedQueryParameters = options.uri.queryParameters.map(
      (key, value) => MapEntry(
        key,
        _sensitiveQueryParams.contains(key.toLowerCase()) ? '***' : value,
      ),
    );

    return options.uri
        .replace(queryParameters: redactedQueryParameters)
        .toString();
  }
}
