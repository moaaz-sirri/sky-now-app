# sky_now_app

A simple Flutter weather app using OpenWeatherMap.

## Release APK

Latest local production release APK:

- [Download app-production-release.apk](release-apks/app-production-release.apk)
- Flavor: `production`
- Size: `46M`
- SHA-256: `56382e87f1996841cd05b20286f7fc9ae1ad6d312fb14124c29d144e3d0a4d7c`

## Environment key files

The app has two Flutter flavors and reads configuration from flavor-specific
Dart define JSON files:

- Staging: `keys_stg.json`
- Production: `keys_pro.json`

Real key files are ignored by Git. Do not commit real OpenWeatherMap keys.

## Create local keys

1. Create an OpenWeatherMap account and API key:
   https://openweathermap.org/
2. Copy the example files:

```sh
cp keys_stg.example.json keys_stg.json
cp keys_pro.example.json keys_pro.json
```

3. Replace the placeholder `WEATHER_API_KEY` values in both local files.

Required fields:

- `APP_FLAVOR`: Must match the Flutter flavor (`staging` or `production`).
- `WEATHER_API_KEY`: OpenWeatherMap API key used by `WeatherService`.

The example JSON files include `_comment` fields because JSON does not support
normal `//` comments. They are only there to explain the setup; the app reads
`APP_FLAVOR` and `WEATHER_API_KEY`.

## Run

Use the matching flavor and key file:

```sh
flutter run --flavor staging --dart-define-from-file=keys_stg.json
flutter run --flavor production --dart-define-from-file=keys_pro.json
```

## Build

Android:

```sh
flutter build apk --flavor staging --dart-define-from-file=keys_stg.json
flutter build apk --flavor production --dart-define-from-file=keys_pro.json
```

iOS:

```sh
flutter build ios --flavor staging --dart-define-from-file=keys_stg.json
flutter build ios --flavor production --dart-define-from-file=keys_pro.json
```

Use the staging key for development and QA builds. Use the production key only
for release builds or production validation.
