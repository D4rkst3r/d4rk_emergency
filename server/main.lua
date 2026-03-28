-- ============================================================
--  d4rk_emergency — Server Main
--  Uses d4rk_core for: Notify, Logging, GetPlayerJob, GetIdentifier
-- ============================================================

ActiveConfig        = {}
local onDutyPlayers = {}

-- ── d4rk_core shortcuts ───────────────────────────────────────

local function Notify(source, title, msg, ntype)
    exports['d4rk_core']:Notify(source, title, msg, ntype)
end

local function Log(msg, level, fields)
    exports['d4rk_core']:Log('emergency', msg, level or 'info', fields)
end

local function GetPlayerJob(source)
    return exports['d4rk_core']:GetPlayerJob(source)
end

-- ── Startup ───────────────────────────────────────────────────

CreateThread(function()
    Wait(500)
    DB.LoadAll(function(depts)
        if next(depts) then
            ActiveConfig = depts
            Log(('Loaded %d department(s) from DB.'):format(DC.TableCount(ActiveConfig)), 'success')
        else
            Log('No departments in DB — seeding from Config.Departments...', 'warn')
            for deptKey, dept in pairs(Config.Departments) do
                DB.Save(deptKey, dept, function(ok)
                    if ok then Log(('Seeded: %s'):format(deptKey)) end
                end)
                ActiveConfig[deptKey] = dept
            end
        end

        -- Broadcast blips to all already-connected clients.
        -- Needed when the resource is restarted while players are online,
        -- because their onClientResourceStart already fired before ActiveConfig was ready.
        local blipData = BuildBlipData()
        if next(blipData) then
            TriggerClientEvent('d4rk_emergency:client:initBlips', -1, blipData)
        end
    end)
end)

-- ── Utility ───────────────────────────────────────────────────

local function IsValidDeptJob(source, deptKey)
    local dept = ActiveConfig[deptKey]
    if not dept then return false end
    local jobName = GetPlayerJob(source)
    return jobName == dept.jobName
end

-- ── Blips ─────────────────────────────────────────────────────

function BuildBlipData()
    local blipData = {}
    for deptKey, dept in pairs(ActiveConfig) do
        if dept.blips and #dept.blips > 0 then
            blipData[deptKey] = {
                shortLabel = dept.shortLabel,
                color      = dept.color,
                blips      = dept.blips,
            }
        end
    end
    return blipData
end

-- Client requests blip data on resource start.
-- Uses a thread with retry because ActiveConfig may not be ready yet
-- (e.g. resource restart while players are online).
RegisterNetEvent('d4rk_emergency:server:requestBlips', function()
    local src = source
    CreateThread(function()
        local attempts = 0
        while not next(ActiveConfig) and attempts < 20 do
            Wait(500)
            attempts = attempts + 1
        end
        TriggerClientEvent('d4rk_emergency:client:initBlips', src, BuildBlipData())
    end)
end)

-- ── Duty ──────────────────────────────────────────────────────

function GetDutyCount(deptKey)
    local count = 0
    for _, data in pairs(onDutyPlayers) do
        if data.deptKey == deptKey then count = count + 1 end
    end
    return count
end

RegisterNetEvent('d4rk_emergency:server:toggleDuty', function(deptKey)
    local source = source
    if not IsValidDeptJob(source, deptKey) then
        Notify(source, 'Access Denied', 'You are not a member of this department.', 'error')
        return
    end

    local jobName, grade = GetPlayerJob(source)
    local dept           = ActiveConfig[deptKey]

    if onDutyPlayers[source] then
        onDutyPlayers[source] = nil
        exports.qbx_core:SetPlayerJobDuty(source, false)
        Notify(source, dept.shortLabel, 'You are now OFF DUTY.', 'inform')
        TriggerClientEvent('d4rk_emergency:client:dutyChanged', source, false, deptKey)
        Log(('%s went OFF DUTY [%s]'):format(
            exports['d4rk_core']:GetPlayerName(source), dept.shortLabel))
    else
        onDutyPlayers[source] = { deptKey = deptKey, grade = grade }
        exports.qbx_core:SetPlayerJobDuty(source, true)
        local gradeLabel = dept.grades[grade] and dept.grades[grade].label or 'Unknown'
        Notify(source, dept.shortLabel, ('You are now ON DUTY as %s.'):format(gradeLabel), 'success')
        TriggerClientEvent('d4rk_emergency:client:dutyChanged', source, true, deptKey)
        Log(('%s went ON DUTY [%s] as %s'):format(
            exports['d4rk_core']:GetPlayerName(source), dept.shortLabel, gradeLabel))
    end

    TriggerClientEvent('d4rk_emergency:client:updateDutyCount', -1, deptKey, GetDutyCount(deptKey))
end)

