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

--- @return string
function util.generate_random_name()
    return game.backer_names[math.random(1, #game.backer_names)]
end

--- @param pair ItemIDAndQualityIDPair?
--- @return ItemIDAndQualityIDPair|false?
function util.normalize_id_quality_pair(pair)
    if not pair then return false end
    if pair.quality and not type(pair.quality) == "string" then
        return {
            name = pair.name,
            quality = pair.quality.name,
        }
    end
    return pair
end

--- @param entity string
--- @param module_config ModuleConfig
--- @return boolean, LocalisedString True if valid, else false and a localised error message
function util.entity_valid_for_modules(entity, module_config)
    local entity_proto = prototypes.entity[entity]
    if entity_proto.allowed_module_categories then
        for category, module_name in pairs(module_config.categories) do
            if not entity_proto.allowed_module_categories[category] then
                return false, { "inventory-restriction.cant-insert-module", prototypes.item[module_name].localised_name, entity_proto.localised_name } -- TODO using the category instead of the localised module name
            end
        end
    end
    if entity_proto.allowed_effects then
        for effect, module_name in pairs(module_config.effects) do
            if not entity_proto.allowed_effects[effect] then
                return false, { "inventory-restriction.cant-insert-module", prototypes.item[module_name].localised_name, entity_proto.localised_name } -- TODO using the category instead of the localised module name
            end
        end
    end
    return true
end

--- @param entity string
--- @param module_config_set ModuleConfigSet
--- @return boolean, LocalisedString True if valid, else false and a localised error message
function util.entity_valid_for_module_set(entity, module_config_set)
    for _, module_row in pairs(module_config_set.configs) do
        local valid, error = util.entity_valid_for_modules(entity, module_row)
        if not valid then
            return valid, error
        end
    end
    return true
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
--- @param entity LuaEntity -- Already checked to be valid
--- @param module_config ModuleConfig
--- @param clear boolean If true, remove all current modules
function util.create_request_proxy(entity, module_config, clear)
    local modules = module_config.module_list

    if entity.type == "entity-ghost" then
        local inventory_define = util.inventory_defines_map[entity.ghost_type]
        local module_requests = {}
        for i = 1, storage.name_to_slot_count[entity.ghost_name] do
            local insert_module = modules[i]
            if insert_module then
                module_requests[i] = createBlueprintInsertPlan(insert_module, i, inventory_define)
            end
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
        game.print("ERROR [ModuleInserterEx]: Unknown inventory type: " .. entity.type)
        return
    end

    -- Remove any existing requests
    local proxies = entity.surface.find_entities_filtered({
        name = "item-request-proxy",
        force = entity.force,
        position = entity.position
    })
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
        local need_to_remove = clear
        local need_to_add = not not target
        if stack.valid_for_read then
            -- If it's already the target module, then do nothing
            if target and stack.name == target.name and stack.quality.name == target.quality then
                need_to_add = false
                need_to_remove = false
            elseif need_to_add then
                need_to_remove = true
            end
        end

        if target and need_to_add then
            module_requests[i] = createBlueprintInsertPlan(target, i, inventory_define)
        end
        if need_to_remove and stack.valid_for_read then
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

    entity.surface.create_entity(create_info)
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
    for _, value in ipairs(module_config.module_list) do
        if value then return true end
    end
    return false
end

--- @param target_config TargetConfig
--- @return boolean
function util.target_config_has_entries(target_config)
    return next(target_config.entities) ~= nil
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

--- Resize the module lists if needed
--- @param slots int Number of slots in each row
--- @param module_set ModuleConfigSet
function util.normalize_module_set(slots, module_set)
    -- Remove all empty configs
    local index = 1
    while index <= #module_set.configs do
        local module_config = module_set.configs[index]
        -- Clear slots that are not used anymore
        for slot_index = slots + 1, storage.max_slot_count do
            module_config.module_list[slot_index] = nil
        end
        -- Make sure it maps each slot
        for slot_index = 1, slots do
            if not module_config.module_list[slot_index] then
                module_config.module_list[slot_index] = false
            end
        end
        index = index + 1
    end
end

--- Resize the config set, removing empty slots
--- @param target_config TargetConfig
function util.normalize_target_config(target_config)
    -- Remove all empty configs
    local index = 1
    while index <= #target_config.entities do
        local have_entries = target_config.entities[index] ~= nil
        if not have_entries then
            table.remove(target_config.entities, index)
        else
            index = index + 1
        end
    end
end

--- Resize the config rows, removing empty rows, and making sure one empty row at the end
--- @param config PresetConfig
function util.normalize_preset_config(config)
    util.normalize_module_set(storage.max_slot_count, config.default)
    -- Remove all empty configs
    local index = 1
    while index <= #config.rows do
        local row_config = config.rows[index]
        local have_entries = util.row_config_has_entries(row_config)
        if not have_entries then
            table.remove(config.rows, index)
        else
            util.normalize_target_config(row_config.target)
            util.normalize_module_set(util.get_target_config_max_slots(row_config.target), row_config.module_configs)
            index = index + 1
        end
    end

    -- Add a single empty config to the end
    table.insert(config.rows, types.make_row_config())
end

--- @param recipe LuaRecipe
--- @param modules ModuleConfig
--- @return true|false, LocalisedString
function util.modules_allowed(recipe, modules)
    if recipe.prototype.allowed_module_categories then
        for category, _ in pairs(modules.categories) do
            if not recipe.prototype.allowed_module_categories[category] then
                return false, { "item-limitation." .. category .. "-effect"}
            end
        end
    end
    if recipe.prototype.allowed_effects then
        for effect, _ in pairs(modules.effects) do
            if not recipe.prototype.allowed_effects[effect] then
                return false, { "item-limitation." .. effect .. "-effect"}
            end
        end
    end
    return true
end

--- @param name string
--- @param preset PresetConfig
--- @return ModuleConfigSet|true Module config set to use for this entity, or nil if none
function util.find_module_set_to_use_for_entity(name, preset)
    for _, row in pairs(preset.rows) do
        for _, target in ipairs(row.target.entities) do
            if name == target then
                return row.module_configs
            end
        end
    end
    if preset.use_default then
        return preset.default
    end
    return true
end

--- @param name string
--- @param recipe false|LuaRecipe?
--- @param module_config_set ModuleConfigSet
--- @return ModuleConfig|false, {[LocalisedString]: LocalisedString}? Module config to use for this entity, or nil if none, with table of error messages
function util.choose_module_config_from_set(name, recipe, module_config_set)
    --- @type ModuleConfig?
    local config_to_use = nil
    local messages = {}
    for _, module_config in pairs(module_config_set.configs) do
        local valid, message = util.entity_valid_for_modules(name, module_config)
        if valid then
            if recipe then
                valid, message = util.modules_allowed(recipe, module_config)
                if valid then
                    config_to_use = module_config
                    break
                else
                    messages[message] = message ---@diagnostic disable-line: need-check-nil
                end
            else
                config_to_use = module_config
                break
            end
        else
            messages[message] = message ---@diagnostic disable-line: need-check-nil
        end
    end
    if config_to_use then
        return config_to_use
    else
        return false, messages
    end
end

--- @param entity LuaEntity
--- @param is_ghost boolean
--- @param field string
--- @param ghost_field string
function util.maybe_ghost_property(entity, is_ghost, field, ghost_field)
    return is_ghost and entity[ghost_field] or entity[field]
end

return util