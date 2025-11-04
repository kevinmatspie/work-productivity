-- Display Arrangement Manager for Hammerspoon
-- Manages window arrangements across multiple display configurations

-- Load user configuration
local userConfig = require("display-profiles")

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
        end
    end

    return true
end

local function arrangeWindows(layout)
    local moved = 0
    local failed = 0

    for appName, config in pairs(layout) do
        local app = hs.application.find(appName)

        if app then
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

    notify("EOD Setup Complete",
           string.format("Moved %d window(s) to laptop display. Safe to unplug!", moved))
    log(string.format("EOD arrangement complete: %d windows moved to primary display", moved))
end

-- Set up CLI for Raycast integration
hs.ipc.cliInstall()

-- Show notification on load
notify("Display Manager", "Hammerspoon display arrangement loaded")
log("Display arrangement module loaded successfully")
