#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title End of Day Setup
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🌙
# @raycast.packageName Display Manager

# Documentation:
# @raycast.description Prepare for unplugging: eject Time Machine, move all windows to laptop display
# @raycast.author Your Name
# @raycast.authorURL https://github.com/yourusername

# Trigger Hammerspoon to prepare for end of day
/usr/local/bin/hs -c "arrangeForEOD()"
