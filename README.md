# Vocabulary Battle Boss (Admin App)

Flutter admin console for operating Vocabulary Battle sessions.
This app is used to create and manage game sessions, track player progress, and control battle lifecycle events.

## Core Features

- Google sign-in with Firebase Auth
- Create new game sessions with selected players and deadlines
- Manage game lifecycle (`preparation`, `ready`, `active`, `completed`)
- View active session details and player progress
- Review game history and statistics
- Log and audit admin actions
- Trigger admin-side game actions (including Cloud Function calls)

## Game Modes

| Mode | Total Questions | Breakdown |
| --- | ---: | --- |
| Quick | 15 | 3 x 4 + 3 random |
| Normal | 23 | 3 x 6 + 5 random |
| Challenge | 35 | 3 x 10 + 5 random |

## Tech Stack

- Flutter + Dart
- Firebase Auth, Firestore, Realtime Database, Cloud Messaging
- Firebase Cloud Functions (callable actions)
- Riverpod for state management
- Hive for local persistence

## Project Setup

### 1. Prerequisites

- Flutter SDK (Dart SDK `^3.6.0`)
- Xcode (for iOS/macOS builds)
- Android Studio and Android SDK (for Android builds)
- A Firebase project configured for admin access

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure environment variables

Copy the example env file and fill in values:

```bash
cp .env.example .env
```

Available keys:

- `ALLE_AI_API_KEY` - reserved for shared AI integrations
- `OPENAI_API_KEY` - reserved for shared AI integrations

### 4. Firebase config

This app expects Firebase platform config files and generated options:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`

If you change Firebase projects, regenerate these files and update `firebase_options.dart`.

### 5. Cloud Functions region

Admin callable functions are configured via `lib/core/firebase_functions_config.dart` using region:

- `us-central1`

Make sure deployed callable functions (for example `deleteGame`) are available in that region.

### 6. Run the app

```bash
flutter run
```

## Useful Commands

```bash
flutter analyze
flutter test
```

## High-Level Structure

```text
lib/
  core/          # constants and firebase functions config
  models/        # domain models (users, sessions, admin actions)
  providers/     # Riverpod providers
  screens/       # dashboard, game management, history, stats
  services/      # firebase/auth/firestore/admin operation logic
  widgets/       # reusable UI components
```

## Notes

- `.env` files are intentionally git-ignored.
- `.env.example` is committed for onboarding.
- Keep admin account permissions restricted through Firebase rules and/or backend validation.
