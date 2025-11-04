#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Home Display Setup
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🏠
# @raycast.packageName Display Manager

# Documentation:
# @raycast.description Arrange windows for home setup (2 displays: laptop + 1 external monitor)
# @raycast.author Your Name
# @raycast.authorURL https://github.com/yourusername

# Trigger Hammerspoon to arrange windows for home
/usr/local/bin/hs -c "arrangeForHome()"
