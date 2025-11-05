fx_version 'cerulean'
game 'gta5'

name 'qb-gangmenu'
author 'du'
description 'Gang menu med NUI (pan/zoom-karta, overlay-markörer, pick-mode)'
lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/gta5_map_full.png'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

shared_script 'config.lua'
server_script '@oxmysql/lib/MySQL.lua'
dependency 'qb-core'
