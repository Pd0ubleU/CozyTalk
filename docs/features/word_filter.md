# Feature: word_filter

Client-side profanity filter. Loads a banned word list from a bundled JSON asset into a SQLite database on first use, then exposes a stateless `CensorText` use case that replaces matched words with asterisks. Entirely gated by a Firebase Remote Config boolean flag.

## File Map

```
features/word_filter/
├── domain/
│   ├── entities/banned_word.dart
│   ├── repositories/word_filter_repository.dart  abstract WordFilterRepository
│   └── usecases/censor_text.dart                 CensorText — stateless; returns censored string
├── data/
│   ├── datasources/
│   │   ├── word_filter_datasource.dart            WordFilterDatasourceImpl
│   │   └── word_filter_database_helper.dart       SQLite helper (sqflite)
│   ├── models/banned_word_model.dart
│   └── repositories/word_filter_repository_impl.dart
└── presentation/
    └── providers/word_filter_provider.dart
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `censorTextProvider` | `Provider<CensorText>` | stateless service; consume with `ref.read` |
| `wordFilterRepositoryProvider` | `Provider<WordFilterRepository>` | shared repository; consumed by `censorTextProvider` |

No `Notifier` — this is a stateless service with no UI state.

## Key Behavior

- **Asset**: `assets/banned_words.json` — bundled word list seeded into SQLite on first launch
- **SQLite**: `WordFilterDatabaseHelper` (sqflite) manages the local DB; seeding is idempotent and guarded by a `SharedPreferences` flag to avoid re-seeding on every launch
- **Remote Config gate**: `content_filtering_enabled` boolean flag — when `false`, `CensorText` returns the input string unchanged (no-op)
- **No Notifier**: call `ref.read(censorTextProvider)(text)` wherever text censoring is needed (e.g. in `ChatDatasourceImpl` before sending, or in message rendering)

## Feature Flag & Rollback

| Property | Value |
|---|---|
| Flag name | `content_filtering_enabled` |
| Type | boolean |
| App-side default | `false` (filter off if Remote Config unreachable) |
| Fetch interval | 1 hour (`minimumFetchInterval` in `main.dart`) |
| Integration point | `word_filter_provider.dart` — passed as `() => FirebaseRemoteConfig.instance.getBool('content_filtering_enabled')` |

**Enable:** set `content_filtering_enabled = true` in the Firebase Remote Config console and publish. Clients activate on next fetch (within 1 hour).

**Rollback:** set `content_filtering_enabled = false` in the Firebase Remote Config console and publish. Clients propagate within 1 hour. No app release required.

The flag is evaluated live on every `censorText()` call — toggling in the console takes effect for all subsequent calls once clients pick up the new config.

## Usage

```dart
// In a datasource or widget
final censor = ref.read(censorTextProvider);
final safe = censor(userInput);
```
