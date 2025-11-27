# Flutter Basic – Modular Structure

An opinionated Flutter starter that focuses on a clean, easy-to-scale project layout for medium-sized apps.

## Project highlights

- **Feature-first modules**: each feature owns its `presentation` layer (and can grow to include `domain`/`data`).
- **Core theme layer**: all colors, typography, spacing, and global styles live under `lib/core/theme`.
- **Shared widgets**: navigation bars and other reusable UI live in `lib/shared/widgets`.
- **Central navigation**: `AppRouter` contains a single source of truth for routes and makes it easy to plug in new screens.

## Directory layout

```
lib/
├── app.dart                 # Root MaterialApp
├── main.dart                # Entry point
├── core/
│   └── theme/               # Colors, typography, spacing, theme builder
├── navigation/              # Route names + generator
├── shared/
│   └── widgets/             # AppBar, bottom nav, etc.
└── features/
	├── dashboard/
	├── counter/
	├── history/
	├── profile/
	└── shell/               # Bottom-nav scaffold that hosts the tabs
```

Add new functionality by creating a folder under `lib/features/<feature_name>/presentation/pages` and registering the page inside `AppRouter` (and optionally the bottom navigation shell).

## Try it

```bash
flutter pub get
flutter run
```

Run static checks anytime with:

```bash
flutter analyze
```

## Resources

- [Flutter documentation](https://docs.flutter.dev/)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
