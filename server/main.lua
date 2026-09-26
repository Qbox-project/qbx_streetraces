local Races = {}
local maxStake = 100000

local function getLicense(source)
    return GetPlayerIdentifierByType(source, 'license')
end

local function getPlayerByLicense(license)
    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if player.PlayerData.license == license then return player end
    end
end

local function getCreatedRace(identifier)
    for raceId, race in pairs(Races) do
        if race.creator == identifier and not race.started then return raceId end
    end
    return 0
end

local function getJoinedRace(identifier)
    for raceId, race in pairs(Races) do
        for i = 1, #race.joined do
            if race.joined[i] == identifier then return raceId end
        end
    end
    return 0
end

local function removeFromRace(identifier)
    for raceId, race in pairs(Races) do
        for i = #race.joined, 1, -1 do
            if race.joined[i] == identifier then table.remove(race.joined, i) end
        end
        if #race.joined == 0 then Races[raceId] = nil end
    end
end

local function syncRaces()
    TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
end

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and math.abs(value) < 10000
end

local function cancelRace(source)
    local license = getLicense(source)
    local raceId = getCreatedRace(license)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    if raceId == 0 then
        exports.qbx_core:Notify(source, 'You Have Not Started A Race!', 'error')
        return
    end

    local race = Races[raceId]
    if race.started then
        exports.qbx_core:Notify(source, 'The Race Has Already Started', 'error')
        return
    end

    for i = 1, #race.joined do
        local joinedPlayer = getPlayerByLicense(race.joined[i])
        if joinedPlayer then
            joinedPlayer.Functions.AddMoney('cash', race.amount, 'race-cancelled')
            exports.qbx_core:Notify(joinedPlayer.PlayerData.source, ('Race Has Stopped, You Got Back $%s'):format(race.amount), 'error')
            TriggerClientEvent('qb-streetraces:StopRace', joinedPlayer.PlayerData.source)
        end
    end

    Races[raceId] = nil
    exports.qbx_core:Notify(source, 'Race Stopped!', 'error')
    syncRaces()
end

RegisterNetEvent('qb-streetraces:NewRace', function(raceData)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local license = getLicense(src)
    if not player or not license or type(raceData) ~= 'table' then return end
    if getJoinedRace(license) ~= 0 then return end

    local amount = tonumber(raceData.amount)
    if not amount or math.type(amount) ~= 'integer' or amount < 1 or amount > maxStake then return end
    if not isFiniteNumber(raceData.endx) or not isFiniteNumber(raceData.endy) or not isFiniteNumber(raceData.endz) then return end

    local startCoords = GetEntityCoords(GetPlayerPed(src))
    local finishCoords = vec3(raceData.endx, raceData.endy, raceData.endz)
    if #(startCoords - finishCoords) <= 500.0 then return end
    if not player.Functions.RemoveMoney('cash', amount, 'streetrace-created') then return end

    local raceId
    repeat
        raceId = math.random(1000, 9999)
    until not Races[raceId]

    Races[raceId] = {
        creator = license,
        started = false,
        startx = startCoords.x,
        starty = startCoords.y,
        startz = startCoords.z,
        endx = finishCoords.x,
        endy = finishCoords.y,
        endz = finishCoords.z,
        amount = amount,
        pot = amount,
        joined = {license},
    }
    syncRaces()
    TriggerClientEvent('qb-streetraces:SetRaceId', src, raceId)
    exports.qbx_core:Notify(src, ('You joined the race for $%s'):format(amount), 'success')
end)

