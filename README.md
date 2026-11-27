# FNAF 4 Wine Compatibility for macOS

A small set of macOS and Windows helpers for running an existing Five Nights at Freddy's 4 installation through Wine. The game remains the Windows build. This project does not include game executables, assets, audio, saves, or a Wine runtime.

## What it adds

- A movable, resizable Wine window with standard window controls and macOS fullscreen support.
- Two display modes that scale the full 4:3 game image to the current window. **Zoom to Fit** keeps the original proportions. **Stretch to Fill** fills the window and changes the proportions.
- A Display menu with **⌘⇧1** and **⌘⇧2** shortcuts. The selection is saved for the next launch.
- An optional short AudioUnit output buffer for reducing audio stutter.
- An optional DSOAL/OpenAL path for the game's DirectSound audio.

The scaler uses the window's current size, including when entering fullscreen or resizing. The game window has a 1024×768 minimum client size because that is the game's original render size.

## Requirements

- macOS with Xcode Command Line Tools.
- An x86_64 Wine installation that can run 32-bit Windows applications. Apple Silicon runs this Wine build through Rosetta.
- Your own installed copy of the game. Put both edition executables in one folder, or configure a folder for each edition separately in a future change.
- Homebrew's MinGW cross-compiler to build the small Windows window helper. Install it with `brew install mingw-w64`.

## Build and configure

From the repository folder, build the helpers:

```sh
./scripts/build.zsh
```

Copy the example configuration into the per-user settings folder and edit the two required paths:

```sh
mkdir -p "$HOME/Library/Application Support/FNAF4-Wine"
cp config.example.zsh "$HOME/Library/Application Support/FNAF4-Wine/config.zsh"
open -t "$HOME/Library/Application Support/FNAF4-Wine/config.zsh"
```

Set `FNAF4_GAME_DIR` to the folder containing the game executables. Set `FNAF4_WINE_BIN` to the full path to your Wine executable. `FNAF4_WINE_PREFIX` is optional and defaults to a separate prefix under `~/Library/Application Support/FNAF4-Wine/prefix`.

If your Wine package needs companion macOS libraries, set `FNAF4_WINE_LIBRARY_PATH` to their colon-separated folders. Standard Wine installations may not need this.

Double-click one of the launchers in `launchers/` to start the matching edition. You can also run `scripts/launch.zsh standard` or `scripts/launch.zsh halloween` from Terminal.

## Display modes

Choose **Zoom to Fit (4:3)** from the Display menu or press **⌘⇧1** to show the entire game image while preserving its proportions. Choose **Stretch to Fill** or press **⌘⇧2** to fill the window with the entire image. Neither mode crops the game image.

## Audio

The default `FNAF4_AUDIO_BUFFER=short` setting requests a smaller buffer from the selected CoreAudio output device during Wine initialization. CoreAudio applies this at the device level, so other apps using the same output device can also be affected while the smaller buffer is set. The helper does not restore the previous buffer size on exit. Set it to `off` in `config.zsh` to keep the device setting unchanged.

For the optional `FNAF4_AUDIO_ENGINE=openal` mode, provide 32-bit `dsound.dll` and `dsoal-aldrv.dll` beside the game executable. An `alsoft.ini` in the same folder is optional. DSOAL is a separate LGPL-2.1 project and OpenAL Soft has its own license. They are not included here. See the [DSOAL project and releases](https://github.com/kcat/dsoal) and [OpenAL Soft](https://github.com/kcat/openal-soft) for their source, releases, and license notices.

## Verification

The helper build succeeded on this Mac. The display scaler was exercised with the standard edition in the existing Wine 10 setup on one Apple Silicon Mac. The full-screen and windowed views used the same scaling modes. The repository launcher has not yet been exercised with a fresh Wine prefix or on every MacBook display size.

## License and game files

The helper source in this repository is licensed under the Mozilla Public License 2.0. See [LICENSE](LICENSE). Optional Wine, DSOAL, and OpenAL components keep their own terms. No game data is included. Use the game files from your own installation.
