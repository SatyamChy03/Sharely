# Security

## Reporting a vulnerability

Please report security problems privately, not in a public issue: open the
repository's **Security** tab and choose **Report a vulnerability**. Include
the app version, the platform, and the steps to reproduce.

You can expect a first reply within a week. A confirmed problem is fixed on a
private branch, released, and then described in the release notes with credit
to the reporter if they want it.

## How Sharely protects a transfer

- **No server in the middle.** Files go from one device to the other over the
  local network. There are no accounts and no cloud.
- **Pairing.** The laptop shows a QR code holding a one-time token and the
  fingerprint of its TLS certificate. The token is random (128 bits), works
  once, and expires after five minutes. The 6-digit code is the fallback; it
  locks after five wrong guesses.
- **Encryption.** Every connection is TLS. The phone accepts only the
  certificate whose fingerprint it learnt at pairing, so another device on
  the same Wi-Fi can neither read a transfer nor answer in the laptop's
  place.
- **Authentication.** Every request carries a 256-bit token issued at
  pairing. Unpaired devices get no data. Removing a device under Devices
  revokes its token at once.
- **Consent.** The receiver sees the sender, file names and sizes and must
  accept, unless "always accept" was turned on for that one device. Offers
  over 4 GB always ask.
- **Files.** Incoming names are reduced to a plain file name inside the save
  folder, existing files are never overwritten, sizes are enforced while
  receiving, and a checksum is verified before a file counts as received.
  Nothing received is opened or run automatically.
- **Links and text.** Only `http` and `https` links are accepted. They are
  shown as text and open only when tapped. Received text is kept in memory
  only.
- **Storage.** Tokens and the laptop's private key live in the platform's
  secure storage (Android Keystore, Windows Credential Manager, libsecret).

## Known limits

- **Typed 6-digit code.** The QR code proves which laptop the phone talks
  to; the typed code does not. An attacker who is already on the same Wi-Fi
  and answers as a laptop during the five minutes a code is on screen could
  place themselves between the two devices. Prefer the QR code on networks
  you do not control.
- **Trusted devices.** A paired device that is itself compromised can offer
  files and send text, within the limits above. Remove devices you no longer
  use.
- **Received files are not scanned.** Treat a file from a device you do not
  control like any other download.
- **Pre-release builds** are signed with a debug key and are not yet
  code-signed for Windows. Check downloads against `SHA256SUMS.txt` in the
  release.
