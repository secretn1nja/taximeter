fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'n1nja'
description 'A modern, optimized taximeter system with enhanced UI and performance improvements.'
version '2.0.0'

ui_page 'html/main.html'

files {
    'html/main.html',
    'html/styles.css',
    'html/script.js',
}

client_scripts {
    'config.lua',
    'client.lua',
}

server_script 'server.lua'

shared_scripts {
    'config.lua',
}

-- Dependencies (optional)
dependencies {
    'yarn',
    'webpack'
}

escrow_ignore {
    'client.lua',
    'server.lua',
    'config.lua',
    'html/main.html',
    'html/styles.css',
    'html/script.js',
}
