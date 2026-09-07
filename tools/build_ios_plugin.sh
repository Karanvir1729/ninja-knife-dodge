#!/usr/bin/env bash
# Build ios/plugins/apple_signin/apple_signin.xcframework (device arm64 + simulator
# arm64/x86_64) against a Godot source checkout of the version the export
# templates use. The plugin is plain Objective-C++ that links against the engine
# symbols already inside the export template, so only headers are needed.
#
#   GODOT_SRC=/path/to/godot-4.7.2 tools/build_ios_plugin.sh
#
# The source tree must have been built once for iOS (any target) so its
# generated headers (*.gen.h) exist.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${GODOT_SRC:-$(cd .. && pwd)/godot-4.7.2}"
PLUGIN=ios/plugins/apple_signin
OUT="$PLUGIN/build"
rm -rf "$OUT" "$PLUGIN"/apple_signin.*.xcframework
mkdir -p "$OUT"
DEV_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
CLANG=$(xcrun --find clang++)
DEFINES="-DIOS_ENABLED -DAPPLE_EMBEDDED_ENABLED -DUNIX_ENABLED -DCOREAUDIO_ENABLED -DMETAL_ENABLED -DRD_ENABLED -DGLES3_ENABLED -DGLES_SILENCE_DEPRECATION -DSDL_ENABLED -D_LIBCPP_REMOVE_TRANSITIVE_INCLUDES -DMINIZIP_ENABLED -DBROTLI_ENABLED -DOVERRIDE_ENABLED -DTHREADS_ENABLED -DCLIPPER2_ENABLED -DZSTD_STATIC_LINKING_ONLY -DGODOT_MODULE"
FLAGS="-std=gnu++17 -fno-exceptions -ffp-contract=off -fobjc-arc -fpascal-strings -fblocks -fvisibility=hidden -O3 -w -Wno-ambiguous-macro -Wno-module-import-in-extern-c -I$SRC -I$SRC/platform/ios -I$SRC/thirdparty/zstd -I$SRC/thirdparty/zlib -I$SRC/thirdparty/libpng -I$SRC/thirdparty/brotli/include -I$SRC/thirdparty/clipper2/include -I$SRC/thirdparty/metal-cpp -I$SRC/thirdparty/spirv-cross"
SRC_MM="$PLUGIN/src/apple_signin.mm"
# The debug and release export templates differ in one ABI detail: with
# DEBUG_ENABLED (template_debug) ClassDB::bind_method takes a MethodDefinition,
# without it a const char*. So the plugin is built twice, and the .gdip names
# the pair (apple_signin.debug/.release.xcframework); Godot picks per export.
build() { # variant name sdk target
  local variant=$1 name=$2 sdk=$3 target=$4
  local defs="$DEFINES -DNDEBUG"
  [[ "$variant" == "debug" ]] && defs="$DEFINES -DDEBUG_ENABLED"
  echo "== $variant $name"
  "$CLANG" -c $FLAGS $defs -target "$target" -isysroot "$sdk" -miphoneos-version-min=14.0 "$SRC_MM" -o "$OUT/apple_signin.$variant.$name.o"
  libtool -static -o "$OUT/libapple_signin.$variant.$name.a" "$OUT/apple_signin.$variant.$name.o"
}
for variant in debug release; do
  build $variant device_arm64 "$DEV_SDK" arm64-apple-ios14.0
  build $variant sim_arm64 "$SIM_SDK" arm64-apple-ios14.0-simulator
  build $variant sim_x86_64 "$SIM_SDK" x86_64-apple-ios14.0-simulator
  lipo -create "$OUT/libapple_signin.$variant.sim_arm64.a" "$OUT/libapple_signin.$variant.sim_x86_64.a" -output "$OUT/libapple_signin.$variant.sim.a"
  xcodebuild -create-xcframework -library "$OUT/libapple_signin.$variant.device_arm64.a" -library "$OUT/libapple_signin.$variant.sim.a" -output "$PLUGIN/apple_signin.$variant.xcframework" >/dev/null
  echo "== built $PLUGIN/apple_signin.$variant.xcframework"
done
ls -d "$PLUGIN"/apple_signin.*.xcframework
