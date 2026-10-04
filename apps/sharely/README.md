# apps/sharely

The single Flutter app (phone + desktop), generated for Android, Windows and Linux.

```bash
flutter run -d linux        # or an Android device id; Windows builds need Windows
flutter test
```

`lib/` layout (planned folders are added as features land):

```
lib/
  main.dart
  app/            # app widget, routing, theme wiring
  design/         # design tokens (colors, type, spacing) — no hardcoded values elsewhere
  features/
    onboarding/   # 3-step first-run guide
    pairing/      # QR display (desktop) / QR scan (phone)
    transfer/     # send, incoming-offer prompt, progress
    history/      # transfer history list
    devices/      # paired devices list
  platform/       # mDNS (nsd), file pickers, share intent, tray/window, firewall hints
  state/          # Riverpod providers bridging sharely_core to the UI
```
