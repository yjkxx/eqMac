# eqMac dB local fork

This is a personal fork of the public eqMac 1.3.2 source. It changes media-key
volume control for fixed-output devices (USB DACs, HDMI, and similar outputs)
from linear amplitude increments to constant audible steps.

## Volume behavior

- Volume Up/Down: `1.00 dB` per press.
- Shift-Option-Volume Up/Down: `0.25 dB` per press.
- Audible range below unity: `-63 dB` through `0 dB`.
- One additional Volume Down press at `-63 dB` mutes.
- Volume Up while muted restores the remembered level; the next press raises it.
- eqMac's existing boost remains supported, with constant-dB steps up to its
  existing amplitude-6 ceiling (`+15.56 dB`).
- Devices with their own writable hardware-volume control retain eqMac's
  original scalar stepping because their manufacturer-defined dB curve is not
  exposed as a known software amplitude.

The forked driver rejects Control Center/SystemUIServer volume writes while the
forked app is running. This prevents macOS's scalar writes from racing and
overwriting an exact dB step. Media keys and the app UI work; the macOS Control
Center volume slider is read-only in practice until the app quits.

## Isolation and updates

The fork deliberately coexists with, and does not overwrite, an official eqMac
installation:

- App: `eqMac dB.app` (`com.local.eqmacdb`)
- Driver: `eqMacDB.driver` (`com.local.eqmacdb.driver`)
- Device UID: `EQMacDBDevice`
- Preferences and Application Support use the fork's bundle ID.

Sparkle, Sentry, automatic app updates, and remote UI updates are removed or
disabled. The bundled offline UI is always used. The unsafe upstream Xcode
scripts that deleted `/Library/Audio/Plug-Ins/HAL/eqMac.driver` were removed.
The legacy x86_64 LaunchAtLogin helper is also removed; launch-at-login is not
available in this arm64 build.

## Build

Requirements:

1. Full Xcode installed at `/Applications/Xcode.app`.
2. CocoaPods (`brew install cocoapods`).
3. Apple silicon Mac running macOS 11 or newer.

Run:

```sh
./scripts/build-local.sh
```

Products are copied to `build/products/` after their signatures verify.

The `Build eqMac dB` GitHub Actions workflow performs the same arm64 Debug
build with Xcode 26.3 and uploads a ZIP containing both products. It never
installs or loads the audio driver on the runner.

## Install and rollback

After a successful build:

```sh
./scripts/install-local.sh
```

The install script verifies both bundle IDs, installs only the fork-specific
app and driver, fixes HAL-driver ownership, and restarts Core Audio. Any prior
fork build is moved to a timestamped backup instead of being deleted.

To remove only the fork and leave official eqMac untouched:

```sh
./scripts/uninstall-local.sh
```

The uninstall script moves the fork app and driver to a timestamped backup and
restarts Core Audio; it does not delete either official or fork files.

## Verification

The constant-dB implementation has both XCTest coverage and a standalone check
that works with Apple's Command Line Tools:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/eqmac-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/eqmac-swiftpm-cache \
swift run --package-path native/shared \
  --scratch-path /tmp/eqmac-shared-build StepperCheck
```

The standalone check covers normal/fine steps, the -63 dB boundary, mute and
restore behavior, boost mapping, and the driver's reserved mute scalar.
