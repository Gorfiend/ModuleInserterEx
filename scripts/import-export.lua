local import_export = {}

local checker = {}

--- @alias Checkers {[string]:Checker}
--- @alias Checker fun(x): boolean

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
--- @param tbl any
--- @param checkers Checkers keys mapped to validator function
--- @return boolean
local function check_all(tbl, checkers)
    if type(tbl) ~= "table" then return false end
    for key, check in pairs(checkers) do
        if not check(tbl[key]) then return false end
    end
    for key, value in pairs(tbl) do
        if checkers[key] then
            if not checkers[key](value) then
                return false
            end
        else
            tbl[key] = nil
        end
    end
    return true
end

--- Run check_all on all elements in the given array
--- @param arr table checks if it is an array first
--- @param checkers Checkers
--- @return boolean
local function check_all_in_array(arr, checkers)
    if not is_array(arr) then return false end
    for _, value in ipairs(arr) do
        if not check_all(value, checkers) then return false end
    end
    return true
end

--- Run check on all elements in the given array
--- @param arr table checks if it is an array first
--- @param check Checker run on every element of the array
--- @return boolean
local function check_array(arr, check)
    if not is_array(arr) then return false end
    for _, value in ipairs(arr) do
        if not check(value) then return false end
    end
    return true
end

--- @return boolean
function checker.preset(preset)
    if type(preset) ~= "table" then
        return false
    end

    if not preset.name then return false end

    return check_all(preset, {
        name = function(x)
            return type(x) == "string" and x ~= ""
        end,
        default = checker.module_config_set,
        use_default = function(x)
            return type(x) == "boolean"
        end,
        rows = checker.rows,
    })
end

--- @return boolean
function checker.rows(rows)
    return check_all_in_array(rows, {
        target = checker.target_config_set,
        module_configs = checker.module_config_set,
    })
end
--- @return boolean
function checker.target_config_set(config_set)
    return check_all(config_set, {
        entities = function(x)
            return check_array(x, function(ent)
                return prototypes.entity[ent] ~= nil
            end)
        end,
    })
end

--- @return boolean
function checker.module_config_set(config_set)
    return check_all(config_set, {
        configs = function(x)
            return check_array(x, checker.module_config)
        end,
    })
end

--- @return boolean
function checker.module_config(config)
    return check_all(config, {
        module_list = function(x)
            return check_array(x, checker.is_item_quality_pair)
        end,
    })
end

--- @return boolean
function checker.is_item_quality_pair(item)
    return check_all(item, {
        name = function(x)
            return type(x) == "string" and prototypes.item[x] ~= nil
        end,
        quality = function(x)
            return x == nil or type(x) == "string" and prototypes.quality[x] ~= nil
        end,
    })
end


--- @param string string
--- @return PresetConfig[]?
--- @nodiscard
function import_export.import_config(string)
    source = helpers.json_to_table(string)
    if type(source) ~= "table" then
        return nil
    end

    if not is_array(source) then
        source = { source }
    end

    if not check_array(source, checker.preset) then return nil end

    return source
end

return import_export
