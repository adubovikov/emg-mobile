# EMG Mobile

Flutter mobile app for Sichiray EMG device monitoring.

## Features

- BLE connection to Sichiray EMG device (HM-10/HM-11 module)
- Real-time 8-channel EMG signal visualization
- 9-axis IMU data display (Gyroscope, Accelerometer, Angles)
- FFT spectral analysis with frequency bands
- Statistics (RMS, Min/Max, Mean) for each channel
- Adjustable threshold and smoothing
- CSV data recording and sharing

## Screenshots

The app has 4 tabs:
- **EMG** - 8 EMG channel graphs
- **IMU** - Gyroscope, Accelerometer, and Angle graphs
- **FFT** - Spectrum analysis with frequency metrics
- **Stats** - Channel statistics and settings

## Building

### Prerequisites

- Flutter SDK 3.x
- Android SDK (for Android build)
- Xcode (for iOS build)

### Build APK

```bash
flutter pub get
flutter build apk --release
```

APK will be in `build/app/outputs/flutter-apk/app-release.apk`

### Build iOS

```bash
flutter pub get
flutter build ios --release
```

## Protocol

The app parses Sichiray binary protocol:
- Header: `AA AA 5F`
- IMU data: 9 bytes (gyro x/y/z, accel x/y/z, angles)
- EMG data: 80 bytes (8 channels × 10 samples)
- Battery: 1 byte
- Checksum: `0x55`

## BLE UUIDs

- Service: `0000ffe0-0000-1000-8000-00805f9b34fb`
- Data characteristic: `0000ffe2-0000-1000-8000-00805f9b34fb`
- Alternative: `0000ff03-0000-1000-8000-00805f9b34fb`

## License

MIT
