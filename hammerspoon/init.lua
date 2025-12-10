-- Display Arrangement Manager for Hammerspoon
-- Manages window arrangements across multiple display configurations

-- Load user configuration
local userConfig = require("display-profiles")

-- Load secrets from external file
-- This file should be in ~/.hammerspoon/display-profiles-secrets.lua
-- It should NOT be committed to version control
local function loadSecrets()
    local secretsPath = os.getenv("HOME") .. "/.hammerspoon/display-profiles-secrets.lua"

    -- Check if file exists
    local file = io.open(secretsPath, "r")
    if not file then
        return nil
    end
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

-- Merge secrets into config
local secrets = loadSecrets()
if secrets then
    -- Merge Slack token if provided
    if secrets.slackToken and userConfig.slackIntegration then
        userConfig.slackIntegration.token = secrets.slackToken
        print("[DisplayManager] Loaded Slack token from secrets file")
    end

    -- Future: Add other secrets here
    -- if secrets.calendarToken then
    --     userConfig.calendarToken = secrets.calendarToken
    -- end
else
    print("[DisplayManager] No secrets file found at ~/.hammerspoon/display-profiles-secrets.lua")
    if userConfig.slackIntegration and userConfig.slackIntegration.enabled then
        print("[DisplayManager] WARNING: Slack integration enabled but no token configured")
    end
end

-- Helper Functions
local function log(message)
    print(string.format("[DisplayManager] %s", message))
end

local function notify(title, message)
    hs.notify.new({title=title, informativeText=message}):send()
end

local function getDisplayCount()
    return #hs.screen.allScreens()
end

local function getPrimaryScreen()
    return hs.screen.primaryScreen()
end

local function getScreenByIndex(index)
    local screens = hs.screen.allScreens()
    -- Sort screens by position (left to right)
    table.sort(screens, function(a, b)
        return a:frame().x < b:frame().x
    end)
    return screens[index]
end

local function moveWindowToScreen(window, screenIndex, position)
    if not window then
        log("Window not found")
        return false
    end

    local screen = getScreenByIndex(screenIndex)
    if not screen then
        log(string.format("Screen %d not found", screenIndex))
        return false
    end

    -- Move window to screen
    window:moveToScreen(screen, false, true)

    -- Apply position/size if specified
    if position then
        local screenFrame = screen:frame()
        local windowFrame = window:frame()

        if position == "maximized" then
            window:maximize()
        elseif position == "left-half" then
            windowFrame.x = screenFrame.x
            windowFrame.y = screenFrame.y
            windowFrame.w = screenFrame.w / 2
            windowFrame.h = screenFrame.h
            window:setFrame(windowFrame)
        elseif position == "right-half" then
            windowFrame.x = screenFrame.x + (screenFrame.w / 2)
            windowFrame.y = screenFrame.y
            windowFrame.w = screenFrame.w / 2
            windowFrame.h = screenFrame.h
            window:setFrame(windowFrame)
        elseif position == "top-half" then
            windowFrame.x = screenFrame.x
            windowFrame.y = screenFrame.y
            windowFrame.w = screenFrame.w
            windowFrame.h = screenFrame.h / 2
            window:setFrame(windowFrame)
        elseif position == "bottom-half" then
            windowFrame.x = screenFrame.x
            windowFrame.y = screenFrame.y + (screenFrame.h / 2)
            windowFrame.w = screenFrame.w
            windowFrame.h = screenFrame.h / 2
            window:setFrame(windowFrame)
        elseif position == "center" then
            windowFrame.x = screenFrame.x + (screenFrame.w - windowFrame.w) / 2
            windowFrame.y = screenFrame.y + (screenFrame.h - windowFrame.h) / 2
            window:setFrame(windowFrame)
        elseif type(position) == "table" then
            -- Custom frame: {x, y, w, h} as absolute coordinates
            windowFrame.x = position.x or position[1]
            windowFrame.y = position.y or position[2]
            windowFrame.w = position.w or position[3]
            windowFrame.h = position.h or position[4]
            window:setFrame(windowFrame)
        end
    end

    return true
end

