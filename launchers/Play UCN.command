#!/bin/zsh
set -e
launcher_dir=${0:A:h}
exec /bin/zsh "$launcher_dir/../scripts/launch.zsh" ucn
