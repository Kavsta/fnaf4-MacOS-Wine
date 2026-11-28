#!/bin/zsh
set -eu

repo_root=${0:A:h:h}
build_dir="$repo_root/build"
mkdir -p "$build_dir"

xcrun clang -arch x86_64 -fobjc-arc -dynamiclib -O2 -Wall -Wextra -Werror \
    -framework AppKit -framework QuartzCore -framework CoreGraphics -framework GameController \
    "$repo_root/src/display-scaler.m" "$repo_root/src/controller-input.m" \
    -o "$build_dir/display-scaler.dylib"

xcrun clang -arch x86_64 -dynamiclib -O2 -Wall -Wextra -Werror \
    -framework AudioToolbox -framework CoreAudio \
    "$repo_root/src/audio-buffer.c" -o "$build_dir/audio-buffer.dylib"

mingw_cc=${MINGW_CC:-x86_64-w64-mingw32-gcc}
if ! command -v "$mingw_cc" >/dev/null 2>&1; then
    print -u2 "Missing $mingw_cc. Install the Windows cross-compiler with: brew install mingw-w64"
    exit 1
fi

"$mingw_cc" -municode -std=c11 -O2 -Wall -Wextra \
    "$repo_root/src/window-frame.c" -o "$build_dir/window-frame.exe" -luser32

print "Built compatibility helpers in $build_dir"
