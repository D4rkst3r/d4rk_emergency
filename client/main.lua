-- ============================================================
--  d4rk_emergency — Client Main
-- ============================================================

local isOnDuty   = false
local currentDept = nil
local dutyCounts  = {}   -- [deptKey] = count

-- ============================================================
--  UTILITY
-- ============================================================

local function GetPlayerJob()
    local playerData = exports.qbx_core:GetPlayerData()
    if not playerData then return nil, nil end
    return playerData.job.name, playerData.job.grade.level
end

local function GetCurrentDept()
    local jobName = GetPlayerJob()
    if not jobName then return nil, nil end
    return Config.GetDeptByJob(jobName)
end

local function Notify(title, msg, ntype)
    lib.notify({
        title       = title,
        description = msg,
        type        = ntype or 'inform',
        duration    = 5000,
        position    = Config.NotifyPosition,
    })
end

-- ============================================================
--  OX_TARGET ZONE REGISTRATION
-- ============================================================

CreateThread(function()
    -- Wait for player data to be ready
    while not exports.qbx_core:GetPlayerData() do Wait(500) end

    local deptKey, dept = GetCurrentDept()
    if not deptKey then return end  -- Not a department member

    -- ── DUTY BOARD ─────────────────────────────────────────
    exports.ox_target:addBoxZone({
        coords   = dept.dutyZone.coords,
        size     = dept.dutyZone.size,
        rotation = dept.dutyZone.rotation,
        options  = {
            {
                label    = isOnDuty and ('Go Off Duty [%s]'):format(dept.shortLabel)
                                     or ('Go On Duty [%s]'):format(dept.shortLabel),
                icon     = isOnDuty and 'fas fa-sign-out-alt' or 'fas fa-sign-in-alt',
                onSelect = function()
                    TriggerServerEvent('d4rk_emergency:server:toggleDuty', deptKey)
                end,
            }
        }
    })

    -- ── CLOAKROOM ───────────────────────────────────────────
    exports.ox_target:addBoxZone({
        coords   = dept.cloakroomZone.coords,
        size     = dept.cloakroomZone.size,
        rotation = dept.cloakroomZone.rotation,
        options  = {
            {
                label    = 'Change Uniform',
                icon     = 'fas fa-tshirt',
                onSelect = function()
                    if not isOnDuty then
                        Notify(dept.shortLabel, 'You must be on duty to change uniform.', 'error')
                        return
                    end
                    OpenCloakroom(deptKey, dept)
                end,
            },
            {
                label    = 'Remove Uniform',
                icon     = 'fas fa-undo',
                onSelect = function()
                    -- Restore saved civilian outfit
                    exports['illenium-appearance']:restoreSavedOutfit()
                    Notify(dept.shortLabel, 'Uniform removed.', 'inform')
                end,
            }
        }
    })

    -- ── ARMORY ──────────────────────────────────────────────
    exports.ox_target:addBoxZone({
        coords   = dept.armoryZone.coords,
        size     = dept.armoryZone.size,
        rotation = dept.armoryZone.rotation,
        options  = {
            {
                label    = 'Open Armory',
                icon     = 'fas fa-shield-alt',
                onSelect = function()
                    if not isOnDuty then
                        Notify(dept.shortLabel, 'You must be on duty to access the armory.', 'error')
                        return
                    end
                    OpenArmoryMenu(deptKey, dept)
                end,
            }
        }
    })

    -- ── GARAGE ──────────────────────────────────────────────
    exports.ox_target:addBoxZone({
        coords   = dept.garageZone.coords,
        size     = dept.garageZone.size,
        rotation = dept.garageZone.rotation,
        options  = {
            {
                label    = 'Open Garage',
                icon     = 'fas fa-car',
                onSelect = function()
                    if not isOnDuty then
                        Notify(dept.shortLabel, 'You must be on duty to access the garage.', 'error')
                        return
                    end
                    OpenGarageMenu(deptKey, dept)
                end,
            }
        }
    })
end)

-- ============================================================
--  CLOAKROOM
-- ============================================================

