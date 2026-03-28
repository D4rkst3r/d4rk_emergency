-- ============================================================
--  d4rk_emergency — Server Main
-- ============================================================

ActiveConfig    = {}
local onDutyPlayers = {}

-- ── Startup ───────────────────────────────────────────────────

CreateThread(function()
    Wait(500)
    DB.LoadAll(function(depts)
        if next(depts) then
            ActiveConfig = depts
            print(('[d4rk_emergency] Loaded %d department(s) from DB.'):format(table.count(ActiveConfig)))
        else
            print('[d4rk_emergency] No departments in DB — seeding from Config.Departments ...')
            for deptKey, dept in pairs(Config.Departments) do
                DB.Save(deptKey, dept, function(ok)
                    if ok then print(('[d4rk_emergency] Seeded: %s'):format(deptKey)) end
                end)
                ActiveConfig[deptKey] = dept
            end
        end
    end)
end)

function table.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- ── Utility ───────────────────────────────────────────────────

local function GetPlayerJob(source)
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return nil, nil end
    return Player.PlayerData.job.name, Player.PlayerData.job.grade.level
end

local function IsValidDeptJob(source, deptKey)
    local dept = ActiveConfig[deptKey]
    if not dept then return false end
    local jobName = GetPlayerJob(source)
    return jobName == dept.jobName
end

local function Notify(source, title, msg, ntype)
    TriggerClientEvent('ox_lib:notify', source, {
        title       = title,
        description = msg,
        type        = ntype or 'inform',
        duration    = 5000,
        position    = Config.NotifyPosition,
    })
end

-- ── Blips ─────────────────────────────────────────────────────
-- Clients request all dept blips on resource start so they get
-- the DB version rather than the static shared.lua fallback.

RegisterNetEvent('d4rk_emergency:server:requestBlips', function()
    local source = source
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
    TriggerClientEvent('d4rk_emergency:client:initBlips', source, blipData)
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
    local dept = ActiveConfig[deptKey]

    if onDutyPlayers[source] then
        onDutyPlayers[source] = nil
        exports.qbx_core:SetPlayerJobDuty(source, false)
        Notify(source, dept.shortLabel, 'You are now OFF DUTY.', 'inform')
        TriggerClientEvent('d4rk_emergency:client:dutyChanged', source, false, deptKey)
    else
        onDutyPlayers[source] = { deptKey = deptKey, grade = grade }
        exports.qbx_core:SetPlayerJobDuty(source, true)
        local gradeLabel = dept.grades[grade] and dept.grades[grade].label or 'Unknown'
        Notify(source, dept.shortLabel, ('You are now ON DUTY as %s.'):format(gradeLabel), 'success')
        TriggerClientEvent('d4rk_emergency:client:dutyChanged', source, true, deptKey)
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
                exports['Renewed-Banking']:addAccountMoney('bank', src, amount, ('Salary - %s'):format(dept.shortLabel))
                Notify(src, 'Payroll', ('Salary received: $%s (%s)'):format(amount, gradeData.label), 'success')
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

    local dept    = ActiveConfig[deptKey]
    local _, grade = GetPlayerJob(source)
    local allowed = false

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