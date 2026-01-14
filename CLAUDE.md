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
  - Profile endpoint: `https://slack.com/api/users.profile.set`
  - Presence endpoint: `https://slack.com/api/users.setPresence`
  - Required scopes: `users.profile:write`, `users:write`
  - **Important**: Must use User OAuth Token (xoxp-), NOT Bot Token (xoxb-)

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
├─→ Slack Status Update (hs.http.asyncPost to users.profile.set)
├─→ Slack Presence Update (hs.http.asyncPost to users.setPresence)
├─→ Disk Ejection (Raycast deep link OR AppleScript via hs.osascript)
└─→ App Activation (hs.application)
```

### Screen Watcher for Auto-Detection

```
Display Count Change Event
    ↓
Screen Watcher Callback
    ↓
├─→ Displays decreased to 1? → Trigger arrangeForEOD() (if enabled)
└─→ Displays increased to 3? → Trigger autoArrangeForWork() (if enabled)
```

### Wake Watcher for Sleep/Wake Detection

```
Wake Event (systemDidWake, screensDidWake, screenIsUnlocked)
    ↓
Wait 5 seconds for displays/network to stabilize
    ↓
Check: 3 displays detected?
    ↓
Check: Within morning window? (if morningOnlyAutoWork enabled)
    ↓
Trigger autoArrangeForWork()
```

### Startup Check for Hibernate/FileVault

```
Hammerspoon Loads
    ↓
Wait 3 seconds for initialization
    ↓
Check: 3 displays detected?
    ↓
Check: Within morning window? (if morningOnlyAutoWork enabled)
    ↓
Trigger autoArrangeForWork()
```

**Why startup check is needed**: With FileVault enabled (standard on Macs), when waking from hibernate the drive is locked and Hammerspoon isn't running yet. By the time Hammerspoon loads, the wake event has already passed. The startup check catches this scenario.

## Implementation Details

### File Structure

```
work-productivity/
├── hammerspoon/
│   ├── init.lua                              # Main automation logic (~800 lines)
│   ├── display-profiles.lua                  # User configuration file
│   └── display-profiles-secrets.lua.example  # Secrets template (not used directly)
├── raycast/
│   ├── work-setup.sh              # Triggers arrangeForWork()
│   ├── home-setup.sh              # Triggers arrangeForHome()
│   ├── meeting-setup.sh           # Triggers arrangeForMeeting()
│   ├── eod-setup.sh               # Triggers arrangeForEOD()
│   ├── walk-setup.sh              # Triggers arrangeForWalk()
│   └── lunch-setup.sh             # Triggers arrangeForLunch()
├── .gitignore                     # Excludes secrets file from version control
├── README.md                      # Full documentation
├── QUICKSTART.md                  # 5-minute setup guide
└── CLAUDE.md                      # This file

User's home directory (~/.hammerspoon/):
├── init.lua                       # Copied from hammerspoon/init.lua
├── display-profiles.lua           # Copied from hammerspoon/display-profiles.lua
└── display-profiles-secrets.lua   # Created by user (NOT in git repo)
                                   # Contains sensitive API tokens
                                   # Permissions: 600 (user read/write only)

User's Raycast scripts directory:
~/bin/raycast/                     # User's preferred location for Raycast scripts
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
   - Also supports custom frame: `{x = ..., y = ..., w = ..., h = ...}` for exact pixel positioning
   - Position "maximized" uses `window:maximize()` - fills screen but NOT macOS full-screen mode
   - Returns success boolean

