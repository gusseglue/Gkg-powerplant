const elements = {
    overview: document.getElementById('city-overview'),
    badge: document.getElementById('control-badge'),
    status: document.getElementById('status-message'),
    metrics: {
        load: document.getElementById('metric-load'),
        capacity: document.getElementById('metric-capacity'),
        utilisation: document.getElementById('metric-utilisation'),
        generators: document.getElementById('metric-generators'),
        players: document.getElementById('metric-players')
    },
    zones: document.getElementById('zones-container'),
    generatorsBody: document.getElementById('generators-body'),
    refresh: document.getElementById('refresh')
};

let latestState = null;
let controlEnabled = false;
let isLoading = false;

const formatNumber = (value, decimals = 0) => {
    if (value === undefined || value === null || Number.isNaN(Number(value))) {
        return '-';
    }
    return Number(value).toLocaleString(undefined, {
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals
    });
};

const formatPercent = (value, decimals = 1) => {
    if (value === undefined || value === null || Number.isNaN(Number(value))) {
        return '-';
    }
    return `${formatNumber(value, decimals)}%`;
};

const formatMw = (value, decimals = 1) => {
    if (value === undefined || value === null || Number.isNaN(Number(value))) {
        return '-';
    }
    return `${formatNumber(value, decimals)} MW`;
};

const setStatus = (message, type = 'info') => {
    elements.status.textContent = message;
    elements.status.classList.toggle('status--error', type === 'error');
};

const setControlBadge = (canControl, cityBlackout) => {
    controlEnabled = !!canControl;
    elements.badge.classList.remove('badge--enabled', 'badge--monitor', 'badge--error');

    if (cityBlackout) {
        elements.badge.textContent = 'City Blackout';
        elements.badge.classList.add('badge--error');
        return;
    }

    if (controlEnabled) {
        elements.badge.textContent = 'Control Enabled';
        elements.badge.classList.add('badge--enabled');
    } else {
        elements.badge.textContent = 'Monitoring Only';
        elements.badge.classList.add('badge--monitor');
    }
};

const renderCity = (city) => {
    if (!city) {
        elements.overview.textContent = 'No data available';
        Object.values(elements.metrics).forEach((node) => (node.textContent = '-'));
        return;
    }

    elements.overview.textContent = `${formatMw(city.load)} of ${formatMw(city.capacity)} • Recovery ${formatMw(city.recovery)} • ${formatNumber(city.players)} players`;

    elements.metrics.load.textContent = formatMw(city.load);
    elements.metrics.capacity.textContent = formatMw(city.capacity);
    elements.metrics.utilisation.textContent = formatPercent(city.utilisation);
    elements.metrics.generators.textContent = formatNumber(city.onlineGenerators);
    elements.metrics.players.textContent = formatNumber(city.players);
};

const renderZones = (zones) => {
    elements.zones.innerHTML = '';

    const zoneList = Array.isArray(zones) ? zones : Object.values(zones || {});

    if (!zoneList.length) {
        const empty = document.createElement('div');
        empty.className = 'empty-state';
        empty.textContent = 'No zones configured';
        elements.zones.appendChild(empty);
        return;
    }

    zoneList
        .sort((a, b) => a.name.localeCompare(b.name))
        .forEach((zone) => {
            const card = document.createElement('div');
            card.className = 'zone-card';
            if (zone.blackout) {
                card.classList.add('blackout');
            }

            const name = document.createElement('div');
            name.className = 'zone-name';
            name.textContent = zone.name || 'Unknown zone';

            const info = document.createElement('div');
            info.className = 'zone-info';
            const status = zone.blackout ? 'BLACKOUT' : 'ONLINE';
            info.innerHTML = `Status: <strong>${status}</strong><br />Load: ${formatMw(zone.currentLoad)} / ${formatMw(zone.capacity)}<br />Deficit: ${formatMw(zone.deficit)}`;

            card.appendChild(name);
            card.appendChild(info);
            elements.zones.appendChild(card);
        });
};

const createFuelBar = (percent) => {
    const wrapper = document.createElement('div');
    wrapper.className = 'fuel-bar';

    const fill = document.createElement('div');
    fill.className = 'fuel-fill';
    fill.style.width = `${Math.max(0, Math.min(100, percent))}%`;

    wrapper.appendChild(fill);
    return wrapper;
};

const requestRepair = async (generatorId, button) => {
    if (!generatorId) return;

    const label = button.textContent;
    button.disabled = true;
    button.textContent = 'Sending…';

    try {
        const response = await globalThis.fetchNui('repairGenerator', { id: generatorId });
        if (!response || response.ok !== true) {
            button.disabled = false;
            button.textContent = label;

            if (response && response.reason === 'forbidden') {
                setStatus('You are not authorised to control generators.', 'error');
            } else {
                setStatus('Failed to trigger repair. Check logs for details.', 'error');
            }
        } else {
            button.textContent = 'Requested';
        }
    } catch (e) {
        button.disabled = false;
        button.textContent = label;
        setStatus('Unable to reach client. Try again.', 'error');
    }
};

