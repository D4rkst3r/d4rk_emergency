-- ============================================================
--  d4rk_emergency — Client Admin
-- ============================================================

local nuiOpen = false

local function OpenAdminPanel()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', isNUI = true })
    nuiOpen = true
end

RegisterCommand(Config.Admin.Command, function()
    OpenAdminPanel()
end, false)

RegisterNUICallback('admin_close', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    nuiOpen = false
    cb('ok')
end)

CreateThread(function()
    while true do
        Wait(0)
        if nuiOpen and IsControlJustReleased(0, 200) then
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })
            nuiOpen = false
        end
    end
end)

RegisterNUICallback('admin_getDepts', function(_, cb)
    lib.callback('d4rk_emergency:admin:getDepts', false, function(depts, err)
        cb({ success = depts ~= nil, data = depts, error = err })
    end)
end)

RegisterNUICallback('admin_saveDept', function(data, cb)
    lib.callback('d4rk_emergency:admin:saveDept', false, function(result)
        cb(result or { success = false, error = 'No response' })
    end, data.key, data.dept)
end)

RegisterNUICallback('admin_deleteDept', function(data, cb)
    lib.callback('d4rk_emergency:admin:deleteDept', false, function(result)
        cb(result or { success = false, error = 'No response' })
    end, data.key)
end)

RegisterNUICallback('admin_getPlayerCoords', function(_, cb)
    local coords = GetEntityCoords(PlayerPedId(), true)
    cb({
        x = DC.Round(coords.x, 2),
        y = DC.Round(coords.y, 2),
        z = DC.Round(coords.z, 2),
    })
end)

RegisterNUICallback('admin_presence', function(data, cb)
    lib.callback('d4rk_emergency:admin:presence', false, function(result)
        cb(result or false)
    end, data)
end)

RegisterNUICallback('admin_getStatus', function(_, cb)
    lib.callback('d4rk_emergency:admin:getStatus', false, function(result)
        cb(result or { editors = {}, versions = {} })
    end)
end)

-- ── Config hot-reload ─────────────────────────────────────────

RegisterNetEvent('d4rk_emergency:client:configUpdated', function(deptKey, deptData)
    -- 1. Statische Config aktualisieren (Fallback)
    if Config.Departments[deptKey] then
        local dept = Config.Departments[deptKey]
        dept.label         = deptData.label
        dept.shortLabel    = deptData.shortLabel
        dept.jobName       = deptData.jobName
        dept.color         = deptData.color
        dept.grades        = deptData.grades
        dept.armory        = deptData.armory
        dept.vehicles      = deptData.vehicles
        dept.blips         = deptData.blips
        dept.dutyZone      = deptData.dutyZone      or dept.dutyZone
        dept.cloakroomZone = deptData.cloakroomZone or dept.cloakroomZone
        dept.armoryZone    = deptData.armoryZone    or dept.armoryZone
        dept.garageZone    = deptData.garageZone    or dept.garageZone
    end

    -- 2. ActiveConfig auf Client aktualisieren (hat ped/prop Felder)
    ActiveConfig[deptKey] = deptData

    -- 3. Blips + Zones live refreshen
    RefreshDeptBlips(deptKey, deptData)
    RefreshDeptZones(deptKey, deptData)
end)

RegisterNetEvent('d4rk_emergency:client:deptDeleted', function(deptKey)
    Config.Departments[deptKey] = nil
end)