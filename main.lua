local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local NetworkMgr = require("ui/network/manager")
local DataStorage = require("luasettings")

local TimeSyncFork = WidgetContainer:extend{ name = "timesync-fork" }

local SETTINGS_FILE = "settings/timesync_fork_tracker.lua"

function TimeSyncFork:forceSync(is_auto)
    -- If it's the auto-sync and no network, just fail silently to not annoy the user
    if not NetworkMgr:isConnected() then
        if not is_auto then UIManager:show(InfoMessage:new{ text = "No Wi-Fi", timeout = 2 }) end
        return
    end

    -- 1. Get Timezone safely
    local loc_handle = io.popen("curl -s --insecure 'http://ip-api.com/line/?fields=timezone'")
    if not loc_handle then return end
    local detected_tz = loc_handle:read("*a"):gsub("%s+", "")
    loc_handle:close()

    if not detected_tz or #detected_tz < 2 or detected_tz:match("fail") then
        if not is_auto then UIManager:show(InfoMessage:new{ text = "Location Error", timeout = 2 }) end
        return
    end

    -- 2. Get Time safely
    local time_url = "https://timeapi.io/api/Time/current/zone?timeZone=" .. detected_tz
    local time_handle = io.popen("curl -s --insecure '" .. time_url .. "'")
    if not time_handle then return end
    local result = time_handle:read("*a")
    time_handle:close()

    -- 3. Parse and Validate
    local year, mon, day, hr, min, sec = result:match('"year":(%d+),"month":(%d+),"day":(%d+),"hour":(%d+),"minute":(%d+),"seconds":(%d+)')

    if year and mon and day and hr and min and sec then
        local ok, final_unix = pcall(os.time, {
            year = tonumber(year), month = tonumber(mon), day = tonumber(day),
            hour = tonumber(hr), min = tonumber(min), sec = tonumber(sec)
        })

        if ok then
            os.execute(string.format("date -s @%d && hwclock -w", final_unix))
            -- Optional: Show success only if manually triggered
            if not is_auto then
                UIManager:show(InfoMessage:new{ text = "Sync Success: " .. detected_tz, timeout = 2 })
            end
            return true
        end
    end

    if not is_auto then UIManager:show(InfoMessage:new{ text = "Sync Failed", timeout = 2 }) end
    return false
end

function TimeSyncFork:checkAndRunDaily()
    local settings = DataStorage:open(SETTINGS_FILE)
    local today = os.date("%Y-%m-%d")
    local last_sync = settings:readSetting("last_sync_date")

    if today ~= last_sync then
        -- Run the sync. Passing 'true' means it's the automatic daily run.
        local success = self:forceSync(true)
        
        if success then
            settings:saveSetting("last_sync_date", today)
            settings:flush()
        end
    end
end

function TimeSyncFork:onResume()
    -- Wait 2 seconds after wake to give Wi-Fi a chance to reconnect
    UIManager:scheduleIn(2, function()
        self:checkAndRunDaily()
    end)
end

function TimeSyncFork:init()
    self.ui.menu:registerToMainMenu(self)
end

-- We keep the manual button just in case you want to force it again later
function TimeSyncFork:addToMainMenu(menu_items)
    menu_items.timesync_fork = {
        text = "Force Time Sync Now",
        sorting_hint = "tools",
        callback = function() self:forceSync(false) end
    }
end

return TimeSyncFork
