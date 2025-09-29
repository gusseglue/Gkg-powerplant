local Config = lib.require('shared.config')
local Utils = lib.require('shared.utils')

local Generators = {}
local Zones = {}
local CachedState = nil
local RepairCooldowns = {}

local function broadcastState()
    CachedState = CachedState or {}
    CachedState.timestamp = os.time()
    TriggerClientEvent('gkg-powerplant:updateState', -1, CachedState)
end

local function getZoneByName(name)
    return Zones[name]
end

local function scheduleNextDisable(generator)
    if not Config.RandomDisable then
        generator.nextDisable = nil
        return
    end

    local variance = Config.DisableVariance or 0
    local interval = Config.DisableInterval or 60
    local minInterval = math.max(1, interval - variance)
    local maxInterval = interval + variance
    local minutes = math.random(minInterval, maxInterval)
    generator.nextDisable = os.time() + minutes * 60
end

local function initialiseZones()
    Zones = {}
    for name, data in pairs(Config.Zones) do
        Zones[name] = {
            name = name,
            capacity = data.capacity or 0,
            loadMultiplier = data.loadMultiplier or 1.0,
            recoveryMultiplier = data.recoveryMultiplier or 1.0,
            currentLoad = 0,
            deficit = 0,
            generators = {},
        }
    end
end

local function initialiseGenerators()
    Generators = {}
    for _, generator in ipairs(Config.Generators) do
        local zone = getZoneByName(generator.zone)
        if zone then
            local state = {
                id = generator.id or ('generator_' .. _),
                label = generator.label or ('Generator #' .. _),
                coords = generator.coords,
                zone = generator.zone,
                maxFuel = generator.fuel or 100,
                fuel = generator.fuel or 100,
                capacity = generator.capacity or Config.RecoveryPerGenerator,
                status = 'online',
                reason = nil,
                nextDisable = nil,
                lastFuelTick = os.time(),
                lastStatusChange = os.time(),
            }
            Generators[state.id] = state
            zone.generators[state.id] = true
            scheduleNextDisable(state)
        else
            print(('[Gkg-powerplant] Generator %s has invalid zone %s'):format(generator.id or '?', generator.zone or '?'))
        end
    end
end

local function buildNetworkSnapshot()
    local playerCount = #GetPlayers()
    local baseLoad = playerCount * (Config.PlayerDrain or 0)

    local totalMultiplier = 0
    for _, zone in pairs(Zones) do
        totalMultiplier += zone.loadMultiplier or 1.0
    end
    if totalMultiplier <= 0 then totalMultiplier = 1 end

    local totalLoad = 0
    local totalRecovery = 0
    local onlineGenerators = 0

    for _, zone in pairs(Zones) do
        local zoneBaseLoad = baseLoad * (zone.loadMultiplier or 1.0) / totalMultiplier
        local zoneRecovery = 0

        for generatorId in pairs(zone.generators) do
            local generator = Generators[generatorId]
            if generator and generator.status == 'online' then
                zoneRecovery += (generator.capacity or Config.RecoveryPerGenerator) * (zone.recoveryMultiplier or 1.0)
                onlineGenerators += 1
            end
        end

        totalRecovery += zoneRecovery
        local effectiveLoad = math.max(zoneBaseLoad - zoneRecovery, 0)
        local cappedLoad = math.min(effectiveLoad, zone.capacity or 0)
        zone.currentLoad = Utils.round(cappedLoad, 2)
        zone.deficit = Utils.round(math.max(effectiveLoad - (zone.capacity or 0), 0), 2)
        totalLoad += zone.currentLoad
    end

    local capacity = Config.CityCapacity or 0
    local utilisation = capacity > 0 and Utils.round((totalLoad / capacity) * 100, 2) or 0

    CachedState = {
        city = {
            capacity = capacity,
            load = Utils.round(totalLoad, 2),
            recovery = Utils.round(totalRecovery, 2),
            players = playerCount,
            onlineGenerators = onlineGenerators,
            utilisation = utilisation,
        },
        zones = {},
        generators = {},
    }

    for name, zone in pairs(Zones) do
        CachedState.zones[name] = {
            name = name,
            capacity = zone.capacity,
            currentLoad = zone.currentLoad,
            deficit = zone.deficit,
            loadMultiplier = zone.loadMultiplier,
            recoveryMultiplier = zone.recoveryMultiplier,
        }
    end

    for id, generator in pairs(Generators) do
        CachedState.generators[id] = {
            id = id,
            label = generator.label,
            zone = generator.zone,
            fuel = Utils.round(generator.fuel, 2),
            maxFuel = generator.maxFuel,
            status = generator.status,
            reason = generator.reason,
            nextDisable = generator.nextDisable,
            capacity = generator.capacity,
            lastStatusChange = generator.lastStatusChange,
        }
    end

    broadcastState()
