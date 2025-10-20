# RUNNR - JioSaavn Music Streaming App

A production-quality Flutter music streaming app that uses JioSaavn API to provide a Spotify-like experience.

## Features

✨ **Core Features:**
- Stream music from JioSaavn API
- Search songs, artists, and albums
- Like/unlike songs with real-time sync across all screens
- Library with "Liked Songs" playlist
- Dynamic color theme based on album art
- Background audio playback (works when screen is locked)
- Full-featured audio player with seek bar, next/previous
- Mini player bar with smooth transitions
- Home screen with greeting and trending songs

## Tech Stack

- **Framework:** Flutter 3.35+
- **State Management:** Provider
- **Audio Playback:** just_audio + audio_service
- **Storage:** JSON-based local storage using path_provider
- **UI:** Material 3 with dynamic theming
- **Image Loading:** cached_network_image
- **Color Extraction:** palette_generator

## Installation

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run the app on Android:**
   ```bash
   flutter run
   ```

## API Integration

The app uses JioSaavn's public API with proper headers as specified in the Android Kotlin version.

### Key Endpoints:
- **Search:** `https://www.jiosaavn.com/api.php?__call=search.getResults`
- **Stream URL:** `https://www.jiosaavn.com/api.php?__call=song.generateAuthToken`

## Key Features

### 1. Background Playback
Music continues when app is minimized or screen is locked using `just_audio` and `audio_service`.

### 2. Real-time Like/Unlike Sync
Changes instantly reflect across Search, Home, Library, and Player screens using Provider.

### 3. Dynamic Color Theme
Uses `palette_generator` to extract dominant color from album art and create adaptive themes.

### 4. Local Storage
Liked songs stored as JSON at `app_documents/playlists/liked_songs.json`.

## Building for Release

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Architecture

Follows **MVVM pattern** with:
- **Models:** Data structures
- **Views:** UI screens and widgets
- **Providers:** State management
- **Services:** Business logic and API calls

## Credits

- **Developer:** bhvym-sudo
- **Original Android App:** RUNNR (Kotlin)

---
