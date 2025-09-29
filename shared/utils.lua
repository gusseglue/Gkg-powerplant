local Utils = {}

function Utils.deepCopy(tbl)
    if type(tbl) ~= 'table' then
        return tbl
    end

    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = Utils.deepCopy(v)
    end

    return copy
end

function Utils.tableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

function Utils.round(value, decimals)
    local multiplier = 10 ^ (decimals or 0)
    return math.floor(value * multiplier + 0.5) / multiplier
end

return Utils
