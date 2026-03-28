-- ============================================================
--  d4rk_emergency — Admin Layer v2
--  Browser: http://server:30120/d4rk_emergency/
--  In-game: /<Config.Admin.Command>  (ace: Config.Admin.Ace)
--  Collaboration: presence heartbeat + version tracking
-- ============================================================

local adminToken = Config.Admin.Token
local adminAce   = Config.Admin.Ace

-- ── Collaboration state ───────────────────────────────────────
-- presences[adminId] = { name, color, deptKey, lastSeen }
local presences = {}
-- deptMeta[deptKey]  = { updatedAt, updatedBy }
local deptMeta  = {}

local function cleanPresences()
    local now = os.time()
    for id, p in pairs(presences) do
        if now - p.lastSeen > 20 then presences[id] = nil end
    end
end

local function getEditors()
    cleanPresences()
    local result = {}
    for _, p in pairs(presences) do
        if p.deptKey and p.deptKey ~= '' then
            if not result[p.deptKey] then result[p.deptKey] = {} end
            result[p.deptKey][#result[p.deptKey] + 1] = { name = p.name, color = p.color }
        end
    end
    return result
end

local function getVersions()
    local result = {}
    for k, m in pairs(deptMeta) do
        result[#result + 1] = { key = k, updatedAt = m.updatedAt, updatedBy = m.updatedBy }
    end
    return result
end

-- ── Permission check ─────────────────────────────────────────

local function isAdmin(source)
    -- Ace check (Standard)
    if IsPlayerAceAllowed(source, adminAce) then return true end

    -- Fallback: QBX Gruppe
    local Player = exports.qbx_core:GetPlayer(source)
    if Player and (Player.PlayerData.group == 'admin' or Player.PlayerData.group == 'superadmin') then
        return true
    end

    return false
end

-- ── Response helpers ─────────────────────────────────────────

local function jsonRes(res, code, data)
    res.writeHead(code, {
        ['Content-Type']                = 'application/json',
        ['Access-Control-Allow-Origin'] = '*',
    })
    res.send(json.encode(data))
end

local function checkToken(req)
    local auth = (req.headers and (req.headers['Authorization'] or req.headers['authorization'])) or ''
    return auth == ('Bearer ' .. adminToken)
end

-- ── Export helpers ────────────────────────────────────────────

local function getAllDepts()
    local list = {}
    for k, v in pairs(ActiveConfig) do
        local exported = DB.ExportDept(k, v)
        -- Attach meta
        if deptMeta[k] then
            exported.updatedAt = deptMeta[k].updatedAt
            exported.updatedBy = deptMeta[k].updatedBy
        end
        list[#list + 1] = exported
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    return list
end

-- ── HTTP Handler ──────────────────────────────────────────────

local adminHtml = LoadResourceFile(GetCurrentResourceName(), 'html/admin/index.html')

SetHttpHandler(function(req, res)
    local path   = req.path   or '/'
    local method = req.method or 'GET'

    -- Serve panel HTML
    if method == 'GET' and (path == '/' or path == '' or path == '/admin') then
        res.writeHead(200, { ['Content-Type'] = 'text/html; charset=utf-8' })
        res.send(adminHtml or '<h1>Not found</h1>')
        return
    end

    -- CORS preflight
    if method == 'OPTIONS' then
        res.writeHead(204, {
            ['Access-Control-Allow-Origin']  = '*',
            ['Access-Control-Allow-Methods'] = 'GET, POST, DELETE, OPTIONS',
            ['Access-Control-Allow-Headers'] = 'Content-Type, Authorization',
        })
        res.send('')
        return
    end

    -- Auth check
    if not checkToken(req) then
        jsonRes(res, 401, { success = false, error = 'Unauthorized' })
        return
    end

    -- ── GET /api/departments ────────────────────────────────
    if method == 'GET' and path == '/api/departments' then
        jsonRes(res, 200, getAllDepts())
        return
    end

    -- ── GET /api/status ─────────────────────────────────────
    if method == 'GET' and path == '/api/status' then
        jsonRes(res, 200, { editors = getEditors(), versions = getVersions() })
        return
    end

    -- ── POST /api/presence ──────────────────────────────────
    if method == 'POST' and path == '/api/presence' then
        req.setDataHandler(function(body)
            local ok, data = pcall(json.decode, body)
            if ok and data and data.adminId then
                presences[data.adminId] = {
                    name     = data.name    or 'Admin',
                    color    = data.color   or '#4f8ef7',
                    deptKey  = data.deptKey or '',
                    lastSeen = os.time(),
                }
                jsonRes(res, 200, { success = true })
            else
                jsonRes(res, 400, { success = false })
            end
        end)
        return
    end

    -- ── POST /api/departments/:key ──────────────────────────
    local saveKey = path:match('^/api/departments/(.+)$')
    if method == 'POST' and saveKey then
        req.setDataHandler(function(body)
            local ok, data = pcall(json.decode, body)
            if not ok or type(data) ~= 'table' then
                jsonRes(res, 400, { success = false, error = 'Invalid JSON' })
                return
            end

            DB.ApplyToActiveConfig(saveKey, data)
            deptMeta[saveKey] = { updatedAt = os.time(), updatedBy = data._savedBy or 'Admin' }

            DB.Save(saveKey, ActiveConfig[saveKey], function(saved)
                if saved then
                    local exported = DB.ExportDept(saveKey, ActiveConfig[saveKey])
                    exported.updatedAt = deptMeta[saveKey].updatedAt
                    exported.updatedBy = deptMeta[saveKey].updatedBy
                    TriggerClientEvent('d4rk_emergency:client:configUpdated', -1, saveKey, exported)
                    jsonRes(res, 200, { success = true, updatedAt = deptMeta[saveKey].updatedAt })
                else
                    jsonRes(res, 500, { success = false, error = 'DB save failed' })
                end
            end)
        end)
        return
    end

    -- ── DELETE /api/departments/:key ────────────────────────
    local delKey = path:match('^/api/departments/(.+)$')
    if method == 'DELETE' and delKey then
        if not ActiveConfig[delKey] then
            jsonRes(res, 404, { success = false, error = 'Not found' })
            return
        end
        ActiveConfig[delKey] = nil
        deptMeta[delKey]     = nil
        MySQL.update('DELETE FROM `d4rk_emergency_departments` WHERE dept_key = ?', { delKey })
        TriggerClientEvent('d4rk_emergency:client:deptDeleted', -1, delKey)
        jsonRes(res, 200, { success = true })
        return
    end

    jsonRes(res, 404, { success = false, error = 'Not found' })
end)

-- ── NUI Callbacks ────────────────────────────────────────────

lib.callback.register('d4rk_emergency:admin:getDepts', function(source)
    if not isAdmin(source) then return nil, 'Access denied' end
    return getAllDepts()
end)

lib.callback.register('d4rk_emergency:admin:getStatus', function(source)
    if not isAdmin(source) then return nil end
    return { editors = getEditors(), versions = getVersions() }
end)

lib.callback.register('d4rk_emergency:admin:presence', function(source, data)
    if not isAdmin(source) then return false end
    if data and data.adminId then
        presences[data.adminId] = {
            name     = data.name    or 'Admin',
            color    = data.color   or '#4f8ef7',
            deptKey  = data.deptKey or '',
            lastSeen = os.time(),
        }
    end
    return true
end)

lib.callback.register('d4rk_emergency:admin:saveDept', function(source, deptKey, data)
    if not isAdmin(source) then return { success = false, error = 'Access denied' } end
    if type(data) ~= 'table' then return { success = false, error = 'Invalid data' } end

    DB.ApplyToActiveConfig(deptKey, data)
    deptMeta[deptKey] = { updatedAt = os.time(), updatedBy = data._savedBy or 'Admin' }

    local saved = DB.SaveAwait(deptKey, ActiveConfig[deptKey])
    if saved then
        local exported = DB.ExportDept(deptKey, ActiveConfig[deptKey])
        exported.updatedAt = deptMeta[deptKey].updatedAt
        exported.updatedBy = deptMeta[deptKey].updatedBy
        TriggerClientEvent('d4rk_emergency:client:configUpdated', -1, deptKey, exported)
        return { success = true, updatedAt = deptMeta[deptKey].updatedAt }
    end
    return { success = false, error = 'DB save failed' }
end)

lib.callback.register('d4rk_emergency:admin:deleteDept', function(source, deptKey)
    if not isAdmin(source) then return { success = false, error = 'Access denied' } end
    if not ActiveConfig[deptKey] then return { success = false, error = 'Not found' } end

    ActiveConfig[deptKey] = nil
    deptMeta[deptKey]     = nil
    DB.DeleteAwait(deptKey)
    TriggerClientEvent('d4rk_emergency:client:deptDeleted', -1, deptKey)
    return { success = true }
end)