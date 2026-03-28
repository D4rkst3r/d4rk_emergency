-- ============================================================
--  d4rk_emergency — DB Layer
--  Handles vec3/vec4 serialization to/from plain JSON tables
-- ============================================================

DB       = {}    -- global: used by main.lua and admin.lua
DeptMeta = {}    -- global: { [deptKey] = { updatedAt, updatedBy } }
                 -- seeded on LoadAll so version tracking works from first poll

-- ── Vec helpers ───────────────────────────────────────────────

local function v3Encode(v)
    if not v then return nil end
    return { x = v.x or 0.0, y = v.y or 0.0, z = v.z or 0.0 }
end

local function v4Encode(v)
    if not v then return nil end
    return { x = v.x or 0.0, y = v.y or 0.0, z = v.z or 0.0, w = v.w or 0.0 }
end

local function v3Decode(t)
    if not t then return vec3(0, 0, 0) end
    return vec3(tonumber(t.x) or 0, tonumber(t.y) or 0, tonumber(t.z) or 0)
end

local function v4Decode(t)
    if not t then return vec4(0, 0, 0, 0) end
    return vec4(tonumber(t.x) or 0, tonumber(t.y) or 0, tonumber(t.z) or 0, tonumber(t.w) or 0)
end

local function encodeZone(zone, hasSpawn)
    if not zone then return nil end
    local z = {
        coords   = v3Encode(zone.coords),
        size     = v3Encode(zone.size),
        rotation = zone.rotation or 0,
        label    = zone.label or '',
    }
    if hasSpawn then
        z.spawnPoint = v4Encode(zone.spawnPoint)
    end
    return z
end

local function decodeZone(z, hasSpawn)
    if not z then return nil end
    local zone = {
        coords   = v3Decode(z.coords),
        size     = v3Decode(z.size),
        rotation = z.rotation or 0,
        label    = z.label or '',
    }
    if hasSpawn and z.spawnPoint then
        zone.spawnPoint = v4Decode(z.spawnPoint)
    end
    return zone
end

-- ── Serialization ─────────────────────────────────────────────

local function encodeDept(deptKey, dept)
    local configData = {
        dutyZone      = encodeZone(dept.dutyZone),
        cloakroomZone = encodeZone(dept.cloakroomZone),
        armoryZone    = encodeZone(dept.armoryZone),
        garageZone    = encodeZone(dept.garageZone, true),
        grades        = dept.grades   or {},
        armory        = dept.armory   or {},
        vehicles      = dept.vehicles or {},
        outfits       = dept.outfits  or { male = {}, female = {} },
    }
    return {
        dept_key    = deptKey,
        label       = dept.label      or '',
        short_label = dept.shortLabel or '',
        job_name    = dept.jobName    or '',
        color       = dept.color      or '#FFFFFF',
        config_json = json.encode(configData),
    }
end

local function decodeDept(row)
    local ok, parsed = pcall(json.decode, row.config_json)
    if not ok or not parsed then
        print(('[d4rk_emergency] DB parse error for dept "%s"'):format(row.dept_key or '?'))
        return nil
    end
    return {
        label         = row.label,
        shortLabel    = row.short_label,
        jobName       = row.job_name,
        color         = row.color,
        dutyZone      = decodeZone(parsed.dutyZone),
        cloakroomZone = decodeZone(parsed.cloakroomZone),
        armoryZone    = decodeZone(parsed.armoryZone),
        garageZone    = decodeZone(parsed.garageZone, true),
        grades        = parsed.grades   or {},
        armory        = parsed.armory   or {},
        vehicles      = parsed.vehicles or {},
        outfits       = parsed.outfits  or { male = {}, female = {} },
    }
end

-- ── Public API ────────────────────────────────────────────────

function DB.LoadAll(cb)
    MySQL.query('SELECT * FROM `d4rk_emergency_departments`', {}, function(rows)
        local result = {}
        if rows then
            for _, row in ipairs(rows) do
                local dept = decodeDept(row)
                if dept then
                    result[row.dept_key] = dept
                end
            end
        end

        -- Seed DeptMeta with baseline timestamps so the version tracking
        -- in the poll loop works correctly from the very first status request.
        local startTime = os.time()
        for key in pairs(result) do
            if not DeptMeta[key] then
                DeptMeta[key] = { updatedAt = startTime, updatedBy = 'server' }
            end
        end

        cb(result)
    end)
