-- ============================================================
--  d4rk_emergency — Server Main
--  Uses d4rk_core for: Notify, Logging, GetPlayerJob, GetIdentifier
-- ============================================================

ActiveConfig    = {}
onDutyPlayers   = {}   -- global so garage.lua can access it

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

-- ── Grade helper ──────────────────────────────────────────────

local function GetGrade(dept, grade)
    return dept.grades[grade] or dept.grades[tostring(grade)] or {}
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

        -- Sync fleet for all departments
        for deptKey, dept in pairs(ActiveConfig) do
            Garage.SyncFleet(deptKey, dept)
        end
        Log('Fleet synced.', 'success')

        -- Broadcast blips to already-connected clients
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
    local Player         = exports.qbx_core:GetPlayer(source)
    if not Player then return end

    if onDutyPlayers[source] then
        onDutyPlayers[source] = nil
        Player.Functions.SetJobDuty(false)
        Notify(source, dept.shortLabel, 'You are now OFF DUTY.', 'inform')
        TriggerClientEvent('d4rk_emergency:client:dutyChanged', source, false, deptKey)
        Log(('%s went OFF DUTY [%s]'):format(exports['d4rk_core']:GetPlayerName(source), dept.shortLabel))
    else
        onDutyPlayers[source] = { deptKey = deptKey, grade = grade }
        Player.Functions.SetJobDuty(true)
        local gradeLabel = GetGrade(dept, grade).label or 'Unknown'
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
            local gradeData = GetGrade(dept, data.grade)
            if gradeData and gradeData.salary then
                local amount = gradeData.salary
                exports['Renewed-Banking']:addAccountMoney(
                    'bank', src, amount,
                    ('Salary - %s'):format(dept.shortLabel)
                )
                Notify(src, 'Payroll',
                    ('Salary received: %s (%s)'):format(DC.FormatMoney(amount), gradeData.label or ''),
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


-- Gibt alle aktiven Dept-Configs zurück (für d4rk_garage + d4rk_acp)
exports('getDeptConfig', function(deptKey)
    return ActiveConfig[deptKey]
end)

exports('getAllDepts', function()
    return ActiveConfig
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