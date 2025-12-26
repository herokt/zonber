# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ZONBER is a hyper-casual bullet hell survival mobile game built with Flutter and Flame Engine. Players survive as long as possible in a confined zone while dodging relentless bullet patterns.

- **Package Name:** com.zonber.game
- **Platforms:** Android, iOS (mobile only for Firebase/AdMob)
- **Backend:** Firebase Firestore
- **Game Engine:** Flame 1.34.0

## Common Commands

```bash
# Run the app
flutter run

# Run on specific device
flutter run -d <device_id>

# Build Android APK
flutter build apk

# Build iOS
flutter build ios

# Static analysis
flutter analyze

# Run tests
flutter test

# Get dependencies
flutter pub get
```

## Architecture

### Entry Point & Navigation
`main.dart` contains:
- App initialization (Firebase, AdMob, GameSettings, AudioManager)
- `ZonberApp` widget with state-based page routing via `_currentPage`
- Pages: Menu, MapSelect, Game, Result, Editor, EditorVerify, Profile, CharacterSelect

### Game Core (Flame Engine)
`ZonberGame` class in `main.dart`:
- Fixed map size: 480x768 (15x24 grid of 32px tiles)
- World height: 800 (includes UI area below map)
- Components: `Player`, `Bullet`, `BulletSpawner`, `Obstacle`, `MapArea`, `GridBackground`
- Touch control: Direct drag (1:1 finger movement, no joystick)
- Collision system uses Flame's `HasCollisionDetection` with manual anti-tunneling for bullets

### Key Files
| File | Purpose |
|------|---------|
| `ranking_system.dart` | Firestore leaderboard (save/fetch records, national rankings) |
| `editor_game.dart` | Grid-based map editor (15x24 grid), 30-second verification required for upload |
| `map_service.dart` | Custom map CRUD operations to Firestore |
| `design_system.dart` | Neon-themed UI components (`NeonButton`, `NeonCard`, `NeonDialog`, etc.) |
| `audio_manager.dart` | Singleton for BGM/SFX using flame_audio |
| `ad_manager.dart` | AdMob integration (banner, interstitial) |
| `game_settings.dart` | Persistent settings via SharedPreferences |
| `user_profile.dart` | User nickname and country flag management |
| `character_data.dart` | Character definitions (4 skins with different shapes) |

### Design System
All UI uses the neon theme defined in `design_system.dart`:
- Colors: `AppColors.primary` (cyan), `AppColors.secondary` (red), `AppColors.background` (deep black)
- Components: `NeonScaffold`, `NeonAppBar`, `NeonCard`, `NeonButton`, `NeonDialog`

### Firebase/AdMob Platform Check
Firebase and AdMob only initialize on mobile platforms:
```dart
if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
  await Firebase.initializeApp();
  await AdManager().initialize();
}
```

## Map System

### Official Maps
- `zone_1_classic`: Standard difficulty
- `zone_2_hard`: Faster bullets, shorter spawn interval
- `zone_3_obstacles`: Random obstacles with bullet ricochet

### Custom Maps (UGC)
- Stored in Firestore `custom_maps` collection
- Grid data stored as flattened 1D array with width/height
- Verification: Creator must survive 30 seconds before upload

### Editor Restrictions
- Center 3x3 tiles (spawn area) cannot have walls
- Outer edge tiles cannot be modified

## Singleton Services

Three singleton managers initialized at app startup:
- `GameSettings()` - Sound/vibration preferences (SharedPreferences)
- `AudioManager()` - BGM/SFX playback (flame_audio)
- `AdManager()` - AdMob ads (mobile only)

## Firestore Collections

```
maps/
  └── {mapId}/
      └── records/          # Leaderboard entries
          └── {recordId}    # nickname, flag, survivalTime, timestamp

custom_maps/
  └── {mapId}               # name, author, width, height, grid[], verified, createdAt
```

## SharedPreferences Keys

| Key | Purpose |
|-----|---------|
| `sound_enabled` | BGM/SFX toggle |
| `vibration_enabled` | Haptic feedback toggle |
| `user_nickname` | Player display name (max 8 chars) |
| `user_flag_code` | Country flag emoji |
| `user_country_name` | Country name string |
| `user_character_id` | Selected character skin |

## Characters

4 character skins with unique shapes:
- `neon_green` - Square (default)
- `electric_blue` - Circle
- `cyber_red` - Triangle
- `plasma_purple` - Rocket/spaceship

Rendering logic in `Player.render()` switches shape based on `characterId`.

## Audio Assets

Located in `assets/audio/`:
- `bgm.mp3` - Background music (loops)
- `shoot.wav`, `hit.wav`, `gameover.wav` - Sound effects

## AdMob Configuration

In `ad_helper.dart`:
- Set `isReleaseMode = true` for production builds
- Replace placeholder Ad Unit IDs with real ones before release
- Test IDs are used automatically when `isReleaseMode = false`

## Android Configuration Notes

Located in `android/`:
- Package path: `android/app/src/main/kotlin/com/zonber/game/`
- `google-services.json` must match package name `com.zonber.game`
- MultiDex enabled for Firebase compatibility
- If build errors occur across drives, check `gradle.properties` for `kotlin.incremental=false`

