-- ============================================================
--  d4rk_emergency — Shared Config
--  Departments: SAPD, SAFD, SAEMS
--  Adjust coords, vehicles, outfits and weapons to your map
-- ============================================================

Config = {}

-- How often salary is paid out (milliseconds) — default 30 min
Config.SalaryInterval = 30 * 60 * 1000

-- Notification position
Config.NotifyPosition = 'top-right'

-- ============================================================
--  ADMIN PANEL
-- ============================================================
Config.Admin = {
    -- Ace permission required for in-game admin command
    -- Add with: add_ace identifier.steam:xxx d4rk_emergency.admin allow
    Ace = 'd4rk_emergency.admin',

    -- Bearer token for the browser panel
    -- Access: http://your-server-ip:30120/d4rk_emergency/
    -- CHANGE THIS before going live!
    Token = '3RRMkXIaqdhHFVjsKI0GDohYOVVdO4vBQSprU1co2rkcLgLz42XfMG1h9Y6J8Ss3',

    -- In-game command to open the admin NUI
    Command = 'adminemergency',
}

-- ============================================================
--  DEPARTMENTS  (used as seed data on first DB run)
--  After first start these are loaded from the DB instead.
-- ============================================================
Config.Departments = {

    -- --------------------------------------------------------
    --  SAPD — San Andreas Police Department
    -- --------------------------------------------------------
    ['sapd'] = {
        label       = 'San Andreas Police Department',
        shortLabel  = 'SAPD',
        jobName     = 'police',
        color       = '#1A56A0',

        dutyZone = {
            coords   = vec3(441.0, -982.0, 30.69),
            size     = vec3(1.5, 1.5, 2.0),
            rotation = 0,
            label    = 'Police Duty Board',
        },
        cloakroomZone = {
            coords   = vec3(453.0, -990.0, 30.69),
            size     = vec3(1.5, 1.5, 2.0),
            rotation = 0,
            label    = 'Police Locker Room',
        },
        armoryZone = {
            coords   = vec3(449.0, -986.0, 30.69),
            size     = vec3(1.5, 1.5, 2.0),
            rotation = 0,
            label    = 'Police Armory',
        },
        garageZone = {
            coords     = vec3(447.0, -1017.0, 28.0),
            size       = vec3(3.0, 3.0, 2.0),
            rotation   = 0,
            label      = 'Police Garage',
            spawnPoint = vec4(432.0, -1020.0, 28.0, 90.0),
        },

        grades = {
            [0] = { label = 'Cadet',            salary = 500  },
            [1] = { label = 'Police Officer I',  salary = 650  },
            [2] = { label = 'Police Officer II', salary = 800  },
            [3] = { label = 'Senior Officer',    salary = 1000 },
            [4] = { label = 'Sergeant',          salary = 1300 },
            [5] = { label = 'Lieutenant',        salary = 1600 },
            [6] = { label = 'Captain',           salary = 2000 },
            [7] = { label = 'Chief of Police',   salary = 2500 },
        },

        armory = {
            { item = 'weapon_pistol',      label = 'Service Pistol', grade = 0 },
            { item = 'weapon_stungun',     label = 'TASER X2',       grade = 0 },
            { item = 'weapon_nightstick',  label = 'Baton',          grade = 0 },
            { item = 'weapon_flashlight',  label = 'Flashlight',     grade = 0 },
            { item = 'weapon_pumpshotgun', label = 'Shotgun',        grade = 3 },
            { item = 'weapon_carbinerifle',label = 'Patrol Rifle',   grade = 5 },
            { item = 'armor',              label = 'Body Armor',     grade = 3 },
            { item = 'handcuffs',          label = 'Handcuffs',      grade = 0 },
        },

        vehicles = {
            { model = 'police',  label = 'Patrol Cruiser',    grade = 0 },
            { model = 'police2', label = 'Patrol Cruiser II', grade = 0 },
            { model = 'policeb', label = 'Police Motorcycle', grade = 3 },
            { model = 'fbi',     label = 'Unmarked SUV',      grade = 5 },
            { model = 'riot',    label = 'SWAT Van',          grade = 6 },
        },

        outfits = {
            male   = { [0] = { model = 'mp_m_freemode_01', components = {} } },
            female = { [0] = { model = 'mp_f_freemode_01', components = {} } },
        },
    },

    -- --------------------------------------------------------
    --  SAFD — San Andreas Fire Department
    -- --------------------------------------------------------
    ['safd'] = {
        label      = 'San Andreas Fire Department',
        shortLabel = 'SAFD',
        jobName    = 'firefdept',
        color      = '#C0392B',

        dutyZone = {
            coords   = vec3(1193.0, -1473.0, 34.86),
            size     = vec3(1.5, 1.5, 2.0),
            rotation = 0,
            label    = 'Fire Duty Board',
        },
        cloakroomZone = {
            coords   = vec3(1198.0, -1470.0, 34.86),
            size     = vec3(1.5, 1.5, 2.0),
            rotation = 0,
            label    = 'Fire Locker Room',
        },
        armoryZone = {
            coords   = vec3(1190.0, -1468.0, 34.86),
            size     = vec3(1.5, 1.5, 2.0),
            rotation = 0,
            label    = 'Equipment Room',
        },
        garageZone = {
            coords     = vec3(1207.0, -1481.0, 34.86),
            size       = vec3(4.0, 4.0, 2.0),
            rotation   = 0,
            label      = 'Fire Apparatus Bay',
            spawnPoint = vec4(1215.0, -1481.0, 34.86, 270.0),
        },

        grades = {
            [0] = { label = 'Recruit / Probie',  salary = 500  },
            [1] = { label = 'Firefighter',        salary = 700  },
            [2] = { label = 'Firefighter / EMT',  salary = 850  },
            [3] = { label = 'Driver / Engineer',  salary = 1050 },
            [4] = { label = 'Lieutenant',         salary = 1350 },
            [5] = { label = 'Captain',            salary = 1700 },
            [6] = { label = 'Battalion Chief',    salary = 2100 },
            [7] = { label = 'Fire Chief',         salary = 2600 },
        },

        armory = {
            { item = 'fireaxe',           label = 'Fire Axe',           grade = 0 },
            { item = 'weapon_flashlight', label = 'Flashlight',         grade = 0 },
            { item = 'firstaidkit',       label = 'First Aid Kit',      grade = 0 },
            { item = 'fireextinguisher',  label = 'Fire Extinguisher',  grade = 0 },
            { item = 'hazmatsuit',        label = 'HazMat Suit',        grade = 3 },
            { item = 'thermalcamera',     label = 'Thermal Camera',     grade = 2 },
            { item = 'jawsoflife',        label = 'Jaws of Life',       grade = 2 },
        },

        vehicles = {
            { model = 'firetruk', label = 'Engine (Type I)',        grade = 0 },
            { model = 'ladder',   label = 'Ladder / Aerial Truck',  grade = 2 },
            { model = 'lguard',   label = 'Battalion Chief SUV',    grade = 4 },
        },

        outfits = {
            male   = { [0] = { model = 'mp_m_freemode_01', components = {} } },
            female = { [0] = { model = 'mp_f_freemode_01', components = {} } },
        },
    },

    -- --------------------------------------------------------
    --  SAEMS — San Andreas Emergency Medical Services
    -- --------------------------------------------------------
    ['saems'] = {
        label      = 'San Andreas Emergency Medical Services',
        shortLabel = 'SAEMS',
        jobName    = 'ambulance',
        color      = '#1A7A4A',

        dutyZone = {
            coords   = vec3(307.0, -594.0, 43.28),
            size     = vec3(1.5, 1.5, 2.0),
            rotation = 0,
            label    = 'EMS Duty Board',
        },
        cloakroomZone = {
            coords   = vec3(310.0, -591.0, 43.28),
            size     = vec3(1.5, 1.5, 2.0),
            rotation = 0,
            label    = 'EMS Locker Room',
        },
        armoryZone = {
            coords   = vec3(305.0, -597.0, 43.28),
            size     = vec3(1.5, 1.5, 2.0),
            rotation = 0,
            label    = 'Medical Supply Room',
        },
        garageZone = {
            coords     = vec3(298.0, -584.0, 43.28),
            size       = vec3(3.0, 3.0, 2.0),
            rotation   = 0,
            label      = 'EMS Vehicle Bay',
            spawnPoint = vec4(290.0, -584.0, 43.28, 90.0),
        },

        grades = {
            [0] = { label = 'EMT Trainee',     salary = 500  },
            [1] = { label = 'EMT-Basic',        salary = 700  },
            [2] = { label = 'EMT-Paramedic',    salary = 900  },
            [3] = { label = 'Flight Paramedic', salary = 1100 },
            [4] = { label = 'EMS Supervisor',   salary = 1400 },
            [5] = { label = 'EMS Lieutenant',   salary = 1800 },
            [6] = { label = 'Medical Director', salary = 2500 },
        },

        armory = {
            { item = 'firstaidkit',   label = 'First Aid Kit',      grade = 0 },
            { item = 'bandage',       label = 'Bandage',            grade = 0 },
            { item = 'painkillers',   label = 'Painkillers',        grade = 0 },
            { item = 'defibrillator', label = 'Defibrillator',      grade = 0 },
            { item = 'morphine',      label = 'Morphine',           grade = 2 },
            { item = 'traumabag',     label = 'Trauma / Jump Bag',  grade = 1 },
            { item = 'drugkit',       label = 'Paramedic Drug Kit', grade = 2 },
        },

        vehicles = {
            { model = 'ambulance', label = 'ALS Ambulance',  grade = 0 },
            { model = 'lguard',    label = 'Supervisor SUV', grade = 4 },
            { model = 'polmav',    label = 'Medical Helo',   grade = 3 },
        },

        outfits = {
            male   = { [0] = { model = 'mp_m_freemode_01', components = {} } },
            female = { [0] = { model = 'mp_f_freemode_01', components = {} } },
        },
    },
}

-- Helper: get department config by job name
function Config.GetDeptByJob(jobName)
    -- searches ActiveConfig (from DB) if available, fallback to static Config
    local source = (type(ActiveConfig) == 'table' and next(ActiveConfig)) and ActiveConfig or Config.Departments
    for deptKey, dept in pairs(source) do
        if dept.jobName == jobName then
            return deptKey, dept
        end
    end
    return nil, nil
end
