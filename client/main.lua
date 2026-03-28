-- ============================================================
--  d4rk_emergency — Client Main
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

-- ── Vec helper (deptData from configUpdated has plain tables, not vec3) ──

local function toVec3(v)
    if not v then return vec3(0, 0, 0) end
    if type(v) == 'userdata' then return v end
    return vec3(tonumber(v.x) or 0, tonumber(v.y) or 0, tonumber(v.z) or 0)
end

-- ── Blip management ───────────────────────────────────────────

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

function RefreshDeptBlips(deptKey, deptData)
    CreateDeptBlips(deptKey, deptData)
end

-- ── Zone management ───────────────────────────────────────────

local registeredZones = {}

local function RemoveDeptZones(deptKey)
    local names = registeredZones[deptKey]
    if not names then return end
    for _, name in pairs(names) do
        exports.ox_target:removeZone(name)
    end
    registeredZones[deptKey] = nil
end

-- ── Utility ───────────────────────────────────────────────────

local function GetCurrentDept()
    local jobName = GetPlayerJob()
    if not jobName then return nil, nil end
    return Config.GetDeptByJob(jobName)
end

-- ── RegisterDeptZones ─────────────────────────────────────────

local function RegisterDeptZones(deptKey, dept)
    RemoveDeptZones(deptKey)

    local p     = 'd4rk_' .. deptKey .. '_'
    local names = {
        duty      = p .. 'duty',
        cloakroom = p .. 'cloakroom',
        armory    = p .. 'armory',
        garage    = p .. 'garage',
    }
    registeredZones[deptKey] = names

    exports.ox_target:addBoxZone({
        name     = names.duty,
        coords   = toVec3(dept.dutyZone.coords),
        size     = vec3(3.0, 3.0, 3.0),
        rotation = dept.dutyZone.rotation or 0,
        debug    = true,
        options  = {
            {
                distance = 1.5,
                label    = isOnDuty and ('Go Off Duty [%s]'):format(dept.shortLabel)
                                     or ('Go On Duty [%s]'):format(dept.shortLabel),
                icon     = isOnDuty and 'fas fa-sign-out-alt' or 'fas fa-sign-in-alt',
                groups   = dept.jobName,
                onSelect = function()
                    TriggerServerEvent('d4rk_emergency:server:toggleDuty', deptKey)
                end,
            }
        }
    })

    exports.ox_target:addBoxZone({
        name     = names.cloakroom,
        coords   = toVec3(dept.cloakroomZone.coords),
        size     = toVec3(dept.cloakroomZone.size),
        rotation = dept.cloakroomZone.rotation or 0,
        options  = {
            {
                distance = 1.5,
                label    = 'Change Uniform',
                icon     = 'fas fa-tshirt',
                groups   = dept.jobName,
                onSelect = function()
                    if not isOnDuty then
                        Notify(dept.shortLabel, 'You must be on duty to change uniform.', 'error')
                        return
                    end
                    OpenCloakroom(deptKey, dept)
                end,
            },
            {
                distance = 1.5,
                label    = 'Remove Uniform',
                icon     = 'fas fa-undo',
                groups   = dept.jobName,
                onSelect = function()
                    exports['illenium-appearance']:restoreSavedOutfit()
                    Notify(dept.shortLabel, 'Uniform removed.', 'inform')
                end,
            }
        }
    })

    exports.ox_target:addBoxZone({
        name     = names.armory,
        coords   = toVec3(dept.armoryZone.coords),
        size     = toVec3(dept.armoryZone.size),
        rotation = dept.armoryZone.rotation or 0,
        options  = {
            {
                distance = 1.5,
                label    = 'Open Armory',
                icon     = 'fas fa-shield-alt',
                groups   = dept.jobName,
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
        name     = names.garage,
        coords   = toVec3(dept.garageZone.coords),
        size     = toVec3(dept.garageZone.size),
        rotation = dept.garageZone.rotation or 0,
        options  = {
            {
                distance = 1.5,
                label    = 'Open Garage',
                icon     = 'fas fa-car',
                groups   = dept.jobName,
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
end

-- ── RefreshDeptZones (called from admin.lua on configUpdated) ─

function RefreshDeptZones(deptKey, deptData)
    local jobName = GetPlayerJob()
    if not jobName then return end
    local myDeptKey = Config.GetDeptByJob(jobName)
    if myDeptKey ~= deptKey then return end
    RegisterDeptZones(deptKey, deptData)
end

-- ── InitZones ─────────────────────────────────────────────────

local function InitZones()
    while not exports.qbx_core:GetPlayerData() do Wait(500) end

    local deptKey, dept = GetCurrentDept()
    if not deptKey then
        print('[d4rk_emergency] InitZones: no matching dept for job ' .. tostring(GetPlayerJob()))
        return
    end

    print('[d4rk_emergency] InitZones: registering zones for ' .. deptKey)
    RegisterDeptZones(deptKey, dept)
end

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

    local dept = Config.Departments[deptKey]
    if dept then
        RegisterDeptZones(deptKey, dept)
    end
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
    RemoveDeptZones(deptKey)
end)

-- ── Resource start ────────────────────────────────────────────

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for deptKey in pairs(Config.Departments) do
        TriggerServerEvent('d4rk_emergency:server:getDutyCount', deptKey)
    end
    TriggerServerEvent('d4rk_emergency:server:requestBlips')

    CreateThread(function()
        InitZones()
    end)
end)

AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    -- Zone re-registration handled via onClientResourceStart / dutyChanged
end)