function OpenCloakroom(deptKey, dept)
    local _, grade = GetPlayerJob()
    local gender   = exports['illenium-appearance']:getPedGender() == 1 and 'female' or 'male'
    local outfits  = dept.outfits[gender]

    -- Find best outfit for current grade (fall back to grade 0)
    local outfit = outfits[grade] or outfits[0]
    if not outfit then
        Notify(dept.shortLabel, 'No outfit configured for your rank.', 'error')
        return
    end

    -- Save current civilian outfit before applying uniform
    exports['illenium-appearance']:saveCurrentOutfit()

    -- Apply components
    for compId, compData in pairs(outfit.components) do
        SetPedComponentVariation(PlayerPedId(), compId, compData.item, compData.texture, 0)
    end

    local gradeLabel = dept.grades[grade] and dept.grades[grade].label or 'Unknown'
    Notify(dept.shortLabel, ('Uniform applied: %s'):format(gradeLabel), 'success')
end

-- ============================================================
--  ARMORY MENU
-- ============================================================

function OpenArmoryMenu(deptKey, dept)
    local _, grade = GetPlayerJob()
    local options  = {}

    for _, entry in ipairs(dept.armory) do
        if grade >= entry.grade then
            options[#options + 1] = {
                title    = entry.label,
                icon     = 'fas fa-box',
                onSelect = function()
                    TriggerServerEvent('d4rk_emergency:server:giveWeapon', deptKey, entry.item)
                end,
            }
        end
    end

    if #options == 0 then
        Notify(dept.shortLabel, 'No equipment available for your rank.', 'error')
        return
    end

    lib.registerContext({
        id      = 'd4rk_armory_' .. deptKey,
        title   = dept.shortLabel .. ' — Armory',
        options = options,
    })
    lib.showContext('d4rk_armory_' .. deptKey)
end

-- ============================================================
--  GARAGE MENU
-- ============================================================

function OpenGarageMenu(deptKey, dept)
    local _, grade = GetPlayerJob()
    local options  = {}

    for _, v in ipairs(dept.vehicles) do
        if grade >= v.grade then
            options[#options + 1] = {
                title    = v.label,
                icon     = 'fas fa-car',
                onSelect = function()
                    TriggerServerEvent('d4rk_emergency:server:spawnVehicle', deptKey, v.model)
                end,
            }
        end
    end

    if #options == 0 then
        Notify(dept.shortLabel, 'No vehicles available for your rank.', 'error')
        return
    end

    lib.registerContext({
        id      = 'd4rk_garage_' .. deptKey,
        title   = dept.shortLabel .. ' — Garage',
        options = options,
    })
    lib.showContext('d4rk_garage_' .. deptKey)
end

-- ============================================================
--  VEHICLE SPAWN (triggered from server)
-- ============================================================

RegisterNetEvent('d4rk_emergency:client:spawnVehicle', function(deptKey, model)
    local dept       = Config.Departments[deptKey]
    local spawnPoint = dept.garageZone.spawnPoint

    lib.requestModel(model)

    local vehicle = CreateVehicle(
        GetHashKey(model),
        spawnPoint.x, spawnPoint.y, spawnPoint.z,
        spawnPoint.w,
        true, false
    )

    SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
    SetVehicleEngineOn(vehicle, true, true, false)

    -- Set faction livery/extras if needed — expand here
    Notify(dept.shortLabel, ('Vehicle spawned: %s'):format(model), 'success')
end)

-- ============================================================
--  DUTY STATE SYNC (from server)
-- ============================================================

RegisterNetEvent('d4rk_emergency:client:dutyChanged', function(onDuty, deptKey)
    isOnDuty    = onDuty
    currentDept = onDuty and deptKey or nil
end)

RegisterNetEvent('d4rk_emergency:client:updateDutyCount', function(deptKey, count)
    dutyCounts[deptKey] = count
end)

-- Fetch duty counts on resource start
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for deptKey in pairs(Config.Departments) do
        TriggerServerEvent('d4rk_emergency:server:getDutyCount', deptKey)
    end
end)

-- ============================================================
--  JOB CHANGE — re-register zones if job changes mid-session
-- ============================================================

AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    -- Resource restart handles re-registration
    -- Optional: TriggerEvent to re-run zone setup
end)
