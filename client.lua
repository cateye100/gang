-- ct-gang / client.lua (HUD prompt + timer)
local QBCore = exports['qb-core']:GetCoreObject()

-- NUI helpers
local function Nui(action, data)
    SendNUIMessage((function()
        local t = data or {}
        t.action = action
        return t
    end)())
end

local function ShowPrompt(text)
    Nui('hud:prompt', { show = true, text = text or '' })
end

local function HidePrompt()
    Nui('hud:prompt', { show = false })
end

-- Open/close menu (kept from your original)
local function openGangUI(defaultTab)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "switchTab", tab = defaultTab or "territories" })
    -- refresh gang name
    QBCore.Functions.TriggerCallback('ct-gang:getPlayerGang', function(gang)
        if gang then SendNUIMessage({ action = 'setGang', data = gang }) end
    end)
end
local function closeGangUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end
RegisterNUICallback("close", function(_, cb) closeGangUI(); if cb then cb({ok=true}) end end)
RegisterCommand("gangmenu", function() openGangUI("overview") end, false)
RegisterKeyMapping("gangmenu", "Öppna Gang-menyn", "keyboard", "F5")

-- ===== Map/areas sync =====
local __lastAreas = {}
RegisterNUICallback('uiReady', function(_, cb)
    cb({ ok = true, areas = __lastAreas })
    TriggerServerEvent('ct-gang:areas:request')
end)
RegisterNetEvent('ct-gang:areas:response', function(list)
    __lastAreas = list or {}
    HidePrompt()
    SendNUIMessage({ action = 'ctgang:setAreas', areas = __lastAreas })
end)

-- ===== Gang cache =====
local __playerGang = nil
CreateThread(function()
    while true do
        QBCore.Functions.TriggerCallback('ct-gang:getPlayerGang', function(g) __playerGang = g and (g.name or g.label) or nil end)
        Wait(5000)
    end
end)

-- ===== Territory detection & custom prompt/timer =====
local function pointInPoly(x, y, poly)
    local inside = false
    local j = #poly
    for i=1,#poly do
        local xi, yi = poly[i].x or poly[i][1], poly[i].y or poly[i][2]
        local xj, yj = poly[j].x or poly[j][1], poly[j].y or poly[j][2]
        local intersect = ((yi>y) ~= (yj>y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) ~= 0 and (yj - yi) or 1e-9) + xi)
        if intersect then inside = not inside end
        j = i
    end
    return inside
end

local function territoryKey(label)
    if not label then return nil end
    return string.lower((label:gsub('%s+','_')))
end

local __currentKey = nil
local __eligible = false
local __eligibleKey = nil
local __eligibleLabel = nil
local __capActive = false

-- coarse detection loop
CreateThread(function()
    while true do
        local ped = PlayerPedId(); local coords = GetEntityCoords(ped)
        local x, y = coords.x, coords.y
        local found = nil
        for _, ar in ipairs(__lastAreas or {}) do
            if ar.polygon_world and #ar.polygon_world >= 3 then
                if pointInPoly(x, y, ar.polygon_world) then found = ar; break end
            end
        end
        local key = found and territoryKey(found.label) or nil

        if key and key ~= __currentKey and __playerGang then
            local owner = found and found.owner or nil
            local msg = owner and ('Du gick in i '..owner..'s territorium') or 'Du gick in i omarkerat territorium'
            TriggerEvent('QBCore:Notify', msg, 'primary')
        end
        __currentKey = key

        local eligible = false
        if key and __playerGang and found and (not found.owner or (string.lower(found.owner) ~= string.lower(__playerGang))) then eligible = true end
        __eligible = eligible
        __eligibleKey = key
        __eligibleLabel = found and found.label or nil

        if (not eligible) or __capActive then HidePrompt() end
        Wait(250)
    end
end)

