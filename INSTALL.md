# EMG Mobile - Installation Guide

## Prerequisites

### Flutter SDK
Download and install Flutter SDK from https://flutter.dev/docs/get-started/install

```bash
# Clone Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
```

---

## Android

### Requirements
- Android Studio or Android SDK
- Android device with Bluetooth LE support
- Android 6.0+ (API 23+)

### Build APK

```bash
# Get dependencies
flutter pub get

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

### Install on Device

**Option 1: Via ADB (USB debugging)**
```bash
# Enable USB debugging on phone:
# Settings → About Phone → Tap "Build Number" 7 times
# Settings → Developer Options → Enable USB Debugging

# Connect phone via USB
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Option 2: Direct install**
- Copy APK to phone (via USB, cloud, or messaging app)
- Open file manager on phone
- Tap APK file
- Allow installation from unknown sources when prompted

### Permissions
On first launch, allow:
- Bluetooth
- Location (required for BLE scanning on Android)

---

## iOS / iPadOS

### Requirements
- macOS with Xcode 14+
- Apple Developer account (for device deployment)
- iOS 12.0+ / iPadOS 12.0+

### Setup

```bash
# Install CocoaPods
sudo gem install cocoapods

# Get Flutter dependencies
flutter pub get

# Install iOS dependencies
cd ios
pod install
cd ..
```

### Build & Run

**Simulator:**
```bash
flutter run -d "iPhone 15"
```

**Physical Device:**
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select your Apple Developer Team in Signing & Capabilities
3. Connect iOS device
4. Select device in Xcode
5. Click Run (⌘R)

Or via command line:
```bash
flutter run -d <device-id>
# Get device ID with: flutter devices
```

### Build IPA (Release)
```bash
flutter build ipa --release
```

IPA location: `build/ios/ipa/emg_mobile.ipa`

### Permissions
Add to `ios/Runner/Info.plist` (already configured):
- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`

---

## macOS

### Requirements
- macOS 10.14+
- Xcode 14+

### Build & Run

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run -d macos

# Build release
flutter build macos --release
```

App location: `build/macos/Build/Products/Release/emg_mobile.app`

### Install
- Copy `.app` to `/Applications` folder
- Or double-click to run

### Permissions
Grant Bluetooth permission when prompted on first launch.

---

## Windows

### Requirements
- Windows 10/11
- Visual Studio 2022 with "Desktop development with C++" workload
- Windows 10 SDK

### Setup Visual Studio
1. Download Visual Studio 2022 from https://visualstudio.microsoft.com/
2. In installer, select "Desktop development with C++"
3. Include Windows 10 SDK

### Build & Run

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run -d windows

# Build release
flutter build windows --release
```

Executable location: `build/windows/x64/runner/Release/emg_mobile.exe`

### Install
- Copy entire `Release` folder to desired location
- Run `emg_mobile.exe`

### Note
Windows Bluetooth support requires Windows 10 version 1803+ and compatible Bluetooth adapter.

---

## Linux

### Requirements
- Ubuntu 20.04+ / Debian 11+ or equivalent
- GTK 3.0 development libraries
- BlueZ (Bluetooth stack)

### Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y \
    clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libstdc++-12-dev \
    libbluetooth-dev bluez
```

**Fedora:**
```bash
sudo dnf install -y \
    clang cmake ninja-build gtk3-devel \
    bluez bluez-libs-devel
```

**Arch Linux:**
```bash
sudo pacman -S --needed \
    clang cmake ninja gtk3 \
    bluez bluez-utils
```

### Build & Run

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run -d linux

# Build release
flutter build linux --release
```

Executable location: `build/linux/x64/release/bundle/emg_mobile`

### Install

```bash
# Copy to /opt
sudo cp -r build/linux/x64/release/bundle /opt/emg_mobile

# Create desktop shortcut
cat > ~/.local/share/applications/emg_mobile.desktop << EOF
[Desktop Entry]
Name=EMG Mobile
Exec=/opt/emg_mobile/emg_mobile
Icon=/opt/emg_mobile/data/flutter_assets/assets/icon.png
Type=Application
Categories=Utility;
EOF
```

### Bluetooth Permissions

```bash
# Add user to bluetooth group
sudo usermod -aG bluetooth $USER

# Restart Bluetooth service
sudo systemctl restart bluetooth

# Logout and login again
```

---

## Troubleshooting

### BLE not working
- Ensure Bluetooth is enabled on device
- On Android: Enable Location services
- On Linux: Check BlueZ service is running
- Restart app after granting permissions

### Build errors
```bash
# Clean build
flutter clean
flutter pub get
flutter build <platform>
```

### Device not found
```bash
# List available devices
flutter devices

# Check specific platform
flutter doctor -v
```

---

## Device Compatibility

| Platform | Minimum Version | BLE Support |
|----------|-----------------|-------------|
| Android  | 6.0 (API 23)    | ✅ Full     |
| iOS      | 12.0            | ✅ Full     |
| iPadOS   | 12.0            | ✅ Full     |
| macOS    | 10.14           | ✅ Full     |
| Windows  | 10 (1803+)      | ⚠️ Limited  |
| Linux    | Ubuntu 20.04+   | ⚠️ Limited  |

**Note:** Mobile platforms (Android, iOS, iPadOS) have the best BLE support. Desktop platforms may have limitations depending on Bluetooth hardware.
