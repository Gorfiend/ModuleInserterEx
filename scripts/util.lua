local types = require("scripts.types")

local util = {}

util.inventory_defines_map = {
    ["furnace"] = defines.inventory.furnace_modules,
    ["assembling-machine"] = defines.inventory.assembling_machine_modules,
    ["lab"] = defines.inventory.lab_modules,
    ["mining-drill"] = defines.inventory.mining_drill_modules,
    ["rocket-silo"] = defines.inventory.rocket_silo_modules,
    ["beacon"] = defines.inventory.beacon_modules,
}

--- @param pair ItemIDAndQualityIDPair?
--- @return ItemIDAndQualityIDPair?
function util.normalize_id_quality_pair(pair)
    if not pair then return end
    if pair.quality and not type(pair.quality) == "string" then
        return {
            name = pair.name,
            quality = pair.quality.name,
        }
    end
    return pair
end

--- @param module ItemIDAndQualityIDPair
--- @param stack_index int
--- @param inventory_define defines.inventory
--- @return BlueprintInsertPlan
local function createBlueprintInsertPlan(module, stack_index, inventory_define)
    --- @type BlueprintInsertPlan
    return {
        id = module,
        items = {
            in_inventory = {{
                inventory = inventory_define,
                stack = stack_index - 1,
                count = 1,
            }}
        }
    }
end

--- Process data to create logistic requests to insert/remove modules
--- @param data ToCreateData
function util.create_request_proxy(data)
    local entity = data.entity
    local modules = data.modules

    if entity.type == "entity-ghost" then
        local inventory_define = util.inventory_defines_map[entity.ghost_type]
        local module_requests = {}
        for i = 1, #modules do
            local target = modules[i]
            module_requests[i] = createBlueprintInsertPlan(target, i, inventory_define)
        end
        entity.insert_plan = module_requests
        return
    end

    local module_inventory = entity.get_module_inventory()
    if not module_inventory then
        return
    end

    local inventory_define = util.inventory_defines_map[entity.type]
    if not inventory_define then
        data.player.print("ERROR: Unknown inventory type: " .. entity.type)
        return
    end

    local module_requests = {}
    local removal_plan = {}
    for i = 1, #module_inventory do
        local stack = module_inventory[i]
        local target = modules[i]
        local need_to_remove = false
        local need_to_add = target ~= nil
        if stack.valid_for_read then
            -- If it's already the target module, then do nothing
            if target and stack.name == target.name and stack.quality.name == target.quality then
                need_to_add = false
            else
                need_to_remove = true
            end
        end

        if need_to_add then
            module_requests[i] = createBlueprintInsertPlan(target, i, inventory_define)
        end
        if need_to_remove then
            removal_plan[i] = createBlueprintInsertPlan({ name = stack.name, quality = stack.quality.name }, i, inventory_define)
        end
    end
    if next(module_requests) == nil and next(removal_plan) == nil then
        -- Nothing needs to change, so skip creating anything
        return
    end

    local create_info = {
        name = "item-request-proxy",
        position = entity.position,
        force = entity.force,
        target = entity,
        modules = module_requests,
        raise_built = true
    }
    if next(removal_plan) ~= nil then
        create_info.removal_plan = removal_plan
    end

    data.surface.create_entity(create_info)
end

--- @param module_config ModuleConfig
--- @return boolean
function util.module_config_has_entries(module_config)
    for _, value in pairs(module_config.module_list) do
        if value then
            return true
        end
    end
    return false
end

--- @param row_config RowConfig
--- @return boolean
function util.row_config_has_entries(row_config)
    return row_config.from ~= nil
end

--- Resize the config set, removing empty configs, and making sure one empty config at the end
--- @param module_set ModuleConfigSet
function util.normalize_module_set(module_set)
    -- Remove all empty configs
    local index = 1
    while index <= #module_set.configs do
        local have_entries = util.module_config_has_entries(module_set.configs[index])
        if not have_entries then
            table.remove(module_set.configs, index)
        else
            index = index + 1
        end
    end

    -- Add a single empty config to the end
    table.insert(module_set.configs, types.make_module_config())
end

--- Resize the config rows, removing empty rows, and making sure one empty row at the end
--- @param config PresetConfig
function util.normalize_preset_config(config)
    -- Remove all empty configs
    local index = 1
    while index <= #config.rows do
        local have_entries = util.row_config_has_entries(config.rows[index])
        if not have_entries then
            table.remove(config.rows, index)
        else
            util.normalize_module_set(config.rows[index].module_configs)
            index = index + 1
        end
    end

    -- Add a single empty config to the end
    table.insert(config.rows, types.make_row_config())
end

return util