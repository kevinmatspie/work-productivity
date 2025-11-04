-- Display Arrangement Profiles
-- Customize this file to match your apps and preferred layouts

local config = {}

-- Time Machine disk name (set to nil if you don't use Time Machine)
-- This will be ejected during the "eod" command
config.timeMachineDisk = "Time Machine"

-- Automatic EOD on unplug
-- When set to true, automatically runs EOD actions when you unplug from docking station
-- (ejects Time Machine disk and moves all windows to laptop screen)
-- Set to false if you prefer to manually trigger EOD via Raycast
config.autoEODOnUnplug = true

-- Work Layout (3 displays)
-- Display numbering: 1 = laptop, 2 = first external, 3 = second external
-- Position options: "maximized", "left-half", "right-half", "top-half", "bottom-half", "center", or nil
config.workLayout = {
    -- Example: Browser on second external display, left half
    ["Google Chrome"] = {display = 3, position = "maximized"},
    ["Safari"] = {display = 3, position = "maximized"},

    -- Example: Code editor on first external, maximized
    ["Visual Studio Code"] = {display = 2, position = "maximized"},
    ["Cursor"] = {display = 2, position = "maximized"},

    -- Example: Communication apps on laptop
    ["Slack"] = {display = 1, position = "right-half"},
    ["Microsoft Teams"] = {display = 1, position = "right-half"},
    ["Messages"] = {display = 1, position = "right-half"},

    -- Example: Terminal on laptop
    ["Terminal"] = {display = 1, position = "left-half"},
    ["iTerm2"] = {display = 1, position = "left-half"},
    ["Warp"] = {display = 1, position = "left-half"},

    -- Example: Email on second external
    ["Mail"] = {display = 3, position = "maximized"},
    ["Microsoft Outlook"] = {display = 3, position = "maximized"},

    -- Example: Notes and productivity
    ["Notion"] = {display = 2, position = "maximized"},
    ["Obsidian"] = {display = 2, position = "maximized"},

    -- Music/Spotify can go anywhere you prefer
    ["Spotify"] = {display = 1, position = "bottom-half"},
    ["Music"] = {display = 1, position = "bottom-half"},

    -- Add your own apps here
    -- ["App Name"] = {display = 1, position = "maximized"},
}

-- Home Layout (2 displays)
-- Display numbering: 1 = laptop, 2 = external monitor
config.homeLayout = {
    -- Example: Browser on external
    ["Google Chrome"] = {display = 2, position = "maximized"},
    ["Safari"] = {display = 2, position = "maximized"},

    -- Example: Code on external
    ["Visual Studio Code"] = {display = 2, position = "left-half"},
    ["Cursor"] = {display = 2, position = "left-half"},

    -- Example: Communication on laptop
    ["Slack"] = {display = 1, position = "right-half"},
    ["Messages"] = {display = 1, position = "right-half"},

    -- Example: Terminal on external
    ["Terminal"] = {display = 2, position = "right-half"},
    ["iTerm2"] = {display = 2, position = "right-half"},
    ["Warp"] = {display = 2, position = "right-half"},

    -- Personal apps on laptop
    ["Mail"] = {display = 1, position = "maximized"},
    ["Notion"] = {display = 1, position = "left-half"},
    ["Obsidian"] = {display = 1, position = "left-half"},

    ["Spotify"] = {display = 1, position = "bottom-half"},
    ["Music"] = {display = 1, position = "bottom-half"},

    -- Add your own apps here
    -- ["App Name"] = {display = 1, position = "maximized"},
}

-- Tips for finding your app names:
-- 1. Open the app
-- 2. Run this in Hammerspoon console: hs.application.frontmostApplication():name()
-- 3. Use the exact name shown (case-sensitive)

-- Tips for display numbering:
-- After connecting your displays, run this in Hammerspoon console:
-- for i, screen in ipairs(hs.screen.allScreens()) do print(i, screen:name()) end

return config
