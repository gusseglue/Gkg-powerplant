local Config = lib.require('shared.config')

if Config.EnableTabletApp == false then
    return
end

local appIdentifier = 'gkg-powerplant-tablet'
local appRegistered = false
local appOpen = false
local canControl = false
local lastPayload = nil
local refreshing = false
local iconDataUrl = [[data:image/svg+xml;base64,PHN2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnIHZpZXdCb3g9JzAgMCAyNCAyNCcgZmlsbD0nI2Y2YzkxNSc+PHBhdGggZD0nTTEzIDJMMyAxNGg2bC0xIDggMTAtMTJoLTZsMS04eicvPjwvc3ZnPg==]]

local function sendAppMessage(action, data)
    if not appRegistered then return end
    exports['lb-tablet']:SendCustomAppMessage(appIdentifier, action, data)
end

local function setLoading(active)
    if not appOpen then return end
    sendAppMessage('loading', active)
end

local function refreshState()
    if not appOpen or refreshing then return end
    refreshing = true
    setLoading(true)

    local success, payload = pcall(function()
        return lib.callback.await('gkg-powerplant:getNetworkState', false)
    end)

    if not appOpen then
        refreshing = false
        return
    end

    setLoading(false)

    if not success or not payload or not payload.state then
        canControl = false
        lastPayload = nil
        sendAppMessage('networkError', true)
        refreshing = false
        return
    end

    canControl = payload.canControl or false
    lastPayload = payload
    sendAppMessage('networkState', payload)
    refreshing = false
end

local function addApp()
    if appRegistered then return end

    Wait(500)

    local success, reason = exports['lb-tablet']:AddCustomApp({
        identifier = appIdentifier,
        name = 'Power Grid',
        description = 'Monitor generator output and zone status in real time.',
        icon = iconDataUrl,
        ui = 'ui/tablet/index.html',
        removable = true,
        defaultApp = false,
        onInstall = function() end,
        onUninstall = function() end,
        onOpen = function()
            appOpen = true
            if lastPayload then
                sendAppMessage('networkState', lastPayload)
            end
            refreshState()
        end,
        onClose = function()
            appOpen = false
            setLoading(false)
        end,
    })

    if not success then
        print(('[gkg-powerplant] Failed to register tablet app: %s'):format(reason or 'unknown'))
        return
    end

    appRegistered = true
    print('[gkg-powerplant] Tablet app registered')
end

RegisterNUICallback('refreshState', function(_, cb)
    if appOpen then
        refreshState()
    end
    cb({ ok = true })
end)

RegisterNUICallback('repairGenerator', function(data, cb)
    if type(data) ~= 'table' or type(data.id) ~= 'string' then
        cb({ ok = false, reason = 'invalid' })
        return
    end

    if not canControl then
        TriggerEvent('ox_lib:notify', {
            type = 'error',
            title = 'Power Grid',
            description = 'Kontrolhandlinger kræver autoriseret job.'
        })
        cb({ ok = false, reason = 'forbidden' })
        return
    end

    TriggerServerEvent('gkg-powerplant:repairGenerator', data.id)
    cb({ ok = true })
end)

RegisterNetEvent('gkg-powerplant:updateState', function(state)
    if lastPayload and state then
        lastPayload.state = state
    end

    if appOpen then
        if lastPayload then
            sendAppMessage('networkState', lastPayload)
        end
        refreshState()
    end
end)

local function ensureTabletReady()
    local state = GetResourceState('lb-tablet')

    if state == 'started' then
        addApp()
        return true
    end

    if state == 'missing' or state == 'unknown' then
        print('[gkg-powerplant] lb-tablet not found, skipping tablet app registration')
        return true
    end

    return false
end

CreateThread(function()
    local attempts = 0
    while not ensureTabletReady() do
        Wait(1000)
        attempts = attempts + 1
        if attempts >= 120 then
            print('[gkg-powerplant] lb-tablet did not start within 120 seconds, skipping tablet app registration')
            break
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == 'lb-tablet' then
        ensureTabletReady()
    end
end)
