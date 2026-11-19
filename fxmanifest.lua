fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'DP-Scripts'
description 'Sistema de inventario de jugadores que proporciona una variedad de funciones para almacenar y administrar artículos y armas'
version '1.5.1'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/es.lua',
    'locales/*.lua',
    'config/*.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

ui_page 'ui/index.html'

files {
    'ui/*.html',
    'ui/*.css',
    'ui/*.js',
    'ui/images/**/*.png',
    'ui/images/*.png',
    'dp_weapons.meta'
}

data_file 'WEAPONINFO_FILE_PATCH' 'dp_weapons.meta'

dependency 'DP-TextUI'