local function arrangeWindows(layout)
    local moved = 0
    local failed = 0

    for appName, config in pairs(layout) do
        local app = hs.application.find(appName, true)  -- exact match only

        if app and app.allWindows then
            local windows = app:allWindows()
            for _, window in ipairs(windows) do
                if window:isStandard() and window:isVisible() then
                    local success = moveWindowToScreen(window, config.display, config.position)
                    if success then
                        moved = moved + 1
                        log(string.format("Moved %s to display %d", appName, config.display))
                    else
                        failed = failed + 1
                        log(string.format("Failed to move %s", appName))
                    end
                end
            end
        else
            log(string.format("App not running: %s", appName))
        end
    end

    return moved, failed
end

local function ejectDisk(diskName)
    local script = string.format([[
        tell application "Finder"
            if disk "%s" exists then
                eject disk "%s"
                return "success"
            else
                return "not found"
            end if
        end tell
    ]], diskName, diskName)

    local ok, result = hs.osascript.applescript(script)
    return ok and result == "success"
end

local function setSlackPresence(presence)
    -- Only proceed if Slack integration is enabled and token is configured
    if not userConfig.slackIntegration or not userConfig.slackIntegration.enabled then
        return
    end

    if not userConfig.slackIntegration.token then
        return
    end

    local token = userConfig.slackIntegration.token
    local url = "https://slack.com/api/users.setPresence"
    local headers = {
        ["Authorization"] = "Bearer " .. token,
        ["Content-Type"] = "application/json; charset=utf-8"
    }
    local body = hs.json.encode({presence = presence})

    hs.http.asyncPost(url, body, headers, function(status, body, headers)
        if status == 200 then
            local response = hs.json.decode(body)
            if response and response.ok then
                log(string.format("Slack presence set to: %s", presence))
            else
                log(string.format("Slack presence API error: %s", response.error or "unknown"))
            end
        else
            log(string.format("Slack presence HTTP error: %d", status))
        end
    end)
end

