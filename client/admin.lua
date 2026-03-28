-- ============================================================
--  d4rk_emergency — Client Admin
--  Opens NUI panel via command, bridges NUI <-> server callbacks
-- ============================================================

local nuiOpen = false

-- ── Open admin panel ─────────────────────────────────────────

local function OpenAdminPanel()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', isNUI = true })
    nuiOpen = true
end

RegisterCommand(Config.Admin.Command, function()
    OpenAdminPanel()
end, false)

-- ── Close ─────────────────────────────────────────────────────

RegisterNUICallback('admin_close', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    nuiOpen = false
    cb('ok')
end)

-- Escape closes the panel
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

-- ── NUI → Server bridge ───────────────────────────────────────

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

-- ── Player position (for blip placement) ─────────────────────

RegisterNUICallback('admin_getPlayerCoords', function(_, cb)
    local coords = GetEntityCoords(PlayerPedId(), true)
    cb({
        x = math.floor(coords.x * 100) / 100,
        y = math.floor(coords.y * 100) / 100,
        z = math.floor(coords.z * 100) / 100,
    })
end)

-- ── Collaboration callbacks ───────────────────────────────────

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
    -- 1. Update local Config.Departments (menus / labels)
    if Config.Departments[deptKey] then
        local dept = Config.Departments[deptKey]
        dept.label      = deptData.label
        dept.shortLabel = deptData.shortLabel
        dept.jobName    = deptData.jobName
        dept.color      = deptData.color
        dept.grades     = deptData.grades
        dept.armory     = deptData.armory
        dept.vehicles   = deptData.vehicles
        dept.blips      = deptData.blips
    end

    -- 2. Refresh map blips live (RefreshDeptBlips is defined in client/main.lua)
    RefreshDeptBlips(deptKey, deptData)
end)

RegisterNetEvent('d4rk_emergency:client:deptDeleted', function(deptKey)
    Config.Departments[deptKey] = nil
    -- Blip removal is handled in client/main.lua's deptDeleted handler
end)