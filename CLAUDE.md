# Claude Code Development Context

This document provides comprehensive context about the display arrangement automation system built for managing MacBook Air window layouts across multiple docking station configurations.

## Project Overview

**Goal**: Create an automated window management system that arranges application windows across different display configurations (work, home, meeting, end-of-day) using Hammerspoon automation and Raycast launcher integration.

**User Context**:
- MacBook Air user with two docking station setups:
  - Work: 2 external monitors (3 displays total)
  - Home: 1 external monitor (2 displays total)
- Uses Mission Control Spaces for workspace organization
- Needs quick window arrangement when switching between locations
- Wants automatic handling when unplugging to prevent window loss
- Uses Slack and wants status to reflect current working mode
- Attends meetings unplugged and needs quick note-taking app access

## Technical Stack

- **Hammerspoon**: macOS automation tool with Lua scripting
  - Window management APIs
  - Display detection APIs
  - HTTP client for Slack API calls
  - Screen watcher for display change detection
  - IPC CLI for Raycast integration

- **Raycast**: macOS launcher (free version)
  - Script commands for triggering Hammerspoon functions
  - User interface for mode selection

- **Slack API**: User token-based status updates
  - Endpoint: `https://slack.com/api/users.profile.set`
  - Required scope: `users.profile:write`

## Architecture

```
User Input (Raycast)
    ↓
Raycast Script Command (bash)
    ↓
Hammerspoon CLI (`hs -c "functionName()"`)
    ↓
Hammerspoon Lua Functions
    ↓
├─→ Window Arrangement (hs.window, hs.screen APIs)
├─→ Slack Status Update (hs.http.asyncPost)
├─→ Disk Ejection (AppleScript via hs.osascript)
└─→ App Activation (hs.application)
```

### Screen Watcher for Auto-Detection

```
Display Count Change Event
    ↓
Screen Watcher Callback
    ↓
Check: Did displays decrease?
    ↓
Check: Down to 1 display (laptop only)?
    ↓
Check: autoEODOnUnplug enabled?
    ↓
Trigger arrangeForEOD() after 1s delay
```

## Implementation Details

### File Structure

```
work-productivity/
├── hammerspoon/
│   ├── init.lua                    # Main automation logic (330 lines)
│   └── display-profiles.lua        # User configuration file (155 lines)
├── raycast/
│   ├── work-setup.sh              # Triggers arrangeForWork()
│   ├── home-setup.sh              # Triggers arrangeForHome()
│   ├── meeting-setup.sh           # Triggers arrangeForMeeting()
│   └── eod-setup.sh               # Triggers arrangeForEOD()
├── README.md                       # Full documentation
├── QUICKSTART.md                   # 5-minute setup guide
└── CLAUDE.md                       # This file
```

### Core Functions (hammerspoon/init.lua)

#### Helper Functions

1. **`log(message)`**
   - Prints formatted log messages to Hammerspoon console
   - Format: `[DisplayManager] {message}`

2. **`notify(title, message)`**
   - Shows macOS notification using hs.notify

3. **`getDisplayCount()`**
   - Returns number of connected displays
   - Uses `hs.screen.allScreens()`

4. **`getPrimaryScreen()`**
   - Returns primary (laptop) screen
   - Uses `hs.screen.primaryScreen()`

5. **`getScreenByIndex(index)`**
   - Returns screen at given index (1-based)
   - Sorts screens left-to-right by x-coordinate
   - Important: Display order is spatial, not arbitrary

6. **`moveWindowToScreen(window, screenIndex, position)`**
   - Moves window to specified display
   - Applies positioning: "maximized", "left-half", "right-half", "top-half", "bottom-half", "center"
   - Position "maximized" uses `window:maximize()` - fills screen but NOT macOS full-screen mode
   - Returns success boolean

7. **`arrangeWindows(layout)`**
   - Iterates through layout table
   - Finds running apps by name (case-sensitive)
   - Moves all visible, standard windows for each app
   - Returns counts: (moved, failed)

8. **`ejectDisk(diskName)`**
   - Uses AppleScript via `hs.osascript.applescript()`
   - Tells Finder to eject disk if it exists
   - Returns boolean success

9. **`setSlackStatus(statusText, statusEmoji, expiration)`**
   - Only proceeds if `config.slackIntegration.enabled == true`
   - Only proceeds if `config.slackIntegration.token` is set
   - Builds JSON profile with status_text, status_emoji, status_expiration
   - Makes async POST to Slack API with Bearer token
   - Logs success/failure to console

10. **`bringAppToForeground(appName)`**
    - Finds app by name using `hs.application.find()`
    - Calls `app:activate()` to bring to front
    - Returns boolean success

