
local isBusy = false
local Blips = {}
local scrapPoly = {}
local listen = false

local function CreateListEmail(location)
    local vehicleList = QBCore.Functions.TriggerCallback('qb-scrapyard:server:getVehicleList', location)
    if not vehicleList then return end
    TriggerServerEvent('qb-phone:server:sendNewMail', {
        sender = Lang:t('email.sender'),
        subject = Lang:t('email.subject'),
        message = Lang:t('email.message').. table.concat(vehicleList, ",  \n  "),
        button = {}
    })
end

local function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

local function ScrapVehicleAnim(time)
    time = (time / 1000)
    loadAnimDict("mp_car_bomb")
    TaskPlayAnim(PlayerPedId(), "mp_car_bomb", "car_bomb_mechanic" ,3.0, 3.0, -1, 16, 0, false, false, false)
    local openingDoor = true
    CreateThread(function()
        while openingDoor do
            TaskPlayAnim(PlayerPedId(), "mp_car_bomb", "car_bomb_mechanic", 3.0, 3.0, -1, 16, 0, 0, 0, 0)
            Wait(2000)
            time = time - 2
            if time <= 0 or not isBusy then
                openingDoor = false
                StopAnimTask(PlayerPedId(), "mp_car_bomb", "car_bomb_mechanic", 1.0)
            end
        end
    end)
end

local function ScrapVehicle(loc)
    if isBusy then return end
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), true)
    if vehicle ~= 0 and vehicle ~= nil then
        if GetPedInVehicleSeat(vehicle, -1) == PlayerPedId() then
                local validVehicle = QBCore.Functions.TriggerCallback('qb-scrapyard:server:verifyVehicle', GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)), loc)
                if not validVehicle.bool then
                    QBCore.Functions.Notify(Lang:t('error.cannot_scrap'), "error")
                    return
                end
                isBusy = true
                ScrapVehicleAnim(validVehicle.time)
                QBCore.Functions.Progressbar("scrap_vehicle", Lang:t('text.demolish_vehicle'), validVehicle.time, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                }, {}, {}, {}, function()
                    local success = QBCore.Functions.TriggerCallback("qb-scrapyard:server:ScrapVehicle", loc, GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
                    if success then
                        SetEntityAsMissionEntity(vehicle, true, true)
                        DeleteVehicle(vehicle)
                    else
                        QBCore.Functions.Notify(Lang:t('error.cannot_scrap'), "error")
                    end
                    isBusy = false
                end, function()
                    TriggerServerEvent('qb-scrapyard:server:cancelScrap')
                    isBusy = false
                    QBCore.Functions.Notify(Lang:t('error.canceled'), "error")
                end)
        else
            QBCore.Functions.Notify(Lang:t('error.not_driver'), "error")
        end
    end
end

local function loadBlips()
    for key, data in pairs(Config.Locations) do
        if data.blip then
            Blips[key] = AddBlipForCoord(data.blip.coords.x, data.blip.coords.y, data.blip.coords.z)
            SetBlipSprite(Blips[key], data.blip.sprite or 380)
            SetBlipDisplay(Blips[key], data.blip.display or 4)
            SetBlipScale(Blips[key], data.blip.scale or 0.7)
            SetBlipAsShortRange(Blips[key], true)
            SetBlipColour(Blips[key], data.blip.color or 9)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(data.blip.text or Lang:t('text.scrapyard'))
            EndTextCommandSetBlipName(Blips[key])
        end
    end
end

loadBlips()

local function unloadBlips()
    for k in pairs(Blips) do
        RemoveBlip(Blips[k])
        Blips[k] = nil
    end
end

local function removeZones()
    if Config.UseTarget then
        for k, v in pairs (Config.Locations) do
            exports["qb-target"]:RemoveZone("yard"..k)
            exports["qb-target"]:RemoveZone("list"..k)
        end
    else
        if scrapPoly ~= nil and next(scrapPoly) ~= nil then
            for k in pairs(scrapPoly) do
                scrapPoly[k]:destroy()
                scrapPoly[k] = nil
            end
        end
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        unloadBlips()
        removeZones()
    end
end)



local function listener(type, loc)
    listen = true
    CreateThread(function()
        while listen do
            if IsControlPressed(0, 38) then
                listen = false
                exports['qb-core']:HideText()
                if type == 'deliver' then
                    ScrapVehicle(loc)
                else
                    if not IsPedInAnyVehicle(PlayerPedId())  then
                        CreateListEmail(loc)
                    end
                end
                break
            end
            Wait(0)
        end
    end)
end

local function initZones()
    for k, v in pairs (Config.Locations) do
        if Config.UseTarget then
            exports["qb-target"]:AddBoxZone("yard"..k, v.deliver.coords, v.deliver.length, v.deliver.width, {
                name = "yard"..k,
                heading = v.deliver.heading,
                minZ = v.deliver.coords.z - 1,
                maxZ = v.deliver.coords.z + 1,
            }, {
                options = {
                    {
                        action = function()
                            ScrapVehicle(k)
                        end,
                        icon = "fa fa-wrench",
                        label = Lang:t('text.disassemble_vehicle_target'),
                    }
                },
                distance = 3
            })
            exports["qb-target"]:AddBoxZone("list"..k, v.list.coords, v.list.length, v.list.width, {
                name = "list"..k,
                heading = v.list.heading,
                minZ = v.list.coords.z - 1,
                maxZ = v.list.coords.z + 1,
            }, {
                options = {
                    {
                        action = function()
                            if not IsPedInAnyVehicle(PlayerPedId(), false) then
                                CreateListEmail(k)
                            end
                        end,
                        icon = "fa fa-envelop",
                        label = Lang:t('text.email_list_target'),
                    }
                },
                distance = 1.5
            })
        else
            local deliverZone = BoxZone:Create(vector3(v.deliver.coords.x, v.deliver.coords.y, v.deliver.coords.z), v.deliver.length, v.deliver.width, {
                heading = v.deliver.heading,
                name = "deliver"..k,
                debugPoly = false,
                minZ = v.deliver.coords.z - 1,
                maxZ = v.deliver.coords.z + 1,
            })
            deliverZone:onPlayerInOut(function(isPointInside)
                if isPointInside then
                    exports['qb-core']:DrawText(Lang:t('text.disassemble_vehicle'),'left')
                    listener('deliver', k)
                else
                    listen = false
                    exports['qb-core']:HideText()
                end
            end)

            local listZone = BoxZone:Create(vector3(v.list.coords.x, v.list.coords.y, v.list.coords.z), v.list.length, v.list.width, {
                heading = v.list.heading,
                name = "list"..k,
                debugPoly = false,
                minZ = v.list.coords.z - 1,
                maxZ = v.list.coords.z + 1,
            })
            listZone:onPlayerInOut(function(isPointInside)
                if isPointInside then
                    exports['qb-core']:DrawText(Lang:t('text.email_list'),'left')
                    listener('list', k)
                else
                    listen = false
                    exports['qb-core']:HideText()
                end
            end)
            scrapPoly[#scrapPoly+1] = listZone
            scrapPoly[#scrapPoly+1] = deliverZone
        end
    end
end

initZones()