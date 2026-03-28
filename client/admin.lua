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
end, false)  -- false = client-side, server checks ace via NUI callback

-- ── Close ─────────────────────────────────────────────────────

RegisterNUICallback('admin_close', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    nuiOpen = false
    cb('ok')
end)

-- Escape key closes the panel
CreateThread(function()
    while true do
        Wait(0)
        if nuiOpen and IsControlJustReleased(0, 200) then  -- 200 = Escape
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })
            nuiOpen = false
        end
    end
end)

-- ── NUI → Server bridge ───────────────────────────────────────

-- Get all departments
RegisterNUICallback('admin_getDepts', function(_, cb)
    lib.callback('d4rk_emergency:admin:getDepts', false, function(depts, err)
        cb({ success = depts ~= nil, data = depts, error = err })
    end)
end)

-- Save / upsert a department
RegisterNUICallback('admin_saveDept', function(data, cb)
    lib.callback('d4rk_emergency:admin:saveDept', false, function(result)
        cb(result or { success = false, error = 'No response' })
    end, data.key, data.dept)
end)

-- Delete a department
RegisterNUICallback('admin_deleteDept', function(data, cb)
    lib.callback('d4rk_emergency:admin:deleteDept', false, function(result)
        cb(result or { success = false, error = 'No response' })
    end, data.key)
end)

-- ── Config hot-reload ─────────────────────────────────────────
-- When admin saves from browser or another in-game client,
-- update the local dept config so zone labels / menus reflect changes

RegisterNetEvent('d4rk_emergency:client:configUpdated', function(deptKey, deptData)
    -- Update the live config used by client/main.lua
    -- (zones re-register on next resource restart; menus/labels update immediately)
    if Config.Departments[deptKey] then
        -- Shallow-merge non-zone fields that don't require zone re-registration
        local dept = Config.Departments[deptKey]
        dept.label      = deptData.label
        dept.shortLabel = deptData.shortLabel
        dept.jobName    = deptData.jobName
        dept.color      = deptData.color
        dept.grades     = deptData.grades
        dept.armory     = deptData.armory
        dept.vehicles   = deptData.vehicles
    end
end)

RegisterNetEvent('d4rk_emergency:client:deptDeleted', function(deptKey)
    Config.Departments[deptKey] = nil
end)
