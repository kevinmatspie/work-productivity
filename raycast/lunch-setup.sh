#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Lunch Setup
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🍕
# @raycast.packageName Display Manager

# Documentation:
# @raycast.description Set Slack status to lunch (random food emoji), lock screen (auto-clears in 1 hour)
# @raycast.author Your Name
# @raycast.authorURL https://github.com/yourusername

# Trigger Hammerspoon to set Slack status and lock screen
/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c "arrangeForLunch()"
