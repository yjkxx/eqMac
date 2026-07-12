#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}
native_dir="$repo_root/native"
build_dir="$repo_root/build"
derived_data="$build_dir/DerivedData"
source_packages="$build_dir/SourcePackages"
products_dir="$build_dir/products"

xcode_app=${XCODE_APP:-/Applications/Xcode.app}
developer_dir=${DEVELOPER_DIR:-$xcode_app/Contents/Developer}

if [[ ! -x "$developer_dir/usr/bin/xcodebuild" ]]; then
  print -u2 "Full Xcode is required at $xcode_app"
  print -u2 "Install Xcode, or set XCODE_APP/DEVELOPER_DIR to its location."
  exit 2
fi

if ! command -v pod >/dev/null 2>&1; then
  print -u2 "CocoaPods is required. Install it with: brew install cocoapods"
  exit 2
fi

export DEVELOPER_DIR="$developer_dir"

cd "$native_dir"
pod install

mkdir -p "$derived_data" "$source_packages" "$products_dir"

xcodebuild \
  -resolvePackageDependencies \
  -workspace eqMac.xcworkspace \
  -scheme eqMac \
  -clonedSourcePackagesDirPath "$source_packages"

common_build_settings=(
  -workspace eqMac.xcworkspace
  -configuration Debug
  -derivedDataPath "$derived_data"
  -clonedSourcePackagesDirPath "$source_packages"
  -disableAutomaticPackageResolution
  ARCHS=arm64
  ONLY_ACTIVE_ARCH=YES
  MACOSX_DEPLOYMENT_TARGET=11.0
  CODE_SIGN_IDENTITY=-
  CODE_SIGN_STYLE=Manual
  DEVELOPMENT_TEAM=
  ENABLE_USER_SCRIPT_SANDBOXING=NO
)

xcodebuild "${common_build_settings[@]}" -scheme "Driver - Debug" build
xcodebuild "${common_build_settings[@]}" -scheme eqMac build

driver="$derived_data/Build/Products/Debug/eqMacDB.driver"
app="$derived_data/Build/Products/Debug/eqMac dB.app"

if [[ ! -d "$driver" || ! -d "$app" ]]; then
  print -u2 "Expected build products were not found."
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$driver"
codesign --verify --deep --strict --verbose=2 "$app"

ditto "$driver" "$products_dir/eqMacDB.driver"
ditto "$app" "$products_dir/eqMac dB.app"

print "Build complete:"
print "  $products_dir/eqMacDB.driver"
print "  $products_dir/eqMac dB.app"
