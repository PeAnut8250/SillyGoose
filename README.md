# 🪿 SillyGoose

**SillyGoose** is a modern, cross-platform music streaming app built with Flutter. Designed with a stunning **LiquidGlass** dark aesthetic, dynamic audio streaming, audio quality tiers, crossfade playback, 30+ language localizations, and automatic in-app updates.

---

## ✨ Key Features

- 🎨 **LiquidGlass Design System**: Premium translucent frosted-glass aesthetic with dynamic mesh background gradients and smooth animations.
- 🎵 **Dual Stream Engine**: High-fidelity audio streaming powered by JioSaavn with fallback YouTube audio integration.
- 🎚️ **Audio Quality Controls**: Select between **Low (48kbps)**, **Normal (96kbps)**, **High (160kbps)**, and **Lossless (320kbps)** for Wi-Fi and Mobile networks.
- 🔀 **Gapless Crossfade**: Adjustable smooth volume transitions between track changes (0s to 10s).
- 🔊 **System Volume Control**: Real-time hardware volume synchronization (`flutter_volume_controller`).
- 🌐 **30+ Languages Supported**: Full app localization including English, Hindi, Bengali, French, Dutch, Spanish, German, Japanese, and 22+ more.
- 🚀 **In-App CI/CD Auto-Updates**: Automatic update check on app launch via GitHub Releases API with seamless release note popups.

---

## 📦 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.16 or higher)
- Android Studio / VS Code with Flutter extension
- Java JDK 17 (for Android build)

### Installation & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/PeAnut8250/SillyGoose.git
   cd SillyGoose
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Run on connected device or emulator:
   ```bash
   # Run on Desktop (Windows)
   flutter run -d windows

   # Run on Android Device
   flutter run -d android
   ```

---

## 🚀 Releasing New Updates (CI/CD Workflow)

SillyGoose is configured with an automated GitHub Actions pipeline (`.github/workflows/release.yml`) for seamless in-app update delivery.

### How to Publish an Update

1. Update the version number in `pubspec.yaml` if desired:
   ```yaml
   version: 1.0.1+2
   ```

2. Commit your changes:
   ```bash
   git add .
   git commit -m "feat: added new feature X"
   ```

3. Tag the release commit and push to GitHub:
   ```bash
   git tag v1.0.1
   git push origin main --tags
   ```

4. **Automated Magic**:
   - GitHub Actions automatically compiles `app-release.apk`.
   - A new GitHub Release is created with auto-generated release notes.
   - Users running SillyGoose will automatically get an **In-App Update Modal** with release notes and direct download button the next time they open the app!

---

## 🛠️ Architecture Overview

- **State Management**: Provider Scope & `ChangeNotifier` singletons (`SettingsService`, `AudioService`, `HistoryService`).
- **Audio Core**: `just_audio` + `audio_service` with dual `AudioPlayer` instances for true background playback and crossfading.
- **Auto-Update Engine**: `UpdateService` querying `api.github.com/repos/PeAnut8250/SillyGoose/releases/latest`.

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.
