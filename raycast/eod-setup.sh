#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title End of Day Setup
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🌙
# @raycast.packageName Display Manager

# Documentation:
# @raycast.description Prepare for unplugging: eject all disks, set Slack status to away
# @raycast.author Your Name
# @raycast.authorURL https://github.com/yourusername

# Eject all disks via Raycast
open "raycast://extensions/raycast/system/eject-all-disks"

# Trigger Hammerspoon to set Slack status
/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c "arrangeForEOD()"
