# GKG Powerplant

A fully dynamic power management system for Qbox that simulates generators, zone based demand and a live monitoring laptop UI powered by ox_lib.

## Features
- **Zone aware grid** – Configure any number of city zones with individual load and recovery multipliers.
- **Generator simulation** – Fuel consumption, random outages, configurable capacity contributions and repair actions with cinematic animation triggers.
- **Player driven demand** – City load automatically scales with the number of connected players.
- **Central command laptop** – Spawn a laptop anywhere in the world to visualise live generator, zone and city stats using ox_lib context menus.
- **Automatic brownouts** – Zones fall into blackout when demand exceeds supply, cutting local lighting and signalling until power is restored.
- **Repair gameplay loop** – Restrict repairs to whitelisted jobs, reward successful fixes with cash payouts and optional notifications.
- **Configuration first** – All behaviour is controlled from `shared/config.lua`, making the resource drop-in friendly without editing the core logic.

## Requirements
- [Qbox](https://github.com/Qbox-project/qbox)
- [ox_lib](https://github.com/overextended/ox_lib)
- [lb-tablet](https://github.com/lbphone/lb-tablet-app-templates/) *(optional, for the tablet dashboard)*

## Installation
1. Place the repository inside your server resources directory (e.g. `resources/[qbox]/gkg-powerplant`).
2. Add `ensure gkg-powerplant` to your `server.cfg` after ox_lib is started.
3. Adjust the configuration described below to match your city layout and balancing goals.

## Configuration overview
All tunable values live in [`shared/config.lua`](shared/config.lua). The default configuration mirrors the example from the technical brief and demonstrates two zones and two generators.

### Core settings
- `CityCapacity` – Maximum capacity of the entire grid measured in MW.
- `PlayerDrain` – Per player demand in MW.
- `RecoveryPerGenerator` – Default MW contribution of an online generator before zone multipliers.
- `FuelUsage` / `FuelTickMinutes` – Fuel consumed every tick and the tick interval.
- `RandomDisable`, `DisableInterval`, `DisableVariance` – Control random generator outages.
- `RepairRewardJobs`, `RepairRewardCash`, `RepairCooldown` – Jobs authorised to repair, cash payout and cooldown between repairs.
- `EnableTabletApp` – Toggle automatic LB Tablet dashboard registration.

### Zones
Each zone can define:
- `capacity` – Maximum load that can be serviced locally.
- `loadMultiplier` – Weight of how much global player load is assigned to this zone.
- `recoveryMultiplier` – Multiplier applied to generator recovery inside the zone.
- `blackout` – Optional table with `center`, `radius` (and `disableTraffic`) used client-side to determine where lights and traffic signals shut off during outages.

### Generators
Each generator entry contains:
- `id` – Unique identifier.
- `label` – Friendly name shown in UI.
- `coords` – `vec3` coordinates used for the interaction sphere.
- `zone` – Which zone the generator services.
- `fuel` – Starting and maximum fuel level.
- `capacity` – Override for recovery contribution (defaults to `RecoveryPerGenerator`).

### Laptop placement
The laptop entity spawned on resource start uses `LaptopEntityCoords`, `LaptopHeading` and `LaptopModel`. Adjust to reposition the interaction point.

### LB Tablet integration
Set `EnableTabletApp` to `true` (default) to automatically register the bundled LB Tablet dashboard once the `lb-tablet` resource is running. The app installs for every player, showing live city, zone and generator data while exposing control buttons only when the player's job is in `Config.RepairRewardJobs`. If your server does not run LB Tablet, simply set `EnableTabletApp = false` to skip the registration entirely.

## Gameplay loop
1. **Demand generation** – Player count drives base load, distributed to zones by their multipliers.
2. **Generator upkeep** – Fuel is automatically drained every tick. When empty or randomly disabled, the generator goes offline.
3. **Repairs** – Authorised jobs can interact with generator sites to refuel/reset them, triggering a repair animation and reward.
4. **Monitoring** – The laptop UI consolidates city, zone and generator metrics for dispatch roles to manage the grid.

## Extending the system
- Persist generator state by adding your own database writes inside the server logic (`server/main.lua`).
- Hook into the `broadcastState` function to integrate alerts with dispatch or logging systems.
- Use the `gkg-powerplant:getNetworkState` callback to retrieve both the cached grid snapshot (`state`) and a `canControl` flag for the requesting player.
- Expand the client UI by replacing the ox_lib context menus with custom NUI if desired.

## License
This project is provided as-is without warranty. Adapt it freely for your server.
