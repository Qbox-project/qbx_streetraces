local Races = {}
local InRace = false
local RaceId = 0
local ShowCountDown = false
local RaceCount = 5

local function RaceCountDown()
    ShowCountDown = true
    while RaceCount ~= 0 do
        FreezeEntityPosition(GetVehiclePedIsIn(cache.ped, true), true)
        PlaySound(-1, "slow", "SHORT_PLAYER_SWITCH_SOUND_SET", 0, 0, 1)
        exports.qbx_core:Notify(RaceCount, 'primary', 800)
        Wait(1000)
        RaceCount = RaceCount - 1
    end
    ShowCountDown = false
    RaceCount = 5
    FreezeEntityPosition(GetVehiclePedIsIn(cache.ped, true), false)
    exports.qbx_core:Notify("GOOOOOOOOO!!!")
end

CreateThread(function()
    while true do
        local sleep = 1000
        if Races ~= nil then
            -- No race yet
            local pos = GetEntityCoords(cache.ped, true)
            if RaceId == 0 then
                for k in pairs(Races) do
                    if Races[k] ~= nil then
                        if #(pos - vector3(Races[k].startx, Races[k].starty, Races[k].startz)) < 15.0 and not Races[k].started then
                            sleep = 0
                            qbx.drawText3d({text = "[~g~H~w~] To Join The Race (~g~$"..Races[k].amount..",-~w~)", coords = vec3(Races[k].startx, Races[k].starty, Races[k].startz)})
                            if IsControlJustReleased(0, 74) then
                                TriggerServerEvent("qb-streetraces:JoinRace", k)
                            end
                        end
                    end
                end
            end
            -- Not started in race yet
            if RaceId ~= 0 and not InRace then
                if #(pos - vector3(Races[RaceId].startx, Races[RaceId].starty, Races[RaceId].startz)) < 15.0 and not Races[RaceId].started then
                    sleep = 0
                    qbx.drawText3d({text = "Race Will Start Soon", coords = vec3(Races[RaceId].startx, Races[RaceId].starty, Races[RaceId].startz)})
                end
            end
            -- In race and started
            if RaceId ~= 0 and InRace then
                if #(pos - vector3(Races[RaceId].endx, Races[RaceId].endy, pos.z)) < 250.0 and Races[RaceId].started then
                    sleep = 0
                    qbx.drawText3d({text = "FINISH", coords = vec3(Races[RaceId].endx, Races[RaceId].endy, pos.z + 0.98)})
                    if #(pos - vector3(Races[RaceId].endx, Races[RaceId].endy, pos.z)) < 15.0 then
                        TriggerServerEvent("qb-streetraces:RaceWon", RaceId)
                        InRace = false
                    end
                end
            end

            if ShowCountDown then
                if #(pos - vector3(Races[RaceId].startx, Races[RaceId].starty, Races[RaceId].startz)) < 15.0 and Races[RaceId].started then
                    sleep = 0
                    qbx.drawText3d({text = "Race start in ~g~"..RaceCount, coords = vec3(Races[RaceId].startx, Races[RaceId].starty, Races[RaceId].startz)})
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('qb-streetraces:StartRace', function(race)
    if RaceId ~= 0 and RaceId == race then
        SetNewWaypoint(Races[RaceId].endx, Races[RaceId].endy)
        InRace = true
        RaceCountDown()
    end
end)

RegisterNetEvent('qb-streetraces:RaceDone', function(race, winner)
    if RaceId ~= 0 and RaceId == race then
        RaceId = 0
        InRace = false
        exports.qbx_core:Notify("Race Is Over! The Winner Is "..winner.."!")
    end
end)

RegisterNetEvent('qb-streetraces:StopRace', function()
    RaceId = 0
    InRace = false
end)

RegisterNetEvent('qb-streetraces:CreateRace', function(amount)
    local pos = GetEntityCoords(cache.ped, true)
    local WaypointHandle = GetFirstBlipInfoId(8)
    if DoesBlipExist(WaypointHandle) then
        local c = GetBlipInfoIdCoord(WaypointHandle)
        if #(pos - c) > 500.0 then
            local race = {
                creator = nil,
                started = false,
                startx = pos.x,
                starty = pos.y,
                startz = pos.z,
                endx = c.x,
                endy = c.y,
                endz = c.z,
                amount = amount,
                pot = amount,
                joined = {}
            }
            TriggerServerEvent("qb-streetraces:NewRace", race)
            exports.qbx_core:Notify("Race Made For $"..amount.."", "success")
        else
            exports.qbx_core:Notify("End Position Is Too Close", "error")
        end
    else
        exports.qbx_core:Notify("You Need To Drop A Marker", "error")
    end
end)

RegisterNetEvent('qb-streetraces:SetRace', function(RaceTable)
    Races = RaceTable
end)

RegisterNetEvent('qb-streetraces:SetRaceId', function(race)
    RaceId = race
    SetNewWaypoint(Races[RaceId].endx, Races[RaceId].endy)
end)
