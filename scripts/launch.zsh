#!/bin/zsh
set -eu

repo_root=${0:A:h:h}
support_dir="$HOME/Library/Application Support/FNAF4-Wine"
config_file="$support_dir/config.zsh"
if [[ -f "$config_file" ]]; then
    source "$config_file"
fi

d3d_config=''
d3d9_dll=''

case "${1:-standard}" in
    fnaf1)
        executable='FiveNightsatFreddys.exe'
        edition=fnaf1
        game_dir=${FNAF1_GAME_DIR:-}
        wine_bin=${FNAF1_WINE_BIN:-${FNAF4_WINE_BIN:-}}
        wine_prefix=${FNAF1_WINE_PREFIX:-"$support_dir/fnaf1-prefix"}
        audio_engine=${FNAF1_AUDIO_ENGINE:-wine}
        audio_buffer=${FNAF1_AUDIO_BUFFER:-off}
        display_prefs=${FNAF1_DISPLAY_PREFS:-"$support_dir/fnaf1-display-mode"}
        wine_debug=${FNAF1_WINE_DEBUG:-${FNAF4_WINE_DEBUG:-fixme-all,warn+dsound,warn+coreaudio}}
        display_width=1280
        display_height=720
        minimum_width=${FNAF1_MIN_WINDOW_WIDTH:-1280}
        minimum_height=${FNAF1_MIN_WINDOW_HEIGHT:-720}
        ;;
    standard)
        executable='FiveNightsatFreddys4.exe'
        edition=standard
        game_dir=${FNAF4_GAME_DIR:-}
        wine_bin=${FNAF4_WINE_BIN:-}
        wine_prefix=${FNAF4_WINE_PREFIX:-${WINEPREFIX:-"$support_dir/prefix"}}
        audio_engine=${FNAF4_AUDIO_ENGINE:-wine}
        audio_buffer=${FNAF4_AUDIO_BUFFER:-short}
        display_prefs=${FNAF4_DISPLAY_PREFS:-"$support_dir/display-mode"}
        wine_debug=${FNAF4_WINE_DEBUG:-fixme-all,warn+dsound,warn+coreaudio}
        ;;
    halloween)
        executable='FiveNightsatFreddys4 HalloweenEdition.exe'
        edition=halloween
        game_dir=${FNAF4_GAME_DIR:-}
        wine_bin=${FNAF4_WINE_BIN:-}
        wine_prefix=${FNAF4_WINE_PREFIX:-${WINEPREFIX:-"$support_dir/prefix"}}
        audio_engine=${FNAF4_AUDIO_ENGINE:-wine}
        audio_buffer=${FNAF4_AUDIO_BUFFER:-short}
        display_prefs=${FNAF4_DISPLAY_PREFS:-"$support_dir/display-mode"}
        wine_debug=${FNAF4_WINE_DEBUG:-fixme-all,warn+dsound,warn+coreaudio}
        ;;
    fnaf3)
        executable='FiveNightsatFreddys3.exe'
        edition=fnaf3
        game_dir=${FNAF3_GAME_DIR:-}
        wine_bin=${FNAF3_WINE_BIN:-${FNAF4_WINE_BIN:-}}
        wine_prefix=${FNAF3_WINE_PREFIX:-"$support_dir/fnaf3-prefix"}
        audio_engine=${FNAF3_AUDIO_ENGINE:-wine}
        audio_buffer=${FNAF3_AUDIO_BUFFER:-off}
        display_prefs=${FNAF3_DISPLAY_PREFS:-"$support_dir/fnaf3-display-mode"}
        wine_debug=${FNAF3_WINE_DEBUG:-${FNAF4_WINE_DEBUG:-fixme-all,warn+dsound,warn+coreaudio}}
        ;;
    ucn)
        executable='Ultimate Custom Night.exe'
        edition=ucn
        game_dir=${UCN_GAME_DIR:-}
        wine_bin=${UCN_WINE_BIN:-${FNAF4_WINE_BIN:-}}
        wine_prefix=${UCN_WINE_PREFIX:-"$support_dir/ucn-prefix"}
        audio_engine=${UCN_AUDIO_ENGINE:-wine}
        audio_buffer=${UCN_AUDIO_BUFFER:-off}
        display_prefs=${UCN_DISPLAY_PREFS:-"$support_dir/ucn-display-mode"}
        wine_debug=${UCN_WINE_DEBUG:-fixme-all,warn+dsound,warn+coreaudio}
        display_width=1920
        display_height=1080
        minimum_width=${UCN_MIN_WINDOW_WIDTH:-960}
        minimum_height=${UCN_MIN_WINDOW_HEIGHT:-540}
        window_width=${UCN_WINDOW_WIDTH:-1280}
        window_height=${UCN_WINDOW_HEIGHT:-720}
        d3d_config=${UCN_WINE_D3D_CONFIG:-}
        d3d9_dll=${UCN_D3D9_DLL:-}
        ;;
    *)
        print -u2 'Choose fnaf1, standard, halloween, fnaf3, or ucn.'
        exit 2
        ;;
