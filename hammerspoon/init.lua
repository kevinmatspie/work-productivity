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

-- Check if current time is within the morning window
local function isWithinMorningWindow()
    local currentHour = tonumber(os.date("%H"))
    local startHour = userConfig.morningWindowStart or 7
    local endHour = userConfig.morningWindowEnd or 10
    return currentHour >= startHour and currentHour < endHour
end

-- Set Slack status with retry logic (exponential backoff)
-- Calls callback(success) when complete
local function setSlackStatusWithRetry(statusText, statusEmoji, expiration, presence, callback)
    -- Only proceed if Slack integration is enabled and token is configured
    if not userConfig.slackIntegration or not userConfig.slackIntegration.enabled then
        log("Slack integration disabled, skipping status update")
        if callback then callback(true) end  -- Consider disabled as success
        return
    end

    if not userConfig.slackIntegration.token then
        log("Slack token not configured, skipping status update")
        if callback then callback(true) end  -- Consider unconfigured as success
        return
    end

    local token = userConfig.slackIntegration.token
    local maxRetries = 3
    local retryDelays = {5, 10, 20}  -- Exponential backoff: 5s, 10s, 20s

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

    local url = "https://slack.com/api/users.profile.set"
    local headers = {
        ["Authorization"] = "Bearer " .. token,
        ["Content-Type"] = "application/json; charset=utf-8"
    }

    local function attemptSlackUpdate(attemptNum)
        log(string.format("Slack status update attempt %d/%d", attemptNum, maxRetries))

        hs.http.asyncPost(url, profileJson, headers, function(status, body, respHeaders)
            if status == 200 then
                local response = hs.json.decode(body)
                if response and response.ok then
                    log(string.format("Slack status updated: %s %s", selectedEmoji, selectedText))
                    -- Set presence if specified
                    if presence then
                        setSlackPresence(presence)
                    end
                    if callback then callback(true) end
                    return
                else
                    log(string.format("Slack API error: %s", response and response.error or "unknown"))
                end
            else
                log(string.format("Slack HTTP error: %d", status or 0))
            end

            -- Retry if we haven't exhausted attempts
            if attemptNum < maxRetries then
                local delay = retryDelays[attemptNum] or 5
                log(string.format("Retrying Slack update in %d seconds...", delay))
                hs.timer.doAfter(delay, function()
                    attemptSlackUpdate(attemptNum + 1)
                end)
            else
                log("Slack status update failed after 3 attempts")
                notify("Slack Update Failed", "Could not update Slack status after 3 attempts")
                if callback then callback(false) end
            end
        end)
    end

    -- Start first attempt
    attemptSlackUpdate(1)
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

    -- Show initial notification, then delay before "Safe to unplug"
    -- This gives time for disk ejection (triggered by Raycast) to complete
    notify("EOD Setup", "Ejecting disks...")
    log(string.format("EOD arrangement complete: %d windows moved to primary display", moved))

    -- Wait 10 seconds for disk ejection to complete before showing "Safe to unplug"
    hs.timer.doAfter(10, function()
        notify("EOD Setup Complete", "Safe to unplug!")
        log("Disk ejection delay complete - safe to unplug")
    end)
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

-- Screen Watcher for Automatic Display Detection
local screenWatcher = nil
local previousDisplayCount = getDisplayCount()

-- Auto-work function that arranges windows first, then updates Slack with retry
local function autoArrangeForWork()
    log("Auto-arranging for work setup (3 displays)...")
    local displayCount = getDisplayCount()

    if displayCount < 3 then
        notify("Display Arrangement",
               string.format("Warning: Only %d display(s) detected. Expected 3 for work setup.", displayCount))
        return
    end

    -- Window arrangement takes priority - do this first
    local moved, failed = arrangeWindows(userConfig.workLayout)
    log(string.format("Work arrangement complete: %d moved, %d failed", moved, failed))

    notify("Work Setup Complete",
           string.format("Arranged %d window(s) across 3 displays", moved))

    -- Set Slack status with retry logic (network may still be connecting)
    if userConfig.slackIntegration and userConfig.slackIntegration.statuses and userConfig.slackIntegration.statuses.work then
        local status = userConfig.slackIntegration.statuses.work
        setSlackStatusWithRetry(status.text, status.emoji, status.expiration, status.presence, function(success)
            if success then
                log("Slack status updated successfully")
            else
                log("Slack status update failed after retries")
            end
        end)
    end
end

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

    -- Check if we've plugged in (display count increased to 3)
    if currentDisplayCount > previousDisplayCount then
        if currentDisplayCount == 3 and userConfig.autoWorkOnPlug then
            -- Check morning window if morningOnlyAutoWork is enabled
            local shouldTrigger = true
            if userConfig.morningOnlyAutoWork then
                if isWithinMorningWindow() then
                    log("Within morning window - auto-work will trigger")
                else
                    log("Outside morning window - skipping auto-work")
                    shouldTrigger = false
                end
            end

            if shouldTrigger then
                log("Plugging into 3 displays detected - triggering automatic Work setup")

                -- 3 second delay for DisplayLink and network to stabilize
                hs.timer.doAfter(3, function()
                    autoArrangeForWork()
                end)
            end
        end
    end

    previousDisplayCount = currentDisplayCount
