fx_version 'cerulean'

game 'gta5'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua',
    'client/tablet.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'ui/tablet/**'
}

ui_page 'ui/tablet/index.html'

