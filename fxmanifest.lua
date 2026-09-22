fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'ks-chat'
author 'KEOPS Studios (keops-studios.com)'
description 'Module de chat RP pour VORP — KEOPS Studios'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/fonts/*.woff2'
}

shared_script 'config.lua'
client_script 'client/cl_chat.lua'
server_script 'server/sv_chat.lua'

-- Exports compatibles avec l'API du chat FiveM/RedM par défaut,
-- utilisés par de nombreuses resources tierces (ex: vorp_core, vorp_admin...)
exports {
    'AddMessage',
    'AddSuggestion',
    'RemoveSuggestion',
    'AddTemplate',
    'Clear'
}
