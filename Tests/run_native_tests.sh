#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ "$(uname -s)" != Darwin ]; then
    printf '%s\n' 'NativeTests require macOS + Xcode and an already booted iOS simulator.' >&2
    exit 2
fi
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
arch=$(uname -m)
out=${TMPDIR:-/tmp}/keyboardtoolbarai-native-tests
mkdir -p "$out"
xcrun --sdk iphonesimulator clang -target "$arch-apple-ios15.0-simulator" -isysroot "$sdk" \
    -fobjc-arc -fblocks -Wall -Wextra -Wno-unused-parameter -I./Sources \
    Tests/NativeTests.m Sources/HaogeKeyboardToolbarAIModel.m Sources/HaogeKeyboardToolbarAINetwork.m \
    -framework Foundation -framework UIKit -framework QuartzCore -o "$out/native-tests"
xcrun simctl spawn booted "$out/native-tests"
