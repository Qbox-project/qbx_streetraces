local Races = {}

local function GetCreatedRace(identifier)
    for key in pairs(Races) do
        if Races[key] ~= nil and Races[key].creator == identifier and not Races[key].started then
            return key
        end
    end
    return 0
end

local function RemoveFromRace(identifier)
    for key in pairs(Races) do
        if Races[key] ~= nil and not Races[key].started then
            for i, iden in pairs(Races[key].joined) do
                if iden == identifier then
                    table.remove(Races[key].joined, i)
                end
            end
        end
    end
end

local function CancelRace(source)
    local RaceId = GetCreatedRace(GetPlayerIdentifierByType(source, 'license'))
    local Player = exports.qbx_core:GetPlayer(source)

    if RaceId ~= 0 then
        for key in pairs(Races) do
            if Races[key] ~= nil and Races[key].creator == Player.PlayerData.license then
                if not Races[key].started then
                    for _, iden in pairs(Races[key].joined) do
                        local xdPlayer = exports.qbx_core:GetPlayer(iden)
                            xdPlayer.Functions.AddMoney('cash', Races[key].amount, "race-cancelled")
                            exports.qbx_core:Notify(xdPlayer.PlayerData.source, "Race Has Stopped, You Got Back $"..Races[key].amount.."", 'error')
                            TriggerClientEvent('qb-streetraces:StopRace', xdPlayer.PlayerData.source)
                            RemoveFromRace(iden)
                    end
                else
                    exports.qbx_core:Notify(Player.PlayerData.source, "The Race Has Already Started", 'error')
                end
                exports.qbx_core:Notify(source, "Race Stopped!", 'error')
                Races[key] = nil
            end
        end
        TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
    else
        exports.qbx_core:Notify(source, "You Have Not Started A Race!", 'error')
    end
end

function GetJoinedRace(identifier)
    for key in pairs(Races) do
        if Races[key] ~= nil and not Races[key].started then
            for _, iden in pairs(Races[key].joined) do
                if iden == identifier then
                    return key
                end
            end
        end
    end
    return 0
end

RegisterNetEvent('qb-streetraces:NewRace', function(RaceTable)
    local src = source
    local RaceId = math.random(1000, 9999)
    local xPlayer = exports.qbx_core:GetPlayer(src)
    if xPlayer.Functions.RemoveMoney('cash', RaceTable.amount, "streetrace-created") then
        Races[RaceId] = RaceTable
        Races[RaceId].creator = GetPlayerIdentifierByType(src, 'license')
        Races[RaceId].joined[#Races[RaceId].joined+1] = GetPlayerIdentifierByType(src, 'license')
        TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
        TriggerClientEvent('qb-streetraces:SetRaceId', src, RaceId)
        exports.qbx_core:Notify(src, "You joind the race for €"..Races[RaceId].amount..",-", 'success')
    end
end)

RegisterNetEvent('qb-streetraces:RaceWon', function(RaceId)
    local src = source
    local xPlayer = exports.qbx_core:GetPlayer(src)
    xPlayer.Functions.AddMoney('cash', Races[RaceId].pot, "race-won")
    exports.qbx_core:Notify(src, "You won the race and €"..Races[RaceId].pot..",- recieved", 'success')
    TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
    TriggerClientEvent('qb-streetraces:RaceDone', -1, RaceId, GetPlayerName(src))
end)

RegisterNetEvent('qb-streetraces:JoinRace', function(RaceId)
    local src = source
    local xPlayer = exports.qbx_core:GetPlayer(src)
    local zPlayer = exports.qbx_core:GetPlayer(Races[RaceId].creator)
    if zPlayer ~= nil then
        if xPlayer.PlayerData.money.cash >= Races[RaceId].amount then
            Races[RaceId].pot = Races[RaceId].pot + Races[RaceId].amount
            Races[RaceId].joined[#Races[RaceId].joined+1] = GetPlayerIdentifierByType(src, 'license')
            if xPlayer.Functions.RemoveMoney('cash', Races[RaceId].amount, "streetrace-joined") then
                TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
                TriggerClientEvent('qb-streetraces:SetRaceId', src, RaceId)
                exports.qbx_core:Notify(zPlayer.PlayerData.source, GetPlayerName(src).." Joined the race", 'primary')
            end
        else
            exports.qbx_core:Notify(src, "You dont have enough cash", 'error')
        end
    else
        exports.qbx_core:Notify(src, "The person wo made the race is offline!", 'error')
        Races[RaceId] = {}
    end
end)

lib.addCommand('createrace', {help = 'Start A Street Race', params = {{name = 'amount', type = 'number', help = 'The Stake Amount For The Race.'}}}, function(source, args)
    local src = source
    if GetJoinedRace(GetPlayerIdentifierByType(src, 'license')) == 0 then
        TriggerClientEvent('qb-streetraces:CreateRace', src, args.amount)
    else
        exports.qbx_core:Notify(src, "You Are Already In A Race", 'error')
    end
end)

lib.addCommand('stoprace', {help = 'Stop The Race You Created'}, function(source, _)
    CancelRace(source)
end)

lib.addCommand('quitrace', {help = 'Get Out Of A Race. (You Will NOT Get Your Money Back!)'}, function(source, _)
    local src = source
    local RaceId = GetJoinedRace(GetPlayerIdentifierByType(src, 'license'))
    if RaceId ~= 0 then
        if GetCreatedRace(GetPlayerIdentifierByType(src, 'license')) ~= RaceId then
            RemoveFromRace(GetPlayerIdentifierByType(src, 'license'))
            exports.qbx_core:Notify(src, "You Have Stepped Out Of The Race! And You Lost Your Money", 'error')
        else
            exports.qbx_core:Notify(src, "/stoprace To Stop The Race", 'error')
        end
    else
        exports.qbx_core:Notify(src, "You Are Not In A Race ", 'error')
    end
end)

lib.addCommand('startrace', {help = 'Start The Race'}, function(source)
    local src = source
    local RaceId = GetCreatedRace(GetPlayerIdentifierByType(src, 'license'))

    if RaceId ~= 0 then

        Races[RaceId].started = true
        TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
        TriggerClientEvent("qb-streetraces:StartRace", -1, RaceId)
    else
        exports.qbx_core:Notify(src, "You Have Not Started A Race", 'error')

    end
end)