#### Main Mode Functions

1. **`arrangeForWork()`**
   - Checks for 3+ displays (warns if less)
   - Arranges windows per `userConfig.workLayout`
   - Updates Slack status if configured
   - Shows success notification

2. **`arrangeForHome()`**
   - Checks for 2+ displays (warns if less)
   - Arranges windows per `userConfig.homeLayout`
   - Updates Slack status if configured
   - Shows success notification

3. **`arrangeForMeeting()`**
   - Consolidates all windows to laptop (primary screen)
   - Applies `userConfig.meetingLayout` if configured
   - Brings `userConfig.meetingNotesApp` to foreground (0.5s delay)
   - Updates Slack status if configured
   - Shows success notification

4. **`arrangeForEOD()`**
   - Ejects Time Machine disk if `userConfig.timeMachineDisk` is set
   - Consolidates all windows to laptop screen
   - Updates Slack status if configured
   - Shows "Safe to unplug!" notification

#### Screen Watcher

```lua
local screenWatcher = nil
local previousDisplayCount = getDisplayCount()

local function handleDisplayChange()
    local currentDisplayCount = getDisplayCount()

    -- Only trigger if displays decreased and we're down to 1
    if currentDisplayCount < previousDisplayCount then
        if currentDisplayCount == 1 and userConfig.autoEODOnUnplug then
            -- 1 second delay for macOS to finish display changes
            hs.timer.doAfter(1, function()
                arrangeForEOD()
            end)
        end
    end

    previousDisplayCount = currentDisplayCount
end

-- Only start watcher if enabled
if userConfig.autoEODOnUnplug then
    screenWatcher = hs.screen.watcher.new(handleDisplayChange)
    screenWatcher:start()
end
```

### Configuration (hammerspoon/display-profiles.lua)

#### Structure

```lua
local config = {}

-- Settings
config.timeMachineDisk = "Time Machine"  -- or nil
config.autoEODOnUnplug = true  -- or false
config.meetingNotesApp = "Notion"  -- app name

-- Slack integration (optional)
config.slackIntegration = {
    enabled = false,  -- Set to true to enable
    token = nil,  -- "xoxp-..." token
    statuses = {
        work = { text = "...", emoji = ":..:", expiration = nil },
        home = { text = "...", emoji = ":..:", expiration = nil },
        meeting = { text = "...", emoji = ":..:", expiration = nil },
        eod = { text = "...", emoji = ":..:", expiration = nil }
    }
}

-- Layouts (app name → display & position)
config.workLayout = {
    ["App Name"] = {display = 3, position = "maximized"},
    -- ...
}

config.homeLayout = { ... }
config.meetingLayout = { ... }

return config
```

#### Layout Configuration Format

```lua
["App Name"] = {
    display = 1,  -- 1=laptop, 2=first external, 3=second external
    position = "maximized"  -- or "left-half", "right-half", etc.
}
```

**Important Notes**:
- App names are case-sensitive (e.g., "Google Chrome", not "chrome")
- Display numbering is spatial (sorted left-to-right by position)
- Position `nil` means just move to display, don't resize
- Position "maximized" does NOT enter macOS full-screen mode (just resizes window)

### Raycast Script Commands

Each script follows the same pattern:

```bash
#!/bin/bash

# Raycast metadata comments
# @raycast.schemaVersion 1
# @raycast.title {Mode} Setup
# @raycast.mode silent
# @raycast.icon {emoji}
# @raycast.packageName Display Manager
# @raycast.description {description}

# Trigger Hammerspoon function
/usr/local/bin/hs -c "arrangeFor{Mode}()"
```

Scripts must be:
- Executable (`chmod +x`)
- Located in `~/Library/Application Support/raycast/scripts/`
- Prefixed with Raycast metadata comments

## Design Decisions

### Why Hammerspoon over yabai?

**Decision**: Use Hammerspoon instead of yabai for window management.

**Reasoning**:
- yabai requires disabling System Integrity Protection (SIP) for Space management
- User declined to disable SIP for security reasons
- Hammerspoon can handle physical display management well
- macOS naturally remembers which apps belong to which Spaces after initial manual setup
- Trade-off: Can't programmatically move windows between Spaces, but this is acceptable

### Why "maximized" instead of full-screen?

**Decision**: Use `window:maximize()` which resizes to fill screen, not macOS full-screen mode.

**Reasoning**:
- User wanted apps to fill entire screen without creating separate Spaces/desktops
- macOS full-screen mode (green button) creates a new Space
- `window:maximize()` just resizes the window frame to match screen dimensions
- Windows stay in current Space and can be easily accessed

