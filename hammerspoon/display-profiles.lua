-- Display Arrangement Profiles
-- Customize this file to match your apps and preferred layouts

local config = {}

-- Time Machine disk name (set to nil if you don't use Time Machine)
-- This will be ejected during the "eod" command
config.timeMachineDisk = nil  -- Disk ejection handled by Raycast "eject all disks"

-- Automatic EOD on unplug
-- When set to true, automatically runs EOD actions when you unplug from docking station
-- (ejects Time Machine disk and moves all windows to laptop screen)
-- Set to false if you prefer to manually trigger EOD via Raycast
config.autoEODOnUnplug = false

-- Slack Integration (optional)
-- To enable Slack status updates, you need a Slack User Token (xoxp-...)
-- Get your token from: https://api.slack.com/authentication/token-types#user
-- Required scopes: users.profile:write
--
-- IMPORTANT: Do NOT put your token here!
-- Instead, create ~/.hammerspoon/display-profiles-secrets.lua (see README.md for setup)
-- The token will be automatically loaded from that file at startup.
config.slackIntegration = {
    enabled = true,  -- Set to true to enable Slack integration
    -- Token is loaded from ~/.hammerspoon/display-profiles-secrets.lua
    -- See hammerspoon/display-profiles-secrets.lua.example for template

    -- Status messages for each mode
    statuses = {
        work = {
            text = "",
            emoji = "",
            expiration = nil,
            presence = "auto"  -- "auto" restores active status
        },
        home = {
            text = "Working from home",
            emoji = ":house:",
            expiration = nil
        },
        meeting = {
            text = {"In a meeting...", "Syncing with humans...", "Currently in a meeting...", "˙˙˙ƃuᴉʇǝǝɯ ɐ uI", "In meetings, send help!"},
            emoji = {":calendar-fire:", ":spiral_calendar_pad:", ":waiting-patiently:", ":waiting-clock:", ":spiral_note_pad:", ":pencil:"},
            expiration = nil,  -- You could set this to auto-expire after 1 hour
            presence = "away"
        },
        eod = {
            text = "Offline",
            emoji = {":night_with_stars:", ":no_entry:", ":bed:", ":crescent_moon:"},
            expiration = nil,
            presence = "away"  -- "away" or "auto"
        },
        walk = {
            text = "Taking a walk",
            emoji = ":walking:",
            expirationMinutes = 30,  -- auto-clears after 30 minutes
            presence = "away"
        },
        lunch = {
            text = "Out to lunch",
            emoji = {":pizza:", ":hamburger:", ":taco:", ":burrito:", ":ramen:", ":sushi:", ":salad:", ":sandwich:"},
            expirationMinutes = 60,  -- auto-clears after 1 hour
            presence = "away"
        }
    }
}

-- Meeting mode settings
-- App to bring to foreground when entering meeting mode
config.meetingNotesApp = "Notes"  -- Apple Notes
-- Options: "Notes" (Apple), "Notion", "Obsidian", "Evernote", "OneNote", etc.

-- Work Layout (3 displays)
-- Display numbering (sorted left to right by x position):
--   1 = Built-in Retina Display (laptop, x:-1470)
--   2 = DELL P2217H (1) (center, x:0)
--   3 = DELL P2217H (2) (right, portrait, x:1920)
-- Position options: "maximized", "left-half", "right-half", "top-half", "bottom-half", "center"
--   or custom: {x = ..., y = ..., w = ..., h = ...}
config.workLayout = {
    -- Communication apps on right monitor (portrait, display 3) - stacked vertically
    ["Slack"] = {display = 3, position = {x = 1926, y = -191, w = 1066, h = 1043}},
    ["Microsoft Teams"] = {display = 3, position = {x = 1926, y = 867, w = 1066, h = 818}},

    -- Email on laptop (display 1)
    ["Microsoft Outlook"] = {display = 1, position = "maximized"},

    -- Add your own apps here:
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

-- Meeting Layout (laptop only)
-- Display numbering: 1 = laptop (all windows will be on laptop for meetings)
-- This layout is used when you trigger "meeting" mode
config.meetingLayout = {
    -- Notes app maximized on laptop
    ["Notes"] = {display = 1, position = "maximized"},

    -- Example: Video conferencing on left, notes on right
    -- ["Zoom"] = {display = 1, position = "left-half"},
    -- ["Google Meet"] = {display = 1, position = "left-half"},
    -- ["Microsoft Teams"] = {display = 1, position = "left-half"},

    -- Keep Slack visible for messages
    -- ["Slack"] = {display = 1, position = "right-half"},

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
