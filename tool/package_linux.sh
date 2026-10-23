#!/usr/bin/env bash
# Packages a built Linux release as a .tar.gz and a .deb.
#
# Usage: tool/package_linux.sh <version> <output-dir>
# Run `flutter build linux --release` in apps/sharely first.
set -euo pipefail

version="${1:?version, such as 0.1.0 or v0.1.0}"
output_dir="$(mkdir -p "${2:?output directory}" && cd "$2" && pwd)"
# Debian versions must start with a digit, so a tag's leading "v" goes.
deb_version="${version#v}"
if [[ ! "$deb_version" =~ ^[0-9] ]]; then
  echo "Version must start with a digit, got: $version" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$repo_root/apps/sharely"
bundle="$app_dir/build/linux/x64/release/bundle"
packaging="$app_dir/linux/packaging"
app_id="com.sharely.sharely"

if [[ ! -x "$bundle/sharely" ]]; then
  echo "No release bundle at $bundle; build it first." >&2
  exit 1
fi

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

# The portable archive: unpack anywhere and run ./sharely.
archive_root="$staging/sharely-$deb_version-linux-x64"
cp -r "$bundle" "$archive_root"
install -m 644 "$packaging/$app_id.desktop" "$packaging/$app_id.svg" "$archive_root/"
tar -C "$staging" -czf "$output_dir/sharely-$version-linux-x64.tar.gz" \
  "$(basename "$archive_root")"

# The .deb: the app under /opt, a launcher on PATH, and a menu entry.
deb_root="$staging/deb"
install -d "$deb_root/DEBIAN" "$deb_root/opt" "$deb_root/usr/bin"
cp -r "$bundle" "$deb_root/opt/sharely"
ln -s ../../opt/sharely/sharely "$deb_root/usr/bin/sharely"
install -D -m 644 "$packaging/$app_id.desktop" \
  "$deb_root/usr/share/applications/$app_id.desktop"
install -D -m 644 "$packaging/$app_id.svg" \
  "$deb_root/usr/share/icons/hicolor/scalable/apps/$app_id.svg"

# Packages must not carry the build machine's group-writable folders.
chmod -R u=rwX,go=rX "$deb_root"

installed_kb="$(du -sk "$deb_root/opt" | cut -f1)"
cat > "$deb_root/DEBIAN/control" <<CONTROL
Package: sharely
Version: $deb_version
Section: net
Priority: optional
Architecture: amd64
Installed-Size: $installed_kb
Depends: libc6 (>= 2.35), libgtk-3-0, libsecret-1-0, libstdc++6
Recommends: gnome-keyring
Maintainer: SatyamChy03 <SatyamChy03@users.noreply.github.com>
Homepage: https://github.com/SatyamChy03/Sharely
Description: Send files between your phone and laptop over Wi-Fi
 Sharely sends files, text and links between a phone and a laptop on the
 same local network. No accounts, no cloud and no ads.
CONTROL

dpkg-deb --build --root-owner-group "$deb_root" \
  "$output_dir/sharely-$version-linux-amd64.deb" > /dev/null

echo "Wrote:"
ls -1 "$output_dir"/sharely-"$version"-linux-*
