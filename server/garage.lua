-- ============================================================
--  d4rk_emergency — Garage System
--  Handles: fleet tracking, plate generation, spawn, return, order
-- ============================================================

Garage = {}   -- global, used by main.lua

local function Log(msg, level, fields)
    exports['d4rk_core']:Log('emergency:garage', msg, level or 'info', fields)
end

local function Notify(source, title, msg, ntype)
    exports['d4rk_core']:Notify(source, title, msg, ntype)
end

-- ── Plate generation ──────────────────────────────────────────

local function GeneratePlate(prefix)
    prefix = ((prefix or 'LS'):upper()):sub(1, 4)
    for _ = 1, 20 do
        local num   = math.random(1000, 9999)
        local plate = (prefix .. tostring(num)):sub(1, 8)
        while #plate < 8 do plate = plate .. ' ' end
        local exists = MySQL.single.await(
            'SELECT id FROM `d4rk_emergency_active_vehicles` WHERE plate = ?', { plate }
        )
        if not exists then return plate end
    end
    return nil
end

-- ── Fleet sync ────────────────────────────────────────────────
-- Called on startup and when dept config is saved.
-- Inserts missing fleet rows without touching existing available counts.

function Garage.SyncFleet(deptKey, dept)
    if not dept or not dept.vehicles then return end
    for _, v in ipairs(dept.vehicles) do
        local max = v.maxCount or 1
        MySQL.update.await(
            [[INSERT INTO `d4rk_emergency_fleet` (dept_key, model, available, max_count)
              VALUES (?, ?, ?, ?)
              ON DUPLICATE KEY UPDATE
                max_count = VALUES(max_count),
                available = LEAST(available, VALUES(max_count))]],
            { deptKey, v.model, max, max }
        )
    end
end

function Garage.GetFleetStatus(deptKey)
    local rows = MySQL.query.await(
        'SELECT model, available, max_count FROM `d4rk_emergency_fleet` WHERE dept_key = ?',
        { deptKey }
    )
    local fleet = {}
    if rows then
        for _, r in ipairs(rows) do
            fleet[r.model] = { available = r.available, maxCount = r.max_count }
        end
    end
    return fleet
end

-- ── Callbacks ─────────────────────────────────────────────────

lib.callback.register('d4rk_emergency:server:getFleetStatus', function(source, deptKey)
    local dept = ActiveConfig[deptKey]
    if not dept then return {} end
    local fleet = Garage.GetFleetStatus(deptKey)
    -- Merge orderGrade + label from vehicle config into fleet status
    for _, v in ipairs(dept.vehicles or {}) do
        if fleet[v.model] then
            fleet[v.model].orderGrade = v.orderGrade or 6
            fleet[v.model].label      = v.label      or v.model
        end
    end
    return fleet
end)

-- ── Spawn vehicle ─────────────────────────────────────────────

RegisterNetEvent('d4rk_emergency:server:spawnVehicle', function(deptKey, model)
    local source   = source
    local dept     = ActiveConfig[deptKey]
    if not dept then return end

    -- Job + duty check
    local jobName, grade = exports['d4rk_core']:GetPlayerJob(source)
    if jobName ~= dept.jobName then
        Notify(source, 'Garage', 'You are not a member of this department.', 'error')
        return
    end
    if not onDutyPlayers[source] then
        Notify(source, 'Garage', 'You must be on duty to access the garage.', 'error')
        return
    end

    -- Find vehicle config + grade check
    local vehicleConfig
    for _, v in ipairs(dept.vehicles) do
        if v.model == model and grade >= v.grade then
            vehicleConfig = v
            break
        end
    end
    if not vehicleConfig then
        Notify(source, 'Garage', 'Your rank does not permit this vehicle.', 'error')
        return
    end

    -- Fleet availability check
    local fleetRow = MySQL.single.await(
        'SELECT available FROM `d4rk_emergency_fleet` WHERE dept_key = ? AND model = ?',
        { deptKey, model }
    )
    if not fleetRow or fleetRow.available <= 0 then
        Notify(source, 'Garage', 'No vehicles of this type currently available.', 'error')
        return
    end

    -- Generate unique plate
    local plate = GeneratePlate(dept.platePrefix)
    if not plate then
        Notify(source, 'Garage', 'Plate generation failed, try again.', 'error')
        return
    end

    -- Track in DB
    local identifier = exports['d4rk_core']:GetIdentifier(source)
    MySQL.insert.await(
        'INSERT INTO `d4rk_emergency_active_vehicles` (dept_key, model, plate, identifier) VALUES (?, ?, ?, ?)',
        { deptKey, model, plate, identifier }
    )
    MySQL.update.await(
        'UPDATE `d4rk_emergency_fleet` SET available = available - 1 WHERE dept_key = ? AND model = ?',
        { deptKey, model }
    )

    Log(('%s spawned %s [%s]'):format(exports['d4rk_core']:GetPlayerName(source), model, plate))
    TriggerClientEvent('d4rk_emergency:client:spawnVehicle', source, deptKey, model, plate, vehicleConfig)
end)

