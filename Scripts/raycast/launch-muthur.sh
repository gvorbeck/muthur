#!/bin/bash
#
# Raycast script command. Add this folder once under
# Raycast → Extensions → Script Commands → Add Script Directory, and MU/TH/UR
# is launchable by name without depending on Raycast's application index or on
# Spotlight having noticed the bundle.
#
# Swap the `open` line for `"$(dirname "$0")/../install.sh"` if you would rather
# it rebuilt and reinstalled on every launch.

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Launch MU/TH/UR
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🛸
# @raycast.packageName MUTHUR
# @raycast.description Launch the installed MU/TH/UR player.

open -a "$HOME/Applications/MUTHUR.app"