-- fine input loop
CreateThread(function()
    while true do
        if __eligible and (not __capActive) then
            ShowPrompt(('Tryck [E] för att ta över Territorium %s'):format(__eligibleLabel or ''))
            if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0,38) then
                __capActive = true
                HidePrompt()
                TriggerEvent('QBCore:Notify', 'Startar övertagande...', 'primary')
                local dur = 5 -- seconds (match server.lua test timer)
                SendNUIMessage({ action='hud:timerStart', title='Tar över: '..(__eligibleLabel or ''), total=dur })
                TriggerServerEvent('ct-gang:territories:startCapture', { key = __eligibleKey, gang = string.lower(__playerGang or ''), pos = { x = GetEntityCoords(PlayerPedId()).x, y = GetEntityCoords(PlayerPedId()).y } })
                CreateThread(function()
                    local secs = dur
                    while secs > 0 do
                        Wait(1000); secs = secs - 1
                        SendNUIMessage({ action='hud:timerUpdate', remaining=secs })
                    end
                    Wait(250)
                    SendNUIMessage({ action='hud:timerEnd' })
                    __capActive = false
                end)
            end
        end
        Wait(0)
    end
end)

-- Send gang color map from Config to NUI
local function sendGangColors()
    local map = {}
    if Config and Config.Gangs then
        for k,v in pairs(Config.Gangs) do
            local c = (v.color or {255,255,255})
            map[k] = { r = c[1] or 255, g = c[2] or 255, b = c[3] or 255 }
        end
    end
    SendNUIMessage({ action = 'ctgang:setGangColors', colors = map })
end

local function ctgPushMembers(data)
    if not data then return end
    SendNUIMessage({ action = 'members:set', data = data })
end

local function ctgRequestMembers(cb)
    QBCore.Functions.TriggerCallback('ct-gang:members:list', function(payload)
        if payload then
            ctgPushMembers(payload)
        end
        if cb then cb(payload) end
    end)
end

-- quick gang on resource start to set NUI title
CreateThread(function()
    Wait(1000)
    sendGangColors()
    QBCore.Functions.TriggerCallback('ct-gang:getPlayerGang', function(gang)
        if gang then SendNUIMessage({ action = 'setGang', data = gang }) end
    end)
    ctgRequestMembers()
end)

-- refresh from server ask
RegisterNetEvent('ct-gang:client:refresh', function()
    sendGangColors()
    QBCore.Functions.TriggerCallback('ct-gang:getPlayerGang', function(gang)
        if gang then SendNUIMessage({ action = 'setGang', data = gang }) end
    end)
    ctgRequestMembers()
end)

RegisterNetEvent('ct-gang:members:refresh', function()
    ctgRequestMembers()
end)

RegisterNUICallback('membersGet', function(_, cb)
    ctgRequestMembers(function(data)
        if cb then cb({ ok = true, data = data }) end
    end)
end)

