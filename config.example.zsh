# Copy this file to:
# ~/Library/Application Support/FNAF4-Wine/config.zsh

export FNAF4_GAME_DIR="$HOME/path/to/your/game-folder"
export FNAF4_WINE_BIN="/path/to/wine64"
# Optional. Used by the convenience launchers in Downloads.
# Update this if you move the repository folder.
# export FNAF4_COMPATIBILITY_DIR="$HOME/Downloads/fnaf4-wine-compatibility"
# Optional. Set this only when your Wine package needs extra macOS libraries.
# export FNAF4_WINE_LIBRARY_PATH="/path/to/Wine/frameworks:/path/to/Wine/lib"
# Optional. Defaults to ~/Library/Application Support/FNAF4-Wine/prefix
# export FNAF4_WINE_PREFIX="$HOME/Library/Application Support/FNAF4-Wine/prefix"

# Options are wine or openal. OpenAL mode requires the DSOAL files beside the
# selected game executable. The default uses Wine's audio implementation.
export FNAF4_AUDIO_ENGINE=wine
# Options are short or off. The short AudioUnit buffer reduces audio stutter.
export FNAF4_AUDIO_BUFFER=short

# Optional FNAF 3 settings. It uses a separate Wine prefix from FNAF 4.
# export FNAF3_GAME_DIR="$HOME/path/to/FNAF3Dump"
# export FNAF3_WINE_PREFIX="$HOME/Library/Application Support/FNAF4-Wine/fnaf3-prefix"
# FNAF3_WINE_BIN defaults to FNAF4_WINE_BIN. Wine audio and no buffer change
# are the defaults because FNAF 3 audio works without the FNAF 4 audio setup.
# export FNAF3_AUDIO_ENGINE=wine
# export FNAF3_AUDIO_BUFFER=off
