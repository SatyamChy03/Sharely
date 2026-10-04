# Sharely

Send files, photos, text, links and clipboard content between your phone and laptop over your local Wi-Fi. No ads, no accounts, no cloud.

**Install, scan, send:** the laptop shows a QR code, the phone scans it, and the two devices stay paired.

> **Status:** early development. The app foundation and the Welcome screen are in place; file transfer is next.

## Platforms

| Stage | Platforms |
|---|---|
| MVP | Android 8+, Windows 10+ |
| Beta | iOS 15+, macOS 12+ |
| Later | Linux |

## How it works

- The **laptop app runs a small local server**. The phone connects to it, and there is no central backend.
- **Pairing:** the laptop shows a QR code containing its address, a one-time token, and its certificate fingerprint. After pairing, each device remembers the other.
- **Control channel:** a WebSocket carrying small JSON messages (`hello`, `offer`, `accept`, `reject`, `progress`, `cancel`, `text`, `link`, `clipboard`).
- **File data:** streamed over HTTP(S) in chunks (`GET/PUT /transfer/{transferId}/{fileIndex}`). `Range` headers let interrupted transfers resume, and a checksum is verified on completion.
- **Security:** only paired devices can talk to each other. Every request carries a pairing token, and traffic is encrypted with TLS using a self-signed certificate pinned at pairing (from v1).
- **Discovery:** mDNS finds paired devices automatically (from v1). The QR code is always available as a fallback.

## Tech stack

Flutter/Dart for every platform in a [Melos](https://melos.invertase.dev) monorepo using Dart pub workspaces.

## Repository layout

```
.
├── apps/
│   └── sharely/            # Flutter app for phone and desktop (UI + platform glue)
├── packages/
│   └── core/               # sharely_core: pure Dart, no Flutter imports
│       ├── lib/src/
│       │   ├── protocol/   # message types and serialization (shared by both sides)
│       │   ├── transfer/   # chunked streaming, resume, checksums, progress
│       │   ├── pairing/    # QR payload, tokens, paired-device identity
│       │   ├── server/     # embedded shelf HTTP + WebSocket server (desktop)
│       │   └── security/   # certificate generation and fingerprint pinning
│       └── test/
├── pubspec.yaml            # workspace root + Melos scripts
└── analysis_options.yaml
```

Business logic lives in `packages/core`, so it can be unit-tested without a device. `apps/sharely` holds the UI and platform-specific code: mDNS, file pickers, share sheet, tray, and window.

## Getting started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK 3.6+)
- Android SDK, or Android Studio, for Android builds
- A Windows machine for Windows builds, because Flutter cannot cross-compile Windows apps from Linux or macOS
- Melos: `dart pub global activate melos`

Run `flutter doctor` to check your setup.

### Setup

```bash
dart pub get          # resolves all workspace packages
```


### Common commands

```bash
melos run analyze     # static analysis across the workspace
melos run format      # format all Dart code
melos run test:core   # run sharely_core unit tests

# single test file / single test by name
cd packages/core && dart test test/<file>_test.dart
cd packages/core && dart test --name "<test name>"

# run the app
cd apps/sharely && flutter run -d linux     # or -d windows / an Android device id
cd apps/sharely && flutter test             # app widget tests
```

## Roadmap

| Stage | Scope |
|---|---|
| **MVP** | QR pairing, two-way file transfer, accept/reject, text and links, history, token auth |
| **v1** | mDNS discovery, guided onboarding, folders and multi-file queues, resume, pinned TLS |
| **v1.5** | Share-sheet sending, desktop tray and drag-and-drop, shared clipboard |
| **Beta** | iOS and macOS, real-device testing, 10–20 beta users |
| **v2** | Hotspot mode (no router), photo auto-backup, gallery browser, internet transfer |

## Principles

- No accounts, no cloud, no ads, no analytics on file contents.
- Files are streamed from disk and never loaded fully into memory.
- The receiver always accepts or rejects incoming files.
- Errors are explained in plain language, each with one suggested fix.