RegisterNetEvent('qb-streetraces:RaceWon', function(raceId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local license = getLicense(src)
    local race = math.type(raceId) == 'integer' and Races[raceId]
    if not player or not license or not race or not race.started or race.finished then return end
    if GetGameTimer() < race.earliestFinish or getJoinedRace(license) ~= raceId then return end

    local ped = GetPlayerPed(src)
    local finishCoords = vec3(race.endx, race.endy, race.endz)
    if ped == 0 or GetVehiclePedIsIn(ped, false) == 0 or #(GetEntityCoords(ped) - finishCoords) > 20.0 then return end

    race.finished = true
    player.Functions.AddMoney('cash', race.pot, 'race-won')
    exports.qbx_core:Notify(src, ('You won the race and received $%s'):format(race.pot), 'success')
    TriggerClientEvent('qb-streetraces:RaceDone', -1, raceId, GetPlayerName(src))
    Races[raceId] = nil
    syncRaces()
end)

RegisterNetEvent('qb-streetraces:JoinRace', function(raceId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local license = getLicense(src)
    local race = math.type(raceId) == 'integer' and Races[raceId]
    if not player or not license or not race or race.started or getJoinedRace(license) ~= 0 then return end

    local startCoords = vec3(race.startx, race.starty, race.startz)
    if #(GetEntityCoords(GetPlayerPed(src)) - startCoords) > 20.0 then return end
    if not player.Functions.RemoveMoney('cash', race.amount, 'streetrace-joined') then
        exports.qbx_core:Notify(src, 'You do not have enough cash', 'error')
        return
    end

    race.pot += race.amount
    race.joined[#race.joined + 1] = license
    syncRaces()
    TriggerClientEvent('qb-streetraces:SetRaceId', src, raceId)

    local creator = getPlayerByLicense(race.creator)
    if creator then
        exports.qbx_core:Notify(creator.PlayerData.source, GetPlayerName(src) .. ' joined the race', 'primary')
    end
end)

lib.addCommand('createrace', {help = 'Start A Street Race', params = {{name = 'amount', type = 'number', help = 'The Stake Amount For The Race.'}}}, function(source, args)
    if getJoinedRace(getLicense(source)) == 0 then
        TriggerClientEvent('qb-streetraces:CreateRace', source, args.amount)
    else
        exports.qbx_core:Notify(source, 'You Are Already In A Race', 'error')
    end
end)

lib.addCommand('stoprace', {help = 'Stop The Race You Created'}, function(source)
    cancelRace(source)
end)

lib.addCommand('quitrace', {help = 'Get Out Of A Race. (You Will NOT Get Your Money Back!)'}, function(source)
    local license = getLicense(source)
    local raceId = getJoinedRace(license)
    if raceId == 0 then
        exports.qbx_core:Notify(source, 'You Are Not In A Race', 'error')
    elseif getCreatedRace(license) == raceId then
        exports.qbx_core:Notify(source, '/stoprace To Stop The Race', 'error')
    else
        removeFromRace(license)
        TriggerClientEvent('qb-streetraces:StopRace', source)
        syncRaces()
        exports.qbx_core:Notify(source, 'You Have Stepped Out Of The Race! And You Lost Your Money', 'error')
    end
end)

AddEventHandler('playerDropped', function()
    local license = getLicense(source)
    if not license then return end

    local raceId = getCreatedRace(license)
    local race = Races[raceId]
    if race then
        Races[raceId] = nil
        for _, joined in ipairs(race.joined) do
            local player = joined ~= license and getPlayerByLicense(joined)
            if player then
                player.Functions.AddMoney('cash', race.amount, 'race-cancelled')
                TriggerClientEvent('qb-streetraces:StopRace', player.PlayerData.source)
            end
        end
    end
    removeFromRace(license)
    syncRaces()
end)

lib.addCommand('startrace', {help = 'Start The Race'}, function(source)
    local raceId = getCreatedRace(getLicense(source))
    if raceId == 0 then
        exports.qbx_core:Notify(source, 'You Have Not Started A Race', 'error')
        return
    end

    local race = Races[raceId]
    local distance = #(vec3(race.startx, race.starty, race.startz) - vec3(race.endx, race.endy, race.endz))
    race.started = true
    race.earliestFinish = GetGameTimer() + math.max(5000, math.floor(distance / 100 * 1000))
    syncRaces()
    TriggerClientEvent('qb-streetraces:StartRace', -1, raceId)
end)