-- ── Return vehicle ────────────────────────────────────────────

RegisterNetEvent('d4rk_emergency:server:returnVehicle', function(deptKey, plate)
    local source = source
    plate = plate:gsub('%s+', '')

    -- Find active vehicle
    local row = MySQL.single.await(
        'SELECT model FROM `d4rk_emergency_active_vehicles` WHERE plate = ? AND dept_key = ?',
        { plate, deptKey }
    )
    if not row then
        Notify(source, 'Garage', 'This vehicle is not registered to your department.', 'error')
        return
    end

    -- Remove from active + restore fleet
    MySQL.update.await(
        'DELETE FROM `d4rk_emergency_active_vehicles` WHERE plate = ?', { plate }
    )
    MySQL.update.await(
        'UPDATE `d4rk_emergency_fleet` SET available = LEAST(available + 1, max_count) WHERE dept_key = ? AND model = ?',
        { deptKey, row.model }
    )

    Log(('Vehicle %s returned by %s'):format(plate, exports['d4rk_core']:GetPlayerName(source)), 'success')
    Notify(source, 'Garage', 'Vehicle returned successfully.', 'success')
    TriggerClientEvent('d4rk_emergency:client:deleteVehicle', source)
end)

-- ── Order vehicle (Chief+) ────────────────────────────────────

RegisterNetEvent('d4rk_emergency:server:orderVehicle', function(deptKey, model)
    local source = source
    local dept   = ActiveConfig[deptKey]
    if not dept then return end

    local jobName, grade = exports['d4rk_core']:GetPlayerJob(source)
    if jobName ~= dept.jobName then return end

    -- Find vehicle config
    local vehicleConfig
    for _, v in ipairs(dept.vehicles) do
        if v.model == model then vehicleConfig = v; break end
    end
    if not vehicleConfig then return end

    -- Grade check
    local orderGrade = vehicleConfig.orderGrade or 6
    if grade < orderGrade then
        Notify(source, 'Garage', 'Insufficient rank to order vehicles.', 'error')
        return
    end

    MySQL.update.await(
        'UPDATE `d4rk_emergency_fleet` SET max_count = max_count + 1, available = available + 1 WHERE dept_key = ? AND model = ?',
        { deptKey, model }
    )

    local playerName = exports['d4rk_core']:GetPlayerName(source)
    Log(('%s ordered 1x %s for %s (fleet expanded)'):format(playerName, model, deptKey), 'success')
    Notify(source, 'Garage', ('Fleet expanded: %s (+1)'):format(vehicleConfig.label), 'success')

    -- Notify all online members of this dept
    for _, playerId in ipairs(GetPlayers()) do
        local pJob = exports['d4rk_core']:GetPlayerJob(tonumber(playerId))
        if pJob == dept.jobName then
            Notify(tonumber(playerId), 'Garage',
                ('%s ordered a new %s'):format(playerName, vehicleConfig.label), 'inform')
        end
    end
end)