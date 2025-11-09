-- ct-gang / server.lua (standalone gang via SQL)
-- Uses qb-core ONLY for permissions & player lookup; DOES NOT touch PlayerData.gang/SetGang.
-- Data source of truth: table ct_gang_members (citizenid, gang, rank)

local QBCore = exports['qb-core']:GetCoreObject()



-- === Gang helpers: normalize, resolve gang key, fetch balance ===
local function norm(str)
    if not str then return nil end
    str = tostring(str)
    str = string.lower(str)
    str = str:gsub("%s+", "")
    return str
end

local function resolveGangKey(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(nil) return end
    local cid = Player.PlayerData.citizenid
    local qbGang = Player.PlayerData and Player.PlayerData.gang and Player.PlayerData.gang.name or nil
    qbGang = norm(qbGang)

    local sql = 'SELECT gang FROM ct_gang_members WHERE citizenid = ? LIMIT 1'
    local args = { cid }
    local function finish(g)
        cb(norm(g or qbGang))
    end

    if exports and exports.oxmysql and exports.oxmysql.scalar then
        exports.oxmysql:scalar(sql, args, function(g) finish(g) end)
    elseif MySQL and MySQL.scalar then
        MySQL.scalar(sql, args, function(g) finish(g) end)
    elseif MySQL and MySQL.Sync and MySQL.Sync.fetchScalar then
        finish(MySQL.Sync.fetchScalar(sql, args))
    else
        finish(qbGang)
    end
end

local function fetchGangBalance(gangKey, cb)
    gangKey = norm(gangKey)
    if not gangKey or gangKey == '' then cb(0) return end

    local sql = 'SELECT balance FROM ct_gang_currency WHERE gang = ? LIMIT 1'
    local args = { gangKey }
    local function finish(v)
        cb(tonumber(v) or 0)
    end

    if exports and exports.oxmysql and exports.oxmysql.scalar then
        exports.oxmysql:scalar(sql, args, function(v) finish(v) end)
    elseif MySQL and MySQL.scalar then
        MySQL.scalar(sql, args, function(v) finish(v) end)
    elseif MySQL and MySQL.Sync and MySQL.Sync.fetchScalar then
        finish(MySQL.Sync.fetchScalar(sql, args))
    else
        local n = (CTG_Tokens and CTG_Tokens[gangKey]) or 0
        finish(n)
    end
end
-- === END Gang helpers ===

-- === CT-GANG: Currency helpers (ct_gang_currency with gang/balance) ===
local CTG_TBL = 'ct_gang_currency'
local CTG_Tokens = CTG_Tokens or {}

local function ctg_hasOx() return exports and exports.oxmysql ~= nil end

local function ctg_tokensEnsureTable(cb)
    if not ctg_hasOx() then if cb then cb(true) end return end
    exports.oxmysql:execute(([[
        CREATE TABLE IF NOT EXISTS %s (
          gang VARCHAR(60) PRIMARY KEY,
          balance INT NOT NULL DEFAULT 0
        )
    ]]):format(CTG_TBL), {}, function() if cb then cb(true) end end)
end

local function ctg_tokensLoadAll(cb)
    if not ctg_hasOx() then if cb then cb(true) end return end
    exports.oxmysql:execute(('SELECT gang, balance FROM %s'):format(CTG_TBL), {}, function(rows)
        CTG_Tokens = {}
        for _, r in ipairs(rows or {}) do
            CTG_Tokens[string.lower(r.gang)] = tonumber(r.balance) or 0
        end
        if cb then cb(true) end
    end)
end

function ctg_tokensGet(key) key = string.lower(key or ''); return CTG_Tokens[key] or 0 end

local function ctg_broadcastGang(gangKey, newBal)
    gangKey = string.lower(gangKey or '')
    if gangKey == '' then return end
    local players = QBCore.Functions.GetPlayers()
    for _, id in pairs(players) do
        local Player = QBCore.Functions.GetPlayer(id)
        if Player then
            local cid = Player.PlayerData.citizenid
            if type(readGang) == 'function' then
                readGang(cid, function(g, _)
                    if g and string.lower(g) == gangKey then
                        TriggerClientEvent('ct-gang:shop:updateBalance', Player.PlayerData.source, { tokens = newBal })
                    end
                end)
            end
        end
    end
end

function ctg_tokensSet(key, value, cb)
    key = string.lower(key or ''); value = math.max(0, tonumber(value) or 0)
    CTG_Tokens[key] = value
    ctg_broadcastGang(key, value)
    if not ctg_hasOx() then if cb then cb(true) end return end
    exports.oxmysql:execute(
        ('INSERT INTO %s (gang, balance) VALUES (?, ?) ON DUPLICATE KEY UPDATE balance = VALUES(balance)'):format(CTG_TBL),
        { key, value },
        function() if cb then cb(true) end end
    )
end

function ctg_tokensAdd(key, amount, cb)
    ctg_tokensSet(key, ctg_tokensGet(key) + (tonumber(amount) or 0), cb)
end

-- fresh fetch from DB (handles Heidi edits)
function ctg_tokensFetch(key, cb)
    key = string.lower(key or '')
    if key == '' then cb(0) return end
    if not ctg_hasOx() then cb(ctg_tokensGet(key)) return end
    exports.oxmysql:execute(('SELECT balance FROM %s WHERE gang = ? LIMIT 1'):format(CTG_TBL), { key }, function(rows)
        local val = tonumber(rows and rows[1] and rows[1].balance) or 0
        ctg_tokensSet(key, val, function() end)
        cb(val)
    end)
end

-- init cache
CreateThread(function() ctg_tokensEnsureTable(function() ctg_tokensLoadAll(function() end) end) end)

-- callback always returns fresh value
-- removed old commented callback block (replaced by fresh DB callback later)

Config = Config or {}

-- guard: define global gangColor if missing (fallback white)
if type(gangColor) ~= 'function' then
    function gangColor(gang)
        if not gang or not Config or not Config.Gangs or not Config.Gangs[gang] then return {255,255,255} end
        local c = Config.Gangs[gang].color
        if type(c) == 'table' and (#c==3 or (c.r and c.g and c.b)) then
            local r = c.r or c[1]; local g = c.g or c[2]; local b = c.b or c[3]
            return {r or 255, g or 255, b or 255}
        end
        return {255,255,255}
    end
end
Config.PermissionMode = Config.PermissionMode or 'qb'

local TerritoryOwners = {}

local function territoryKey(label)
    if not label then return nil end
    label = string.lower(label)
    label = label:gsub('%s+', '_')
    return label
end


-- simple rgb color from Config.Gangs[gang].color {r,g,b}
local function gangColor(gang)
    if not gang or not Config or not Config.Gangs or not Config.Gangs[gang] then return {255,255,255} end
    local c = Config.Gangs[gang].color
    if type(c) == 'table' and (#c==3 or (c.r and c.g and c.b)) then
        local r = c.r or c[1]; local g = c.g or c[2]; local b = c.b or c[3]
        return {r or 255, g or 255, b or 255}
    end
    return {255,255,255}
end

local function rgba(r,g,b,a)
    return string.format('rgba(%d, %d, %d, %.2f)', r or 255, g or 255, b or 255, a or 1.0)
end

-- Ray casting point in polygon for {x=,y=} list, coords in world-space
local function pointInPolygon(pt, poly)
    if type(poly) ~= 'table' or not poly[1] then return false end
    local x, y = pt.x, pt.y
    local inside = false
    local j = #poly
    for i=1,#poly do
        local xi, yi = poly[i].x, poly[i].y
        local xj, yj = poly[j].x, poly[j].y
        local intersect = ((yi>y) ~= (yj>y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) ~= 0 and (yj - yi) or 1e-9) + xi)
        if intersect then inside = not inside end
        j = i
    end
    return inside
end
 -- qb | ace | all

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

local function getGangRankLabel(gang, rank)
    if not gang then return tostring(rank or 0) end
    local grades = Config and Config.Gangs and Config.Gangs[gang] and Config.Gangs[gang].grades or nil
    if type(grades) == 'table' then
        local entry = grades[rank] or grades[tostring(rank)]
        if entry and entry.label then return entry.label end
    end
    return tostring(rank or 0)
end

local function getGangGradesList(gang)
    local grades = {}
    local maxRank = 0
    local cfg = Config and Config.Gangs and Config.Gangs[gang] and Config.Gangs[gang].grades or nil
    if type(cfg) == 'table' then
        for key, info in pairs(cfg) do
            local rank = tonumber(key) or (type(info) == 'table' and tonumber(info.grade))
            if rank then
                local label = (type(info) == 'table' and info.label) or tostring(rank)
                grades[#grades + 1] = { value = rank, label = label }
                if rank > maxRank then maxRank = rank end
            end
        end
    end
    if #grades == 0 then
        for i = 0, 4 do
            grades[#grades + 1] = { value = i, label = tostring(i) }
        end
        maxRank = 4
    else
        table.sort(grades, function(a, b) return a.value < b.value end)
    end
    return grades, maxRank
end

local function parseCharinfoName(charinfo, fallback)
    if not charinfo then return fallback end
    if type(charinfo) == 'string' then
        local ok, decoded = pcall(json.decode, charinfo)
        if ok and type(decoded) == 'table' then
            charinfo = decoded
        end
    end
    if type(charinfo) == 'table' then
        local first = charinfo.firstname or charinfo.firstName or ''
        local last = charinfo.lastname or charinfo.lastName or ''
        local name = (first ~= '' and first or '')
        if last ~= '' then
            name = name ~= '' and (name .. ' ' .. last) or last
        end
        if name ~= '' then
            return name
        end
    end
    return fallback
end

local function fetchGangMembers(gang, cb)
    if not gang or gang == '' then cb({}) return end
    exports.oxmysql:execute('SELECT citizenid, rank FROM ct_gang_members WHERE gang = ? ORDER BY rank DESC, citizenid ASC', { gang }, function(rows)
        rows = rows or {}
        local players = QBCore.Functions.GetQBPlayers()
        local online = {}
        for _, Player in pairs(players) do
            if Player and Player.PlayerData then
                local cid = Player.PlayerData.citizenid
                if cid and cid ~= '' then
                    local charinfo = Player.PlayerData.charinfo or {}
                    local first = charinfo.firstname or charinfo.firstName or ''
                    local last = charinfo.lastname or charinfo.lastName or ''
                    local fullname = (first ~= '' and first or '')
                    if last ~= '' then
                        fullname = fullname ~= '' and (fullname .. ' ' .. last) or last
                    end
                    if fullname == '' then
                        fullname = GetPlayerName(Player.PlayerData.source) or cid
                    end
                    online[cid] = { name = fullname, source = Player.PlayerData.source }
                end
            end
        end

        local list = {}
        local missing = {}
        for _, row in ipairs(rows) do
            local cid = row.citizenid
            local rank = tonumber(row.rank) or 0
            local entry = {
                citizenid = cid,
                rank = rank,
                rank_label = getGangRankLabel(gang, rank),
                online = online[cid] ~= nil
            }
            if entry.online then
                entry.name = online[cid].name
            else
                missing[#missing + 1] = cid
            end
            list[#list + 1] = entry
        end

        if #missing == 0 then
            cb(list)
            return
        end

        local marks = {}
        for i = 1, #missing do marks[i] = '?' end
        local query = ('SELECT citizenid, charinfo FROM players WHERE citizenid IN (%s)'):format(table.concat(marks, ','))
        exports.oxmysql:execute(query, missing, function(infoRows)
            local names = {}
            for _, row in ipairs(infoRows or {}) do
                names[row.citizenid] = parseCharinfoName(row.charinfo, row.citizenid)
            end
            for _, entry in ipairs(list) do
                if not entry.name then
                    entry.name = names[entry.citizenid] or entry.citizenid
                end
            end
            cb(list)
        end)
    end)
end

local function buildMembersPayload(gang, cb)
    fetchGangMembers(gang, function(list)
        local onlineCount = 0
        for _, entry in ipairs(list) do
            if entry.online then onlineCount = onlineCount + 1 end
        end
        local grades, maxRank = getGangGradesList(gang)
        cb({
            gang = gang,
            gangLabel = (Config and Config.Gangs and Config.Gangs[gang] and Config.Gangs[gang].label) or gang,
            members = list,
            counts = { online = onlineCount, total = #list },
            ranks = grades,
            maxRank = maxRank
        })
    end)
end

local function hasAffectedRows(result)
    if not result then return false end
    if type(result) == 'number' then return result > 0 end
    if result.affectedRows and result.affectedRows > 0 then return true end
    if result.changedRows and result.changedRows > 0 then return true end
    return false
end

local function broadcastMembersRefresh(gang, extraSources)
    if not gang or gang == '' then return end
    exports.oxmysql:execute('SELECT citizenid FROM ct_gang_members WHERE gang = ?', { gang }, function(rows)
        local cidSet = {}
        for _, row in ipairs(rows or {}) do
            cidSet[row.citizenid] = true
        end
        local notified = {}
        for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
            if Player and Player.PlayerData then
                local cid = Player.PlayerData.citizenid
                local src = Player.PlayerData.source
                if cid and cidSet[cid] and src then
                    TriggerClientEvent('ct-gang:members:refresh', src)
                    notified[src] = true
                end
            end
        end
        if type(extraSources) == 'table' then
            for _, src in ipairs(extraSources) do
                if src and not notified[src] then
                    TriggerClientEvent('ct-gang:members:refresh', src)
                end
            end
        end
    end)
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

QBCore.Functions.CreateCallback('ct-gang:members:list', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb({ members = {}, counts = { online = 0, total = 0 }, ranks = {}, canManage = false, selfRank = 0 }) return end
    readGang(Player.PlayerData.citizenid, function(gang, rank)
        gang = gang or ''
        local numericRank = tonumber(rank) or 0
        if gang == '' then
            cb({ members = {}, counts = { online = 0, total = 0 }, ranks = {}, canManage = false, selfRank = numericRank, gang = gang, gangLabel = nil, maxRank = 0, rankLabel = tostring(numericRank) })
            return
        end
        buildMembersPayload(gang, function(payload)
            payload = payload or {}
            payload.selfRank = numericRank
            payload.canManage = numericRank >= 4
            payload.selfCitizenid = Player.PlayerData.citizenid
            payload.rankLabel = getGangRankLabel(gang, numericRank)
            cb(payload)
        end)
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
        broadcastMembersRefresh(string.lower(gangName or ''))
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

RegisterNetEvent('ct-gang:members:setRank', function(payload)
    local src = source
    local data = payload or {}
    local targetCid = data.citizenid or data.cid
    local newRank = tonumber(data.rank)
    if not targetCid or not newRank then return end
    local Player = QBCore.Functions.GetPlayer(src); if not Player then return end
    readGang(Player.PlayerData.citizenid, function(gang, rank)
        gang = gang or ''
        local selfRank = tonumber(rank) or 0
        if gang == '' or selfRank < 4 then
            notify(src, 'Du har inte behörighet att hantera medlemmar.', 'error')
            return
        end
        if targetCid == Player.PlayerData.citizenid then
            notify(src, 'Du kan inte ändra din egen rank.', 'error')
            return
        end

        newRank = math.floor(newRank)
        if newRank < 0 then newRank = 0 end
        local _, maxRank = getGangGradesList(gang)
        if newRank > maxRank then newRank = maxRank end
        if newRank > selfRank then newRank = selfRank end

        exports.oxmysql:execute('SELECT rank FROM ct_gang_members WHERE citizenid = ? AND gang = ? LIMIT 1', { targetCid, gang }, function(rows)
            if not rows or not rows[1] then
                notify(src, 'Medlemmen hittades inte.', 'error')
                return
            end
            local currentRank = tonumber(rows[1].rank) or 0
            if currentRank == newRank then
                notify(src, 'Medlemmen har redan den ranken.', 'primary')
                return
            end
            if currentRank >= selfRank and newRank > currentRank then
                notify(src, 'Du kan inte befordra en medlem med lika hög eller högre rank.', 'error')
                return
            end

            exports.oxmysql:execute('UPDATE ct_gang_members SET rank = ? WHERE citizenid = ? AND gang = ?', { newRank, targetCid, gang }, function(result)
                if not hasAffectedRows(result) then
                    notify(src, 'Kunde inte uppdatera ranken.', 'error')
                    return
                end

                notify(src, 'Rank uppdaterad.', 'success')
                local targetSrc = nil
                for _, member in pairs(QBCore.Functions.GetQBPlayers()) do
                    if member and member.PlayerData and member.PlayerData.citizenid == targetCid then
                        targetSrc = member.PlayerData.source
                        notify(targetSrc, ('Din rank är nu %s.'):format(getGangRankLabel(gang, newRank)), 'success')
                        TriggerClientEvent('ct-gang:client:refresh', targetSrc)
                        break
                    end
                end

                broadcastMembersRefresh(gang)
            end)
        end)
    end)
end)

RegisterNetEvent('ct-gang:members:kick', function(targetCid)
    local src = source
    if type(targetCid) == 'table' then targetCid = targetCid.citizenid or targetCid.cid end
    if not targetCid then return end
    local Player = QBCore.Functions.GetPlayer(src); if not Player then return end
    readGang(Player.PlayerData.citizenid, function(gang, rank)
        gang = gang or ''
        local selfRank = tonumber(rank) or 0
        if gang == '' or selfRank < 4 then
            notify(src, 'Du har inte behörighet att hantera medlemmar.', 'error')
            return
        end
        if targetCid == Player.PlayerData.citizenid then
            notify(src, 'Du kan inte sparka dig själv.', 'error')
            return
        end

        exports.oxmysql:execute('DELETE FROM ct_gang_members WHERE citizenid = ? AND gang = ? LIMIT 1', { targetCid, gang }, function(result)
            if not hasAffectedRows(result) then
                notify(src, 'Medlemmen hittades inte.', 'error')
                return
            end

            notify(src, 'Medlem borttagen.', 'success')
            local targetSrc = nil
            for _, member in pairs(QBCore.Functions.GetQBPlayers()) do
                if member and member.PlayerData and member.PlayerData.citizenid == targetCid then
                    targetSrc = member.PlayerData.source
                    notify(targetSrc, 'Du har blivit utslängd från gänget.', 'error')
                    TriggerClientEvent('ct-gang:client:refresh', targetSrc)
                    break
                end
            end

            broadcastMembersRefresh(gang, targetSrc and { targetSrc } or nil)
        end)
    end)
end)


-- === Territories: serve stored (DB) + config (world) ===
local function loadAllAreas(cb)
    local out = {}

    local function mergeConfig()
        if Config and Config.Territories then
            local nid = -1
            for _, t in ipairs(Config.Territories) do
                local key = territoryKey(t.label)
                local owner = TerritoryOwners and TerritoryOwners[key] or nil
                local col = owner and gangColor(owner) or nil
                local _fill = (col and rgba(col[1], col[2], col[3], 0.28)) or t.fill
                local _stroke = (col and rgba(col[1], col[2], col[3], 0.90)) or t.stroke
                table.insert(out, {
                    id = nid,
                    label = t.label,
                    owner = owner,
                    polygon_world = t.polygon_world,
                    fill = _fill,
                    stroke = _stroke,
                    stroke_width = t.stroke_width
                })
                nid = nid - 1
            end
        end
        cb(out)
    end

    if exports and exports.oxmysql then
        exports.oxmysql:execute(
            'SELECT id, label, polygon_pixels, polygon_world FROM ct_gang_territories ORDER BY id ASC',
            {},
            function(rows)
                for _, r in ipairs(rows or {}) do
                    local px = r.polygon_pixels
                    local wx = r.polygon_world
                    if type(px) == 'string' and json and json.decode then local ok,v=pcall(json.decode, px); if ok then px=v end end
                    if type(wx) == 'string' and json and json.decode then local ok,v=pcall(json.decode, wx); if ok then wx=v end end
                    local key = territoryKey(r.label)
                local owner = TerritoryOwners and TerritoryOwners[key] or nil
                local col = owner and gangColor(owner) or nil
                local _fill = (col and rgba(col[1], col[2], col[3], 0.28)) or nil
                local _stroke = (col and rgba(col[1], col[2], col[3], 0.90)) or nil
                table.insert(out, { id=r.id, label=r.label, owner=owner, polygon_pixels=px, polygon_world=wx, fill=_fill, stroke=_stroke })
                end
                mergeConfig()
            end
        )
    else
        mergeConfig()
    end
end

RegisterNetEvent('ct-gang:areas:request', function()
    local src = source
    loadOwners(function()
        loadAllAreas(function(list)
            TriggerClientEvent('ct-gang:areas:response', src, list)
        end)
    end)
end)


RegisterNetEvent('ct-gang:territories:capture', function(payload)
    local src = source
    local gang = payload and payload.gang or nil
    local pos = payload and payload.pos or nil
    if not gang or not pos or not pos.x or not pos.y then return end
    -- find matching config territory by point-in-polygon
    local foundId = nil
    if Config and Config.Territories then
        local nid = -1
        for _, t in ipairs(Config.Territories) do
            local poly = normalizePolygon(t.polygon_world)
            if poly and #poly>=3 and pointInPolygon({x=pos.x, y=pos.y}, poly) then foundId = nid; break end
            nid = nid - 1
        end
    end
    if not foundId then return end
    TerritoryOwners[foundId] = gang
    -- broadcast updated list to everyone
    loadAllAreas(function(list)
        TriggerClientEvent('ct-gang:areas:response', -1, list)
    end)
end)

-- Load owners from DB into TerritoryOwners
function loadOwners(cb)
    if not exports or not exports.oxmysql then TerritoryOwners = TerritoryOwners or {}; if cb then cb(true) end return end
    exports.oxmysql:execute('CREATE TABLE IF NOT EXISTS ct_gang_territory_owners (territory_key VARCHAR(100) PRIMARY KEY, owner VARCHAR(50), updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)', {}, function()
        exports.oxmysql:execute('SELECT territory_key, owner FROM ct_gang_territory_owners', {}, function(rows)
            local t = {}
            for _,r in ipairs(rows or {}) do if r.territory_key and r.owner then t[r.territory_key] = r.owner end end
            TerritoryOwners = t
            if cb then cb(true) end
        end)
    end)
end

local function saveOwner(key, owner, cb)
    if not key then if cb then cb(false) end return end
    if not exports or not exports.oxmysql then TerritoryOwners[key] = owner; if cb then cb(true) end return end
    exports.oxmysql:execute('INSERT INTO ct_gang_territory_owners (territory_key, owner) VALUES (?, ?) ON DUPLICATE KEY UPDATE owner=VALUES(owner)', { key, owner }, function(_)
        TerritoryOwners[key] = owner
        if cb then cb(true) end
    end)
end

local ActiveCaptures = {}


-- Resolve a human label from a territory key (lowercase with underscores)
local function getLabelByKey(key)
    if not key then return key end
    if Config and Config.Territories then
        for _, t in ipairs(Config.Territories) do
            local k = territoryKey(t.label)
            if k == key then return t.label end
        end
    end
    return key
end

-- Notify all online members of a given gang (by gang key)
local function notifyGangMembers(gangKey, message)
    if not gangKey or gangKey == '' then return end
    local players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(players) do
        local cid = Player.PlayerData.citizenid
        readGang(cid, function(g, r)
            if g and g == gangKey then
                local src = Player.PlayerData.source
                notify(src, message, 'error')
            end
        end)
    end
end

RegisterNetEvent('ct-gang:territories:startCapture', function(payload)
    local src = source
    local gang = payload and payload.gang or nil
    local key  = payload and payload.key or nil
    local pos  = payload and payload.pos or nil
    if not gang or not key or not pos then return end
    -- prevent overlapping captures
    if ActiveCaptures[key] then TriggerClientEvent('QBCore:Notify', src, 'Pågående övertagande...', 'error'); return end
    ActiveCaptures[key] = { by = gang, started = os.time() }
    -- ALERT owner gang
    local currentOwner = TerritoryOwners[key]
    if currentOwner and currentOwner ~= gang then
        local label = getLabelByKey(key)
        notifyGangMembers(currentOwner, ('Någon tar över %s'):format(label))
    end
    TriggerClientEvent('QBCore:Notify', src, 'Övertagande påbörjat', 'primary')
    TriggerClientEvent('ct-gang:notify', src, 'Övertagande ('..key..') startat', 'primary')
    -- short timer for now (5s); later 5min
    SetTimeout(5000, function()
        saveOwner(key, gang, function()
            ActiveCaptures[key] = nil
            TriggerClientEvent('ct-gang:notify', src, 'Övertagande klart', 'success')
            loadAllAreas(function(list)
                TriggerClientEvent('ct-gang:areas:response', -1, list)
            end)
        end)
    end)
end)


-- Periodic income: +1 per owned zone / 10s
CreateThread(function()
    while true do
        Wait(10000)
        local counts = {}
        if type(TerritoryOwners) == 'table' then
            for _, owner in pairs(TerritoryOwners) do
                if owner and owner ~= '' then
                    owner = string.lower(owner)
                    counts[owner] = (counts[owner] or 0) + 1
                end
            end
        end
        for gangKey, cnt in pairs(counts) do
            if cnt > 0 then ctg_tokensAdd(gangKey, cnt, function() end) end
        end
    end
end)


-- === ALWAYS FRESH FROM DB (minimal & robust) ===
QBCore.Functions.CreateCallback('ct-gang:getGangTokens', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src); if not Player then cb(0) return end
    local g = Player.PlayerData and Player.PlayerData.gang and Player.PlayerData.gang.name or nil
    if not g or g == '' then cb(0) return end
    g = string.lower(g)

    if exports and exports.oxmysql and exports.oxmysql.scalar then
        exports.oxmysql:scalar('SELECT balance FROM ct_gang_currency WHERE gang = ? LIMIT 1', { g }, function(balance)
            cb(tonumber(balance) or 0)
        end)
    elseif MySQL and MySQL.scalar then
        MySQL.scalar('SELECT balance FROM ct_gang_currency WHERE gang = ? LIMIT 1', { g }, function(balance)
            cb(tonumber(balance) or 0)
        end)
    elseif MySQL and MySQL.Sync and MySQL.Sync.fetchScalar then
        local balance = MySQL.Sync.fetchScalar('SELECT balance FROM ct_gang_currency WHERE gang = ? LIMIT 1', { g })
        cb(tonumber(balance) or 0)
    else
        cb((CTG_Tokens and CTG_Tokens[g]) or 0)
    end
end)


-- === Callback: always fetch fresh balance for player's gang ===
QBCore.Functions.CreateCallback('ct-gang:getGangTokens', function(src, cb)
    resolveGangKey(src, function(gangKey)
        if not gangKey or gangKey == '' then cb(0) return end
        fetchGangBalance(gangKey, function(bal) cb(bal) end)
    end)
end)

-- Optional: simple debug command /gangwho
RegisterCommand('gangwho', function(src)
    resolveGangKey(src, function(g)
        if not g then
            if src ~= 0 then TriggerClientEvent('QBCore:Notify', src, 'Inget gäng hittades', 'error', 5000) end
            print('[ct-gang] gangwho: no gang')
            return
        end
        fetchGangBalance(g, function(b)
            local msg = ('Gang: %s | Balance: %d'):format(g, b or 0)
            if src ~= 0 then TriggerClientEvent('QBCore:Notify', src, msg, 'primary', 7500) end
            print('[ct-gang] gangwho: '..msg)
        end)
    end)
end)


-- Try to debit tokens atomically: fetch -> check -> set
function ctg_tokensTryDebit(gangKey, amount, cb)
    gangKey = string.lower(gangKey or '')
    amount = tonumber(amount) or 0
    if gangKey == '' or amount <= 0 then if cb then cb(false) end return end
    ctg_tokensFetch(gangKey, function(cur)
        cur = tonumber(cur) or 0
        if cur < amount then if cb then cb(false, cur) end return end
        ctg_tokensSet(gangKey, cur - amount, function(ok) if cb then cb(ok, cur) end end)
    end)
end



local CourierSpawns = {
    {
        vehicle = vector4(1288.59, -3337.59, 5.92, 178.55),
        ped = vector4(1289.51, -3334.27, 5.9, 26.59)
    },
    {
        vehicle = vector4(-410.38, 1237.94, 325.67, 31.13),
        ped = vector4(-409.37, 1234.67, 325.64, 245.35)
    },
    {
        vehicle = vector4(-127.57, 1924.24, 197.26, 182.38),
        ped = vector4(-126.91, 1927.58, 197.08, 44.62)
    },
    {
        vehicle = vector4(1691.48, 3285.65, 41.17, 31.58),
        ped = vector4(1692.49, 3282.33, 41.14, 250.82)
    }
}

local CourierDefaultSpawn = CourierSpawns[1] or {
    vehicle = vector4(1288.59, -3337.59, 5.92, 178.55),
    ped = vector4(1289.51, -3334.27, 5.9, 26.59)
}

local CourierDefaultLocation = CourierDefaultSpawn.ped
local CourierDefaultVehicle = CourierDefaultSpawn.vehicle
local CourierOrders = CourierOrders or {}
local CitizenCourierOrders = CitizenCourierOrders or {}
local NextCourierOrderId = NextCourierOrderId or 1

local function packPedLocation(spawn)
    if not spawn then return nil end
    local vec = spawn.ped or spawn
    if not vec then return nil end
    return { x = vec.x + 0.0, y = vec.y + 0.0, z = vec.z + 0.0, w = vec.w + 0.0 }
end

local function packHintLocation(spawn)
    if not spawn then return nil end
    local vec = spawn.hint or spawn.ped or spawn
    if not vec then return nil end
    local x = vec.x + 0.0
    local y = vec.y + 0.0
    local z = vec.z + 0.0
    local w = vec.w + 0.0
    if not spawn.hint then
        y = y - 10.0
    end
    return { x = x, y = y, z = z, w = w }
end

local function packVehicleLocation(spawn)
    if not spawn then return nil end
    local vec = spawn.vehicle or CourierDefaultVehicle
    if not vec then return nil end
    return { x = vec.x + 0.0, y = vec.y + 0.0, z = vec.z + 0.0, w = vec.w + 0.0 }
end

local function buildOrderPayload(entry)
    if not entry then return nil end
    return {
        id = entry.id,
        ped = packPedLocation(entry.spawn),
        hint = packHintLocation(entry.spawn),
        vehicle = packVehicleLocation(entry.spawn)
    }
end

local function ensureCitizenOrderMap(cid)
    if not cid or cid == '' then return nil end
    CitizenCourierOrders[cid] = CitizenCourierOrders[cid] or {}
    return CitizenCourierOrders[cid]
end

local function getOrdersForCitizen(cid)
    local result = {}
    local map = CitizenCourierOrders[cid]
    if map then
        for orderId in pairs(map) do
            local entry = CourierOrders[orderId]
            if entry then
                result[#result + 1] = entry
            end
        end
    end
    return result
end

local function chooseCourierSpawn(exclude)
    if #CourierSpawns <= 0 then return CourierDefaultSpawn end
    local pool = {}
    for _, spawn in ipairs(CourierSpawns) do
        local used = false
        if exclude then
            for _, entry in ipairs(exclude) do
                local other = entry.spawn or entry
                local op = other and (other.ped or other) or nil
                local sp = spawn.ped or spawn
                if op and sp then
                    local dist = #(vector3(op.x, op.y, op.z) - vector3(sp.x, sp.y, sp.z))
                    if dist < 2.0 then
                        used = true
                        break
                    end
                end
            end
        end
        if not used then
            pool[#pool + 1] = spawn
        end
    end
    if #pool <= 0 then pool = CourierSpawns end
    if #pool <= 0 then return CourierDefaultSpawn end
    local idx = math.random(1, #pool)
    return pool[idx] or CourierDefaultSpawn
end

local function addPendingPickup(cid, item, count)
    if not cid or cid == '' then return nil end
    local orders = getOrdersForCitizen(cid)
    local spawn = chooseCourierSpawn(orders)
    local orderId = NextCourierOrderId
    NextCourierOrderId = NextCourierOrderId + 1
    if NextCourierOrderId > 900000000 then
        NextCourierOrderId = 1
    end
    local entry = {
        id = orderId,
        cid = cid,
        item = item,
        count = count or 1,
        spawn = spawn
    }
    CourierOrders[orderId] = entry
    local map = ensureCitizenOrderMap(cid)
    if map then
        map[orderId] = true
    end
    return entry
end

local function removeOrder(entry)
    if not entry or not entry.id then return end
    CourierOrders[entry.id] = nil
    local map = CitizenCourierOrders[entry.cid]
    if map then
        map[entry.id] = nil
        if next(map) == nil then
            CitizenCourierOrders[entry.cid] = nil
        end
    end
end

local function takePendingPickup(cid, orderId, item)
    local entry = CourierOrders[orderId]
    if not entry or entry.cid ~= cid or entry.item ~= item then return false end
    if entry.count <= 0 then return false end
    entry.count = entry.count - 1
    local finished = entry.count <= 0
    return true, finished, entry
end

local function getPendingPayload(cid)
    local payload = {}
    for _, entry in ipairs(getOrdersForCitizen(cid)) do
        local built = buildOrderPayload(entry)
        if built then
            payload[#payload + 1] = built
        end
    end
    return payload
end

local function pushDepotState(src, cid)
    if not src then return end
    TriggerClientEvent('ct-gang:client:depotState', src, getPendingPayload(cid))
end

RegisterNetEvent('ct-gang:shop:buy', function(payload)
    local src = source
    if not payload or payload.item ~= 'phone' then
        TriggerClientEvent('QBCore:Notify', src, 'Ogiltig produkt.', 'error', 5000)
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(readGang) ~= 'function' then return end

    local cid = Player.PlayerData.citizenid
    readGang(cid, function(gangKey, _)
        gangKey = string.lower(gangKey or '')
        if gangKey == '' then
            TriggerClientEvent('QBCore:Notify', src, 'Du tillhör inget gäng.', 'error', 5000)
            return
        end

        ctg_tokensTryDebit(gangKey, 1, function(ok)
            if not ok then
                TriggerClientEvent('QBCore:Notify', src, 'För lite g-mynt.', 'error', 5000)
                return
            end

            local entry = addPendingPickup(cid, 'phone', 1)
            local spawn = entry and entry.spawn or CourierDefaultSpawn
            TriggerClientEvent('QBCore:Notify', src, 'Din beställning väntar hos kontaktpersonen. Följ markeringen för att hämta den.', 'success', 7500)
            TriggerClientEvent('ct-gang:shop:pickupHint', src, buildOrderPayload(entry) or {
                ped = packPedLocation(spawn),
                hint = packHintLocation(spawn),
                vehicle = packVehicleLocation(spawn)
            })
            pushDepotState(src, cid)
        end)
    end)
end)

RegisterNetEvent('ct-gang:shop:pickup', function(orderId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src); if not Player then return end
    local cid = Player.PlayerData.citizenid
    local order = tonumber(orderId)
    if not order then
        local orders = getOrdersForCitizen(cid)
        if orders[1] then
            order = orders[1].id
        else
            TriggerClientEvent('QBCore:Notify', src, 'Inget att hämta.', 'error', 5000)
            return
        end
    end

    local entry = CourierOrders[order]
    if not entry or entry.cid ~= cid then
        TriggerClientEvent('QBCore:Notify', src, 'Inget att hämta.', 'error', 5000)
        pushDepotState(src, cid)
        return
    end

    local ped = GetPlayerPed(src)
    local px, py, pz = table.unpack(GetEntityCoords(ped))
    local spawn = entry.spawn or CourierDefaultSpawn
    local location = spawn and (spawn.ped or CourierDefaultLocation) or CourierDefaultLocation
    local d = #(vector3(px, py, pz) - vector3(location.x, location.y, location.z))
    if d > 5.0 then
        TriggerClientEvent('QBCore:Notify', src, 'Du är inte hos kontaktpersonen.', 'error', 5000)
        return
    end

    local success, finished = takePendingPickup(cid, order, 'phone')
    if not success then
        TriggerClientEvent('QBCore:Notify', src, 'Inget att hämta.', 'error', 5000)
        pushDepotState(src, cid)
        return
    end

    local giveOk = Player.Functions.AddItem('phone', 1)
    if giveOk then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['phone'], 'add')
        TriggerClientEvent('QBCore:Notify', src, 'Du hämtade Mobil.', 'success', 5000)
        if finished then
            removeOrder(entry)
        end
    else
        entry.count = entry.count + 1
        TriggerClientEvent('QBCore:Notify', src, 'Din väska är full.', 'error', 5000)
    end

    pushDepotState(src, cid)
end)

RegisterNetEvent('ct-gang:shop:requestDepotState', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src); if not Player then return end
    local cid = Player.PlayerData.citizenid
    pushDepotState(src, cid)
end)