RegisterNetEvent('d4rk_emergency:server:getDutyCount', function(deptKey)
    TriggerClientEvent('d4rk_emergency:client:updateDutyCount', source, deptKey, GetDutyCount(deptKey))
end)

-- ── Salary ────────────────────────────────────────────────────

local function PaySalary()
    for src, data in pairs(onDutyPlayers) do
        local dept = ActiveConfig[data.deptKey]
        if dept then
            local gradeData = dept.grades[data.grade]
            if gradeData then
                local amount = gradeData.salary
                exports['Renewed-Banking']:addAccountMoney(
                    'bank', src, amount,
                    ('Salary - %s'):format(dept.shortLabel)
                )
                Notify(src, 'Payroll',
                    ('Salary received: %s (%s)'):format(DC.FormatMoney(amount), gradeData.label),
                    'success')
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(Config.SalaryInterval)
        PaySalary()
    end
end)

-- ── Armory ────────────────────────────────────────────────────

RegisterNetEvent('d4rk_emergency:server:giveWeapon', function(deptKey, itemName)
    local source = source
    if not IsValidDeptJob(source, deptKey) then return end
    if not onDutyPlayers[source] then
        Notify(source, 'Armory', 'You must be on duty to access the armory.', 'error')
        return
    end

    local dept     = ActiveConfig[deptKey]
    local _, grade = GetPlayerJob(source)
    local allowed  = false

    for _, entry in ipairs(dept.armory) do
        if entry.item == itemName and grade >= entry.grade then
            allowed = true
            break
        end
    end

    if not allowed then
        Notify(source, 'Armory', 'Your rank does not permit this equipment.', 'error')
        return
    end

    exports.ox_inventory:AddItem(source, itemName, 1)
    Notify(source, 'Armory', ('Issued: %s'):format(itemName), 'success')
end)

-- ── Garage ────────────────────────────────────────────────────

RegisterNetEvent('d4rk_emergency:server:spawnVehicle', function(deptKey, model)
    local source = source
    if not IsValidDeptJob(source, deptKey) then return end
    if not onDutyPlayers[source] then
        Notify(source, 'Garage', 'You must be on duty to access the garage.', 'error')
        return
    end

    local dept     = ActiveConfig[deptKey]
    local _, grade = GetPlayerJob(source)
    local allowed  = false

    for _, v in ipairs(dept.vehicles) do
        if v.model == model and grade >= v.grade then
            allowed = true
            break
        end
    end

    if not allowed then
        Notify(source, 'Garage', 'Your rank does not permit this vehicle.', 'error')
        return
    end

    TriggerClientEvent('d4rk_emergency:client:spawnVehicle', source, deptKey, model)
end)

-- ── Config sync ───────────────────────────────────────────────

lib.callback.register('d4rk_emergency:server:getActiveConfig', function(source)
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return nil end
    local jobName = Player.PlayerData.job.name
    for deptKey, dept in pairs(ActiveConfig) do
        if dept.jobName == jobName then
            return DB.ExportDept(deptKey, dept)
        end
    end
    return nil
end)

-- ── Cleanup ───────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local source = source
    if onDutyPlayers[source] then
        local data = onDutyPlayers[source]
        onDutyPlayers[source] = nil
        TriggerClientEvent('d4rk_emergency:client:updateDutyCount', -1, data.deptKey, GetDutyCount(data.deptKey))
    end
end)