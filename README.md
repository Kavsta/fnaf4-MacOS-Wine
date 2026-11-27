# Five Nights at Freddy's Wine Compatibility for macOS

Small macOS and Windows helpers for running existing Windows builds of Five Nights at Freddy's through Wine. The project does not include game executables, assets, audio, saves, or a Wine runtime.

## Launchers

| Game | Launcher command | Current status |
| --- | --- | --- |
| FNAF 1 | `fnaf1` | Playable through the default Wine renderer. Camera panning and the office fan animation remain less smooth than expected; see [known issues](KNOWN_ISSUES.md). |
| FNAF 3 | `fnaf3` | Starts and reaches gameplay. Frame rate is lower than expected. |
| FNAF 4 | `standard`, `halloween` | Confirmed working on one Apple Silicon Mac. |
| Ultimate Custom Night | `ucn` | Starts, but 1–5 FPS was reported during testing; performance remains unresolved. |

The launchers use a separate Wine prefix for each game by default. The repository does not package game files or change the installed game data.

## Features

- Movable, resizable windows with standard macOS controls and fullscreen support.
- FNAF 4 offers **Zoom to Fit (4:3)** and **Stretch to Fill**, from the Display menu or with **⌘⇧1** and **⌘⇧2**.
- FNAF 3 uses **Stretch to Fill** because its game image does not fit the 4:3 mode correctly.
- FNAF 1 and Ultimate Custom Night use game-specific window sizing.
- An optional short AudioUnit output buffer and an optional DSOAL/OpenAL audio path for FNAF 4.

## Requirements

- macOS with Xcode Command Line Tools.
- An x86_64 Wine installation that can run 32-bit Windows applications. Apple Silicon runs this Wine build through Rosetta.
- Your own installed copy of any supported game.
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

Set `FNAF4_GAME_DIR` to the folder containing the FNAF 4 executables and `FNAF4_WINE_BIN` to your Wine executable. Set `FNAF3_GAME_DIR` to the folder containing `FiveNightsatFreddys3.exe`, `FNAF1_GAME_DIR` to the folder containing `FiveNightsatFreddys.exe`, and `UCN_GAME_DIR` to the folder containing `Ultimate Custom Night.exe` to enable those launchers. FNAF 1, FNAF 3, and UCN each use their own Wine prefix by default. Their Wine executable settings default to `FNAF4_WINE_BIN` when no per-game path is set.

If your Wine package needs companion macOS libraries, set `FNAF4_WINE_LIBRARY_PATH` to their colon-separated folders. Standard Wine installations may not need this.

Double-click a matching launcher in `launchers/`, or run one of these from Terminal:

```sh
scripts/launch.zsh fnaf1
scripts/launch.zsh fnaf3
scripts/launch.zsh standard
scripts/launch.zsh halloween
scripts/launch.zsh ucn
```

The repository can be moved because its launchers find helper files relative to the repository folder. Convenience launchers in Downloads use `FNAF4_COMPATIBILITY_DIR` from `~/Library/Application Support/FNAF4-Wine/config.zsh`; update it if you move the repository.

## Display modes

FNAF 4 can preserve its original proportions with **Zoom to Fit (4:3)** or fill the window with **Stretch to Fill**. FNAF 3 only shows **Stretch to Fill**. The FNAF 4 display choice is saved separately from FNAF 3's display setting.

## Audio

FNAF 4 defaults to `FNAF4_AUDIO_BUFFER=short`, which requests a smaller CoreAudio buffer while Wine runs. CoreAudio applies this at the selected output device, so other apps using the same device can be affected while the smaller buffer is active. The helper does not restore the previous buffer size on exit. Set the option to `off` to leave the device setting unchanged.

FNAF 1, FNAF 3, and UCN default to Wine's audio path without changing the AudioUnit buffer. Their optional `FNAF1_AUDIO_BUFFER`, `FNAF3_AUDIO_BUFFER`, and `UCN_AUDIO_BUFFER` settings accept `short` or `off`.

For FNAF 4's optional `FNAF4_AUDIO_ENGINE=openal` mode, provide 32-bit `dsound.dll` and `dsoal-aldrv.dll` beside the game executable. An `alsoft.ini` in the same folder is optional. DSOAL and OpenAL Soft are separate projects with their own license terms and are not included here. See the [DSOAL project](https://github.com/kcat/dsoal) and [OpenAL Soft](https://github.com/kcat/openal-soft).

## Verification

FNAF 4 standard and Halloween editions have been confirmed working through the launchers on one Apple Silicon Mac with Wine 10. FNAF 3 and FNAF 1 both reached gameplay on that machine; FNAF 3's frame rate is lower than expected, and FNAF 1's camera and fan animation remain choppy. FNAF 1's controls worked and its audio played at the correct speed during the check. UCN's frame rate was reported at 1–5 FPS and is not considered verified as playable. Other Mac models and display sizes have not been tested. See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for the FNAF 1 renderer results and the remaining panning issue.

## Contributions

Pull requests are welcome, especially for the unresolved FNAF 1 frame pacing issue. Please include the Mac chip, macOS version, Wine build, renderer settings, and what changed in the fan animation and camera pan. Do not include game files, assets, or saves.

## License and game files

The helper source is licensed under the Mozilla Public License 2.0. See [LICENSE](LICENSE). Optional Wine, DSOAL, and OpenAL components keep their own terms. No game data is included; provide the files from your own installation.
