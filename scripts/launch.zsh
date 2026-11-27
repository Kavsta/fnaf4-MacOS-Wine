#!/bin/zsh
set -eu

repo_root=${0:A:h:h}
support_dir="$HOME/Library/Application Support/FNAF4-Wine"
config_file="$support_dir/config.zsh"
if [[ -f "$config_file" ]]; then
    source "$config_file"
fi

case "${1:-standard}" in
    standard) executable='FiveNightsatFreddys4.exe'; edition=standard ;;
    halloween) executable='FiveNightsatFreddys4 HalloweenEdition.exe'; edition=halloween ;;
    *) print -u2 'Choose standard or halloween.'; exit 2 ;;
esac

game_dir=${FNAF4_GAME_DIR:-}
if [[ -z "$game_dir" || ! -d "$game_dir" ]]; then
    print -u2 "Set FNAF4_GAME_DIR in $config_file to the folder containing your game files."
    exit 1
fi

wine_bin=${FNAF4_WINE_BIN:-}
if [[ -z "$wine_bin" ]]; then
    wine_bin=$(whence -p wine64 || whence -p wine || true)
fi
if [[ -z "$wine_bin" || ! -x "$wine_bin" ]]; then
    print -u2 "Set FNAF4_WINE_BIN in $config_file to your Wine executable."
    exit 1
fi
if [[ ! -f "$game_dir/$executable" ]]; then
    print -u2 "Could not find $executable in $game_dir"
    exit 1
fi

for helper in display-scaler.dylib audio-buffer.dylib window-frame.exe; do
    if [[ ! -f "$repo_root/build/$helper" ]]; then
        print -u2 "Build helpers first with $repo_root/scripts/build.zsh"
        exit 1
    fi
done

mkdir -p "$support_dir"
wine_prefix=${FNAF4_WINE_PREFIX:-${WINEPREFIX:-"$support_dir/prefix"}}
audio_engine=${FNAF4_AUDIO_ENGINE:-wine}
audio_buffer=${FNAF4_AUDIO_BUFFER:-short}
wine_overrides='mscoree,mshtml='

case "$audio_buffer" in
    short|off) ;;
    *) print -u2 'FNAF4_AUDIO_BUFFER must be short or off.'; exit 2 ;;
esac

case "$audio_engine" in
    wine) ;;
    openal)
        if [[ ! -f "$game_dir/dsound.dll" || ! -f "$game_dir/dsoal-aldrv.dll" ]]; then
            print -u2 'OpenAL mode requires dsound.dll and dsoal-aldrv.dll beside the game executable.'
            exit 1
        fi
        wine_overrides='dsound=n,b;mscoree,mshtml='
        if [[ -f "$game_dir/alsoft.ini" ]]; then
            export ALSOFT_CONF="Z:$game_dir/alsoft.ini"
        fi
        export ALSOFT_LOGLEVEL=${ALSOFT_LOGLEVEL:-1} DSOAL_LOGLEVEL=${DSOAL_LOGLEVEL:-1}
        ;;
    *) print -u2 'FNAF4_AUDIO_ENGINE must be wine or openal.'; exit 2 ;;
esac

if [[ ! -x "$repo_root/build/display-scaler.dylib" || ! -x "$repo_root/build/audio-buffer.dylib" ]]; then
    print -u2 'The macOS helpers are not executable. Rebuild them with scripts/build.zsh.'
    exit 1
fi

export WINEPREFIX="$wine_prefix"
export WINEDEBUG="${FNAF4_WINE_DEBUG:-fixme-all,warn+dsound,warn+coreaudio}"
export WINEDLLOVERRIDES="$wine_overrides"
if [[ -n "${FNAF4_WINE_LIBRARY_PATH:-}" ]]; then
    export DYLD_FALLBACK_LIBRARY_PATH="$FNAF4_WINE_LIBRARY_PATH${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"
fi
export FNAF4_DISPLAY_SCALER=1
export FNAF4_DISPLAY_PREFS="$support_dir/display-mode"
export FNAF4_AUDIO_BUFFER="$audio_buffer"
insert_libraries="$repo_root/build/display-scaler.dylib"
if [[ "$audio_buffer" == short ]]; then
    insert_libraries="$repo_root/build/audio-buffer.dylib:$insert_libraries"
fi
export DYLD_INSERT_LIBRARIES="$insert_libraries${DYLD_INSERT_LIBRARIES:+:$DYLD_INSERT_LIBRARIES}"

log="$support_dir/$edition-launch.log"
window_log="$support_dir/$edition-window.log"
cd "$game_dir"
"$wine_bin" "$game_dir/$executable" /NOF > "$log" 2>&1 &
game_pid=$!
"$wine_bin" "$repo_root/build/window-frame.exe" "$executable" > "$window_log" 2>&1 &
frame_pid=$!

result=0
wait "$game_pid" || result=$?
kill "$frame_pid" 2>/dev/null || true
wait "$frame_pid" 2>/dev/null || true
print -r -- "Wine exit status: $result" >> "$log"
if (( result != 0 )); then
    print -u2 "Wine exited with status $result. Log: $log"
fi
exit "$result"