const renderGenerators = (generators) => {
    elements.generatorsBody.innerHTML = '';

    const generatorList = Array.isArray(generators) ? generators : Object.values(generators || {});

    if (!generatorList.length) {
        const empty = document.createElement('div');
        empty.className = 'empty-state';
        empty.textContent = 'No generators defined';
        elements.generatorsBody.appendChild(empty);
        return;
    }

    generatorList
        .sort((a, b) => a.label.localeCompare(b.label))
        .forEach((generator) => {
            const row = document.createElement('div');
            row.className = 'table-row';

            const label = document.createElement('div');
            label.textContent = generator.label || generator.id || 'Generator';

            const statusWrapper = document.createElement('div');
            statusWrapper.className = 'generator-status';
            const pill = document.createElement('span');
            pill.className = `status-pill ${generator.status === 'online' ? 'online' : 'offline'}`;
            pill.textContent = generator.status === 'online' ? 'Online' : 'Offline';
            statusWrapper.appendChild(pill);

            if (generator.status === 'offline' && generator.reason) {
                const reason = document.createElement('div');
                reason.className = 'generator-reason';
                reason.textContent = generator.reason === 'fuel' ? 'Awaiting refuel' : 'Requires maintenance';
                statusWrapper.appendChild(reason);
            }

            const fuelColumn = document.createElement('div');
            fuelColumn.className = 'generator-fuel';
            const maxFuel = Number(generator.maxFuel) || 0;
            const currentFuel = Number(generator.fuel) || 0;
            const percent = maxFuel > 0 ? Math.floor(Math.max(0, Math.min(100, (currentFuel / maxFuel) * 100))) : 0;
            fuelColumn.appendChild(createFuelBar(percent));
            const fuelLabel = document.createElement('div');
            fuelLabel.className = 'generator-fuel-label';
            fuelLabel.textContent = `${formatNumber(currentFuel, 0)} / ${formatNumber(maxFuel, 0)} (${percent}%)`;
            fuelColumn.appendChild(fuelLabel);

            const actions = document.createElement('div');
            actions.className = 'actions-col';

            if (generator.status === 'offline') {
                if (controlEnabled) {
                    const button = document.createElement('button');
                    button.className = 'generator-action';
                    button.textContent = generator.reason === 'fuel' ? 'Refuel' : 'Restart';
                    button.addEventListener('click', () => requestRepair(generator.id, button));
                    actions.appendChild(button);
                } else {
                    const note = document.createElement('span');
                    note.className = 'generator-reason';
                    note.textContent = 'Restricted';
                    actions.appendChild(note);
                }
            }

            row.appendChild(label);
            row.appendChild(statusWrapper);
            row.appendChild(fuelColumn);
            row.appendChild(actions);

            elements.generatorsBody.appendChild(row);
        });
};

const updateStatusForState = (state) => {
    if (!state || !state.city) {
        setStatus('No live grid data available.', 'error');
        return;
    }

    if (state.city.blackout) {
        setStatus('City load exceeds capacity. Blackout protocols active.', 'error');
        return;
    }

    const timestamp = state.timestamp ? new Date(state.timestamp * 1000) : new Date();
    setStatus(`Last update ${timestamp.toLocaleTimeString()}`);
};

const setLoading = (active) => {
    isLoading = !!active;
    elements.refresh.disabled = isLoading;
    elements.refresh.classList.toggle('is-loading', isLoading);

    if (isLoading) {
        setStatus('Refreshing data…');
    } else if (latestState) {
        updateStatusForState(latestState);
    }
};

const handleNetworkState = (payload) => {
    if (!payload || !payload.state) {
        latestState = null;
        renderCity(null);
        renderZones([]);
        elements.generatorsBody.innerHTML = '';
        setControlBadge(false, false);
        setStatus('No live grid data available.', 'error');
        return;
    }

    latestState = payload.state;
    renderCity(payload.state.city);
    renderZones(payload.state.zones);
    renderGenerators(payload.state.generators);
    const cityData = (payload.state && payload.state.city) || {};
    setControlBadge(payload.canControl, cityData.blackout);
    updateStatusForState(payload.state);
};

elements.refresh.addEventListener('click', () => {
    setLoading(true);
    if (typeof globalThis.fetchNui === 'function') {
        globalThis.fetchNui('refreshState');
    } else {
        setLoading(false);
    }
});

if (typeof globalThis.useNuiEvent === 'function') {
    globalThis.useNuiEvent('networkState', (payload) => {
        setLoading(false);
        handleNetworkState(payload);
    });

    globalThis.useNuiEvent('networkError', () => {
        setLoading(false);
        latestState = null;
        renderCity(null);
        renderZones([]);
        elements.generatorsBody.innerHTML = '';
        setControlBadge(false, false);
        setStatus('Unable to load power network state.', 'error');
    });

    globalThis.useNuiEvent('loading', (active) => {
        setLoading(active);
    });
}

if (!window.invokeNative) {
    setStatus('Use the refresh button to load live data.');
}