### Why async Slack API calls?

**Decision**: Use `hs.http.asyncPost()` instead of sync version.

**Reasoning**:
- Don't block window arrangement while waiting for API response
- Slack status update is non-critical (can fail silently)
- Better user experience - immediate window movement

### Why 1-second delay for auto-EOD?

**Decision**: `hs.timer.doAfter(1, ...)` before running EOD on unplug.

**Reasoning**:
- macOS needs time to finish display disconnection process
- Attempting to move windows while displays are still disconnecting can cause errors
- 1 second is enough for macOS to stabilize
- Short enough to feel responsive to user

### Why screen watcher only triggers on decrease to 1 display?

**Decision**: Auto-EOD only when going down to exactly 1 display.

**Reasoning**:
- Prevents false triggers when switching between 2 and 3 displays
- User explicitly wants auto-consolidation when fully unplugging
- Going from 3→2 displays (e.g., turning off one monitor) shouldn't trigger EOD
- Going from 2→1 means fully unplugging from docking station

## Important Limitations

1. **Cannot move windows between Mission Control Spaces**
   - Hammerspoon has no API for Space management
   - macOS doesn't provide public APIs for this
   - Workaround: Rely on macOS to remember Space assignments after manual setup

2. **Some apps don't support window management**
   - Full-screen apps (already in their own Space)
   - System Preferences
   - Some menu bar-only apps
   - Apps without standard windows

3. **Display numbering can change**
   - Based on physical position (left-to-right)
   - If monitors are rearranged, numbering changes
   - User should verify display order after physical changes

4. **App name matching is exact**
   - Case-sensitive: "Google Chrome" ≠ "google chrome"
   - Must match `hs.application:name()` exactly
   - User can check with: `hs.application.frontmostApplication():name()`

5. **Slack token security**
   - User token stored in plain text in config file
   - Config file should have restricted permissions
   - Token has full user privileges (limited by scopes)
   - Consider: Only grant `users.profile:write` scope, nothing more

## Configuration Tips for Users

### Finding App Names

```lua
-- In Hammerspoon Console:
hs.application.frontmostApplication():name()
```

### Finding Display Order

```lua
-- In Hammerspoon Console:
for i, screen in ipairs(hs.screen.allScreens()) do
    print(i, screen:name())
end
```

### Finding Disk Names

```bash
# In Terminal:
diskutil list
```

### Getting Slack Token

1. Go to https://api.slack.com/apps
2. Create new app or select existing
3. Navigate to "OAuth & Permissions"
4. Add `users.profile:write` scope
5. Install app to workspace
6. Copy "User OAuth Token" (starts with `xoxp-`)

## Testing Workflow

1. **Test in Hammerspoon Console first**
   ```lua
   arrangeForWork()
   arrangeForHome()
   arrangeForMeeting()
   arrangeForEOD()
   ```

2. **Check logs for errors**
   - Open Hammerspoon Console
   - Look for `[DisplayManager]` log messages
   - Common issues: app names, display counts

3. **Test Raycast integration**
   - Type command in Raycast
   - Verify Hammerspoon function executes
   - Check for notifications

4. **Test auto-unplug detection**
   - Enable `config.autoEODOnUnplug = true`
   - Plug into docking station
   - Unplug and wait 1-2 seconds
   - Verify EOD actions trigger

5. **Test Slack integration**
   - Enable Slack integration with valid token
   - Run each mode
   - Check Slack status updates in workspace
   - Verify emojis and text are correct

## Future Enhancement Ideas

### Potential Features

1. **Auto-arrange on plug-in**
   - Detect when displays increase
   - Automatically trigger work/home based on display count
   - Challenge: How to distinguish between work (3) and temporary 3rd display?

2. **Time-based auto-switching**
   - Morning: Auto-trigger work mode
   - Evening: Auto-trigger EOD mode
   - Use `hs.timer` for scheduled triggers

3. **Calendar integration**
   - Detect upcoming meetings from Calendar.app
   - Auto-trigger meeting mode 2 minutes before
   - Auto-clear Slack status after meeting ends

4. **App-specific triggers**
   - When Zoom/Teams launches → suggest meeting mode
   - When certain work apps quit → suggest EOD mode

5. **Multiple work locations**
   - Distinguish between different 3-display setups
   - Use display serial numbers or arrangement
   - Different layouts for each location

6. **Focus mode integration**
   - Sync with macOS Focus modes
   - "Work" focus → work layout
   - "Personal" focus → home layout

