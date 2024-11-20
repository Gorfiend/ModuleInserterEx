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

--- @param module string
--- @param target_config TargetConfig
--- @return boolean, LocalisedString True if valid, else false and a localised error message
function util.module_valid_for_config(module, target_config)
    local proto = prototypes.item[module]
    local itemEffects = proto.module_effects
    if itemEffects then
        for name, effect in pairs(itemEffects) do
            if effect > 0 then
                for _, entity in pairs(target_config.entities) do
                    local entity_proto = prototypes.entity[entity]
                    if not entity_proto.allowed_effects[name] then
                        return false, { "inventory-restriction.cant-insert-module", proto.localised_name, entity_proto.localised_name }
                    end
                end
            end
        end
    end
    return true
end

--- Process data to create logistic requests to insert/remove modules
--- @param data ToCreateData
function util.create_request_proxy(data)
    local entity = data.entity
    local modules = data.module_config.module_list

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

    -- Remove any existing requests
    local proxies = entity.surface.find_entities_filtered {
        name = "item-request-proxy",
        force = entity.force,
        position = entity.position
    }
    for _, proxy in pairs(proxies) do
        if proxy.proxy_target == entity then
            proxy.destroy({ raise_destroy = true })
        end
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

--- @param entity_name string?
--- @param fallback LocalisedString
--- @return LocalisedString
function util.get_localised_entity_name(entity_name, fallback)
    return entity_name and prototypes.entity[entity_name] and prototypes.entity[entity_name].localised_name or fallback
end

--- @param module_config ModuleConfig
--- @return boolean
function util.module_config_has_entries(module_config)
    return #module_config.module_list > 0
end

--- @param target_config TargetConfig
--- @return boolean
function util.target_config_has_entries(target_config)
    return #target_config.entities > 0
end

--- @param row_config RowConfig
--- @return boolean
function util.row_config_has_entries(row_config)
    return util.target_config_has_entries(row_config.target)
end

--- @param target_config TargetConfig
--- @return int
function util.get_target_config_max_slots(target_config)
    local max_slots = 0
    for _, target in pairs(target_config.entities) do
        max_slots = math.max(max_slots, storage.name_to_slot_count[target])
    end
    return max_slots
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

--- @param recipe LuaRecipe
--- @param modules ModuleConfig
--- @return LocalisedString?
function util.modules_allowed(recipe, modules)
    -- TODO really not sure what the checks here should be
    -- TODO also add the entity in this check?
    -- TODO may want to cache this result?
    if recipe.prototype.allowed_module_categories then
        for _, module in pairs(modules.module_list) do
            local category = prototypes.item[module.name].category
            if not recipe.prototype.allowed_module_categories[category] then
                return { "item-limitation." .. category .. "-effect"}
            end
        end
    end
    if recipe.prototype.allowed_effects then
        for _, module in pairs(modules.module_list) do
            for effect_name, effect_num in pairs(prototypes.item[module.name].module_effects) do
                if effect_num > 0 and not recipe.prototype.allowed_effects[effect_name] then
                    local category = prototypes.item[module.name].category
                    return { "item-limitation." .. category .. "-effect"}
                end
            end
        end
    end
end

--- @param entity LuaEntity
--- @param preset PresetConfig
--- @return ModuleConfig?, {[string]: string}? Module config to use for this entity, or nil if none, with table of error messages
function util.find_modules_to_use_for_entity(entity, preset)
    local name = util.maybe_ghost_property(entity, "name")
    for _, row in pairs(preset.rows) do
        for _, target in ipairs(row.target.entities) do
            if name == target then
                return util.choose_module_config_from_set(entity, row.module_configs)
            end
        end
    end
    if preset.use_default then
        return util.choose_module_config_from_set(entity, preset.default)
    end
end

--- @param entity LuaEntity
--- @param module_config_set ModuleConfigSet
--- @return ModuleConfig?, {[string]: string}? Module config to use for this entity, or nil if none, with table of error messages
function util.choose_module_config_from_set(entity, module_config_set)
    ent_type = util.maybe_ghost_property(entity, "type")

    local recipe = ent_type == "assembling-machine" and entity.get_recipe()
    --- @type ModuleConfig?
    local config_to_use = nil
    -- add checks for the assembler type, in case this is the default config
    local messages = {}
    if recipe then
        for _, e_config in pairs(module_config_set.configs) do
            local message = util.modules_allowed(recipe, e_config)
            if not message then
                config_to_use = e_config
                break
            else
                messages[message] = message
            end
        end
    else
        config_to_use = module_config_set.configs[1]
    end
    if config_to_use then
        if not util.module_config_has_entries(config_to_use) then
            return -- don't use anything, and no errors
        end
        return config_to_use
    else
        return nil, messages
    end
end

function util.maybe_ghost_property(entity, field)
    local is_ghost = entity.type == "entity-ghost"
    if is_ghost then return entity["ghost_"..field] end
    return entity[field]
end

return util