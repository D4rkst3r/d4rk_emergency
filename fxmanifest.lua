fx_version 'cerulean'
game 'gta5'

name 'd4rk_emergency'
description 'SAPD / SAFD / SAEMS — Duty, Ranks, Armory, Garage, Cloakroom, Salary + Admin Panel'
version '2.1.0'
author 'D4rkst3r'

ui_page 'html/admin/index.html'

dependencies {
    'd4rk_core',
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

shared_scripts {
    '@ox_lib/init.lua',
    '@d4rk_core/shared/events.lua',   -- DC_EVENTS global
    '@d4rk_core/shared/utils.lua',    -- DC utils (TableCount, Round, etc.)
    'config/shared.lua',
}

client_scripts {
    'client/main.lua',
    'client/admin.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/main.lua',
    'server/admin.lua',
}

files {
    'html/admin/index.html',
}

lua54 'yes'