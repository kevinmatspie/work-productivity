#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Work Display Setup
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 💼
# @raycast.packageName Display Manager

# Documentation:
# @raycast.description Arrange windows for work setup (3 displays: laptop + 2 external monitors)
# @raycast.author Your Name
# @raycast.authorURL https://github.com/yourusername

# Trigger Hammerspoon to arrange windows for work
/usr/local/bin/hs -c "arrangeForWork()"
