#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}
products_dir=${1:-$repo_root/build/products}
source_driver="$products_dir/eqMacDB.driver"
source_app="$products_dir/eqMac dB.app"
target_driver="/Library/Audio/Plug-Ins/HAL/eqMacDB.driver"
target_app="/Applications/eqMac dB.app"

if [[ ! -d "$source_driver" || ! -d "$source_app" ]]; then
  print -u2 "Missing build products in: $products_dir"
  print -u2 "Run scripts/build-local.sh first."
  exit 2
fi

driver_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$source_driver/Contents/Info.plist")
app_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$source_app/Contents/Info.plist")

if [[ "$driver_id" != "com.local.eqmacdb.driver" || "$app_id" != "com.local.eqmacdb" ]]; then
  print -u2 "Refusing to install products with unexpected bundle IDs."
  exit 3
fi

codesign --verify --deep --strict --verbose=2 "$source_driver"
codesign --verify --deep --strict --verbose=2 "$source_app"

if (( EUID != 0 )); then
  exec sudo "$0" "$products_dir"
fi

owner=${SUDO_USER:-$(stat -f '%Su' /dev/console)}
owner_home=$(dscl . -read "/Users/$owner" NFSHomeDirectory 2>/dev/null | awk '{print $2}' || true)
owner_home=${owner_home:-/Users/$owner}
owner_group=$(id -gn "$owner")
backup_root="$owner_home/Library/Application Support/eqMac dB/Backups/$(date +%Y%m%d-%H%M%S)"
install -d -m 755 "$backup_root"

osascript -e 'tell application id "com.local.eqmacdb" to quit' >/dev/null 2>&1 || true
sleep 2

if [[ -d "$target_driver" ]]; then
  mv "$target_driver" "$backup_root/eqMacDB.driver"
fi
if [[ -d "$target_app" ]]; then
  mv "$target_app" "$backup_root/eqMac dB.app"
fi

ditto "$source_driver" "$target_driver"
chown -R root:wheel "$target_driver"
chmod -R go-w "$target_driver"

ditto "$source_app" "$target_app"
chown -R root:wheel "$target_app"

codesign --verify --deep --strict --verbose=2 "$target_driver"
codesign --verify --deep --strict --verbose=2 "$target_app"
chown -R "$owner:$owner_group" "$backup_root"

/usr/bin/killall -9 coreaudiod || true

print "Installed eqMac dB without changing the official eqMac app or driver."
print "Previous fork files, if any, were moved to: $backup_root"
print "Core Audio was asked to restart. Reboot if the new driver does not appear."
print "Open /Applications/eqMac dB.app to test it."