RegisterNUICallback('membersSetRank', function(data, cb)
    local payload = data or {}
    local cid = payload.citizenid or payload.cid
    local rank = tonumber(payload.rank)
    if cid and rank then
        TriggerServerEvent('ct-gang:members:setRank', { citizenid = cid, rank = rank })
    end
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('membersKick', function(data, cb)
    local payload = data or {}
    local cid = payload.citizenid or payload.cid
    if cid then
        TriggerServerEvent('ct-gang:members:kick', cid)
    end
    if cb then cb({ ok = true }) end
end)


-- ctg_tokens_poll_thread: Poll DB every 5s and update NUI
CreateThread(function()
    while true do
        Wait(5000)
        QBCore.Functions.TriggerCallback('ct-gang:getGangTokens', function(v)
            SendNUIMessage({ action='update', data={ shop = { tokens = tonumber(v) or 0 } } })
        end)
    end
end)


-- ctg_tokens_poll_every5s: ask server for fresh DB value and update NUI
CreateThread(function()
    while true do
        Wait(5000) -- 5 seconds
        QBCore.Functions.TriggerCallback('ct-gang:getGangTokens', function(v)
            SendNUIMessage({ action='update', data={ shop = { tokens = tonumber(v) or 0 } } })
        end)
    end
end)



local CourierDefaultLocation = vector4(1289.51, -3334.27, 5.9, 26.59)
local CourierVehicleDefault = vector4(1288.59, -3337.59, 5.92, 178.55)
local CourierBlipSprite = 898
local CourierBlipColour = 8 -- pink
local CourierModel = joaat('cs_chengsr')
local CourierVehicleModel = joaat('rumpo')
local CourierScenario = 'WORLD_HUMAN_GUARD_STAND'
local CourierOrigin = vector4(1122.77, 267.53, 80.88, 111.23)

local function ctgVector4FromTable(value, fallback)
    fallback = fallback or CourierDefaultLocation

    local function toComponents(vec)
        if not vec then return nil end
        local t = type(vec)
        if t == 'vector4' then
            return vec.x + 0.0, vec.y + 0.0, vec.z + 0.0, vec.w + 0.0
        elseif t == 'vector3' then
            return vec.x + 0.0, vec.y + 0.0, vec.z + 0.0, nil
        elseif t == 'table' then
            local x = vec.x or vec[1]
            local y = vec.y or vec[2]
            local z = vec.z or vec[3]
            local w = vec.w or vec.heading or vec.h or vec[4]
            return x and (x + 0.0) or nil, y and (y + 0.0) or nil, z and (z + 0.0) or nil, w and (w + 0.0) or nil
        end
        return nil
    end

    local fx, fy, fz, fw = toComponents(fallback)
    fx = fx or 0.0; fy = fy or 0.0; fz = fz or 0.0; fw = fw or 0.0

    local x, y, z, w = toComponents(value)
    x = x or fx
    y = y or fy
    z = z or fz
    w = w or fw

    return vector4(x or 0.0, y or 0.0, z or 0.0, w or 0.0)
end

local CourierOrders = {}

local function ctgEnsureCourierState(orderId)
    if not orderId then return nil end
    if CourierOrders[orderId] then return CourierOrders[orderId] end
    CourierOrders[orderId] = {
        id = orderId,
        location = CourierDefaultLocation,
        vehicleLocation = CourierVehicleDefault,
        hint = CourierDefaultLocation,
        start = CourierOrigin,
        hasPending = false,
        awaitingRoute = false,
        traveling = false,
        travelMonitorActive = false,
        preArrivalNotified = false,
        arrived = false,
        departThread = nil,
        targetRegistered = false,
        targetWaitThread = nil,
        ped = nil,
        vehicle = nil,
        blip = nil
    }
    return CourierOrders[orderId]
end

local function ctgDeleteCourierState(orderId)
    if not orderId then return end
    CourierOrders[orderId] = nil
end

local function ctgWaitForVehicleToReach(vehicle, dest, tolerance, timeout)
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    local start = GetGameTimer()
    tolerance = tolerance or 2.0
    timeout = timeout or 8000
    while DoesEntityExist(vehicle) and GetGameTimer() - start < timeout do
        local pos = GetEntityCoords(vehicle)
        if #(pos - dest) <= tolerance then
            return true
        end
        Wait(100)
    end
    return false
end

local function ctgWaitForVehicleToSettle(vehicle, timeout)
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    timeout = timeout or 4000
    local start = GetGameTimer()
    while DoesEntityExist(vehicle) and GetGameTimer() - start < timeout do
        if GetEntitySpeed(vehicle) <= 0.5 then
            return true
        end
        Wait(100)
    end
    return false
end

local function ctgWaitForPedToLeaveVehicle(ped, vehicle, timeout)
    if not ped or not DoesEntityExist(ped) then return false end
    timeout = timeout or 5000
    local start = GetGameTimer()
    while DoesEntityExist(ped) and GetGameTimer() - start < timeout do
        if not vehicle or not DoesEntityExist(vehicle) then return true end
        if GetVehiclePedIsIn(ped, false) ~= vehicle then
            return true
        end
        Wait(100)
    end
    return GetVehiclePedIsIn(ped, false) ~= vehicle
end

local function ctgWaitForPedToReach(ped, dest, tolerance, timeout)
    if not ped or not DoesEntityExist(ped) then return false end
    tolerance = tolerance or 0.9
    timeout = timeout or 6000
    local start = GetGameTimer()
    while DoesEntityExist(ped) and GetGameTimer() - start < timeout do
        local pos = GetEntityCoords(ped)
        if #(pos - dest) <= tolerance then
            return true
        end
        Wait(100)
    end
    return false
end

local function ctgSetCourierLocation(state, loc)
    if not state then return nil end
    if loc then
        state.location = ctgVector4FromTable(loc, state.location or CourierDefaultLocation)
    end
    return state.location
end

local function ctgSetCourierVehicleLocation(state, loc)
    if not state then return nil end
    if loc then
        state.vehicleLocation = ctgVector4FromTable(loc, state.vehicleLocation or CourierVehicleDefault)
    end
    return state.vehicleLocation
end

local function ctgSetCourierHint(state, loc)
    if not state then return nil end
    if loc then
        state.hint = ctgVector4FromTable(loc, state.hint or CourierDefaultLocation)
    end
    return state.hint
end

local function ctgClearCourierBlip(state)
    if not state then return end
    if state.blip and DoesBlipExist(state.blip) then
        RemoveBlip(state.blip)
    end
    state.blip = nil
end

local function ctgUpdateCourierBlip(state)
    if not state then return end
    if not state.hasPending then
        ctgClearCourierBlip(state)
        return
    end

    local hint = state.hint or state.location or CourierDefaultLocation
    if not hint or not hint.x then
        ctgClearCourierBlip(state)
        return
    end

    if state.blip and DoesBlipExist(state.blip) then
        SetBlipCoords(state.blip, hint.x + 0.0, hint.y + 0.0, hint.z + 0.0)
        return
    end

    local blip = AddBlipForCoord(hint.x + 0.0, hint.y + 0.0, hint.z + 0.0)
    SetBlipSprite(blip, CourierBlipSprite)
    SetBlipColour(blip, CourierBlipColour)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Kontaktperson')
    EndTextCommandSetBlipName(blip)
    state.blip = blip
end

local function ctgRemoveCourierTarget(state)
    if not state or not state.targetRegistered then return end
    local target = exports and exports['qb-target']
    if target and state.ped and DoesEntityExist(state.ped) then
        target:RemoveTargetEntity(state.ped)
    end
    state.targetRegistered = false
    state.targetWaitThread = nil
end

local function ctgGetCourierStart(state)
    if not state then return CourierDefaultLocation end
    local start = state.start or CourierOrigin or CourierVehicleDefault or CourierDefaultLocation
    return start or CourierDefaultLocation
end

local function ctgEnsureCourierVehicle(state, locOverride, freezeOverride)
    if not state then return nil end

    local destLoc = state.vehicleLocation or CourierVehicleDefault or CourierDefaultLocation
    local startLoc = ctgGetCourierStart(state)
    local loc = locOverride or ((state.arrived and destLoc) or startLoc)
    local freeze = freezeOverride
    if freeze == nil then
        freeze = state.arrived and true or false
    end

    if state.traveling and not locOverride and state.vehicle and DoesEntityExist(state.vehicle) then
        return state.vehicle
    end

    if state.vehicle and DoesEntityExist(state.vehicle) then
        SetEntityCoords(state.vehicle, loc.x, loc.y, loc.z, false, false, false, true)
        SetEntityHeading(state.vehicle, loc.w or 0.0)
        SetVehicleOnGroundProperly(state.vehicle)
        SetVehicleEngineOn(state.vehicle, true, true, false)
        for _, door in ipairs({0, 1, 2, 3, 4, 5}) do
            SetVehicleDoorShut(state.vehicle, door, false)
        end
        SetVehicleDoorsLocked(state.vehicle, 1)
        FreezeEntityPosition(state.vehicle, freeze)
        return state.vehicle
    end

    local model = CourierVehicleModel
    if type(model) ~= 'number' then model = joaat(model) end
    if not HasModelLoaded(model) then
        RequestModel(model)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do
            Wait(0)
        end
    end

    if not HasModelLoaded(model) then
        print('[ct-gang] Failed to load courier vehicle model')
        return nil
    end

    local veh = CreateVehicle(model, loc.x, loc.y, loc.z, loc.w or 0.0, false, false)
    if veh and veh ~= 0 then
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleDoorsLocked(veh, 1)
        SetVehicleOnGroundProperly(veh)
        SetVehicleEngineOn(veh, true, true, false)
        SetVehicleDoorsLocked(veh, 1)
        SetVehicleDoorsLockedForAllPlayers(veh, false)
        for _, door in ipairs({0, 1, 2, 3, 4, 5}) do
            SetVehicleDoorShut(veh, door, false)
        end
        FreezeEntityPosition(veh, freeze)
        state.vehicle = veh
        SetModelAsNoLongerNeeded(model)
        return veh
    end

    return nil
end

local function ctgPrepareCourierPed(state, x, y, z, heading)
    if not state then return nil end

    if type(CourierModel) ~= 'number' then
        CourierModel = joaat(CourierModel)
    end
    if CourierModel == nil or CourierModel == 0 then return nil end

    if not HasModelLoaded(CourierModel) then
        RequestModel(CourierModel)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(CourierModel) and GetGameTimer() < timeout do
            Wait(0)
        end
    end

    if not HasModelLoaded(CourierModel) then
        print('[ct-gang] Failed to load courier ped model')
        return nil
    end

    local ped = state.ped
    if ped and DoesEntityExist(ped) then
        SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        SetEntityHeading(ped, heading)
        return ped
    end

    ped = CreatePed(4, CourierModel, x, y, z, heading, false, false)
    if not ped or ped == 0 then return nil end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanBeDraggedOut(ped, false)
    SetPedRelationshipGroupHash(ped, `PLAYER`)
    SetPedKeepTask(ped, true)
    SetPedConfigFlag(ped, 32, false)
    SetPedConfigFlag(ped, 281, true)
    TaskSetBlockingOfNonTemporaryEvents(ped, true)
    state.ped = ped
    SetModelAsNoLongerNeeded(CourierModel)
    return ped
end

local function ctgDestroyCourierVehicle(state)
    if not state then return end
    if state.vehicle and DoesEntityExist(state.vehicle) then
        FreezeEntityPosition(state.vehicle, false)
        DeleteVehicle(state.vehicle)
        DeleteEntity(state.vehicle)
    end
    state.vehicle = nil
end

local function ctgRegisterCourierTarget(state)
    if not state or state.targetRegistered or not state.arrived then return end
    local ped = state.ped
    if not ped or not DoesEntityExist(ped) then return end

    local orderId = state.id

    local function addTarget(target)
        target:AddTargetEntity(ped, {
            options = {
                {
                    icon = 'fas fa-box-open',
                    label = 'Hämta beställning',
                    action = function()
                        if state.hasPending and state.arrived then
                            TriggerServerEvent('ct-gang:shop:pickup', orderId)
                        end
                    end,
                    canInteract = function(entity)
                        return state.hasPending and state.arrived and entity == ped
                    end
                }
            },
            distance = 2.0
        })
        state.targetRegistered = true
    end

    local target = exports and exports['qb-target']
    if target then
        addTarget(target)
        return
    end

    if state.targetWaitThread then return end

    state.targetWaitThread = true
    CreateThread(function()
        while state.arrived and state.hasPending and not state.targetRegistered do
            local t = exports and exports['qb-target']
            if t then
                addTarget(t)
                break
            end
            Wait(200)
        end
        state.targetWaitThread = nil
    end)
end

local function ctgHandleCourierArrival(state)
    if not state or state.arrived then return end

    state.arrived = true
    state.traveling = false
    state.travelMonitorActive = false

    local pedLoc = state.location or CourierDefaultLocation
    local pedHeading = pedLoc.w or 0.0
    local vehicleLoc = state.vehicleLocation or pedLoc
    local vehicleHeading = vehicleLoc.w or pedHeading

    local ped = state.ped
    local vehicle = state.vehicle
    if vehicle and DoesEntityExist(vehicle) then
        FreezeEntityPosition(vehicle, false)
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleEngineOn(vehicle, true, true, false)

        if ped and DoesEntityExist(ped) then
            TaskVehiclePark(ped, vehicle, vehicleLoc.x, vehicleLoc.y, vehicleLoc.z, vehicleHeading, 1, 3.0, true)
            ctgWaitForVehicleToReach(vehicle, vector3(vehicleLoc.x, vehicleLoc.y, vehicleLoc.z), 2.0, 8000)
            ctgWaitForVehicleToSettle(vehicle, 4000)
        end

        SetEntityCoords(vehicle, vehicleLoc.x, vehicleLoc.y, vehicleLoc.z, false, false, false, true)
        SetEntityHeading(vehicle, vehicleHeading)
        SetVehicleOnGroundProperly(vehicle)
        SetVehicleEngineOn(vehicle, false, true, false)
    end

    if ped and DoesEntityExist(ped) and vehicle and DoesEntityExist(vehicle) then
        TaskLeaveVehicle(ped, vehicle, 0)
        if not ctgWaitForPedToLeaveVehicle(ped, vehicle, 5000) then
            TaskWarpPedOutOfVehicle(ped, vehicle)
        end
    end

    if ped and DoesEntityExist(ped) then
        ClearPedTasksImmediately(ped)
    else
        ped = ctgPrepareCourierPed(state, pedLoc.x, pedLoc.y, pedLoc.z, pedHeading)
    end

    if ped and DoesEntityExist(ped) then
        TaskGoStraightToCoord(ped, pedLoc.x, pedLoc.y, pedLoc.z, 1.5, 5000, pedHeading, 0.1)
        if not ctgWaitForPedToReach(ped, vector3(pedLoc.x, pedLoc.y, pedLoc.z), 0.9, 6000) then
            TaskGoToCoordAnyMeans(ped, pedLoc.x, pedLoc.y, pedLoc.z, 1.5, 0, false, 786603, 0.0)
            ctgWaitForPedToReach(ped, vector3(pedLoc.x, pedLoc.y, pedLoc.z), 0.6, 4000)
        end
        SetEntityCoordsNoOffset(ped, pedLoc.x, pedLoc.y, pedLoc.z, false, false, false)
        SetEntityHeading(ped, pedHeading)
        ClearPedTasks(ped)
        TaskStartScenarioAtPosition(ped, CourierScenario, pedLoc.x, pedLoc.y, pedLoc.z, pedHeading, 0, true, false)
        SetPedKeepTask(ped, true)
    end

    if vehicle and DoesEntityExist(vehicle) then
        for _, door in ipairs({2, 3, 5}) do
            SetVehicleDoorOpen(vehicle, door, false, false)
        end
        SetVehicleDoorsLocked(vehicle, 1)
        FreezeEntityPosition(vehicle, true)
    end

    state.preArrivalNotified = true
    ctgRegisterCourierTarget(state)
    ctgUpdateCourierBlip(state)
end

local ctgEnsureCourier

local function ctgBeginCourierTravel(state)
    if not state or state.departThread then return end

    ctgRemoveCourierTarget(state)

    local startLoc = ctgGetCourierStart(state)
    local vehicle = ctgEnsureCourierVehicle(state, startLoc, false)
    if not vehicle then return end

    local ped = ctgPrepareCourierPed(state, startLoc.x, startLoc.y, startLoc.z + 0.3, startLoc.w or 0.0)
    if not ped then return end

    TaskWarpPedIntoVehicle(ped, vehicle, -1)
    SetPedKeepTask(ped, true)
    FreezeEntityPosition(vehicle, false)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleEngineOn(vehicle, true, true, false)
    for _, door in ipairs({0, 1, 2, 3, 4, 5}) do
        SetVehicleDoorShut(vehicle, door, false)
    end

    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, 1.0)

    local dest = state.vehicleLocation or state.location or CourierDefaultLocation
    TaskVehicleDriveToCoordLongrange(ped, vehicle, dest.x, dest.y, dest.z, 44.0, 1074528293, 5.0)
    SetDriveTaskDrivingStyle(ped, 1074528293)
    SetDriveTaskMaxCruiseSpeed(ped, 44.0)

    state.traveling = true
    state.arrived = false
    state.preArrivalNotified = false
    state.awaitingRoute = false

    if state.travelMonitorActive then
        state.travelMonitorActive = false
    end

    CreateThread(function()
        state.travelMonitorActive = true
        while state.travelMonitorActive and state.hasPending do
            if state.arrived then break end

            local curPed = state.ped
            local curVehicle = state.vehicle
            if not curPed or not DoesEntityExist(curPed) or not curVehicle or not DoesEntityExist(curVehicle) then
                break
            end

            local destInfo = state.location or CourierDefaultLocation
            local destVec3 = vector3(destInfo.x, destInfo.y, destInfo.z)
            local vehiclePos = GetEntityCoords(curVehicle)
            local distVehicle = #(vehiclePos - destVec3)
            if distVehicle <= 12.0 then
                ctgHandleCourierArrival(state)
                break
            end

            if not state.preArrivalNotified then
                local playerPos = GetEntityCoords(PlayerPedId())
                local distPlayer = #(playerPos - destVec3)
                if distPlayer <= 12.0 then
                    TriggerEvent('QBCore:Notify', 'Beställningen är snart framme', 'primary', 5000)
                    state.preArrivalNotified = true
                end
            end

            Wait(500)
        end

        state.travelMonitorActive = false

        if state.hasPending and not state.arrived and not state.departThread then
            state.traveling = false
            Wait(500)
            if state.hasPending then
                ctgEnsureCourier(state)
            end
        end
    end)
