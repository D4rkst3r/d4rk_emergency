-- ============================================================
--  d4rk_emergency — Client Main
--  Uses d4rk_core for: Notify, GetPlayerJob, CreateBlip
-- ============================================================

local isOnDuty    = false
local currentDept = nil
local dutyCounts  = {}

-- ── d4rk_core shortcuts ───────────────────────────────────────

local function Notify(title, msg, ntype)
    exports['d4rk_core']:Notify(title, msg, ntype)
end

local function GetPlayerJob()
    return exports['d4rk_core']:GetPlayerJob()
end

-- ── Blip management ───────────────────────────────────────────
-- Blips are visible to ALL players (public map markers)
-- activeBlips[deptKey] = { blipHandle, blipHandle, ... }

local activeBlips = {}

local function RemoveDeptBlips(deptKey)
    if not activeBlips[deptKey] then return end
    for _, blip in ipairs(activeBlips[deptKey]) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    activeBlips[deptKey] = nil
end

local function CreateDeptBlips(deptKey, deptData)
    RemoveDeptBlips(deptKey)
    local blips = deptData.blips
    if not blips or #blips == 0 then return end

    activeBlips[deptKey] = {}
    for _, b in ipairs(blips) do
        if b.coords then
            local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
            SetBlipDisplay(blip, 2)
            SetBlipSprite(blip, b.sprite or 1)
            SetBlipColour(blip, b.color or 0)
            SetBlipScale(blip, b.scale or 0.85)
            SetBlipAsShortRange(blip, b.shortRange ~= false)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(b.label ~= '' and b.label or (deptData.shortLabel or deptKey))
            EndTextCommandSetBlipName(blip)
            activeBlips[deptKey][#activeBlips[deptKey] + 1] = blip
        end
    end
end

-- Called by client/admin.lua when configUpdated fires
function RefreshDeptBlips(deptKey, deptData)
    CreateDeptBlips(deptKey, deptData)
end

-- ── Utility ───────────────────────────────────────────────────

local function GetCurrentDept()
    local jobName = GetPlayerJob()
    if not jobName then return nil, nil end
    return Config.GetDeptByJob(jobName)
end

-- ── Zone registration ─────────────────────────────────────────

CreateThread(function()
    while not exports.qbx_core:GetPlayerData() do Wait(500) end

    local deptKey, dept = GetCurrentDept()
    if not deptKey then return end

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
                    exports['illenium-appearance']:restoreSavedOutfit()
                    Notify(dept.shortLabel, 'Uniform removed.', 'inform')
                end,
            }
        }
    })

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

-- ── Cloakroom ─────────────────────────────────────────────────

function OpenCloakroom(deptKey, dept)
    local _, grade = GetPlayerJob()
    local gender   = exports['illenium-appearance']:getPedGender() == 1 and 'female' or 'male'
    local outfits  = dept.outfits[gender]
    local outfit   = outfits[grade] or outfits[0]
    if not outfit then
        Notify(dept.shortLabel, 'No outfit configured for your rank.', 'error')
        return
    end
    exports['illenium-appearance']:saveCurrentOutfit()
    for compId, compData in pairs(outfit.components) do
        SetPedComponentVariation(PlayerPedId(), compId, compData.item, compData.texture, 0)
    end
    local gradeLabel = dept.grades[grade] and dept.grades[grade].label or 'Unknown'
    Notify(dept.shortLabel, ('Uniform applied: %s'):format(gradeLabel), 'success')
end

-- ── Armory menu ───────────────────────────────────────────────

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
    lib.registerContext({ id = 'd4rk_armory_' .. deptKey, title = dept.shortLabel .. ' — Armory', options = options })
    lib.showContext('d4rk_armory_' .. deptKey)
end

-- ── Garage menu ───────────────────────────────────────────────

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
    lib.registerContext({ id = 'd4rk_garage_' .. deptKey, title = dept.shortLabel .. ' — Garage', options = options })
    lib.showContext('d4rk_garage_' .. deptKey)
end

-- ── Vehicle spawn ─────────────────────────────────────────────

RegisterNetEvent('d4rk_emergency:client:spawnVehicle', function(deptKey, model)
    local dept       = Config.Departments[deptKey]
    local spawnPoint = dept.garageZone.spawnPoint
    lib.requestModel(model)
    local vehicle = CreateVehicle(
        GetHashKey(model),
        spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w,
        true, false
    )
    SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
    SetVehicleEngineOn(vehicle, true, true, false)
    Notify(dept.shortLabel, ('Vehicle spawned: %s'):format(model), 'success')
end)

-- ── Duty sync ─────────────────────────────────────────────────

RegisterNetEvent('d4rk_emergency:client:dutyChanged', function(onDuty, deptKey)
    isOnDuty    = onDuty
    currentDept = onDuty and deptKey or nil
end)

RegisterNetEvent('d4rk_emergency:client:updateDutyCount', function(deptKey, count)
    dutyCounts[deptKey] = count
end)

-- ── Blip init from server (DB data) ──────────────────────────

RegisterNetEvent('d4rk_emergency:client:initBlips', function(blipData)
    for deptKey, data in pairs(blipData) do
        CreateDeptBlips(deptKey, data)
    end
end)

-- ── Dept deleted ──────────────────────────────────────────────

RegisterNetEvent('d4rk_emergency:client:deptDeleted', function(deptKey)
    RemoveDeptBlips(deptKey)
end)

-- ── Resource start ────────────────────────────────────────────

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for deptKey in pairs(Config.Departments) do
        TriggerServerEvent('d4rk_emergency:server:getDutyCount', deptKey)
    end
    TriggerServerEvent('d4rk_emergency:server:requestBlips')
end)

AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    -- Zone re-registration handled on resource restart
end)