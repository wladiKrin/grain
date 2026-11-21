# Grain

Grain is an open-source film lightmeter for Android (iOS to follow). It helps
film photographers read exposure with their phone and set aperture, shutter
speed and ISO. It is free software with no proprietary dependencies and no
network access.

## Toolchain

Install JDK 17, the Flutter stable SDK
(<https://docs.flutter.dev/get-started/install>) and the Android SDK
(command-line tools, platform-tools, a current platform and build-tools), then
accept licences with `flutter doctor --android-licenses` and check
`flutter doctor`.

On the maintainer's machine, `source ~/.grain-env.sh` sets up the user-space
toolchain (JDK 17, Android SDK, Flutter at `~/flutter`).

## Run and test

```
flutter run
flutter test
```

## Install from APK

```
flutter build apk --release --split-per-abi
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Licence

GPLv3, see [LICENSE](LICENSE). The bundled Inter Tight font is licensed under
the SIL Open Font License, see `assets/fonts/OFL.txt`.