end

ctgEnsureCourier = function(state)
    if not state or state.departThread then return end
    if not state.hasPending then return end

    if state.arrived then
        local loc = state.location or CourierDefaultLocation
        local ped = ctgPrepareCourierPed(state, loc.x, loc.y, loc.z, loc.w or 0.0)
        if ped then
            SetEntityCoordsNoOffset(ped, loc.x, loc.y, loc.z, false, false, false)
            SetEntityHeading(ped, loc.w or 0.0)
            ClearPedTasksImmediately(ped)
            TaskStartScenarioAtPosition(ped, CourierScenario, loc.x, loc.y, loc.z, loc.w or 0.0, 0, true, false)
            SetPedKeepTask(ped, true)
        end
        ctgRegisterCourierTarget(state)
        return
    end

    if state.traveling then
        local ped = state.ped
        local vehicle = state.vehicle
        if ped and DoesEntityExist(ped) and vehicle and DoesEntityExist(vehicle) then
            return
        end
        state.traveling = false
        if ped and not DoesEntityExist(ped) then state.ped = nil end
        if vehicle and not DoesEntityExist(vehicle) then state.vehicle = nil end
    end

    ctgBeginCourierTravel(state)
end

local function ctgCourierDepart(state)
    if not state or state.departThread then return end

    state.hasPending = false
    ctgClearCourierBlip(state)
    ctgRemoveCourierTarget(state)
    state.travelMonitorActive = false
    state.traveling = false
    state.arrived = false
    state.preArrivalNotified = false
    state.targetWaitThread = nil
    state.awaitingRoute = false

    local ped = state.ped
    local vehicle = state.vehicle

    state.departThread = true

    CreateThread(function()
        if ped and DoesEntityExist(ped) then
            ClearPedTasksImmediately(ped)
        end

        if vehicle and DoesEntityExist(vehicle) then
            FreezeEntityPosition(vehicle, false)
            SetVehicleDoorsLocked(vehicle, 1)
        end

        if ped and DoesEntityExist(ped) and vehicle and DoesEntityExist(vehicle) then
            TaskEnterVehicle(ped, vehicle, -1, -1, 1.5, 1, 0)
            local start = GetGameTimer()
            local entered = false
            while GetGameTimer() - start < 5000 do
                if not DoesEntityExist(ped) then break end
                if GetVehiclePedIsIn(ped, false) == vehicle then
                    entered = true
                    break
                end
                Wait(100)
            end

            if not entered then
                TaskWarpPedIntoVehicle(ped, vehicle, -1)
                entered = (GetVehiclePedIsIn(ped, false) == vehicle)
            end

            if entered then
                Wait(250)
                for _, door in ipairs({2, 3, 5}) do
                    SetVehicleDoorShut(vehicle, door, false)
                end
                SetDriverAbility(ped, 1.0)
                SetDriverAggressiveness(ped, 1.0)
                TaskVehicleDriveWander(ped, vehicle, 40.0, 1074528293)
                SetDriveTaskDrivingStyle(ped, 1074528293)
                SetDriveTaskMaxCruiseSpeed(ped, 44.0)
            end
        end

        Wait(20000)

        if ped and DoesEntityExist(ped) then
            DeletePed(ped)
        end
        if vehicle and DoesEntityExist(vehicle) then
            DeleteVehicle(vehicle)
        end

        if state.ped == ped then state.ped = nil end
        if state.vehicle == vehicle then state.vehicle = nil end
        state.targetRegistered = false
        state.departThread = nil
        ctgClearCourierBlip(state)
        ctgDeleteCourierState(state.id)
    end)
