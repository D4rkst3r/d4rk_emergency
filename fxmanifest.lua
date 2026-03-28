fx_version 'cerulean'
game 'gta5'

name 'd4rk_emergency'
description 'SAPD / SAFD / SAEMS — Duty, Ranks, Armory, Garage, Cloakroom, Salary + Admin Panel'
version '2.0.0'
author 'D4rkst3r'

ui_page 'html/admin/index.html'   -- NEU

shared_scripts {
    '@ox_lib/init.lua',
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