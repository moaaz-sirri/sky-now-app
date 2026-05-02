import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/weather_model.dart';
import 'repositories/weather_repository.dart';
import 'services/weather_service.dart' show WeatherException;

class AppConfig {
  static const String fallbackAppVersion = '1.0.0+1';
  static const String flavor = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'production',
  );
  static String get appTitle =>
      flavor == 'staging' ? 'SkyNow Staging' : 'SkyNow';

  static bool get showFlavorBadge => flavor != 'production';
}

void main() {
  runApp(const MyApp());
}

class ThemeModeController extends ChangeNotifier {
  static const String _storageKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _themeMode = _themeModeFromStorageValue(
        preferences.getString(_storageKey),
      );
      notifyListeners();
    } catch (_) {
      _themeMode = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_themeMode == themeMode) {
      return;
    }

    _themeMode = themeMode;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey,
        _themeModeToStorageValue(themeMode),
      );
    } catch (_) {
      // Keep the in-memory theme update even if persistence is unavailable.
    }
  }

  static ThemeMode _themeModeFromStorageValue(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _themeModeToStorageValue(ThemeMode themeMode) {
    return switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ThemeModeController _themeModeController;

  @override
  void initState() {
    super.initState();
    _themeModeController = ThemeModeController()..load();
  }

  @override
  void dispose() {
    _themeModeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeModeController,
      builder: (context, _) {
        return MaterialApp(
          title: AppConfig.appTitle,
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: _themeModeController.themeMode,
          home: WeatherHomePage(themeModeController: _themeModeController),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      useMaterial3: true,
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key, required this.themeModeController});

  final ThemeModeController themeModeController;

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  static const String _defaultCity = 'Kuala Lumpur, Malaysia';

  final TextEditingController _cityController = TextEditingController(
    text: _defaultCity,
  );
  final WeatherRepository _weatherRepository = WeatherRepository();

  WeatherModel? _weather;
  String? _errorMessage;
  String _lastCity = _defaultCity;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather(_defaultCity);
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather(String city) async {
    final query = city.trim();

    if (query.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter a city name.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final weather = await _weatherRepository.getCurrentWeatherByCity(query);

      if (!mounted) {
        return;
      }

      setState(() {
        _weather = weather;
        _lastCity = query;
        _cityController.text = weather.locationName;
        _isLoading = false;
      });
    } on WeatherException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _searchWeather() {
    FocusScope.of(context).unfocus();
    _loadWeather(_cityController.text);
  }

  void _openSettings() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            SettingsScreen(themeModeController: widget.themeModeController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF042F2E), Color(0xFF0F172A), Color(0xFF111827)]
        : const [Color(0xFF0F766E), Color(0xFF155E75), Color(0xFF312E81)];

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 42,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SearchHeader(
                          controller: _cityController,
                          isLoading: _isLoading,
                          onSubmitted: _loadWeather,
                          onSearch: _searchWeather,
                          onOpenSettings: _openSettings,
                        ),
                        const SizedBox(height: 28),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _buildContent(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const _LoadingWeather(key: ValueKey('loading'));
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return _WeatherError(
        key: const ValueKey('error'),
        message: errorMessage,
        onRetry: () => _loadWeather(_lastCity),
      );
    }

    final weather = _weather;
    if (weather == null) {
      return _WeatherError(
        key: const ValueKey('empty'),
        message: 'No weather data available.',
        onRetry: () => _loadWeather(_lastCity),
      );
    }

    return _WeatherOverview(key: const ValueKey('weather'), weather: weather);
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.isLoading,
    required this.onSubmitted,
    required this.onSearch,
    required this.onOpenSettings,
  });

  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConfig.appTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  if (AppConfig.showFlavorBadge) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        AppConfig.flavor.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Search real-time conditions by city',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                foregroundColor: Colors.white,
                fixedSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isLoading,
                onSubmitted: isLoading ? null : onSubmitted,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  color: Color(0xFF102A2A),
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter city',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.94),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: isLoading ? null : onSearch,
              icon: const Icon(Icons.search, size: 20),
              label: const Text('Search'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF8FAFC),
                foregroundColor: const Color(0xFF134E4A),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                disabledForegroundColor: const Color(
                  0xFF134E4A,
                ).withValues(alpha: 0.45),
                minimumSize: const Size(104, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.themeModeController});

  final ThemeModeController themeModeController;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      if (!mounted) {
        return;
      }

      setState(() {
        _appVersion = _formatVersion(packageInfo);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _appVersion = AppConfig.fallbackAppVersion;
      });
    }
  }

  String _formatVersion(PackageInfo packageInfo) {
    if (packageInfo.buildNumber.isEmpty) {
      return packageInfo.version;
    }

    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Appearance',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: widget.themeModeController,
              builder: (context, _) {
                return SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('System'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {widget.themeModeController.themeMode},
                  onSelectionChanged: (selection) {
                    widget.themeModeController.setThemeMode(selection.single);
                  },
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              'About',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _SettingsInfoTile(
              icon: Icons.info_outline,
              label: 'App version',
              value: _appVersion ?? 'Loading...',
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsInfoTile extends StatelessWidget {
  const _SettingsInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(
          value,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _WeatherOverview extends StatelessWidget {
  const _WeatherOverview({super.key, required this.weather});

  final WeatherModel weather;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 18),
        Text(
          weather.locationName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          weather.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Image.network(
          weather.iconUrl,
          width: 148,
          height: 148,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.cloud_outlined,
              color: Colors.white,
              size: 116,
            );
          },
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${weather.temperature.round()}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 112,
              fontWeight: FontWeight.w900,
              height: 0.92,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          weather.condition,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 34),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 330;

            return GridView.count(
              crossAxisCount: isCompact ? 1 : 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isCompact ? 3.8 : 0.95,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _InfoCard(
                  icon: Icons.water_drop_outlined,
                  label: 'Humidity',
                  value: '${weather.humidity}%',
                ),
                _InfoCard(
                  icon: Icons.air,
                  label: 'Wind',
                  value: '${weather.windSpeed.toStringAsFixed(1)} m/s',
                ),
                _InfoCard(
                  icon: Icons.thermostat_outlined,
                  label: 'Feels like',
                  value: '${weather.feelsLike.round()}°',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingWeather extends StatelessWidget {
  const _LoadingWeather({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Loading weather...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherError extends StatelessWidget {
  const _WeatherError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 72),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Colors.white, size: 54),
          const SizedBox(height: 14),
          const Text(
            'Unable to load weather',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.75)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