end

function DB.Save(deptKey, dept, cb)
    local row = encodeDept(deptKey, dept)
    MySQL.update(
        [[INSERT INTO `d4rk_emergency_departments`
            (dept_key, label, short_label, job_name, color, config_json)
          VALUES (?, ?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE
            label       = VALUES(label),
            short_label = VALUES(short_label),
            job_name    = VALUES(job_name),
            color       = VALUES(color),
            config_json = VALUES(config_json)]],
        { row.dept_key, row.label, row.short_label, row.job_name, row.color, row.config_json },
        function(affected)
            if cb then cb(affected and affected > 0) end
        end
    )
end

function DB.SaveAwait(deptKey, dept)
    local row = encodeDept(deptKey, dept)
    local affected = MySQL.update.await(
        [[INSERT INTO `d4rk_emergency_departments`
            (dept_key, label, short_label, job_name, color, config_json)
          VALUES (?, ?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE
            label       = VALUES(label),
            short_label = VALUES(short_label),
            job_name    = VALUES(job_name),
            color       = VALUES(color),
            config_json = VALUES(config_json)]],
        { row.dept_key, row.label, row.short_label, row.job_name, row.color, row.config_json }
    )
    return affected and affected > 0
end

function DB.DeleteAwait(deptKey)
    local affected = MySQL.update.await(
        'DELETE FROM `d4rk_emergency_departments` WHERE dept_key = ?',
        { deptKey }
    )
    return affected and affected > 0
end

-- ── Export helper ─────────────────────────────────────────────
-- Returns a plain-table version safe for json.encode / NUI / HTTP

function DB.ExportDept(deptKey, dept)
    local function ev3(v) return v and { x = v.x, y = v.y, z = v.z } or nil end
    local function ev4(v) return v and { x = v.x, y = v.y, z = v.z, w = v.w } or nil end
    local function ez(z, sp)
        if not z then return nil end
        local t = { coords = ev3(z.coords), size = ev3(z.size), rotation = z.rotation, label = z.label }
        if sp then t.spawnPoint = ev4(z.spawnPoint) end
        return t
    end
    return {
        key           = deptKey,
        label         = dept.label,
        shortLabel    = dept.shortLabel,
        jobName       = dept.jobName,
        color         = dept.color,
        dutyZone      = ez(dept.dutyZone),
        cloakroomZone = ez(dept.cloakroomZone),
        armoryZone    = ez(dept.armoryZone),
        garageZone    = ez(dept.garageZone, true),
        grades        = dept.grades,
        armory        = dept.armory,
        vehicles      = dept.vehicles,
    }
end

-- Applies plain-table data (from JSON/NUI) back into ActiveConfig with vec3/vec4

function DB.ApplyToActiveConfig(deptKey, data)
    local function mkv3(t)
        if not t then return vec3(0, 0, 0) end
        return vec3(tonumber(t.x) or 0, tonumber(t.y) or 0, tonumber(t.z) or 0)
    end
    local function mkv4(t)
        if not t then return vec4(0, 0, 0, 0) end
        return vec4(tonumber(t.x) or 0, tonumber(t.y) or 0, tonumber(t.z) or 0, tonumber(t.w) or 0)
    end
    local function mkZone(z, sp)
        if not z then return nil end
        local zone = {
            coords   = mkv3(z.coords),
            size     = mkv3(z.size),
            rotation = z.rotation or 0,
            label    = z.label or '',
        }
        if sp and z.spawnPoint then zone.spawnPoint = mkv4(z.spawnPoint) end
        return zone
    end

    ActiveConfig[deptKey] = {
        label         = data.label      or '',
        shortLabel    = data.shortLabel or '',
        jobName       = data.jobName    or '',
        color         = data.color      or '#FFFFFF',
        dutyZone      = mkZone(data.dutyZone),
        cloakroomZone = mkZone(data.cloakroomZone),
        armoryZone    = mkZone(data.armoryZone),
        garageZone    = mkZone(data.garageZone, true),
        grades        = data.grades   or {},
        armory        = data.armory   or {},
        vehicles      = data.vehicles or {},
        outfits       = data.outfits  or { male = {}, female = {} },
    }
end