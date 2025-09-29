fx_version 'cerulean'
game 'gta5'

name 'gkg-powerplant-tablet'
description 'LB Tablet app for the GKG powerplant network overview'
author 'GKG'

lua54 'yes'

client_scripts {
    '@ox_lib/init.lua',
    'client.lua'
}

files {
    'ui/**'
}

ui_page 'ui/index.html'

dependencies {
    'lb-tablet',
    'ox_lib'
}