esac

if [[ -z "$game_dir" || ! -d "$game_dir" ]]; then
    if [[ "$edition" == fnaf1 ]]; then
        print -u2 "Set FNAF1_GAME_DIR in $config_file to the folder containing FiveNightsatFreddys.exe."
    elif [[ "$edition" == fnaf3 ]]; then
        print -u2 "Set FNAF3_GAME_DIR in $config_file to the folder containing FiveNightsatFreddys3.exe."
    elif [[ "$edition" == ucn ]]; then
        print -u2 "Set UCN_GAME_DIR in $config_file to the folder containing Ultimate Custom Night.exe."
    else
        print -u2 "Set FNAF4_GAME_DIR in $config_file to the folder containing the FNAF 4 game files."
    fi
    exit 1
fi

if [[ -z "$wine_bin" ]]; then
    wine_bin=$(whence -p wine64 || whence -p wine || true)
fi
if [[ -z "$wine_bin" || ! -x "$wine_bin" ]]; then
    print -u2 "Set a Wine executable path in $config_file (FNAF1_WINE_BIN, FNAF4_WINE_BIN, FNAF3_WINE_BIN, or UCN_WINE_BIN)."
    exit 1
fi
if [[ ! -f "$game_dir/$executable" ]]; then
    print -u2 "Could not find $executable in $game_dir"
    exit 1
fi

if [[ "$edition" == ucn && -n "$d3d9_dll" ]]; then
    if [[ ! -f "$d3d9_dll" ]]; then
        print -u2 "Could not find the optional Direct3D 9 DLL at $d3d9_dll"
        exit 1
    fi
    if [[ -e "$game_dir/d3d9.dll" || -L "$game_dir/d3d9.dll" ]]; then
        print -u2 "Remove or rename $game_dir/d3d9.dll before enabling the optional Direct3D 9 renderer."
        exit 1
    fi
fi

if [[ ! -f "$repo_root/build/display-scaler.dylib" || ! -f "$repo_root/build/window-frame.exe" ]]; then
    print -u2 "Build the window helpers first with $repo_root/scripts/build.zsh"
    exit 1
fi

if [[ "$audio_buffer" == short && ! -f "$repo_root/build/audio-buffer.dylib" ]]; then
    print -u2 "Build the audio helper first with $repo_root/scripts/build.zsh"
    exit 1
fi
case "$audio_buffer" in
    short|off) ;;
    *) print -u2 'The selected audio buffer setting must be short or off.'; exit 2 ;;
esac

wine_overrides='mscoree,mshtml='
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
    *) print -u2 'The selected audio engine must be wine or openal.'; exit 2 ;;
esac

