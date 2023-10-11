fx_version 'cerulean'
game 'gta5'

description 'QBX-StreetRaces'
repository 'https://github.com/Qbox-project/qbx_streetraces'
version '1.0.0'

shared_scripts {'@ox_lib/init.lua', '@qbx_core/import.lua'}
client_script 'client/main.lua'
server_script 'server/main.lua'

modules {'qbx_core:utils'}

lua54 'yes'
use_experimental_fxv2_oal 'yes'