end

-- Initialize screen watcher if either auto-EOD or auto-work is enabled
local watcherNeeded = userConfig.autoEODOnUnplug or userConfig.autoWorkOnPlug
if watcherNeeded then
    screenWatcher = hs.screen.watcher.new(handleDisplayChange)
    screenWatcher:start()
    log("Screen watcher: ENABLED")
    if userConfig.autoEODOnUnplug then
        log("  - Automatic EOD on unplug: ENABLED")
    end
    if userConfig.autoWorkOnPlug then
        local modeDesc = userConfig.morningOnlyAutoWork
            and string.format("morning only (%d:00-%d:00)", userConfig.morningWindowStart or 7, userConfig.morningWindowEnd or 10)
            or "any time"
        log(string.format("  - Automatic Work on plug-in: ENABLED (%s)", modeDesc))
    end
else
    log("Screen watcher: DISABLED (no auto features enabled)")
end

-- Wake Watcher for "wake while docked" scenario
-- Handles the case where Mac wakes from sleep already connected to dock
-- Watches multiple events because systemDidWake may not fire after hibernate (FileVault)
local wakeWatcher = nil
local lastWakeCheck = 0  -- Prevent duplicate triggers within short time

local function checkAndTriggerAutoWork(source)
    -- Debounce: Don't trigger if we just checked within the last 30 seconds
    local now = os.time()
    if now - lastWakeCheck < 30 then
        log(string.format("Skipping %s check - already checked %d seconds ago", source, now - lastWakeCheck))
        return
    end
    lastWakeCheck = now

    -- Only proceed if auto-work is enabled
    if not userConfig.autoWorkOnPlug then
        return
    end

    local displayCount = getDisplayCount()
    log(string.format("%s: %d displays detected", source, displayCount))

    if displayCount == 3 then
        -- Check morning window if morningOnlyAutoWork is enabled
        local shouldTrigger = true
        if userConfig.morningOnlyAutoWork then
            if isWithinMorningWindow() then
                log("Within morning window - auto-work will trigger")
            else
                log("Outside morning window - skipping auto-work")
                shouldTrigger = false
            end
        end

        if shouldTrigger then
            log(string.format("%s with 3 displays - triggering automatic Work setup", source))
            autoArrangeForWork()
        end
    else
        log(string.format("%s with %d displays - no auto-work needed", source, displayCount))
    end
end

local function handleWakeEvent(event)
    -- Handle multiple wake-related events for better coverage
    -- systemDidWake: Standard wake from sleep
    -- screensDidWake: Displays woke up (may fire when systemDidWake doesn't)
    -- screenIsUnlocked: User unlocked the screen (catches hibernate/FileVault scenario)

    local eventName = nil
    if event == hs.caffeinate.watcher.systemDidWake then
        eventName = "System wake"
    elseif event == hs.caffeinate.watcher.screensDidWake then
        eventName = "Screens wake"
    elseif event == hs.caffeinate.watcher.screenIsUnlocked then
        eventName = "Screen unlocked"
    end

    if eventName then
        log(string.format("Wake event: %s", eventName))

        -- Delay to let displays and network stabilize after wake
        hs.timer.doAfter(5, function()
            checkAndTriggerAutoWork(eventName)
        end)
    end
end

-- Initialize wake watcher if auto-work is enabled
if userConfig.autoWorkOnPlug then
    wakeWatcher = hs.caffeinate.watcher.new(handleWakeEvent)
    wakeWatcher:start()
    log("Wake watcher: ENABLED (systemDidWake, screensDidWake, screenIsUnlocked)")
end

-- Set up CLI for Raycast integration
hs.ipc.cliInstall()

-- Show notification on load
local features = {}
if userConfig.autoEODOnUnplug then table.insert(features, "Auto-EOD") end
if userConfig.autoWorkOnPlug then
    local modeDesc = userConfig.morningOnlyAutoWork and "AM" or "always"
    table.insert(features, string.format("Auto-Work(%s)", modeDesc))
end
local statusMsg = #features > 0 and table.concat(features, ", ") or "Manual mode"
notify("Display Manager", string.format("Hammerspoon loaded - %s", statusMsg))
log("Display arrangement module loaded successfully")

-- Startup check: If we load with 3 displays already connected, trigger auto-work
-- This handles the hibernate/FileVault scenario where Hammerspoon loads after
-- the system has already woken and displays are connected
if userConfig.autoWorkOnPlug then
    -- Short delay to let everything initialize
    hs.timer.doAfter(3, function()
        checkAndTriggerAutoWork("Startup check")
    end)
end
