local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local NetworkMgr = require("ui/network/manager")
local G_reader_settings = require("luasettings")
local _ = require("gettext")

local settings_file = "settings/timesync_plugin.lua"

local TimeSync = WidgetContainer:extend{
    name = "timesync",
}

-- 1. Generate all world timezones
local function getTimezoneOptions()
    local options = {
        neg = {}, -- UTC-12 to UTC-1
        pos = {}, -- UTC+0 to UTC+14
        special = {
            { text = "London / Lisbon (UTC+0)", offset = 0 },
            { text = "São Paulo / Brasilia (UTC-3)", offset = -180 },
            { text = "New York / Miami (UTC-5)", offset = -300 },
            { text = "India / Sri Lanka (UTC+5:30)", offset = 330 },
            { text = "Adelaide, AU (UTC+9:30)", offset = 570 },
        }
    }
    
    for i = -12, 14 do
        local sign = i >= 0 and "+" or ""
        local item = { text = string.format("UTC %s%d:00", sign, i), offset = i * 60 }
        if i < 0 then table.insert(options.neg, item)
        else table.insert(options.pos, item) end
    end
    return options
end

function TimeSync:getSavedOffset()
    local settings = G_reader_settings:open(settings_file)
    -- Default to São Paulo (-180 min) if nothing is saved
    return settings:readSetting("timezone_offset_min") or -180
end

function TimeSync:saveOffset(offset_min)
    local settings = G_reader_settings:open(settings_file)
    settings:saveSetting("timezone_offset_min", offset_min)
    settings:flush()
end

function TimeSync:syncDeviceTime(is_auto)
    if not NetworkMgr:isConnected() then
        if not is_auto then UIManager:show(InfoMessage:new{ text = "Error: Wi-Fi disconnected." }) end
        return
    end

    local info = InfoMessage:new{ text = "Synchronizing system time..." }
    if not is_auto then UIManager:show(info) end

    -- Fetch UTC date from Google
    local cmd = "curl -sI --insecure https://google.com | grep -i '^date:'"
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()

    if result and result ~= "" then
        local d, mon_str, y, h, m, s = result:match("(%d%d) (%a%a%a) (%d%d%d%d) (%d%d):(%d%d):(%d%d)")
        
        if h then
            local months = {Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12}
            local mon = months[mon_str]

            -- Calculate Unix Time
            local utc_unix = os.time({year=y, month=mon, day=d, hour=h, min=m, sec=s})
            local offset_sec = self:getSavedOffset() * 60
            local final_unix = utc_unix + offset_sec

            -- Apply to Linux System
            os.execute(string.format("date -s @%d", final_unix))
            os.execute("hwclock -w")
            
            -- Apply to Kindle Framework
            if Device:isKindle() then
                os.execute(string.format("/usr/sbin/setdate %d", final_unix))
            end

            -- Force KOReader internal update
            Device:setDateTime(final_unix)

            if not is_auto then
                UIManager:close(info)
                UIManager:show(InfoMessage:new{ text = "Time synced successfully!", timeout = 3 })
            end
            return
        end
    end

    if not is_auto then 
        UIManager:close(info)
        UIManager:show(InfoMessage:new{ text = "Sync failed: Server unreachable." }) 
    end
end

function TimeSync:init()
    self.ui.menu:registerToMainMenu(self)
    -- Auto-sync 5 seconds after network is online
    self.ui.menu:registerAction("network_connected", function()
        UIManager:scheduleIn(5, function() self:syncDeviceTime(true) end)
    end)
end

function TimeSync:addToMainMenu(menu_items)
    local tz_data = getTimezoneOptions()
    
    local function buildSubmenu(list)
        local sub = {}
        for _, tz in ipairs(list) do
            table.insert(sub, {
                text = tz.text,
                checked_func = function() return self:getSavedOffset() == tz.offset end,
                callback = function() 
                    self:saveOffset(tz.offset)
                    UIManager:show(InfoMessage:new{ text = "Timezone set to: " .. tz.text, timeout = 2 })
                end,
            })
        end
        return sub
    end

    menu_items.timesync = {
        text = "Internet Time Sync",
        sorting_hint = "tools",
        sub_item_table = {
            { 
                text = "Sync Time Now", 
                callback = function() self:syncDeviceTime(false) end 
            },
            {
                text = "Select Timezone",
                sub_item_table = {
                    { text = "Common / Special Zones", sub_item_table = buildSubmenu(tz_data.special) },
                    { text = "West (Negative UTC)", sub_item_table = buildSubmenu(tz_data.neg) },
                    { text = "East (Positive UTC)", sub_item_table = buildSubmenu(tz_data.pos) },
                }
            },
        }
    }
end

return TimeSync