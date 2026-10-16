# VYTR

A personal iOS app for meal logging, workout tracking and local reminders.
Private build, not intended for the App Store.

## Why this repo layout

The app is written on Windows and compiled on a macOS GitHub Actions runner,
because Xcode only runs on macOS. There is no `.xcodeproj` in the repository:
it is generated from `project.yml` by XcodeGen during each build.

## Target device

iPhone 17 running iOS 27. Stage 1 builds on both the `xcode-27`
(iOS 27 SDK) and `macos-26` (iOS 26 SDK) runner images to confirm which
produces an installable IPA, then pins the one that works.

## Build chain

1. Push to `main` triggers `.github/workflows/ios-build.yml`
2. The macOS runner installs XcodeGen and generates `VYTR.xcodeproj`
3. `xcodebuild` compiles an unsigned `.app` for a real device
4. The `.app` is packaged into `VYTR-unsigned.ipa` and uploaded as an artifact
5. The IPA is signed and installed locally with Sideloadly using a free Apple ID

## Layout

| Path | Purpose |
|---|---|
| `project.yml` | Xcode project definition (edit this, not a `.xcodeproj`) |
| `VYTR/` | Swift sources |
| `.github/workflows/` | Cloud build definition |

## Secrets

No API keys, tokens or personal data belong in this repository.
Any key the app needs is entered on the device and stored in the iOS Keychain.