7. **`arrangeWindows(layout)`**
   - Iterates through layout table
   - Finds running apps by name using `hs.application.find(appName, true)` (exact match)
   - Checks `app.allWindows` method exists before calling (some objects aren't full app objects)
   - Moves all visible, standard windows for each app
   - Returns counts: (moved, failed)

8. **`ejectDisk(diskName)`**
   - Uses AppleScript via `hs.osascript.applescript()`
   - Tells Finder to eject disk if it exists
   - Returns boolean success

9. **`setSlackPresence(presence)`**
   - Sets Slack presence to "auto" (active) or "away"
   - Only proceeds if Slack integration is enabled and token is set
   - Uses `users.setPresence` API endpoint
   - Makes async POST to Slack API with Bearer token

10. **`setSlackStatus(statusText, statusEmoji, expiration, presence)`**
   - Only proceeds if `config.slackIntegration.enabled == true`
   - Only proceeds if `config.slackIntegration.token` is set
   - Supports random emoji selection: if `statusEmoji` is a table, picks random item
   - Builds JSON profile wrapped in `{profile: {...}}` (required by Slack API)
   - Makes async POST to Slack API with Bearer token
   - Optionally sets presence via `setSlackPresence()` if presence parameter provided
   - Logs success/failure to console

11. **`bringAppToForeground(appName)`**
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
   - Note: Current implementation uses Raycast "eject all disks" command instead
   - Updates Slack status if configured (supports random emoji selection, sets presence to "away")
   - Shows "Ejecting disks..." notification immediately
   - Shows "Safe to unplug!" notification after 10-second delay (allows disk ejection to complete)

5. **`arrangeForWalk()`**
   - Sets Slack status with 30-minute expiration
   - Sets Slack presence to "away"
   - Prevents system sleep for 30 minutes (allows Time Machine backups)
   - Locks screen after 1-second delay
   - Restores presence to "auto" when status expires

6. **`arrangeForLunch()`**
   - Sets Slack status with 1-hour expiration
   - Sets Slack presence to "away"
   - Prevents system sleep for 1 hour (allows Time Machine backups)
   - Locks screen after 1-second delay
   - Restores presence to "auto" when status expires

#### Auto-Work Function

**`autoArrangeForWork()`**
- Used by screen watcher, wake watcher, and startup check
- Arranges windows first (priority), then updates Slack
- Uses `setSlackStatusWithRetry()` for network resilience

#### Slack Retry Helper

**`setSlackStatusWithRetry(statusText, statusEmoji, expiration, presence, callback)`**
- Exponential backoff: 5s → 10s → 20s between retries
- Maximum 3 attempts
- Shows notification on final failure
- Used for auto-work when network may still be connecting after wake

#### Screen Watcher

Detects display count changes for auto-EOD (unplug) and auto-Work (plug-in):

```lua
local function handleDisplayChange()
    local currentDisplayCount = getDisplayCount()

    -- Auto-EOD: Displays decreased to 1
    if currentDisplayCount < previousDisplayCount then
        if currentDisplayCount == 1 and userConfig.autoEODOnUnplug then
            hs.timer.doAfter(1, function()
                arrangeForEOD()
            end)
        end
    end

    -- Auto-Work: Displays increased to 3
    if currentDisplayCount > previousDisplayCount then
        if currentDisplayCount == 3 and userConfig.autoWorkOnPlug then
            -- Check morning window if enabled
            if not userConfig.morningOnlyAutoWork or isWithinMorningWindow() then
                hs.timer.doAfter(3, function()  -- 3s delay for DisplayLink
                    autoArrangeForWork()
                end)
            end
        end
    end

    previousDisplayCount = currentDisplayCount
end
```

#### Wake Watcher

Handles wake-from-sleep scenarios. Watches multiple events for better coverage:
- `systemDidWake` - Standard wake from sleep
- `screensDidWake` - Displays woke up
- `screenIsUnlocked` - User unlocked screen (catches hibernate/FileVault)

```lua
local function handleWakeEvent(event)
    if event == hs.caffeinate.watcher.systemDidWake or
       event == hs.caffeinate.watcher.screensDidWake or
       event == hs.caffeinate.watcher.screenIsUnlocked then
        -- 5 second delay for displays/network to stabilize
        hs.timer.doAfter(5, function()
            checkAndTriggerAutoWork(eventName)
        end)
    end
end
```

#### Startup Check

Catches hibernate/FileVault scenario where Hammerspoon loads after wake:

```lua
-- On Hammerspoon load, check if already at 3 displays
if userConfig.autoWorkOnPlug then
    hs.timer.doAfter(3, function()
        checkAndTriggerAutoWork("Startup check")
    end)
end
```

**Debounce Logic**: A 30-second debounce prevents duplicate triggers when multiple wake events fire in quick succession.

### Configuration (hammerspoon/display-profiles.lua)

#### Structure

```lua
local config = {}

-- Settings
config.timeMachineDisk = nil  -- Disk ejection handled by Raycast "eject all disks"
config.autoEODOnUnplug = false  -- Auto-EOD when unplugging to 1 display
config.meetingNotesApp = "Notes"  -- Apple Notes for meeting mode

-- Auto-Work settings
config.autoWorkOnPlug = true  -- Auto-work when plugging into 3 displays
config.morningOnlyAutoWork = false  -- false = any time, true = morning window only
config.morningWindowStart = 7   -- 7:00 AM
config.morningWindowEnd = 10    -- 10:00 AM

-- Slack integration (optional)
config.slackIntegration = {
    enabled = true,
    -- Token is loaded from ~/.hammerspoon/display-profiles-secrets.lua
    statuses = {
        work = { text = "", emoji = "", expiration = nil, presence = "auto" },
        home = { text = "Working from home", emoji = ":house:", expiration = nil },
        meeting = {
            text = {"In a meeting...", "Syncing with humans...", "Currently in a meeting..."},  -- random
            emoji = {":calendar-fire:", ":spiral_calendar_pad:", ":waiting-patiently:"},  -- random
            expiration = nil,
            presence = "away"
        },
        eod = {
            text = "Offline",
            emoji = {":night_with_stars:", ":no_entry:", ":bed:", ":crescent_moon:"},
            expiration = nil,
            presence = "away"
        },
        walk = {
            text = "Taking a walk",
            emoji = ":walking:",
            expirationMinutes = 30,  -- auto-clears after 30 minutes
            presence = "away"
        },
        lunch = {
            text = "Out to lunch",
            emoji = {":pizza:", ":hamburger:", ":taco:", ":ramen:"},  -- random
            expirationMinutes = 60,
            presence = "away"
        }
    }
}

-- Layouts (app name → display & position)
config.workLayout = { ... }
config.homeLayout = { ... }
config.meetingLayout = { ... }

return config
```

#### Layout Configuration Format

```lua
-- String position (preset)
["App Name"] = {
    display = 1,  -- 1=laptop, 2=first external, 3=second external
    position = "maximized"  -- or "left-half", "right-half", etc.
}

-- Custom frame position (exact pixel coordinates)
["Slack"] = {
    display = 3,
    position = {x = 1926, y = -191, w = 1066, h = 1043}
}
```

**Important Notes**:
- App names are case-sensitive (e.g., "Google Chrome", not "chrome")
- Display numbering is spatial (sorted left-to-right by x-coordinate)
- Position `nil` means just move to display, don't resize
- Position "maximized" does NOT enter macOS full-screen mode (just resizes window)
- Custom frame positions use absolute pixel coordinates (useful for stacking windows)

### Secrets Management

**Architecture**

To protect sensitive information (Slack API tokens, future credentials), the system uses a separate, untracked secrets file:

1. **Template file** (in git repo): `hammerspoon/display-profiles-secrets.lua.example`
   - Example structure for users to copy
   - Committed to version control as documentation
   - Not used directly by the system

2. **Actual secrets file** (NOT in git): `~/.hammerspoon/display-profiles-secrets.lua`
   - Created by user from template
   - Contains real API tokens and sensitive data
   - File permissions: `600` (user read/write only)
   - Listed in `.gitignore` to prevent accidental commits
   - Loaded automatically by `init.lua` at startup

**Loading Process** (in `init.lua` lines 7-48)

```lua
-- 1. Define loading function
local function loadSecrets()
    local secretsPath = os.getenv("HOME") .. "/.hammerspoon/display-profiles-secrets.lua"

    -- Check if file exists
    local file = io.open(secretsPath, "r")
    if not file then return nil end
    file:close()

    -- Load secrets using Lua's dofile
    local success, secrets = pcall(dofile, secretsPath)
    if success then
        return secrets
    else
        print("[DisplayManager] Error loading secrets file: " .. tostring(secrets))
        return nil
    end
end

-- 2. Load secrets
local secrets = loadSecrets()

-- 3. Merge into config
if secrets then
    if secrets.slackToken and userConfig.slackIntegration then
        userConfig.slackIntegration.token = secrets.slackToken
        print("[DisplayManager] Loaded Slack token from secrets file")
    end
    -- Future secrets can be added here
else
    print("[DisplayManager] No secrets file found")
    if userConfig.slackIntegration and userConfig.slackIntegration.enabled then
        print("[DisplayManager] WARNING: Slack integration enabled but no token configured")
    end
end
```

**Secrets File Format** (`~/.hammerspoon/display-profiles-secrets.lua`)

```lua
local secrets = {}

-- Slack API Token
secrets.slackToken = "xoxp-your-actual-token-here"

-- Future secrets can be added:
-- secrets.calendarToken = "your-calendar-api-token"
-- secrets.teamsToken = "your-teams-api-token"

return secrets
```

**Security Features**

1. **File system protection**: `chmod 600` ensures only user can read/write
2. **Version control protection**: Listed in `.gitignore` prevents git commits
3. **Encryption at rest**: macOS FileVault encrypts the file on disk
4. **Graceful fallback**: System warns if secrets expected but not found
5. **Safe loading**: Uses `pcall()` to catch errors without crashing

**User Setup Steps**

```bash
# 1. Copy template
cp hammerspoon/display-profiles-secrets.lua.example ~/.hammerspoon/display-profiles-secrets.lua

# 2. Edit with real token
nano ~/.hammerspoon/display-profiles-secrets.lua

# 3. Set restrictive permissions
chmod 600 ~/.hammerspoon/display-profiles-secrets.lua

# 4. Enable Slack integration in display-profiles.lua
# (Set enabled = true)

# 5. Reload Hammerspoon
```

**Why This Approach?**

Compared to alternatives:
- **vs. Environment variables**: File-based is more secure (not visible in process list), easier to manage
- **vs. macOS Keychain**: Simpler implementation, no async subprocess calls, fast startup
- **vs. Keeper CLI**: No external dependencies, works offline, appropriate for single-token use case
- **vs. Hardcoded in config**: Secrets file is never committed, separate from version-controlled config

**Future Enhancements**

Could add support for:
- Multiple secret sources (Keychain fallback)
- Encrypted secrets file
- Integration with enterprise secret managers (Keeper, 1Password CLI)
- Per-secret configuration (which source to use)

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

### Getting Window Positions

To capture current window positions for custom frame configuration:

```lua
-- In Hammerspoon Console:
-- Get all windows for an app with their positions
local app = hs.application.find("Slack")
if app then
    for i, win in ipairs(app:allWindows()) do
        local f = win:frame()
        print(string.format("Window %d: x=%d, y=%d, w=%d, h=%d", i, f.x, f.y, f.w, f.h))
    end
end
```

### Getting Slack Token

1. Go to https://api.slack.com/apps
2. Create new app or select existing
3. Navigate to "OAuth & Permissions"
4. Under **User Token Scopes**, add:
   - `users.profile:write` (for status updates)
   - `users:write` (for presence/away status)
5. Install app to workspace
6. Copy "User OAuth Token" (starts with `xoxp-`)

**Important**: You need a **User OAuth Token** (xoxp-), NOT a Bot User OAuth Token (xoxb-). Bot tokens cannot update user profiles.

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

1. ~~**Auto-arrange on plug-in**~~ ✅ IMPLEMENTED
   - Detect when displays increase to 3
   - Automatically trigger Work mode
   - Configurable morning-only window

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
2. Token is valid (starts with `xoxp-`, NOT `xoxb-`)
3. Token has `users.profile:write` scope (and `users:write` for presence)
4. Check Hammerspoon Console for HTTP errors
5. Network connectivity to Slack API

**Common Slack API Errors**:
- `not_allowed_token_type`: Using bot token (xoxb-) instead of user token (xoxp-)
- `invalid_profile`: JSON format issue - must wrap profile in `{profile: {...}}`
- `missing_scope`: Need to add required scope and reinstall app to workspace

### Auto-EOD doesn't trigger

**Check**:
1. `config.autoEODOnUnplug = true`
2. Screen watcher is started (check logs on Hammerspoon load)
3. Going from 2+ displays down to 1 (not 3→2)
4. Wait 1-2 seconds after unplugging

### Raycast command not found

**Check**:
1. Scripts are in user's Raycast scripts directory (`~/bin/raycast/`)
2. Scripts are executable (`chmod +x *.sh`)
3. Raycast Script Commands is enabled
4. Reload Script Commands in Raycast settings

### Auto-Work doesn't trigger on morning plug-in

**Symptoms**: You plug into dock in the morning but Work mode doesn't auto-trigger.

**Root Cause**: With FileVault enabled, after overnight sleep/hibernate:
1. Mac hibernates to save power
2. FileVault locks the drive
3. When you open the lid, Hammerspoon isn't running yet
4. By the time Hammerspoon loads, the `systemDidWake` event has passed

**Solution** (implemented):
- Startup check detects 3 displays on Hammerspoon load
- Multiple wake events watched (systemDidWake, screensDidWake, screenIsUnlocked)
- 30-second debounce prevents duplicate triggers

**Check**:
1. Look for "Startup check: 3 displays detected" in Hammerspoon console
2. Look for "Wake watcher: ENABLED" on startup
3. Verify `config.autoWorkOnPlug = true`

**References**:
- [Hammerspoon issue #520](https://github.com/Hammerspoon/hammerspoon/issues/520) - hibernate/FileVault issues
- [Hammerspoon issue #3178](https://github.com/Hammerspoon/hammerspoon/issues/3178) - caffeinate watcher reliability

### Changes not taking effect

**Cause**: Hammerspoon runs code from memory. Editing files doesn't automatically reload.

**Solution**: After copying files to `~/.hammerspoon/`, reload Hammerspoon:

```bash
# Via CLI (used by Claude Code after updates)
/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c "hs.reload()"

# Or: Click Hammerspoon menubar icon → Reload Config
```

**Development workflow**:
1. Edit files in `work-productivity/hammerspoon/`
2. Copy to `~/.hammerspoon/`
3. Run reload command
4. Test changes
5. Commit when working

## Git History

### Recent Commits (newest first)

1. **baa3725**: Improve wake detection for auto-work trigger
   - Added startup check for hibernate/FileVault scenario
   - Watch multiple wake events (systemDidWake, screensDidWake, screenIsUnlocked)
   - Added 30-second debounce to prevent duplicate triggers

2. **e1cf10c**: Add delay before "Safe to unplug" notification in EOD flow
   - Shows "Ejecting disks..." immediately
   - Waits 10 seconds before "Safe to unplug!" notification

3. **c69e353**: Add wake watcher to trigger Work setup when waking while docked
   - Initial wake watcher implementation using systemDidWake

4. **9e038de**: Add automatic Work setup when plugging into 3-display dock
   - Screen watcher detects display increase to 3
   - 3-second delay for DisplayLink to stabilize
   - Configurable morning-only mode
   - Slack retry with exponential backoff

5. **15e6fb9**: Prevent system sleep during Walk/Lunch to allow Time Machine backups
   - Caffeinate assertions keep system awake while screen is locked

6. **83aa617**: Add meeting mode config and fix presence restoration
   - Meeting mode with Apple Notes
   - Random status text/emoji selection
   - Presence restoration timers for Walk/Lunch

7. **e06ec48**: Add walk/lunch modes, enhance Slack integration
   - Walk mode (30 min) and Lunch mode (1 hour)
   - Screen lock after status set
   - Custom window positioning support

### Earlier History

- **Commit 1**: Core Hammerspoon + Raycast display arrangement system
- **Commit 2**: Automatic EOD detection on unplug (screen watcher)
- **Commit 3**: Slack integration and Meeting mode
- **Session 4**: Enhanced Slack integration, custom window positions, presence API

## User's Display Configuration

**Work Setup (3 displays, sorted by x-coordinate)**:
- Display 1: Built-in Retina Display (laptop, x:-1470) - leftmost
- Display 2: DELL P2217H (1) (center, x:0) - center monitor
- Display 3: DELL P2217H (2) (right, x:1920) - portrait mode, rightmost

**Current Work Layout**:
```lua
config.workLayout = {
    -- Communication apps on right monitor (portrait, display 3) - stacked vertically
    ["Slack"] = {display = 3, position = {x = 1926, y = -191, w = 1066, h = 1043}},
    ["Microsoft Teams"] = {display = 3, position = {x = 1926, y = 867, w = 1066, h = 818}},

    -- Email on laptop (display 1)
    ["Microsoft Outlook"] = {display = 1, position = "maximized"},
}
```

**Raycast Deep Links**:
The EOD script uses Raycast's deep link feature to trigger built-in commands:
```bash
# Eject all disks via Raycast
open "raycast://extensions/raycast/system/eject-all-disks"
```

This is preferred over Hammerspoon's AppleScript disk ejection because:
1. Works with all mounted disks, not just named Time Machine disk
2. User can see Raycast's UI feedback
3. Consistent with user's existing workflow

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

1. ~~Does the user want auto-arrangement when plugging in?~~ ✅ Implemented
2. Should we add more display modes (e.g., presentation, focus)?
3. Are there other integrations needed (Calendar, Teams, etc.)?
4. Should we add window state backup/restore?
5. Is there a need for multiple profiles per mode?

## Known Issues and Workarounds

### FileVault/Hibernate Wake Detection

**Issue**: After overnight sleep with FileVault, `systemDidWake` event doesn't fire because Hammerspoon isn't running when the Mac actually wakes - it loads after the drive is unlocked.

**Workaround**: Startup check detects 3 displays on Hammerspoon load and triggers auto-work. Multiple wake events are watched as fallback.

### Hammerspoon Config Changes Require Reload

**Issue**: Editing `~/.hammerspoon/init.lua` doesn't automatically reload the config.

**Workaround**: Run `hs -c "hs.reload()"` after making changes, or use Hammerspoon menubar → Reload Config.

### Slack Status Empty String Clearing

**Issue**: Setting status to empty string (`text = ""`, `emoji = ""`) should clear status, but occasionally doesn't work after extended Hammerspoon sessions.

**Workaround**: Reload Hammerspoon to reset state.

## Resources

- **Hammerspoon API Docs**: https://www.hammerspoon.org/docs/
- **Hammerspoon Getting Started**: https://www.hammerspoon.org/go/
- **Hammerspoon Caffeinate Watcher**: https://www.hammerspoon.org/docs/hs.caffeinate.watcher.html
- **Raycast Script Commands**: https://github.com/raycast/script-commands
- **Raycast Deep Links**: https://developers.raycast.com/api-reference/deeplinks
- **Slack API - User Profile**: https://api.slack.com/methods/users.profile.set
- **Slack API - User Presence**: https://api.slack.com/methods/users.setPresence
- **Slack API - Token Types**: https://api.slack.com/authentication/token-types

### Hammerspoon Issue References

- [Issue #520](https://github.com/Hammerspoon/hammerspoon/issues/520) - Screen watcher not triggered after hibernate (FileVault)
- [Issue #3178](https://github.com/Hammerspoon/hammerspoon/issues/3178) - Caffeinate watcher stops working after extended periods

## Contact & Support

This project is maintained by the user in their personal `work-productivity` repository. For future Claude Code sessions, reference this CLAUDE.md file for complete context on architecture, implementation details, and design decisions.
