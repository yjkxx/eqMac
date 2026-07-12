#!/bin/zsh
set -euo pipefail

target_driver="/Library/Audio/Plug-Ins/HAL/eqMacDB.driver"
target_app="/Applications/eqMac dB.app"

if (( EUID != 0 )); then
  exec sudo "$0"
fi

owner=${SUDO_USER:-$(stat -f '%Su' /dev/console)}
owner_home=$(dscl . -read "/Users/$owner" NFSHomeDirectory 2>/dev/null | awk '{print $2}' || true)
owner_home=${owner_home:-/Users/$owner}
owner_group=$(id -gn "$owner")
backup_root="$owner_home/Library/Application Support/eqMac dB/Removed/$(date +%Y%m%d-%H%M%S)"
install -d -m 755 "$backup_root"

osascript -e 'tell application id "com.local.eqmacdb" to quit' >/dev/null 2>&1 || true
sleep 2

if [[ -d "$target_driver" ]]; then
  mv "$target_driver" "$backup_root/eqMacDB.driver"
fi
if [[ -d "$target_app" ]]; then
  mv "$target_app" "$backup_root/eqMac dB.app"
fi

chown -R "$owner:$owner_group" "$backup_root"
/usr/bin/killall -9 coreaudiod || true

print "Removed only the eqMac dB fork. Files were moved to: $backup_root"
print "Core Audio was asked to restart. Reboot if the device list does not refresh."
print "The official eqMac installation was not changed."
