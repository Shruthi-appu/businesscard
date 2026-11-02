# Softxu iPhone app

Flutter app for iPhone: register, sign in, and a wallet of saved card titles. On iPhone the screens use the iOS interface. The same project still runs the Material interface on Android. Tokens stay in the iOS keychain through `flutter_secure_storage`.

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
