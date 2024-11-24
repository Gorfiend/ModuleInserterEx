local import_export = {}

local checker = {}

--- @alias Checkers {[string]:Checker}
--- @alias Checker fun(x): string?

local function is_array(t)
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end

--- Checks every field passed as defined by checkers param
--- Removed any keys not present in checkers
--- @param table_name string name of the table
--- @param tbl any
--- @param checkers Checkers keys mapped to validator function
--- @return string? error string
local function check_all(table_name, tbl, checkers)
    if type(tbl) ~= "table" then return table_name .. " not a table" end
    for key, check in pairs(checkers) do
        local err = check(tbl[key])
        if err then return key .. " in " .. table_name .. " not valid: " .. err end
    end
    for key, _ in pairs(tbl) do
        -- Remove any keys not wanted by the checkers
        if not checkers[key] then
            tbl[key] = nil
        end
    end
end

--- Run check_all on all elements in the given array
--- @param table_name string name of the table
--- @param arr table checks if it is an array first
--- @param checkers Checkers
--- @return string? error string
local function check_all_in_array(table_name, arr, checkers)
    if not is_array(arr) then return table_name .. " not an array" end
    for i, value in ipairs(arr) do
        local val_name = table_name .. "[" .. i .. "]"
        local err = check_all(val_name, value, checkers)
        if err then return val_name .. " not valid: " .. err end
    end
end

--- Run check on all elements in the given array
--- @param table_name string name of the table
--- @param arr table checks if it is an array first
--- @param check Checker run on every element of the array
--- @return string? error string
local function check_array(table_name, arr, check)
    if not is_array(arr) then return table_name .. " not an array" end
    for i, value in ipairs(arr) do
        local val_name = table_name .. "[" .. i .. "]"
        local err = check(value)
        if err then return val_name .. " not valid: " .. err end
    end
end

--- @return string? error string
function checker.preset(preset)
    if type(preset) ~= "table" then
        return "preset not a table"
    end

    if not preset.name then return "preset has no name" end

    return check_all("preset", preset, {
        name = function(x)
            if type(x) ~= "string" then return "name is not a string" end
            if x == "" then return "name is empty" end
        end,
        default = checker.module_config_set,
        use_default = function(x)
            if type(x) ~= "boolean" then return "use_default not a boolean" end
        end,
        rows = checker.rows,
    })
end

--- @return string? error string
function checker.rows(rows)
    return check_all_in_array("rows", rows, {
        target = checker.target_config_set,
        module_configs = checker.module_config_set,
    })
end

--- @return string? error string
function checker.target_config_set(config_set)
    return check_all("config_set", config_set, {
        entities = function(x)
            return check_array("entities", x, function(ent)
                -- TODO instead of failing with a missing prototype, maybe do a clean after and notify of the missing things?
                if prototypes.entity[ent] == nil then return "entity not valid: " .. ent end
            end)
        end,
    })
end

--- @return string? error string
function checker.module_config_set(config_set)
    return check_all("config_set", config_set, {
        configs = function(x)
            return check_array("configs", x, checker.module_config)
        end,
    })
end

--- @return string? error string
function checker.module_config(config)
    return check_all("module_config", config, {
        module_list = function(x)
            return check_array("module_list", x, checker.is_module_definition)
        end,
    })
end

--- @return string? error string
function checker.is_module_definition(item)
    if item == false then return end
    return check_all("item_quality_pair", item, {
        name = function(x)
            -- TODO instead of failing with a missing prototype, maybe do a clean after and notify of the missing things?
            if type(x) ~= "string" then return "name is not a string" end
            if prototypes.item[x] == nil then return "not a valid item: " .. x end
        end,
        quality = function(x)
            if x ~= nil then
                if type(x) ~= "string" then return "quality is not a string" end
                if prototypes.quality[x] == nil then return "not a valid quality: " .. x end
            end
        end,
    })
end


--- @param string string
--- @return PresetConfig[]|string
--- @nodiscard
function import_export.import_config(string)
    source = helpers.json_to_table(string)
    if type(source) ~= "table" then
        return "did not parse into a table"
    end

    if not is_array(source) then
        source = { source }
    end

    local err = check_array("", source, checker.preset)

    return err or source
end

return import_export
