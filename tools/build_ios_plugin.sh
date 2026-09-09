#!/usr/bin/env bash
# Build the game's native iOS plugins (device arm64 + simulator arm64/x86_64)
# against a Godot source checkout of the version the export templates use. Each
# plugin is plain Objective-C++ that links against the engine symbols already
# inside the export template, so only headers are needed.
#
#   GODOT_SRC=/path/to/godot-4.7.2 tools/build_ios_plugin.sh            # all plugins
#   GODOT_SRC=/path/to/godot-4.7.2 tools/build_ios_plugin.sh apple_signin
#
# The source tree must have been built once for iOS (any target) so its
# generated headers (*.gen.h) exist.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${GODOT_SRC:-$(cd .. && pwd)/godot-4.7.2}"
PLUGINS=("${@:-apple_signin game_center}")
read -r -a PLUGINS <<< "${PLUGINS[*]}"
DEV_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
CLANG=$(xcrun --find clang++)
DEFINES="-DIOS_ENABLED -DAPPLE_EMBEDDED_ENABLED -DUNIX_ENABLED -DCOREAUDIO_ENABLED -DMETAL_ENABLED -DRD_ENABLED -DGLES3_ENABLED -DGLES_SILENCE_DEPRECATION -DSDL_ENABLED -D_LIBCPP_REMOVE_TRANSITIVE_INCLUDES -DMINIZIP_ENABLED -DBROTLI_ENABLED -DOVERRIDE_ENABLED -DTHREADS_ENABLED -DCLIPPER2_ENABLED -DZSTD_STATIC_LINKING_ONLY -DGODOT_MODULE"
FLAGS="-std=gnu++17 -fno-exceptions -ffp-contract=off -fobjc-arc -fpascal-strings -fblocks -fvisibility=hidden -O3 -w -Wno-ambiguous-macro -Wno-module-import-in-extern-c -I$SRC -I$SRC/platform/ios -I$SRC/thirdparty/zstd -I$SRC/thirdparty/zlib -I$SRC/thirdparty/libpng -I$SRC/thirdparty/brotli/include -I$SRC/thirdparty/clipper2/include -I$SRC/thirdparty/metal-cpp -I$SRC/thirdparty/spirv-cross"
# The debug and release export templates differ in one ABI detail: with
# DEBUG_ENABLED (template_debug) ClassDB::bind_method takes a MethodDefinition,
# without it a const char*. So each plugin is built twice and its .gdip names
# the pair (<name>.debug/.release.xcframework); Godot picks one per export.
for plugin in "${PLUGINS[@]}"; do
  DIR="ios/plugins/$plugin"
  OUT="$DIR/build"
  SRC_MM="$DIR/src/$plugin.mm"
  test -f "$SRC_MM" || { echo "no source at $SRC_MM"; exit 1; }
  rm -rf "$OUT" "$DIR/$plugin".*.xcframework
  mkdir -p "$OUT"
  for variant in debug release; do
    defs="$DEFINES -DNDEBUG"
    [[ "$variant" == "debug" ]] && defs="$DEFINES -DDEBUG_ENABLED"
    for slice in "device_arm64 $DEV_SDK arm64-apple-ios14.0" "sim_arm64 $SIM_SDK arm64-apple-ios14.0-simulator" "sim_x86_64 $SIM_SDK x86_64-apple-ios14.0-simulator"; do
      set -- $slice
      echo "== $plugin $variant $1"
      "$CLANG" -c $FLAGS $defs -target "$3" -isysroot "$2" -miphoneos-version-min=14.0 "$SRC_MM" -o "$OUT/$plugin.$variant.$1.o"
      libtool -static -o "$OUT/lib$plugin.$variant.$1.a" "$OUT/$plugin.$variant.$1.o"
    done
    lipo -create "$OUT/lib$plugin.$variant.sim_arm64.a" "$OUT/lib$plugin.$variant.sim_x86_64.a" -output "$OUT/lib$plugin.$variant.sim.a"
    xcodebuild -create-xcframework -library "$OUT/lib$plugin.$variant.device_arm64.a" -library "$OUT/lib$plugin.$variant.sim.a" -output "$DIR/$plugin.$variant.xcframework" >/dev/null
    echo "== built $DIR/$plugin.$variant.xcframework"
  done
done
ls -d ios/plugins/*/*.xcframework