end

local function setGeneratorStatus(generator, status, reason)
    if generator.status == status and generator.reason == reason then
        return
    end

    generator.status = status
    generator.reason = reason
    generator.lastStatusChange = os.time()
end

local function consumeFuel()
    local now = os.time()
    for _, generator in pairs(Generators) do
        if generator.status == 'online' then
            local elapsedMinutes = (now - generator.lastFuelTick) / 60
            if elapsedMinutes >= (Config.FuelTickMinutes or 5) then
                local ticks = math.floor(elapsedMinutes / (Config.FuelTickMinutes or 5))
                local usage = ticks * (Config.FuelUsage or 1)
                generator.fuel = math.max(generator.fuel - usage, 0)
                generator.lastFuelTick = now

                if generator.fuel <= 0 then
                    generator.fuel = 0
                    setGeneratorStatus(generator, 'offline', 'fuel')
                end
            end
        end
    end
end

local function processRandomDisable()
    if not Config.RandomDisable then return end
    local now = os.time()
    for _, generator in pairs(Generators) do
        if generator.status == 'online' and generator.nextDisable and generator.nextDisable <= now then
            setGeneratorStatus(generator, 'offline', 'failure')
            scheduleNextDisable(generator)
        end
    end
end

local function maintenanceLoop()
    while true do
        consumeFuel()
        processRandomDisable()
        buildNetworkSnapshot()
        Wait(60 * 1000)
    end
end

local function getPlayerJob(source)
    local ok, player = pcall(function()
        return exports.qbx_core:GetPlayerData(source)
    end)

    if ok and player and player.job then
        return player.job.name
    end

    return nil
end

local function rewardPlayer(source)
    if not Config.RepairRewardCash or Config.RepairRewardCash <= 0 then
        return
    end

    local rewarded = pcall(function()
        exports.qbx_core:AddMoney(source, 'cash', Config.RepairRewardCash, 'powerplant-repair')
    end)

    if not rewarded then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'success',
            title = 'Power Grid',
            description = ('Reward: $%s'):format(Config.RepairRewardCash)
        })
    end
end

local function canRepair(source, generator)
    if not generator then
        return false, 'Generator not found'
    end

    if generator.status == 'online' then
        return false, 'Generator is already online'
    end

    local cooldown = RepairCooldowns[source]
    if cooldown and cooldown > os.time() then
        return false, 'You must wait before repairing again'
    end

    local job = getPlayerJob(source)
    if job and Config.RepairRewardJobs[job] then
        return true
    end

    return false, 'You are not authorised to repair generators'
end

RegisterNetEvent('gkg-powerplant:repairGenerator', function(generatorId)
    local source = source
    local generator = Generators[generatorId]
    local allowed, message = canRepair(source, generator)
    if not allowed then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            title = 'Power Grid',
            description = message
        })
        return
    end

    if generator.reason == 'fuel' then
        generator.fuel = generator.maxFuel
    end

    generator.lastFuelTick = os.time()
    TriggerClientEvent('gkg-powerplant:playRepairAnimation', source)
    setGeneratorStatus(generator, 'online', nil)
    scheduleNextDisable(generator)
    buildNetworkSnapshot()
    RepairCooldowns[source] = os.time() + (Config.RepairCooldown or 0)
    rewardPlayer(source)

    TriggerClientEvent('ox_lib:notify', source, {
        type = 'success',
        title = 'Power Grid',
        description = ('%s is back online'):format(generator.label)
    })
end)

lib.callback.register('gkg-powerplant:getNetworkState', function()
    if not CachedState then
        buildNetworkSnapshot()
    end
    return CachedState
end)

AddEventHandler('playerDropped', function()
    local playerId = source
    RepairCooldowns[playerId] = nil
    SetTimeout(500, buildNetworkSnapshot)
end)

AddEventHandler('playerJoining', function()
    SetTimeout(500, buildNetworkSnapshot)
end)

CreateThread(function()
    initialiseZones()
    initialiseGenerators()
    buildNetworkSnapshot()
    maintenanceLoop()
end)