end

local function ctgDestroyCourier(state)
    if not state then return end
    ctgRemoveCourierTarget(state)
    ctgClearCourierBlip(state)
    state.hasPending = false
    state.travelMonitorActive = false
    state.traveling = false
    state.arrived = false
    state.preArrivalNotified = false
    state.targetWaitThread = nil
    state.awaitingRoute = false
    state.departThread = nil
    if state.ped and DoesEntityExist(state.ped) then
        ClearPedTasksImmediately(state.ped)
        DeletePed(state.ped)
    end
    state.ped = nil
    ctgDestroyCourierVehicle(state)
    ctgDeleteCourierState(state.id)
end

local function ctgDestroyAllCouriers()
    local ids = {}
    for id in pairs(CourierOrders) do
        ids[#ids + 1] = id
    end
    for _, id in ipairs(ids) do
        ctgDestroyCourier(CourierOrders[id])
    end
end

RegisterNetEvent('ct-gang:shop:pickupHint', function(data)
    if type(data) ~= 'table' or not data.id then return end
    local state = ctgEnsureCourierState(data.id)
    if data.vehicle then ctgSetCourierVehicleLocation(state, data.vehicle) end
    if data.ped then ctgSetCourierLocation(state, data.ped) end
    if data.hint then ctgSetCourierHint(state, data.hint) end
    state.hasPending = true
    state.awaitingRoute = true
    local hint = state.hint or state.location
    if hint and hint.x then SetNewWaypoint(hint.x + 0.0, hint.y + 0.0) end
    ctgUpdateCourierBlip(state)
    ctgEnsureCourier(state)
end)

RegisterNetEvent('ct-gang:client:pickup', function(orderId)
    if orderId then
        TriggerServerEvent('ct-gang:shop:pickup', orderId)
        return
    end

    local nearestId = nil
    local nearestDist = 9999.0
    local playerPos = GetEntityCoords(PlayerPedId())
    for id, state in pairs(CourierOrders) do
        if state.hasPending and state.arrived then
            local ped = state.ped
            if ped and DoesEntityExist(ped) then
                local dist = #(GetEntityCoords(ped) - playerPos)
                if dist < nearestDist then
                    nearestDist = dist
                    nearestId = id
                end
            end
        end
    end

    if nearestId then
        TriggerServerEvent('ct-gang:shop:pickup', nearestId)
    end
end)

RegisterNetEvent('ct-gang:client:depotState', function(list)
    local active = {}
    if type(list) == 'table' then
        for _, entry in ipairs(list) do
            if entry and entry.id then
                local state = ctgEnsureCourierState(entry.id)
                active[entry.id] = true
                state.hasPending = true
                state.awaitingRoute = state.awaitingRoute or false
                if entry.vehicle then ctgSetCourierVehicleLocation(state, entry.vehicle) end
                if entry.ped then ctgSetCourierLocation(state, entry.ped) end
                if entry.hint then ctgSetCourierHint(state, entry.hint) end
                ctgUpdateCourierBlip(state)
                ctgEnsureCourier(state)
            end
        end
    end

    for id, state in pairs(CourierOrders) do
        if not active[id] then
            if state.hasPending then
                ctgCourierDepart(state)
            else
                ctgDestroyCourier(state)
            end
        end
    end
end)
-- === SHOP: NUI <-> LUA ===
RegisterNUICallback('shopGet', function(_, cb)
    QBCore.Functions.TriggerCallback('ct-gang:getGangTokens', function(v)
        SendNUIMessage({ action='update', data={ shop = { tokens = tonumber(v) or 0 } } })
        if cb then cb({ ok = true }) end
    end)
end)

RegisterNUICallback('shopBuy', function(data, cb)
    local item = (data and data.item) or 'phone'
    TriggerServerEvent('ct-gang:shop:buy', { item = item })
    if cb then cb({ ok = true }) end
end)
CreateThread(function()
    Wait(1500)
    TriggerServerEvent('ct-gang:shop:requestDepotState')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ctgDestroyAllCouriers()
end)

