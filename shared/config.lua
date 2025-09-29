local Config = {}

Config.CityCapacity = 1000
Config.PlayerDrain = 2
Config.RecoveryPerGenerator = 100
Config.FuelUsage = 1
Config.FuelTickMinutes = 5
Config.RandomDisable = true
Config.DisableInterval = 60
Config.DisableVariance = 15
Config.RepairRewardJobs = {
    electrician = true,
    mechanic = true,
    police = true,
}
Config.RepairRewardCash = 500
Config.RepairCooldown = 120
Config.RepairAnimation = {
    dict = 'amb@world_human_welding@male@base',
    anim = 'base',
    duration = 10000
}
Config.LaptopModel = `prop_laptop_01a`
Config.LaptopInteractionDistance = 2.0
Config.LaptopEntityCoords = vec3(-50.4, -1102.2, 26.4)
Config.LaptopHeading = 180.0

Config.Zones = {
    Downtown = {
        capacity = 500,
        loadMultiplier = 1.0,
        recoveryMultiplier = 1.0,
    },
    Airport = {
        capacity = 300,
        loadMultiplier = 0.8,
        recoveryMultiplier = 0.9,
    }
}

Config.Generators = {
    {
        id = 'downtown_1',
        label = 'Downtown Substation',
        coords = vec3(200.0, -1000.0, 28.0),
        zone = 'Downtown',
        fuel = 100,
        capacity = 100,
    },
    {
        id = 'airport_1',
        label = 'Airport Relay',
        coords = vec3(1000.0, 2000.0, 30.0),
        zone = 'Airport',
        fuel = 100,
        capacity = 80,
    }
}

return Config
