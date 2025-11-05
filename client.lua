-- ct-gang / client.lua (clean rebuild)

local QBCore = exports['qb-core']:GetCoreObject()

-- ================== NUI OPEN/CLOSE ==================
local function OpenGangMenu()
    SetNuiFocus(true, true)
    -- Open panel cleanly (no demo snapshot)
    SendNUIMessage({ action = 'open' })
    -- Immediately fetch real gang from SQL-backed callback
    QBCore.Functions.TriggerCallback('ct-gang:getPlayerGang', function(gang)
        if gang then
            SendNUIMessage({ action = 'setGang', data = gang })
        end
    end)
end


local function CloseGangMenu()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)

RegisterCommand('gangmenu', function()
    OpenGangMenu()
end, false)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    if cb then cb({ ok = true }) end
end)

-- ================== WORLD -> PIXEL (affin) ==================
-- u = a11*X + a12*Y + t1
-- v = a21*X + a22*Y + t2
local A11, A12, T1 = 0.151798598000, 0.00000349709, 627.884751
local A21, A22, T2 = -0.000609547131, -0.151636800, 1275.04431

local function WorldToPixel(x, y)
    local u = A11 * x + A12 * y + T1
    local v = A21 * x + A22 * y + T2
    return u, v
end

-- ================== TRACKING ==================
local _tracking = false
local _trackThreadRunning = false

local Config_UpdateInterval = 350   -- ms
local Config_MinWorldDelta  = 0.75  -- meters
local Config_MinHeadingDeg  = 6.0   -- degrees

local function StartTracking()
    if _trackThreadRunning then return end
    _tracking = true
    _trackThreadRunning = true
    -- NUI hint
    SendNUIMessage({ action = 'toast', msg = 'Trackme ON' })
    -- Kör tråd
    CreateThread(function()
        local lastx, lasty, lasth = nil, nil, nil
        while _tracking do
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local hdg = GetEntityHeading(ped) or 0.0

            local send = false
            if lastx == nil then
                send = true
            else
                local dx = pos.x - lastx
                local dy = pos.y - lasty
                local dist = math.sqrt(dx * dx + dy * dy)
                local dh = math.abs(hdg - (lasth or 0.0))
                if dist >= Config_MinWorldDelta or dh >= Config_MinHeadingDeg then
                    send = true
                end
            end

            if send then
                lastx, lasty, lasth = pos.x, pos.y, hdg
                local px, py = WorldToPixel(pos.x, pos.y)
                SendNUIMessage({ action = 'setPlayerMarker', x = px, y = py, heading = hdg, label = 'Player' })
            end

            Wait(Config_UpdateInterval)
        end
        _trackThreadRunning = false
        SendNUIMessage({ action = 'removePlayerMarker' })
        SendNUIMessage({ action = 'toast', msg = 'Trackme OFF' })
    end)
end

local function StopTracking()
    _tracking = false
end

RegisterCommand('trackme', function()
    if _tracking then StopTracking() else StartTracking() end
end, false)

RegisterCommand('trackrate', function(_, args)
    local ms = tonumber(args[1] or '') or 350
    if ms < 100 then ms = 100 end
    if ms > 2000 then ms = 2000 end
    Config_UpdateInterval = ms
    SendNUIMessage({ action = 'toast', msg = ('Trackrate ' .. ms .. ' ms') })
end, false)

RegisterKeyMapping('gangmenu', 'Öppna gängmeny', 'keyboard', 'F6')


-- === User patch: NUI open/close & keybind (F5) ===
local nuiOpen = false

local function openGangUI(defaultTab)
    if nuiOpen then return end
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "switchTab", tab = defaultTab or "territories" })
end

local function closeGangUI()
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end

RegisterNUICallback("close", function(data, cb)
    closeGangUI()
    cb({ ok = true })
end)

RegisterCommand("gangmenu", function()
    openGangUI("overview")
end, false)

RegisterKeyMapping("gangmenu", "Öppna Gang-menyn", "keyboard", "F5")


-- När servern ber om refresh, hämta från callback och skicka till NUI
RegisterNetEvent('ct-gang:client:refresh', function()
    QBCore.Functions.TriggerCallback('ct-gang:getPlayerGang', function(gang)
        if gang then
            SendNUIMessage({ action = 'setGang', data = gang })
        end
    end)
end)


-- Ensure we have gang cached early after resource start and on NUI's request
CreateThread(function()
    Wait(1000)
    QBCore.Functions.TriggerCallback('ct-gang:getPlayerGang', function(gang)
        if gang then
            SendNUIMessage({ action = 'setGang', data = gang })
        end
    end)
end)

-- When NUI asks for a refresh (after DOMContentLoaded), send current gang
RegisterNUICallback('noop', function(d, cb) cb({ok=true}) end) -- placeholder

-- Since NUI can't directly call Lua here, just refresh also on menu open which we already do.
-- (If needed, we could add a RegisterNUICallback to listen, but keeping minimal.)