temporary_d3d9_link=''
if [[ "$edition" == ucn && -n "$d3d9_dll" ]]; then
    temporary_d3d9_link="$game_dir/d3d9.dll"
    ln -s "$d3d9_dll" "$temporary_d3d9_link"
    wine_overrides="d3d9=n,b;$wine_overrides"
    trap 'rm -f -- "$temporary_d3d9_link"' EXIT
    export DXVK_LOG_PATH="$support_dir"
    if [[ "$edition" == ucn && -n "${UCN_DXVK_HUD:-}" ]]; then
        export DXVK_HUD="$UCN_DXVK_HUD"
    else
        unset DXVK_HUD
    fi
else
    unset DXVK_LOG_PATH DXVK_HUD
fi

mkdir -p "$support_dir"
export WINEPREFIX="$wine_prefix"
export WINEDEBUG="$wine_debug"
export WINEDLLOVERRIDES="$wine_overrides"
export PATH="${wine_bin:h}:$PATH"
if [[ -n "${FNAF4_WINE_LIBRARY_PATH:-}" ]]; then
    export DYLD_FALLBACK_LIBRARY_PATH="$FNAF4_WINE_LIBRARY_PATH${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"
fi
export FNAF4_AUDIO_BUFFER="$audio_buffer"
if [[ "$edition" == standard || "$edition" == halloween ]]; then
    export FNAF4_ENABLE_CHEATS=1
    export FNAF4_CHEATS_STATE="$support_dir/cheats-state.plist"
else
    unset FNAF4_ENABLE_CHEATS FNAF4_CHEATS_STATE
fi
if [[ "$edition" == fnaf3 ]]; then
    export FNAF_DISPLAY_STRETCH_ONLY=1
else
    unset FNAF_DISPLAY_STRETCH_ONLY
fi
if [[ "$edition" == ucn || "$edition" == fnaf1 ]]; then
    export FNAF_DISPLAY_WIDTH="$display_width"
    export FNAF_DISPLAY_HEIGHT="$display_height"
    export FNAF_DISPLAY_MIN_WIDTH="$minimum_width"
    export FNAF_DISPLAY_MIN_HEIGHT="$minimum_height"
    if [[ -n "$d3d_config" ]]; then
        export WINE_D3D_CONFIG="$d3d_config"
    else
        unset WINE_D3D_CONFIG
    fi
else
    unset FNAF_DISPLAY_WIDTH FNAF_DISPLAY_HEIGHT FNAF_DISPLAY_MIN_WIDTH FNAF_DISPLAY_MIN_HEIGHT WINE_D3D_CONFIG
fi

insert_libraries=''
if [[ "$edition" != ucn ]]; then
    export FNAF4_DISPLAY_SCALER=1
    export FNAF4_DISPLAY_PREFS="$display_prefs"
    insert_libraries="$repo_root/build/display-scaler.dylib"
    if [[ "$audio_buffer" == short ]]; then
        insert_libraries="$repo_root/build/audio-buffer.dylib:$insert_libraries"
    fi
else
    unset FNAF4_DISPLAY_SCALER FNAF4_DISPLAY_PREFS
fi
if [[ -n "$insert_libraries" ]]; then
    export DYLD_INSERT_LIBRARIES="$insert_libraries${DYLD_INSERT_LIBRARIES:+:$DYLD_INSERT_LIBRARIES}"
else
    unset DYLD_INSERT_LIBRARIES
fi

log="$support_dir/$edition-launch.log"
window_log="$support_dir/$edition-window.log"
cd "$game_dir"
"$wine_bin" "$game_dir/$executable" /NOF > "$log" 2>&1 &
game_pid=$!
if [[ "$edition" == ucn ]]; then
    "$wine_bin" "$repo_root/build/window-frame.exe" "$executable" "$window_width" "$window_height" > "$window_log" 2>&1 &
else
    "$wine_bin" "$repo_root/build/window-frame.exe" "$executable" > "$window_log" 2>&1 &
fi
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
