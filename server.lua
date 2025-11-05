-- ct-gang / server.lua (standalone gang via SQL)
-- Uses qb-core ONLY for permissions & player lookup; DOES NOT touch PlayerData.gang/SetGang.
-- Data source of truth: table ct_gang_members (citizenid, gang, rank)

local QBCore = exports['qb-core']:GetCoreObject()

Config = Config or {}
Config.PermissionMode = Config.PermissionMode or 'qb' -- qb | ace | all

-- === Utils ===
local function canUseCommand(src)
    local mode = (Config.PermissionMode or 'qb')
    if mode == 'all' then return true end
    if src == 0 then return true end -- console
    if mode == 'ace' then return IsPlayerAceAllowed(src, 'command.gangset') end
    return QBCore.Functions.HasPermission(src,'admin') or QBCore.Functions.HasPermission(src,'god')
end

local function notify(src, msg, ntype) TriggerClientEvent('QBCore:Notify', src, msg, ntype or 'primary') end

local function getPlayer(srcOrId)
    local id = tonumber(srcOrId)
    return id and QBCore.Functions.GetPlayer(id) or nil
end

-- === SQL helpers ===
local function readGang(citizenid, cb)
    exports.oxmysql:execute('SELECT LOWER(gang) as gang, rank FROM ct_gang_members WHERE citizenid = ? LIMIT 1', {citizenid}, function(rows)
        if rows and rows[1] then
            cb(rows[1].gang, tonumber(rows[1].rank) or 0)
        else
            cb(nil, nil)
        end
    end)
end

local function upsertGang(citizenid, gang, rank, cb)
    exports.oxmysql:execute(
        'INSERT INTO ct_gang_members (citizenid, gang, rank) VALUES (?, LOWER(?), ?) ON DUPLICATE KEY UPDATE gang=VALUES(gang), rank=VALUES(rank)',
        { citizenid, gang, rank },
        function(_) if cb then cb(true) end end
    )
end

-- === Exports / Callback for other resources & NUI ===
QBCore.Functions.CreateCallback('ct-gang:getPlayerGang', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src); if not Player then cb(nil) return end
    readGang(Player.PlayerData.citizenid, function(g, r)
        local label = (Config.Gangs and Config.Gangs[g] and Config.Gangs[g].label) or g
        local rlabel = (Config.Gangs and Config.Gangs[g] and Config.Gangs[g].grades and Config.Gangs[g].grades[r] and Config.Gangs[g].grades[r].label) or tostring(r or 0)
        cb({ name = g or 'none', label = label or (g or 'none'), grade = r or 0, grade_label = rlabel })
    end)
end)

exports('GetPlayerGang', function(src)
    local Player = QBCore.Functions.GetPlayer(src); if not Player then return nil end
    local ret = nil
    readGang(Player.PlayerData.citizenid, function(g, r) ret = { name=g, grade=r } end)
    return ret
end)

-- === Commands ===

-- /gangset id gang rank : writes ONLY to SQL
RegisterCommand('gangset', function(src, args)
    if not canUseCommand(src) then if src~=0 then notify(src,'Ingen behörighet.','error') end return end
    local targetId = tonumber(args[1] or '')
    local gangName = args[2] and string.lower(args[2]) or nil
    local rank     = tonumber(args[3] or '0') or 0
    if not (targetId and gangName) then if src~=0 then notify(src,'Användning: /gangset (id) (gang) (rank)','error') end return end

    local Player = getPlayer(targetId)
    if not Player then if src~=0 then notify(src,('Hittar ej spelare %s'):format(targetId),'error') end return end

    local cid = Player.PlayerData.citizenid
    upsertGang(cid, gangName, rank, function()
        local label = (Config.Gangs and Config.Gangs[gangName] and Config.Gangs[gangName].label) or gangName
        local rlabel = (Config.Gangs and Config.Gangs[gangName] and Config.Gangs[gangName].grades and Config.Gangs[gangName].grades[rank] and Config.Gangs[gangName].grades[rank].label) or tostring(rank)
        notify(targetId, ('Du sattes till %s | Rank: %s'):format(label, rlabel), 'success')
        if src~=0 then notify(src, ('Satte %s till %s (%s)'):format(GetPlayerName(targetId), label, rlabel), 'success') end
        -- uppdatera NUI live
        TriggerClientEvent('ct-gang:client:refresh', targetId)
    end)
end)

-- /gang : show from SQL only
RegisterCommand('gang', function(src)
    local Player = getPlayer(src); if not Player then return end
    readGang(Player.PlayerData.citizenid, function(g, r)
        local label = (Config.Gangs and Config.Gangs[g] and Config.Gangs[g].label) or (g or 'none')
        local rlabel = (Config.Gangs and Config.Gangs[g] and Config.Gangs[g].grades and Config.Gangs[g].grades[r] and Config.Gangs[g].grades[r].label) or tostring(r or 0)
        notify(src, ('Du är i %s | Rank: %s'):format(label, rlabel), 'primary')
    end)
end, false)

-- Admin debug: PD vs SQL (PD will be none since we don't use core gangs, but kept for clarity)
RegisterCommand('gangdebug', function(src)
    if src ~= 0 and not (QBCore.Functions.HasPermission(src,'admin') or QBCore.Functions.HasPermission(src,'god')) then
        notify(src, 'Ingen behörighet.', 'error'); return
    end
    local Player = getPlayer(src); if not Player then return end
    local pd = Player.PlayerData.gang or {}
    local curName = pd.name or 'none'
    local curRank = (pd.grade and (pd.grade.level or pd.grade)) or 0
    readGang(Player.PlayerData.citizenid, function(sqlGang, sqlRank)
        notify(src, ("PD: %s/%s | SQL: %s/%s"):format(curName, tostring(curRank), tostring(sqlGang or 'nil'), tostring(sqlRank or 'nil')), 'primary')
    end)
end)

-- Optional: refresh callback on join so NUI updates
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if Player and Player.PlayerData and Player.PlayerData.source then
        TriggerClientEvent('ct-gang:client:refresh', Player.PlayerData.source)
    end
end)
