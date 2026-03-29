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

-- ── Vec helper ────────────────────────────────────────────────

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

-- ── Entity management ─────────────────────────────────────────

local spawnedEntities = {}

local function SpawnZoneProp(model, coords, rotation)
    if not model or model == '' then return nil end
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then
        print('[d4rk_emergency] Prop not in cdimage: ' .. model)
        return nil
    end
    lib.requestModel(model)
    local prop = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityAsMissionEntity(prop, true, true)
    FreezeEntityPosition(prop, true)
    SetEntityHeading(prop, rotation or 0)
    SetModelAsNoLongerNeeded(hash)
    return prop
end

local function SpawnZonePed(model, coords, rotation, scenario)
    if not model or model == '' then return nil end
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then
        print('[d4rk_emergency] Ped not in cdimage: ' .. model)
        return nil
    end
    lib.requestModel(model)
    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, rotation or 0, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)
    SetModelAsNoLongerNeeded(hash)
    if scenario and scenario ~= '' then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end
    return ped
end

local function SpawnZoneEntity(zone)
    local coords   = toVec3(zone.coords)
    local rotation = zone.rotation or 0
    if zone.ped and zone.ped ~= '' then
        return SpawnZonePed(zone.ped, coords, rotation, zone.pedScenario)
    elseif zone.prop and zone.prop ~= '' then
        return SpawnZoneProp(zone.prop, coords, rotation)
    end
    return nil
end

local function DespawnDeptEntities(deptKey)
    if not spawnedEntities[deptKey] then return end
    for _, entity in pairs(spawnedEntities[deptKey]) do
        if DoesEntityExist(entity) then
            exports.ox_target:removeLocalEntity(entity)
            DeleteEntity(entity)
        end
    end
    spawnedEntities[deptKey] = nil
end

-- ── Zone management ───────────────────────────────────────────

local registeredZones = {}

local function RemoveDeptZones(deptKey)
    local names = registeredZones[deptKey]
    if names then
        for _, name in pairs(names) do
            pcall(function()
                exports.ox_target:removeZone(name)
            end)
        end
        registeredZones[deptKey] = nil
    end
    DespawnDeptEntities(deptKey)
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
    spawnedEntities[deptKey] = {}

    local function attachOptions(zoneKey, zoneData, options)
        local entity = SpawnZoneEntity(zoneData)
        if entity then
            spawnedEntities[deptKey][zoneKey] = entity
            exports.ox_target:addLocalEntity(entity, options)
        else
            exports.ox_target:addBoxZone({
                name     = names[zoneKey],
                coords   = toVec3(zoneData.coords),
                size     = toVec3(zoneData.size),
                rotation = zoneData.rotation or 0,
                debug    = false,
                options  = options,
            })
        end
    end

    -- ── Duty ──────────────────────────────────────────────────
    attachOptions('duty', dept.dutyZone, {
        {
            distance = 2.0,
            label    = isOnDuty and ('Go Off Duty [%s]'):format(dept.shortLabel)
                                 or ('Go On Duty [%s]'):format(dept.shortLabel),
            icon     = isOnDuty and 'fas fa-sign-out-alt' or 'fas fa-sign-in-alt',
            groups   = dept.jobName,
            onSelect = function()
                TriggerServerEvent('d4rk_emergency:server:toggleDuty', deptKey)
            end,
        }
    })

    -- ── Cloakroom ─────────────────────────────────────────────
    attachOptions('cloakroom', dept.cloakroomZone, {
        {
            distance = 2.0,
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
            distance = 2.0,
            label    = 'Remove Uniform',
            icon     = 'fas fa-undo',
            groups   = dept.jobName,
            onSelect = function()
                exports['illenium-appearance']:restoreSavedOutfit()
                Notify(dept.shortLabel, 'Uniform removed.', 'inform')
            end,
        }
    })

    -- ── Armory ────────────────────────────────────────────────
    attachOptions('armory', dept.armoryZone, {
        {
            distance = 2.0,
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
    })

    -- ── Garage (via d4rk_garage) ──────────────────────────────
    attachOptions('garage', dept.garageZone, {
        {
            distance = 2.0,
            label    = 'Open Garage',
            icon     = 'fas fa-car',
            groups   = dept.jobName,
            onSelect = function()
                if not isOnDuty then
                    Notify(dept.shortLabel, 'You must be on duty to access the garage.', 'error')
                    return
                end
                local ok = pcall(function()
                    exports['d4rk_garage']:OpenGarageMenu(deptKey)
                end)
                if not ok then
                    Notify(dept.shortLabel, 'Garage system not available.', 'error')
                end
            end,
        },
        {
            distance    = 2.0,
            label       = 'Return Vehicle',
            icon        = 'fas fa-undo',
            groups      = dept.jobName,
            canInteract = function()
                return GetVehiclePedIsIn(PlayerPedId(), false) ~= 0
            end,
            onSelect = function()
                local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                if vehicle == 0 then
                    Notify(dept.shortLabel, 'You must be in a vehicle to return it.', 'error')
                    return
                end
                local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
                local ok = pcall(function()
                    exports['d4rk_garage']:ReturnVehicle(deptKey, plate)
                end)
                if not ok then
                    Notify(dept.shortLabel, 'Garage system not available.', 'error')
                end
            end,
        }
    })
end

-- ── RefreshDeptZones ──────────────────────────────────────────

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

    local attempts = 0
    while (type(ActiveConfig) ~= 'table' or not next(ActiveConfig)) and attempts < 20 do
        Wait(500)
        attempts = attempts + 1
    end

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

-- ── Garage menu → handled by d4rk_garage ───────────────────

-- ── Vehicle spawn/delete → handled by d4rk_garage ─────────

-- ── Duty sync ─────────────────────────────────────────────────

RegisterNetEvent('d4rk_emergency:client:dutyChanged', function(onDuty, deptKey)
    isOnDuty    = onDuty
    currentDept = onDuty and deptKey or nil

    -- ActiveConfig bevorzugen (hat ped/prop Felder aus DB)
    local dept = (type(ActiveConfig) == 'table' and ActiveConfig[deptKey])
              or Config.Departments[deptKey]
    if dept then
        RegisterDeptZones(deptKey, dept)
    end
end)

-- ── Blip init ─────────────────────────────────────────────────

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


-- Gibt Client-seitige Dept Config zurück (für d4rk_garage client)
exports('getClientDeptConfig', function(deptKey)
    if type(ActiveConfig) == 'table' and ActiveConfig[deptKey] then
        return ActiveConfig[deptKey]
    end
    return Config.Departments[deptKey]
end)

-- ── Resource start / stop ─────────────────────────────────────

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

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local keys = {}
    for deptKey in pairs(spawnedEntities) do
        keys[#keys + 1] = deptKey
    end
    for _, deptKey in ipairs(keys) do
        DespawnDeptEntities(deptKey)
    end
end)

AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    -- Zone re-registration handled via onClientResourceStart / dutyChanged
end)