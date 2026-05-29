# Facebouffe

A personal recipe catalog for your phone — add, organize, and cook from your own
recipes. Phase 1 is standalone and local-only (no accounts, no feed). Built with
Flutter/Dart for **Android** and as an **iOS web app**.

The UI faithfully reproduces the Claude Design mockup in [`MockUp/`](MockUp/), per
the design brief in [`DesignBrief/`](DesignBrief/). The recipe database is seeded
from [`assets/facebouffe-seed.json`](assets/facebouffe-seed.json).

## Features

- **Home** — colorful category browse hub, favorites carousel, recently cooked,
  all recipes (editorial or grid layout).
- **Recipe page** — hero (photo or deterministic fallback color), tag pills,
  variant chips, servings stepper with friendly-fraction scaling, structured
  ingredients, numbered steps with timers, gallery, personal journal, and a
  "Add to groceries" action.
- **Sous-chef mode** — lean two-pane cooking view (ingredients checklist +
  step-by-step) with running timers and a kept-awake indicator.
- **Add/Edit** — sectioned flow (Infos / Ingredients / Steps / Description) with
  a tag picker (inline create), recipe-link picker, and automatic `°C`/`°F`
  temperature detection.
- **Search** — by title, ingredient (preset chips) and category, with variant
  de-duplication.
- **Shopping list** — aggregated, unit-merging, with manual items.
- **Settings** — username, language (FR/EN), independent unit toggles
  (temperature/volume/weight), text size, dark mode, custom-tag management, and
  JSON import / JSON + PDF export.
- **Bilingual** UI chrome (FR/EN); recipe content is never translated.
- **Just-in-time coach marks** and an in-app help glossary.

## Tech

Flutter · `provider` (state) · `shared_preferences` (local persistence) ·
`google_fonts` (Newsreader + Hanken Grotesk) · `image_picker` · `printing`/`pdf`
· `file_picker` · `share_plus`.

## Run

```bash
flutter pub get
flutter run                 # connected Android device / emulator
flutter run -d chrome       # iOS-style web app
```

## Build

```bash
flutter build apk           # Android
flutter build web           # web (iOS)
```
