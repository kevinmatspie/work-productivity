# Quick Start Guide

Get your display arrangement system up and running in 5 minutes!

## Installation Steps

### 1. Install Hammerspoon (2 minutes)

```bash
brew install --cask hammerspoon
```

Open Hammerspoon from Applications and:
- ✅ Grant Accessibility permissions when prompted
- ✅ Enable "Launch Hammerspoon at login"

### 2. Copy Configuration Files (1 minute)

```bash
# Navigate to this repo
cd /path/to/work-productivity

# Copy Hammerspoon configs
cp hammerspoon/init.lua ~/.hammerspoon/
cp hammerspoon/display-profiles.lua ~/.hammerspoon/

# Reload Hammerspoon (click menu bar icon → Reload Config)
```

### 3. Install Raycast Scripts (1 minute)

```bash
# Copy scripts to Raycast
mkdir -p ~/Library/Application\ Support/raycast/scripts
cp raycast/*.sh ~/Library/Application\ Support/raycast/scripts/
```

Open Raycast and type "script commands" to verify they appear.

### 4. Customize Your Apps (1 minute)

Edit `~/.hammerspoon/display-profiles.lua` and add your apps:

```lua
config.workLayout = {
    ["Your Browser"] = {display = 3, position = "maximized"},
    ["Your Editor"] = {display = 2, position = "left-half"},
    -- Add more apps here
}
```

**Find app names:** Open Hammerspoon Console and type:
```lua
hs.application.frontmostApplication():name()
```

### 5. Test It!

Open Raycast and type:
- `work` → Your windows should rearrange!
- `home` → Test home setup
- `eod` → Test end of day

## Next Steps

- [ ] Plug into your work docking station and run "work" command
- [ ] Adjust window positions in the config file as needed
- [ ] Set your Time Machine disk name in config (if applicable)
- [ ] Create keyboard shortcuts in Raycast for even faster access

## Troubleshooting

**Nothing happens when I run the command:**
- Check Hammerspoon Console for errors
- Verify apps are running
- Check app names match exactly (case-sensitive)

**Raycast doesn't show my commands:**
- Ensure scripts are executable: `chmod +x ~/Library/Application\ Support/raycast/scripts/*.sh`
- Reload Script Commands in Raycast

**Need help?** Check the full README.md for detailed instructions and tips.

## Pro Tips

1. **Automatic unplugging:** By default, Hammerspoon detects when you unplug and automatically runs EOD actions (ejects Time Machine, consolidates windows). Just unplug and go! Disable by setting `config.autoEODOnUnplug = false` in your config.

2. **Keyboard shortcuts:** In Raycast, right-click each command and assign a hotkey for even faster access

3. **Display order:** Run this in Hammerspoon Console to see your display numbers:
   ```lua
   for i, screen in ipairs(hs.screen.allScreens()) do print(i, screen:name()) end
   ```

4. **Testing layouts:** Use Hammerspoon Console to test functions directly before creating new Raycast commands

Enjoy your automated workspace! 🚀