7. **Window size presets**
   - Quarter-screen layouts
   - Custom pixel dimensions
   - Percentage-based sizing

8. **Backup/restore window positions**
   - Save current window state
   - Restore to previous state
   - Useful for experimentation

9. **Multi-workspace support**
   - Different profiles for different projects
   - Switch entire workspace contexts
   - Include app launches/quits

10. **Status expiration handling**
    - Auto-clear Slack "In a meeting" status after X hours
    - Calculate expiration timestamp from current time
    - Example: `expiration = os.time() + (60 * 60)` for 1 hour

### Code Refactoring Opportunities

1. **Consolidation logic is duplicated**
   - `arrangeForEOD()` and `arrangeForMeeting()` have same consolidation code
   - Could extract to `consolidateToLaptop()` helper

2. **Slack status update is repeated**
   - Each mode function has same Slack update pattern
   - Could be abstracted further

3. **Configuration validation**
   - Add validation on Hammerspoon load
   - Check for common config errors
   - Provide helpful error messages

4. **Error handling**
   - More graceful handling of missing apps
   - Retry logic for Slack API failures
   - Better user feedback on errors

## Troubleshooting Common Issues

### Windows don't move

**Check**:
1. App name matches exactly (case-sensitive)
2. App is running and has visible windows
3. Window is not full-screen
4. Hammerspoon has Accessibility permissions
5. Check Hammerspoon Console for errors

### Displays not detected correctly

**Check**:
1. Wait 2-3 seconds after plugging in
2. Run `getDisplayCount()` in Console to verify
3. Check display numbering with screen iteration
4. macOS may need time to initialize displays

### Slack status doesn't update

**Check**:
1. `config.slackIntegration.enabled = true`
2. Token is valid (starts with `xoxp-`)
3. Token has `users.profile:write` scope
4. Check Hammerspoon Console for HTTP errors
5. Network connectivity to Slack API

### Auto-EOD doesn't trigger

**Check**:
1. `config.autoEODOnUnplug = true`
2. Screen watcher is started (check logs on Hammerspoon load)
3. Going from 2+ displays down to 1 (not 3→2)
4. Wait 1-2 seconds after unplugging

### Raycast command not found

**Check**:
1. Scripts are in `~/Library/Application Support/raycast/scripts/`
2. Scripts are executable (`chmod +x *.sh`)
3. Raycast Script Commands is enabled
4. Reload Script Commands in Raycast settings

## Git History

### Commit 1: Add Hammerspoon + Raycast display arrangement system
- Core functionality
- Work/home/EOD modes
- Window arrangement logic
- Raycast integration
- Basic documentation

### Commit 2: Add automatic EOD detection on unplug
- Screen watcher implementation
- Auto-consolidation on unplug
- Configuration toggle
- Updated documentation

### Commit 3: Add Slack integration and Meeting mode
- Slack API integration
- Meeting mode implementation
- Meeting notes app foreground activation
- Comprehensive Slack configuration
- Full documentation update

## Development Context for Future Sessions

### When continuing this project, consider:

1. **User's workflow**:
   - MacBook Air with two docking stations (work & home)
   - Frequent switching between locations
   - Uses Mission Control Spaces extensively
   - Participates in video calls unplugged
   - Active Slack user

2. **Technical constraints**:
   - Cannot disable SIP
   - Free version of Raycast
   - Must work within Hammerspoon's capabilities
   - No Space management possible

3. **User preferences**:
   - Wants automatic behavior where sensible
   - Values safety (Time Machine ejection before unplug)
   - Likes integration (Slack status updates)
   - Prefers quick commands over GUI

4. **Code quality standards**:
   - Comprehensive error handling
   - Detailed logging for troubleshooting
   - User notifications for important events
   - Configuration validation
   - Extensive documentation

### Questions for future development:

1. Does the user want auto-arrangement when plugging in?
2. Should we add more display modes (e.g., presentation, focus)?
3. Are there other integrations needed (Calendar, Teams, etc.)?
4. Should we add window state backup/restore?
5. Is there a need for multiple profiles per mode?

## Resources

- **Hammerspoon API Docs**: https://www.hammerspoon.org/docs/
- **Hammerspoon Getting Started**: https://www.hammerspoon.org/go/
- **Raycast Script Commands**: https://github.com/raycast/script-commands
- **Slack API - User Profile**: https://api.slack.com/methods/users.profile.set
- **Slack API - Token Types**: https://api.slack.com/authentication/token-types

## Contact & Support

This project is maintained by the user in their personal `work-productivity` repository. For future Claude Code sessions, reference this CLAUDE.md file for complete context on architecture, implementation details, and design decisions.