local function setSlackStatus(statusText, statusEmoji, expiration, presence)
    -- Only proceed if Slack integration is enabled and token is configured
    if not userConfig.slackIntegration or not userConfig.slackIntegration.enabled then
        log("Slack integration disabled, skipping status update")
        return
    end

    if not userConfig.slackIntegration.token then
        log("Slack token not configured, skipping status update")
        return
    end

    local token = userConfig.slackIntegration.token

    -- Support text as string or table (random selection from table)
    local selectedText = statusText
    if type(statusText) == "table" then
        selectedText = statusText[math.random(#statusText)]
    end

    -- Support emoji as string or table (random selection from table)
    local selectedEmoji = statusEmoji
    if type(statusEmoji) == "table" then
        selectedEmoji = statusEmoji[math.random(#statusEmoji)]
    end

    -- Build the status profile JSON
    local profile = {
        status_text = selectedText or "",
        status_emoji = selectedEmoji or "",
    }

    -- Add expiration if provided (Unix timestamp)
    if expiration then
        profile.status_expiration = expiration
    end

    -- Convert to JSON - Slack expects {profile: {...}}
    local profileJson = hs.json.encode({profile = profile})

    -- Make API call to Slack
    local url = "https://slack.com/api/users.profile.set"
    local headers = {
        ["Authorization"] = "Bearer " .. token,
        ["Content-Type"] = "application/json; charset=utf-8"
    }

    hs.http.asyncPost(url, profileJson, headers, function(status, body, headers)
        if status == 200 then
            local response = hs.json.decode(body)
            if response and response.ok then
                log(string.format("Slack status updated: %s %s", selectedEmoji, selectedText))
            else
                log(string.format("Slack API error: %s", response.error or "unknown"))
            end
        else
            log(string.format("Slack HTTP error: %d", status))
        end
    end)

    -- Set presence if specified ("auto" or "away")
    if presence then
        setSlackPresence(presence)
    end
end

local function bringAppToForeground(appName)
    local app = hs.application.find(appName)
    if app then
        app:activate()
        log(string.format("Brought %s to foreground", appName))
        return true
    else
        log(string.format("App not running: %s", appName))
        return false
    end
end

-- Main Functions

function arrangeForWork()
    log("Arranging for work setup (3 displays)...")
    local displayCount = getDisplayCount()

    if displayCount < 3 then
        notify("Display Arrangement",
               string.format("Warning: Only %d display(s) detected. Expected 3 for work setup.", displayCount))
        return
    end

    local moved, failed = arrangeWindows(userConfig.workLayout)

    -- Set Slack status if configured
    if userConfig.slackIntegration and userConfig.slackIntegration.statuses and userConfig.slackIntegration.statuses.work then
        local status = userConfig.slackIntegration.statuses.work
        setSlackStatus(status.text, status.emoji, status.expiration, status.presence)
    end

    notify("Work Setup Complete",
           string.format("Arranged %d window(s) across 3 displays", moved))
    log(string.format("Work arrangement complete: %d moved, %d failed", moved, failed))
end

function arrangeForHome()
    log("Arranging for home setup (2 displays)...")
    local displayCount = getDisplayCount()

    if displayCount < 2 then
        notify("Display Arrangement",
               string.format("Warning: Only %d display(s) detected. Expected 2 for home setup.", displayCount))
        return
    end

    local moved, failed = arrangeWindows(userConfig.homeLayout)

    -- Set Slack status if configured
    if userConfig.slackIntegration and userConfig.slackIntegration.statuses and userConfig.slackIntegration.statuses.home then
        local status = userConfig.slackIntegration.statuses.home
        setSlackStatus(status.text, status.emoji, status.expiration, status.presence)
    end

    notify("Home Setup Complete",
           string.format("Arranged %d window(s) across 2 displays", moved))
    log(string.format("Home arrangement complete: %d moved, %d failed", moved, failed))
end

function arrangeForEOD()
    log("Preparing for end of day (consolidating to laptop)...")

    -- Eject Time Machine disk if configured
    if userConfig.timeMachineDisk then
        log(string.format("Attempting to eject %s...", userConfig.timeMachineDisk))
        local ejected = ejectDisk(userConfig.timeMachineDisk)

        if ejected then
            log("Time Machine disk ejected successfully")
        else
            notify("EOD Setup",
                   string.format("Could not eject %s - make sure backups are complete", userConfig.timeMachineDisk))
        end
    end

    -- Move all windows to primary (laptop) screen
    local moved = 0
    -- local allApps = hs.application.runningApplications()

    -- for _, app in ipairs(allApps) do
    --     local windows = app:allWindows()
    --     for _, window in ipairs(windows) do
    --         if window:isStandard() and window:isVisible() then
    --             local currentScreen = window:screen()
    --             if currentScreen ~= getPrimaryScreen() then
    --                 window:moveToScreen(getPrimaryScreen(), false, true)
    --                 moved = moved + 1
    --             end
    --         end
    --     end
    -- end

    -- Set Slack status if configured
    if userConfig.slackIntegration and userConfig.slackIntegration.statuses and userConfig.slackIntegration.statuses.eod then
        local status = userConfig.slackIntegration.statuses.eod
        setSlackStatus(status.text, status.emoji, status.expiration, status.presence)
    end

    notify("EOD Setup Complete", "Safe to unplug!")
    log(string.format("EOD arrangement complete: %d windows moved to primary display", moved))
end

function arrangeForMeeting()
    log("Arranging for meeting (laptop only)...")

    -- Move all windows to laptop screen
    local moved = 0
    local allApps = hs.application.runningApplications()

    for _, app in ipairs(allApps) do
        local windows = app:allWindows()
        for _, window in ipairs(windows) do
            if window:isStandard() and window:isVisible() then
                local currentScreen = window:screen()
                if currentScreen ~= getPrimaryScreen() then
                    window:moveToScreen(getPrimaryScreen(), false, true)
                    moved = moved + 1
                end
            end
        end
    end

    -- Apply meeting layout if configured
    if userConfig.meetingLayout then
        arrangeWindows(userConfig.meetingLayout)
    end

    -- Bring note-taking app to foreground if configured
    if userConfig.meetingNotesApp then
        -- Small delay to let window arrangement finish
        hs.timer.doAfter(0.5, function()
            bringAppToForeground(userConfig.meetingNotesApp)
        end)
    end

    -- Set Slack status if configured
    if userConfig.slackIntegration and userConfig.slackIntegration.statuses and userConfig.slackIntegration.statuses.meeting then
        local status = userConfig.slackIntegration.statuses.meeting
        setSlackStatus(status.text, status.emoji, status.expiration, status.presence)
    end

    notify("Meeting Setup Complete",
           string.format("Ready for meeting - %s opened", userConfig.meetingNotesApp or "windows arranged"))
    log(string.format("Meeting arrangement complete: %d windows moved to primary display", moved))
end

function arrangeForWalk()
    log("Setting up for walk...")

    -- Set Slack status if configured
    if userConfig.slackIntegration and userConfig.slackIntegration.statuses and userConfig.slackIntegration.statuses.walk then
        local status = userConfig.slackIntegration.statuses.walk
        -- Calculate expiration timestamp from minutes
        local expiration = nil
        local expirationSeconds = nil
        if status.expirationMinutes then
            expirationSeconds = status.expirationMinutes * 60
            expiration = os.time() + expirationSeconds
        end
        setSlackStatus(status.text, status.emoji, expiration, status.presence)

        -- Schedule presence restoration when status expires
        if expirationSeconds and status.presence == "away" then
            hs.timer.doAfter(expirationSeconds, function()
                log("Walk timer expired - restoring presence to auto")
                setSlackPresence("auto")
            end)
        end
    end

    notify("Walk Setup Complete", "Screen will lock. Status clears in 30 min.")
    log("Walk setup complete")

    -- Prevent system sleep for 30 minutes to allow Time Machine backups to complete
    local walkDuration = 30 * 60  -- 30 minutes in seconds
    hs.caffeinate.set("systemIdle", true, true)
    log("Caffeinate assertion set - preventing system sleep for 30 minutes")
    hs.timer.doAfter(walkDuration, function()
        hs.caffeinate.set("systemIdle", false, true)
        log("Caffeinate assertion released - system can sleep normally")
    end)

    -- Lock the screen after a brief delay for notification to show
    hs.timer.doAfter(1, function()
        hs.caffeinate.lockScreen()
    end)
end

function arrangeForLunch()
    log("Setting up for lunch...")

    -- Set Slack status if configured
    if userConfig.slackIntegration and userConfig.slackIntegration.statuses and userConfig.slackIntegration.statuses.lunch then
        local status = userConfig.slackIntegration.statuses.lunch
        -- Calculate expiration timestamp from minutes
        local expiration = nil
        local expirationSeconds = nil
        if status.expirationMinutes then
            expirationSeconds = status.expirationMinutes * 60
            expiration = os.time() + expirationSeconds
        end
        setSlackStatus(status.text, status.emoji, expiration, status.presence)

        -- Schedule presence restoration when status expires
        if expirationSeconds and status.presence == "away" then
            hs.timer.doAfter(expirationSeconds, function()
                log("Lunch timer expired - restoring presence to auto")
                setSlackPresence("auto")
            end)
        end
    end

    notify("Lunch Setup Complete", "Screen will lock. Status clears in 1 hour.")
    log("Lunch setup complete")

    -- Prevent system sleep for 1 hour to allow Time Machine backups to complete
    local lunchDuration = 60 * 60  -- 1 hour in seconds
    hs.caffeinate.set("systemIdle", true, true)
    log("Caffeinate assertion set - preventing system sleep for 1 hour")
    hs.timer.doAfter(lunchDuration, function()
        hs.caffeinate.set("systemIdle", false, true)
        log("Caffeinate assertion released - system can sleep normally")
    end)

    -- Lock the screen after a brief delay for notification to show
    hs.timer.doAfter(1, function()
        hs.caffeinate.lockScreen()
    end)
end

-- Screen Watcher for Automatic Unplug Detection
local screenWatcher = nil
local previousDisplayCount = getDisplayCount()

local function handleDisplayChange()
    local currentDisplayCount = getDisplayCount()

    log(string.format("Display change detected: %d -> %d displays", previousDisplayCount, currentDisplayCount))

    -- Check if we've unplugged (display count decreased)
    if currentDisplayCount < previousDisplayCount then
        -- Only trigger if we're going down to just the laptop screen
        -- and the feature is enabled in config
        if currentDisplayCount == 1 and userConfig.autoEODOnUnplug then
            log("Unplugging detected - triggering automatic EOD")

            -- Small delay to let macOS finish display changes
            hs.timer.doAfter(1, function()
                arrangeForEOD()
            end)
        end
    end

    previousDisplayCount = currentDisplayCount
end

-- Initialize screen watcher if auto-EOD is enabled
if userConfig.autoEODOnUnplug then
    screenWatcher = hs.screen.watcher.new(handleDisplayChange)
    screenWatcher:start()
    log("Automatic EOD on unplug: ENABLED")
else
    log("Automatic EOD on unplug: DISABLED")
end

-- Set up CLI for Raycast integration
hs.ipc.cliInstall()

-- Show notification on load
local statusMsg = userConfig.autoEODOnUnplug and "Auto-EOD enabled" or "Manual mode"
notify("Display Manager", string.format("Hammerspoon loaded - %s", statusMsg))
log("Display arrangement module loaded successfully")
