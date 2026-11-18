fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot'
description 'Player inventory system providing a variety of features for storing and managing items'
version '2.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/es.lua',
    'locales/*.lua',
    'config/*.lua'
}

client_scripts {
    'client/main_client.lua',
    'client/drops.lua',
    'client/vehicles.lua',
    'client/backitems.lua',
    'client/backpack_cl.lua',
    'client/sim.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main_server.lua',
    'server/functions.lua',
    'server/commands.lua',
    'server/backpack_sv.lua',
    'server/sim.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
    'ui/sounds/*.mp3',
    'ui/images/**/*.png',
    'ui/images/*.png'
}

dependency 'qb-weapons'
dependency 'DP-TextUI'