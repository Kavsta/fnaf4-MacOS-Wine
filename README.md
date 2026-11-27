# FNAF 3 & 4 Wine Compatibility for macOS

Small macOS and Windows helpers for running existing Five Nights at Freddy's 3 and 4 installations through Wine. The games remain their Windows builds. This project does not include game executables, assets, audio, saves, or a Wine runtime.

## Features

- A movable, resizable game window with standard macOS window controls and fullscreen support.
- FNAF 4 offers **Zoom to Fit (4:3)** and **Stretch to Fill**, from the Display menu or with **⌘⇧1** and **⌘⇧2**. FNAF 3 uses **Stretch to Fill** because its image does not fit the 4:3 mode correctly.
- FNAF 4's display choice is saved independently from FNAF 3's stretch-only setting.
- An optional short AudioUnit output buffer for reducing audio stutter.
- An optional DSOAL/OpenAL audio path for FNAF 4.

The scaler uses the current window size, including in fullscreen. Both game windows remain resizable.

## Requirements

- macOS with Xcode Command Line Tools.
- An x86_64 Wine installation that can run 32-bit Windows applications. Apple Silicon runs this Wine build through Rosetta.
- Your own installed copy of FNAF 3 and/or FNAF 4.
- Homebrew's MinGW cross-compiler to build the small Windows window helper: `brew install mingw-w64`.

## Build and configure

Build the helpers from the repository folder:

```sh
./scripts/build.zsh
```

Copy the example configuration into the per-user settings folder and edit it:

```sh
mkdir -p "$HOME/Library/Application Support/FNAF4-Wine"
cp config.example.zsh "$HOME/Library/Application Support/FNAF4-Wine/config.zsh"
open -t "$HOME/Library/Application Support/FNAF4-Wine/config.zsh"
```

Set `FNAF4_GAME_DIR` to the folder containing the FNAF 4 executables and `FNAF4_WINE_BIN` to your Wine executable. Set `FNAF3_GAME_DIR` to the folder containing `FiveNightsatFreddys3.exe` to enable FNAF 3. FNAF 3 uses its own Wine prefix at `~/Library/Application Support/FNAF4-Wine/fnaf3-prefix` by default; set `FNAF3_WINE_PREFIX` to choose another one. If no separate `FNAF3_WINE_BIN` is set, FNAF 3 uses `FNAF4_WINE_BIN`.

If your Wine package needs companion macOS libraries, set `FNAF4_WINE_LIBRARY_PATH` to their colon-separated folders. Standard Wine installations may not need this.

Double-click a matching launcher in `launchers/`, or run one of these from Terminal:

```sh
scripts/launch.zsh standard
scripts/launch.zsh halloween
scripts/launch.zsh fnaf3
```

The repository can be moved because its launchers find the helper files relative to the repository folder. Convenience launchers in Downloads use `FNAF4_COMPATIBILITY_DIR` from `~/Library/Application Support/FNAF4-Wine/config.zsh`; update it if you move the repository.

## Display modes

FNAF 4 can preserve its original proportions with **Zoom to Fit (4:3)** or fill the window with **Stretch to Fill**. FNAF 3 only shows **Stretch to Fill**. FNAF 4's choice is saved separately from FNAF 3's display setting.

## Audio

FNAF 4 defaults to `FNAF4_AUDIO_BUFFER=short`, which requests a smaller CoreAudio buffer while Wine runs. CoreAudio applies this at the selected output device, so other apps using the same device can be affected while the smaller buffer is active. The helper does not restore the previous buffer size on exit. Set the option to `off` to leave the device setting unchanged.

FNAF 3 defaults to Wine's audio path and leaves the AudioUnit buffer unchanged. Its optional `FNAF3_AUDIO_BUFFER` setting accepts `short` or `off`.

For FNAF 4's optional `FNAF4_AUDIO_ENGINE=openal` mode, provide 32-bit `dsound.dll` and `dsoal-aldrv.dll` beside the game executable. An `alsoft.ini` in the same folder is optional. DSOAL and OpenAL Soft are separate projects with their own license terms and are not included here. See the [DSOAL project](https://github.com/kcat/dsoal) and [OpenAL Soft](https://github.com/kcat/openal-soft).

## Verification

FNAF 4 standard and Halloween editions have been confirmed working through the launchers on one Apple Silicon Mac with Wine 10. FNAF 3 has also booted to gameplay on that Mac. The FNAF 3 frame rate is lower than expected and remains under investigation; its audio played at normal speed during the check. Other Mac models and display sizes have not been tested.

## License and game files

The helper source is licensed under the Mozilla Public License 2.0. See [LICENSE](LICENSE). Optional Wine, DSOAL, and OpenAL components keep their own terms. No game data is included; provide the files from your own installation.
