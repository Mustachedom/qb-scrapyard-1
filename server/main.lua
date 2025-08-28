local currentVehicles = {}
local scrapingCar = {}
local maxItemRolls = 6

local itemRewards = {
    {item = 'metalscrap', min = 1, max = 5},
    {item = 'plastic', min = 1, max = 5},
    {item = 'copper', min = 1, max = 5},
    {item = 'iron', min = 1, max = 5},
    {item = 'aluminum', min = 1, max = 5},
    {item = 'steel', min = 1, max = 5},
    {item = 'glass', min = 1, max = 5},
}

local function tableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local function createVehicleList()
    if #Config.Vehicles <= Config.VehicleCount then
        currentVehicles = Config.Vehicles
    end
    for i = 1, Config.VehicleCount, 1 do
        local randVehicle = Config.Vehicles[math.random(1, #Config.Vehicles)]
        table.insert(currentVehicles, randVehicle)
    end
    table.insert(currentVehicles, "alpha")
end

CreateThread(function()
    repeat
        createVehicleList()
        Wait((1000 * 60) * 60)
        currentVehicles = {}
    until false
end)

QBCore.Functions.CreateCallback('qb-scrapyard:server:getVehicleList', function(source, cb, locationKey)
    local src = source
    local distance = #(GetEntityCoords(GetPlayerPed(src)) - Config.Locations[locationKey].list.coords)
    if distance > 3.5 then
        return
    end
    cb(currentVehicles)
end)

QBCore.Functions.CreateCallback('qb-scrapyard:server:verifyVehicle', function(source, cb, vehicleName, location)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if scrapingCar[Player.PlayerData.citizenid] then
        cb({bool = false})
        return
    end
    local distance = #(GetEntityCoords(GetPlayerPed(src)) - Config.Locations[location].deliver.coords)
    if distance > 5.5 then
        cb({bool = false})
        return
    end

    vehicleName = string.lower(vehicleName)

    if not tableContains(currentVehicles, vehicleName) then
        cb({bool = false})
        return
    end
    local plate = GetVehicleNumberPlateText(GetVehiclePedIsIn(GetPlayerPed(src), false))
    local checkOwnership = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ?', {plate})

    if checkOwnership and checkOwnership[1] then
        cb({bool = false})
        return
    else
        local timeNeeded = math.random(28000, 37000)
        scrapingCar[Player.PlayerData.citizenid] = {plate = plate, modelType = vehicleName, time = GetGameTimer() + timeNeeded}
        cb({bool = true, time = timeNeeded})
        return
    end
end)

QBCore.Functions.CreateCallback('qb-scrapyard:server:ScrapVehicle', function(source, cb, loc, vehicleName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not scrapingCar[Player.PlayerData.citizenid] then
        cb(false)
        return
    end

    local distance = #(GetEntityCoords(GetPlayerPed(src)) - Config.Locations[loc].deliver.coords)
    if distance > 5.5 then
        cb(false)
        return
    end

    vehicleName = string.lower(vehicleName)

    if not tableContains(currentVehicles, vehicleName) then
        cb(false)
        return
    end

    local plate = GetVehicleNumberPlateText(GetVehiclePedIsIn(GetPlayerPed(src), false))
    if plate ~= scrapingCar[Player.PlayerData.citizenid].plate then
        cb(false)
        return
    end

    local checkOwnership = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ?', {plate})
    if checkOwnership and checkOwnership[1] then
        cb(false)
        return
    else
        local currentTime = GetGameTimer() + 1000
        if currentTime < scrapingCar[Player.PlayerData.citizenid].time then
            return
        end
        scrapingCar[Player.PlayerData.citizenid] = nil
        local rewardAmount = math.random(1, maxItemRolls)
        repeat
            Wait(1)
            rewardAmount = rewardAmount - 1
            local itemRoll = math.random(1, #itemRewards)
            Player.Functions.AddItem(itemRewards[itemRoll].item, math.random(itemRewards[itemRoll].min, itemRewards[itemRoll].max))
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemRewards[itemRoll].item], "add")
        until rewardAmount <= 0
        cb(true)
    end
end)

RegisterNetEvent('qb-scrapyard:server:cancelScrap', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if scrapingCar[Player.PlayerData.citizenid] then
        scrapingCar[Player.PlayerData.citizenid] = nil
    end
end)