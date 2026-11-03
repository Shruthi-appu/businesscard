# Softxu phone app

Flutter app for Android and iPhone. A person can register, sign in, and open the IncardIt wallet. Android uses the Material interface. iPhone uses the iOS interface. On both, cards wait in the red pocket, **Open wallet** deals the fan, and Add, Scan, and Design sit on one header row. Tokens stay in secure storage through `flutter_secure_storage`.

## Android

The Android target is portrait-only, application id `technology.softxu.softxu`. Debug builds allow cleartext HTTP to the API. A release build expects HTTPS. Card links can open the browser, Google Maps, WhatsApp, the phone app, and email. The system back button closes the account menu before it leaves a screen.

Run this from the repository root, the folder that contains `apps`. On a Mac that already has the iPhone simulator open, check out this branch first. `flutter run -d android` installs only after `flutter devices` lists an Android emulator or a phone. The iPhone simulator, macOS, and Chrome do not satisfy that.

```bash
cd "$(git rev-parse --show-toplevel)"
git fetch origin
git checkout cursor/android-app-1b55
git pull origin cursor/android-app-1b55
cd apps/mobile
flutter pub get
flutter doctor
flutter emulators
```

When `flutter emulators` prints an emulator name, start it and wait until `flutter devices` shows an `android` row. Then run:

```bash
# Emulator. 10.0.2.2 is the computer running the API.
flutter run -d android --dart-define=API_ORIGIN=http://10.0.2.2:3001

# A physical phone, with USB debugging on. Use the computer's LAN address.
flutter run -d android --dart-define=API_ORIGIN=http://192.168.1.10:3001
```

If `flutter emulators` prints nothing, install Android Studio, open Device Manager, and create a phone with an arm64 system image. Start that device, then run the `flutter run` command above. `flutter doctor` names the Android toolchain when it is still missing.

## iPhone

This repository was built on Linux, which cannot compile or install an iPhone app. Open the project on a Mac with Xcode and run:

```bash
cd apps/mobile
flutter pub get
open ios/Runner.xcworkspace
```

In Xcode, pick your Apple team under Signing & Capabilities. Then:

```bash
# Simulator. localhost is the Mac running the API.
flutter run -d ios --dart-define=API_ORIGIN=http://localhost:3001

# A physical iPhone. Use the Mac's LAN address, not localhost.
flutter run -d ios --dart-define=API_ORIGIN=http://192.168.1.10:3001
```

The iPhone target is portrait-only, bundle id `technology.softxu.softxu`, and iOS 15 or newer. Debug builds allow local HTTP. A release build expects HTTPS.

On iPhone the wallet matches the web phases: add a card, read the mock sample scan, design and publish a public card, open a card to edit it, favourite it, tag it, share a link, and show an exchange QR. Account export copies the JSON, and deletion asks for confirmation before signing out. The scan uses the mock reader, so it reads a sample card instead of the camera.
