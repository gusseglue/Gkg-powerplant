local Config = lib.require('shared.config')
local Utils = lib.require('shared.utils')

local networkState = nil
local laptopEntity = nil
local generatorPoints = {}
local laptopPoint = nil
local uiOpen = false

RegisterNetEvent('gkg-powerplant:updateState', function(state)
    networkState = state
end)

local function ensureLaptopExists()
    if DoesEntityExist(laptopEntity) then
        return
    end

    local model = Config.LaptopModel
    lib.requestModel(model)
    laptopEntity = CreateObject(model, Config.LaptopEntityCoords.x, Config.LaptopEntityCoords.y, Config.LaptopEntityCoords.z, false, false, false)
    SetEntityAsMissionEntity(laptopEntity, true, false)
    SetEntityHeading(laptopEntity, Config.LaptopHeading or 0.0)
    PlaceObjectOnGroundProperly(laptopEntity)
    FreezeEntityPosition(laptopEntity, true)
    SetEntityInvincible(laptopEntity, true)
end

local function buildGeneratorMenu(id)
    if not networkState then return end

    local generator = networkState.generators[id]
    if not generator then return end

    lib.hideTextUI()

    local options = {
        {
            title = ('Status: %s'):format(generator.status == 'online' and 'Online' or 'Offline'),
            icon = generator.status == 'online' and 'fa-solid fa-plug-circle-check' or 'fa-solid fa-plug-circle-xmark',
            readOnly = true,
        },
        {
            title = ('Fuel: %s / %s'):format(generator.fuel, generator.maxFuel),
            readOnly = true,
        },
    }

    if generator.status == 'offline' then
        options[#options + 1] = {
            title = 'Repair generator',
            description = generator.reason == 'fuel' and 'Refuel and restart the generator.' or 'Bring the generator back online.',
            icon = 'fa-solid fa-screwdriver-wrench',
            onSelect = function()
                TriggerServerEvent('gkg-powerplant:repairGenerator', generator.id)
            end,
        }
    end

    lib.registerContext({
        id = 'gkg_powerplant_generator_' .. id,
        title = generator.label,
        options = options,
    })

    lib.showContext('gkg_powerplant_generator_' .. id)
end

local function formatZoneRow(zone)
    return ('%s  |  Load: %s/%s MW'):format(zone.name, zone.currentLoad, zone.capacity)
end

local function openLaptop()
    if uiOpen then
        return
    end

    uiOpen = true
    lib.hideTextUI()

    if not networkState then
        networkState = lib.callback.await('gkg-powerplant:getNetworkState', false)
    end

    if not networkState then
        lib.notify({
            type = 'error',
            title = 'Power Grid',
            description = 'Ingen data tilgængelig'
        })
        uiOpen = false
        return
    end

    local zoneSummary = {}
    for _, zone in pairs(networkState.zones or {}) do
        zoneSummary[#zoneSummary + 1] = formatZoneRow(zone)
    end

    local generatorOptions = {}
    for id, generator in pairs(networkState.generators or {}) do
        local percent = generator.maxFuel > 0 and Utils.round((generator.fuel / generator.maxFuel) * 100, 1) or 0
        generatorOptions[#generatorOptions + 1] = {
            title = generator.label,
            description = ('%s | Fuel %s%%'):format(generator.status == 'online' and 'Online' or 'Offline', percent),
            icon = generator.status == 'online' and 'fa-solid fa-plug' or 'fa-solid fa-triangle-exclamation',
            onSelect = function()
                buildGeneratorMenu(id)
            end,
        }
    end

    table.sort(generatorOptions, function(a, b)
        return a.title < b.title
    end)

    lib.registerContext({
        id = 'gkg_powerplant_laptop',
        title = 'City Power Network',
        menu = 'gkg_powerplant_root',
        options = generatorOptions,
    })

    lib.registerContext({
        id = 'gkg_powerplant_root',
        title = ('Power Status | Players: %s | Load: %s/%s MW'):format(networkState.city.players, networkState.city.load, networkState.city.capacity),
        canClose = true,
        options = {
            {
                title = 'Zones',
                description = table.concat(zoneSummary, '\n'),
                readOnly = true,
            },
            {
                title = 'Generators',
                menu = 'gkg_powerplant_laptop',
            },
        }
    })

    lib.showContext('gkg_powerplant_root')
    uiOpen = false
end

local function createGeneratorPoints()
    for _, point in pairs(generatorPoints) do
        point:remove()
    end

    generatorPoints = {}

    for id, data in pairs(Config.Generators) do
        local point = lib.points.new({
            coords = data.coords,
            distance = 6.0,
            onEnter = function()
                lib.showTextUI('[E] Inspect generator')
            end,
            onExit = function()
                lib.hideTextUI()
            end,
            nearby = function(self)
                if self.currentDistance <= 2.5 and IsControlJustReleased(0, 38) then
                    if not networkState then
                        networkState = lib.callback.await('gkg-powerplant:getNetworkState', false)
                    end
                    if networkState then
                        buildGeneratorMenu(self.generatorId)
                    end
                end
            end
        })

        point.generatorId = data.id or id
        generatorPoints[#generatorPoints + 1] = point
    end
end

local function createLaptopPoint()
    if laptopPoint then
        laptopPoint:remove()
    end

    local interactDistance = Config.LaptopInteractionDistance or 2.0
    laptopPoint = lib.points.new({
        coords = Config.LaptopEntityCoords,
        distance = math.max(interactDistance * 2.0, 2.5),
        onEnter = function()
            lib.showTextUI('[E] Åbn netværkslaptop')
        end,
        onExit = function()
            lib.hideTextUI()
        end,
        nearby = function(self)
            if self.currentDistance <= interactDistance and IsControlJustReleased(0, 38) then
                openLaptop()
            end
        end
    })
end

RegisterNetEvent('ox_lib:cacheLoaded', function()
    ensureLaptopExists()
    createLaptopPoint()
    createGeneratorPoints()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    ensureLaptopExists()
    createLaptopPoint()
    createGeneratorPoints()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if DoesEntityExist(laptopEntity) then
        DeleteEntity(laptopEntity)
    end
    for _, point in pairs(generatorPoints) do
        point:remove()
    end
    if laptopPoint then
        laptopPoint:remove()
    end
end)

RegisterNetEvent('gkg-powerplant:playRepairAnimation', function()
    local anim = Config.RepairAnimation
    if not anim then return end

    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(cache.ped, anim.dict, anim.anim, 1.0, 1.0, anim.duration, 1, 0, false, false, false)
    Wait(anim.duration)
    ClearPedTasks(cache.ped)
end)

CreateThread(function()
    networkState = lib.callback.await('gkg-powerplant:getNetworkState', false)
end)
