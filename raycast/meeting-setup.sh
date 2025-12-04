#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Meeting Setup
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📝
# @raycast.packageName Display Manager

# Documentation:
# @raycast.description Arrange for meeting: consolidate to laptop, bring notes app to foreground, set Slack status
# @raycast.author Your Name
# @raycast.authorURL https://github.com/yourusername

# Eject all disks via Raycast
open "raycast://extensions/raycast/system/eject-all-disks"

# Trigger Hammerspoon to arrange for meeting
/usr/local/bin/hs -c "arrangeForMeeting()"
