# Work Productivity Scripts

Automated display arrangement system for MacBook Air with multiple docking station configurations.

## Overview

This system uses **Hammerspoon** (window management automation) + **Raycast** (launcher) to quickly arrange your workspace across different display configurations:

- **Work Setup** (3 displays): Laptop + 2 external monitors
- **Home Setup** (2 displays): Laptop + 1 external monitor
- **Meeting Setup**: Consolidate to laptop, bring notes app to foreground
- **End of Day**: Consolidate to laptop screen, eject Time Machine disk

## Features

✅ Move windows between physical displays
✅ Resize and position windows (maximized, left-half, right-half, etc.)
✅ Detect display configuration automatically
✅ **Automatic EOD when unplugging** - Detects when you unplug and automatically consolidates windows
✅ **Slack status integration** - Automatically update Slack status based on work/home/meeting/eod mode
✅ **Meeting mode** - Quick setup for unplugged meetings with note-taking app
✅ Safely eject Time Machine disk before unplugging
✅ Fast one-command setup via Raycast
⚠️ Does NOT move windows between Mission Control Spaces (relies on macOS to remember)

## Prerequisites

1. **Hammerspoon** - Download from [hammerspoon.org](https://www.hammerspoon.org/)
2. **Raycast** (free version) - Download from [raycast.com](https://www.raycast.com/)

## Installation

### 1. Install Hammerspoon

```bash
# Install via Homebrew
brew install --cask hammerspoon

# Or download from https://www.hammerspoon.org/
```

### 2. Set Up Hammerspoon Configuration

```bash
# Copy Hammerspoon configs to your home directory
cp -r hammerspoon/init.lua ~/.hammerspoon/
cp -r hammerspoon/display-profiles.lua ~/.hammerspoon/

# Enable Hammerspoon CLI (required for Raycast integration)
# This will be done automatically when you first run Hammerspoon
```

**Open Hammerspoon** from Applications and:
- Grant Accessibility permissions when prompted (required for window management)
- Enable "Launch Hammerspoon at login" in preferences
- Click "Reload Config" to load the display arrangement system

### 3. Customize Your Display Profiles

Edit `~/.hammerspoon/display-profiles.lua` to match your apps and preferences:

```lua
config.workLayout = {
    ["Google Chrome"] = {display = 3, position = "maximized"},
    ["Visual Studio Code"] = {display = 2, position = "left-half"},
    ["Slack"] = {display = 1, position = "right-half"},
    -- Add your apps here
}
```

**Finding your app names:**
1. Open the app
2. Open Hammerspoon Console (menu bar icon → Console)
3. Type: `hs.application.frontmostApplication():name()`
4. Use the exact name shown (case-sensitive)

**Display numbering:**
Displays are numbered left to right:
- Display 1: Laptop screen
- Display 2: First external monitor
- Display 3: Second external monitor

To verify your display order, run in Hammerspoon Console:
```lua
for i, screen in ipairs(hs.screen.allScreens()) do print(i, screen:name()) end
```

**Position options:**
- `"maximized"` - Full screen
- `"left-half"` - Left 50% of screen
- `"right-half"` - Right 50% of screen
- `"top-half"` - Top 50% of screen
- `"bottom-half"` - Bottom 50% of screen
- `"center"` - Centered (keeps current size)
- `nil` - Just move to display, don't resize

### 4. Install Raycast Script Commands

```bash
# Create Raycast scripts directory if it doesn't exist
mkdir -p ~/Library/Application\ Support/raycast/scripts

# Copy the script commands
cp raycast/*.sh ~/Library/Application\ Support/raycast/scripts/

# Make them executable (already done in this repo, but just in case)
chmod +x ~/Library/Application\ Support/raycast/scripts/*.sh
```

**In Raycast:**
1. Open Raycast (Cmd+Space or your configured hotkey)
2. Type "script commands" and press Enter
3. If prompted, enable Script Commands
4. Your commands should now appear:
   - 💼 **Work Display Setup**
   - 🏠 **Home Display Setup**
   - 📝 **Meeting Setup**
   - 🌙 **End of Day Setup**

### 5. Configure Automatic Behavior (Optional)

Open `~/.hammerspoon/display-profiles.lua` to customize:

**Automatic EOD on Unplug** (default: enabled)
```lua
config.autoEODOnUnplug = true  -- Set to false for manual-only mode
```

When enabled, Hammerspoon automatically detects when you unplug from your docking station and:
- Ejects Time Machine disk (if configured)
- Moves all windows to laptop screen
- Shows completion notification

**Time Machine Disk** (optional)
```lua
config.timeMachineDisk = "Time Machine"  -- Use your actual disk name, or nil to disable
```

To find your disk name, run in Terminal:
```bash
diskutil list
```

**Slack Integration** (optional)

To automatically update your Slack status based on mode (work/home/meeting/eod):

1. Get a Slack User Token:
   - Go to https://api.slack.com/apps
   - Create a new app or select an existing one
   - Navigate to "OAuth & Permissions"
   - Add the `users.profile:write` scope
   - Install the app to your workspace
   - Copy your User OAuth Token (starts with `xoxp-`)

2. Configure in `~/.hammerspoon/display-profiles.lua`:
   ```lua
   config.slackIntegration = {
       enabled = true,
       token = "xoxp-your-token-here",  -- KEEP THIS PRIVATE!

       statuses = {
           work = {
               text = "At the office",
               emoji = ":office:",
               expiration = nil
           },
           home = {
               text = "Working from home",
               emoji = ":house:",
               expiration = nil
           },
           meeting = {
               text = "In a meeting",
               emoji = ":calendar:",
               expiration = nil
           },
           eod = {
               text = "Offline",
               emoji = ":zzz:",
               expiration = nil
           }
       }
   }
   ```

3. Customize status text and emojis to your preference

**Meeting Mode Settings**

Configure which note-taking app to bring to foreground during meetings:

```lua
config.meetingNotesApp = "Notion"  -- Change to your preferred app
-- Options: "Notion", "Obsidian", "Apple Notes", "Evernote", "OneNote", etc.
```

## Usage

### Via Raycast (Recommended)

Open Raycast and type:
- `work` → Select "Work Display Setup"
- `home` → Select "Home Display Setup"
- `meeting` → Select "Meeting Setup"
- `eod` → Select "End of Day Setup"

### Via Hammerspoon Console (for testing)

Open Hammerspoon Console and type:
- `arrangeForWork()`
- `arrangeForHome()`
- `arrangeForMeeting()`
- `arrangeForEOD()`

## How It Works

1. **Raycast** triggers a script command when you type "work", "home", "meeting", or "eod"
2. The script calls **Hammerspoon** via CLI: `hs -c "arrangeForWork()"`
3. **Hammerspoon** reads your configuration and:
   - Detects connected displays
   - Moves each app's windows to the configured display
   - Resizes/positions windows as specified
   - Updates your Slack status (if enabled)
   - Brings note-taking app to foreground (meeting mode)
   - Shows a notification when complete

## Tips & Best Practices

### Mission Control Spaces

While Hammerspoon cannot move windows between Mission Control Spaces, macOS does a good job remembering window positions:

1. **Initial setup**: Manually arrange apps in your desired Spaces once
2. **Let macOS remember**: macOS will remember which Space each app belongs to
3. **Use Hammerspoon for displays**: Let Hammerspoon handle the physical display arrangement
4. **Spaces follow displays**: When you reconnect displays, Spaces usually restore correctly

### Workflow Recommendations

**Arriving at Work:**
1. Plug into docking station (2 external monitors)
2. Wait 2-3 seconds for displays to initialize
3. Open Raycast → type "work" → Enter
4. Your windows arrange across 3 displays

**Arriving Home:**
1. Plug into docking station (1 external monitor)
2. Wait for display to initialize
3. Open Raycast → type "home" → Enter
4. Windows arrange across 2 displays

**Preparing for a Meeting:**
1. Open Raycast → type "meeting" → Enter
2. Windows consolidate to laptop screen
3. Note-taking app comes to foreground
4. Slack status updates to "In a meeting"
5. Join your video call - ready to take notes!

**End of Day:**

*With automatic EOD enabled (default):*
1. Just unplug from docking station
2. Hammerspoon automatically detects and consolidates windows
3. You'll see a notification when it's done

*Manual mode (if autoEODOnUnplug is disabled):*
1. Open Raycast → type "eod" → Enter
2. Wait for notification "Safe to unplug!"
3. Unplug from docking station

### Troubleshooting

**"Display not found" warnings:**
- Wait a few seconds after plugging in before running the command
- macOS may need time to detect all displays

**Apps not moving:**
- Check app name matches exactly (case-sensitive)
- Verify app is running and has visible windows
- Check Hammerspoon Console for error messages

**Raycast command not found:**
- Verify scripts are in: `~/Library/Application Support/raycast/scripts/`
- Ensure scripts are executable: `chmod +x *.sh`
- Reload Script Commands in Raycast

**Hammerspoon not responding:**
- Open Hammerspoon Console and check for errors
- Try "Reload Config" from menu bar icon
- Verify accessibility permissions in System Preferences

## File Structure

```
work-productivity/
├── hammerspoon/
│   ├── init.lua              # Main Hammerspoon logic with Slack integration
│   └── display-profiles.lua  # Your customizable app layouts and settings
├── raycast/
│   ├── work-setup.sh         # Raycast command for work
│   ├── home-setup.sh         # Raycast command for home
│   ├── meeting-setup.sh      # Raycast command for meetings
│   └── eod-setup.sh          # Raycast command for end of day
├── README.md                 # This file
└── QUICKSTART.md             # 5-minute setup guide
```

## Advanced Customization

### Adding More Profiles

You can create additional profiles for other scenarios:

1. Add to `~/.hammerspoon/display-profiles.lua`:
   ```lua
   config.presentationLayout = {
       ["Keynote"] = {display = 2, position = "maximized"},
       -- etc.
   }
   ```

2. Add function to `~/.hammerspoon/init.lua`:
   ```lua
   function arrangeForPresentation()
       arrangeWindows(userConfig.presentationLayout)
       notify("Presentation Setup", "Ready to present!")
   end
   ```

3. Create new Raycast script following the same pattern

### Position Options

You can create custom positions by modifying the `moveWindowToScreen` function in `init.lua`. For example, quarter-screen layouts or specific pixel dimensions.

## Limitations

- **Cannot move windows between Mission Control Spaces** - This is a macOS API limitation
- **Some apps don't support window management** - Full-screen apps, system preferences, etc.
- **Display order may vary** - Displays are ordered left-to-right by physical position

## License

MIT - Feel free to modify and use for your own productivity!

## Credits

Built with:
- [Hammerspoon](https://www.hammerspoon.org/) - Powerful macOS automation
- [Raycast](https://www.raycast.com/) - Blazingly fast launcher
