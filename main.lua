local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local NetworkMgr = require("ui/network/manager")
local DataStorage = require("luasettings")
local InputDialog = require("ui/widget/inputdialog")

local TimeSyncFork = WidgetContainer:extend{ name = "timesync-fork" }

local SETTINGS_FILE = "settings/timesync_fork_tracker.lua"

function TimeSyncFork:forceSync(is_auto)
    local settings = DataStorage:open(SETTINGS_FILE)
    local use_manual = settings:readSetting("use_manual")
    local manual_tz = settings:readSetting("manual_timezone") or "America/Sao_Paulo"
    
    if not NetworkMgr:isConnected() then
        if not is_auto then UIManager:show(InfoMessage:new{ text = "No Wi-Fi", timeout = 2 }) end
        return false
    end

    local target_tz = ""

    if use_manual then
        target_tz = manual_tz
    else
        local loc_handle = io.popen("curl -s --insecure 'http://ip-api.com/line/?fields=timezone'")
        if loc_handle then
            target_tz = loc_handle:read("*a"):gsub("%s+", "")
            loc_handle:close()
        end
    end

    if not target_tz or #target_tz < 2 or target_tz:match("fail") then
        if not is_auto then UIManager:show(InfoMessage:new{ text = "TZ Error", timeout = 2 }) end
        return false
    end

    local time_url = "https://timeapi.io/api/Time/current/zone?timeZone=" .. target_tz
    local time_handle = io.popen("curl -s --insecure '" .. time_url .. "'")
    if not time_handle then return false end
    local result = time_handle:read("*a")
    time_handle:close()

    local year, mon, day, hr, min, sec = result:match('"year":(%d+),"month":(%d+),"day":(%d+),"hour":(%d+),"minute":(%d+),"seconds":(%d+)')

    if year and hr then
        local ok, final_unix = pcall(os.time, {
            year = tonumber(year), month = tonumber(mon), day = tonumber(day),
            hour = tonumber(hr), min = tonumber(min), sec = tonumber(sec)
        })

        if ok then
            os.execute(string.format("date -s @%d && hwclock -w", final_unix))
            if not is_auto then
                UIManager:show(InfoMessage:new{ text = "Sync Success: " .. target_tz, timeout = 2 })
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
        if self:forceSync(true) then
            settings:saveSetting("last_sync_date", today)
            settings:flush()
        end
    end
end

function TimeSyncFork:onResume()
    UIManager:scheduleIn(3, function() self:checkAndRunDaily() end)
end

function TimeSyncFork:init()
    self.ui.menu:registerToMainMenu(self)
end

function TimeSyncFork:addToMainMenu(menu_items)
    menu_items.timesync_fork = {
        text = "Time Sync Settings",
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = "Manual Mode",
                checked_func = function()
                    local s = DataStorage:open(SETTINGS_FILE)
                    return s:readSetting("use_manual")
                end,
                callback = function()
                    local s = DataStorage:open(SETTINGS_FILE)
                    local current = s:readSetting("use_manual")
                    s:saveSetting("use_manual", not current)
                    s:flush()
                    self:forceSync(false)
                end,
            },
            {
                text = "Set Manual Timezone ID",
                callback = function()
                    local s = DataStorage:open(SETTINGS_FILE)
                    local current_tz = s:readSetting("manual_timezone") or "America/Sao_Paulo"
                    local input_dialog
                    input_dialog = InputDialog:new{
                        title = "Enter IANA Timezone ID",
                        input = current_tz,
                        buttons = {
                            {
                                {
                                    text = "Cancel",
                                    callback = function()
                                        input_dialog:onCloseKeyboard()
                                        UIManager:close(input_dialog)
                                    end,
                                },
                                {
                                    text = "Save",
                                    callback = function()
                                        local val = input_dialog:getInputValue()
                                        if val and #val > 2 then
                                            s:saveSetting("manual_timezone", val)
                                            -- Logic: Auto-enable Manual Mode if it was off
                                            if not s:readSetting("use_manual") then
                                                s:saveSetting("use_manual", true)
                                            end
                                            s:flush()
                                        end
                                        input_dialog:onCloseKeyboard()
                                        UIManager:close(input_dialog)
                                        self:forceSync(false)
                                    end,
                                },
                            },
                        },
                    }
                    UIManager:show(input_dialog)
                    input_dialog:onShowKeyboard()
                end,
            },
            {
                text = "Force Sync Now",
                callback = function() self:forceSync(false) end,
            },
        }
    }
end

return TimeSyncFork
