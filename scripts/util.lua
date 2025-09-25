local types = require("scripts.types")

local util = {}

util.inventory_defines_map = {
    ["furnace"] = defines.inventory.crafter_modules,
    ["assembling-machine"] = defines.inventory.crafter_modules,
    ["lab"] = defines.inventory.lab_modules,
    ["mining-drill"] = defines.inventory.mining_drill_modules,
    ["rocket-silo"] = defines.inventory.crafter_modules,
    ["beacon"] = defines.inventory.beacon_modules,
}

--- @return string
function util.generate_random_name()
    return game.backer_names[math.random(1, #game.backer_names)]
end

--- @param table table
--- @return boolean
function util.table_is_empty(table)
    return next(table) == nil
end

--- @param entity LuaEntity
--- @return string
function util.get_entity_name(entity)
    if entity.type == "entity-ghost" then
        return entity.ghost_name
    else
        return entity.name
    end
end

--- @param entity LuaEntity
--- @return string
function util.get_entity_type(entity)
    if entity.type == "entity-ghost" then
        return entity.ghost_type
    else
        return entity.type
    end
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

--- @param pair RecipeIDAndQualityIDPair?
--- @return PrototypeWithQuality?
function util.normalize_recipe_id_quality_pair(pair)
    if not pair then return nil end
    local string_pair = {}
    if type(pair.name) == "string" then
        string_pair.name = pair.name
    else
        string_pair.name = pair.name.name
    end
    if type(pair.quality) == "string" then
        string_pair.quality = pair.quality
    else
        string_pair.quality = pair.quality.name
    end
    return string_pair
end

--- @param entity LuaEntity?
--- @return PrototypeWithQuality?
function util.recipe_pair_from_entity(entity)
    if not entity or not entity.valid then return nil end

    local type = util.get_entity_type(entity)

    if type == "assembling-machine" then
        local r, q = entity.get_recipe()
        if r and q then
            return {
                name = r.name,
                quality = q.name,
            }
        end
    elseif type == "furnace" then
        return util.normalize_recipe_id_quality_pair(entity.previous_recipe)
    end
    return nil
end

--- @param entity string
--- @param module_config ModuleConfig
--- @return boolean, LocalisedString True if valid, else false and a localised error message
function util.entity_valid_for_modules(entity, module_config)
    local entity_proto = prototypes.entity[entity]
    if entity_proto.allowed_effects then
        for effect, module_name in pairs(module_config.effects) do
            if not entity_proto.allowed_effects[effect] then
                return false, { "inventory-restriction.cant-insert-module", prototypes.item[module_name].localised_name, entity_proto.localised_name }
            end
        end
    end
    if entity_proto.allowed_module_categories then
        for category, module_name in pairs(module_config.categories) do
            if not entity_proto.allowed_module_categories[category] then
                return false, { "inventory-restriction.cant-insert-module", prototypes.item[module_name].localised_name, entity_proto.localised_name }
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
    for _, entity in pairs(target_config.entities) do
        local entity_proto = prototypes.entity[entity]
        if entity_proto.allowed_module_categories and not entity_proto.allowed_module_categories[proto.category] then
            return false, { "inventory-restriction.cant-insert-module", proto.localised_name, entity_proto.localised_name }
        end
        if itemEffects then
            for name, effect in pairs(itemEffects) do
                if effect > 0 then
                    if entity_proto.allowed_effects and not entity_proto.allowed_effects[name] then
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

--- Removes planes in the provided array that have an inventory target matching the provided define
--- Allows removing module requests, while leaving requests for ingredients or other items
--- @param plans BlueprintInsertPlan[]
--- @param inventory_define defines.inventory
local function removePlansWithInventoryTarget(plans, inventory_define)
    for ip = #plans, 1, -1 do
        local in_inv = plans[ip].items.in_inventory
        if in_inv then
            for ii = #in_inv, 1, -1 do
                if in_inv[ii].inventory == inventory_define then
                    table.remove(in_inv, ii)
                end
            end
        end
        if #in_inv == 0 then
            table.remove(plans, ip)
        end
    end
end

--- Process data to create logistic requests to insert/remove modules
--- @param entity LuaEntity -- Already checked to be valid
--- @param module_config ModuleConfig
--- @param clear boolean If true, remove all current modules
function util.create_request_proxy(entity, module_config, clear)
    local modules = module_config.module_list

    if entity.type == "entity-ghost" then
        local inventory_define = util.inventory_defines_map[entity.ghost_type]
        local insert_plan = entity.insert_plan
        removePlansWithInventoryTarget(insert_plan, inventory_define)
        local slots = storage.name_to_slot_count[entity.ghost_name]
        if slots then
            for i = 1, slots do
                local insert_module = modules[i]
                if insert_module then
                    table.insert(insert_plan, createBlueprintInsertPlan(insert_module, i, inventory_define))
                end
            end
            entity.insert_plan = insert_plan
        end
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

    -- Determine what module additions/removals are needed
    ---@type BlueprintInsertPlan[]
    local module_requests = {}
    ---@type BlueprintInsertPlan[]
    local new_removal_plan = {}
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
            new_removal_plan[i] = createBlueprintInsertPlan({ name = stack.name, quality = stack.quality.name }, i, inventory_define)
        end
    end

    local proxy = entity.item_request_proxy
    if next(module_requests) == nil and next(new_removal_plan) == nil then
        -- Nothing needs to change, so skip creating anything, but remove any existing plans
        if proxy then
            local insert_plan = proxy.insert_plan
            removePlansWithInventoryTarget(insert_plan, inventory_define)
            proxy.insert_plan = insert_plan
            local removal_plan = proxy.removal_plan
            removePlansWithInventoryTarget(removal_plan, inventory_define)
            proxy.removal_plan = removal_plan
        end
        return
    end

    if proxy then
        -- Remove any existing module requests/removals, and add our requests/removals
        local insert_plan = proxy.insert_plan
        removePlansWithInventoryTarget(insert_plan, inventory_define)
        for _, to_add in pairs(module_requests) do
            table.insert(insert_plan, to_add)
        end
        proxy.insert_plan = insert_plan

        local removal_plan = proxy.removal_plan
        removePlansWithInventoryTarget(removal_plan, inventory_define)
        for _, to_add in pairs(new_removal_plan) do
            table.insert(removal_plan, to_add)
        end
        proxy.removal_plan = removal_plan
    else
        -- Else make a new proxy with our requests/removals
        local create_info = {
            name = "item-request-proxy",
            position = entity.position,
            force = entity.force,
            target = entity,
            modules = module_requests,
            raise_built = true
        }
        if next(new_removal_plan) ~= nil then
            create_info.removal_plan = new_removal_plan
        end

        entity.surface.create_entity(create_info)
    end
end

--- @param entity_name string?
--- @param fallback LocalisedString
--- @return LocalisedString
function util.get_localised_entity_name(entity_name, fallback)
    return entity_name and prototypes.entity[entity_name] and prototypes.entity[entity_name].localised_name or fallback
end

--- @param entity_name string|PrototypeWithQuality?
--- @param fallback LocalisedString
--- @return LocalisedString
function util.get_localised_recipe_name(entity_name, fallback)
    local name = nil
    if type(entity_name) == "string" then
        name = entity_name
    elseif entity_name then
        name = entity_name.name
    end
    return name and prototypes.recipe[name] and prototypes.recipe[name].localised_name or fallback
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
    return not util.table_is_empty(target_config.entities) or not util.table_is_empty(target_config.recipes)
end

--- @param row_config RowConfig
--- @return boolean
function util.row_config_has_entries(row_config)
    return util.target_config_has_entries(row_config.target)
end

--- @param target_config TargetConfig
--- @return int
function util.get_target_config_max_slots(target_config)
    if #target_config.recipes > 0 and #target_config.entities == 0 then
        return storage.max_slot_count
    end
    local max_slots = 0
    for _, target in pairs(target_config.entities) do
        max_slots = math.max(max_slots, storage.name_to_slot_count[target])
    end
    return max_slots
end

--- Resize the module lists if needed
--- @param slots int Number of slots in each row
--- @param module_config ModuleConfig
function util.normalize_module_config(slots, module_config)
    local current_size = #module_config.module_list
    if current_size > 256 then
        -- Special case in case theres a config with tons of slots that need to be removed
        local old_list = module_config.module_list
        module_config.module_list = {}
        for slot_index = 1, slots do
            module_config.module_list[slot_index] = old_list[slot_index]
        end
    else
        -- Clear slots that are not used anymore
        for slot_index = slots + 1, current_size do
            module_config.module_list[slot_index] = nil
        end
    end
    -- Make sure it maps each slot
    for slot_index = 1, slots do
        if not module_config.module_list[slot_index] then
            module_config.module_list[slot_index] = false
        end
    end

    -- Rebuild category/effect mapping
    module_config.categories = {}
    module_config.effects = {}
    for _, module in pairs(module_config.module_list) do
        if module then
            local name = module.name
            ---@cast name string
            local module_proto = prototypes.item[name]
            if module_proto then
                module_config.categories[module_proto.category] = name
                for cat, val in pairs(module_proto.module_effects) do
                    if val > 0 then
                        module_config.effects[cat] = name
                    end
                end
            end
        end
    end
end

--- Resize the module lists if needed
--- @param slots int Number of slots in each row
--- @param module_set ModuleConfigSet
function util.normalize_module_set(slots, module_set)
    -- Remove all empty configs
    local index = 1
    while index <= #module_set.configs do
        util.normalize_module_config(slots, module_set.configs[index])
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

    -- ensure there is a recipe array
    target_config.recipes = target_config.recipes or {}
end

--- Resize the config rows, removing empty rows, and making sure one empty row at the end
--- @param config PresetConfig
function util.normalize_preset_config(config)
    util.normalize_module_set(storage.max_slot_count, config.default)
    -- Remove all empty configs
    local index = 1
    while index <= #config.rows do
        local row_config = config.rows[index]
        util.normalize_target_config(row_config.target)
        local have_entries = util.row_config_has_entries(row_config)
        if not have_entries then
            table.remove(config.rows, index)
        else
            util.normalize_module_set(util.get_target_config_max_slots(row_config.target), row_config.module_configs)
            index = index + 1
        end
    end

    -- Add a single empty config to the end
    table.insert(config.rows, types.make_row_config())
end

--- @param recipe LuaRecipePrototype
--- @param modules ModuleConfig
--- @return true|false, LocalisedString
function util.modules_allowed(recipe, modules)
    if recipe.allowed_effects then
        for effect, _ in pairs(modules.effects) do
            if not recipe.allowed_effects[effect] then
                return false, { "item-limitation." .. effect .. "-effect"}
            end
        end
    end
    if recipe.allowed_module_categories then
        for category, _ in pairs(modules.categories) do
            if not recipe.allowed_module_categories[category] then
                return false, { "item-limitation." .. category .. "-effect"}
            end
        end
    end
    return true
end

function util.array_contains(tab, search_for)
    for _, value in ipairs(tab) do
        if value == search_for then
            return true
        end
    end

    return false
end

--- @param tab PrototypeWithQuality[]
--- @param recipe PrototypeWithQuality
function util.array_contains_recipe(tab, recipe)
    for _, value in ipairs(tab) do
        if value.name == recipe.name and (value.quality == "normal" or value.quality == recipe.quality) then
            return true
        end
    end

    return false
end

--- @param entity_name string
--- @param recipe PrototypeWithQuality?
--- @param preset PresetConfig
--- @return ModuleConfigSet|true Module config set to use for this entity, or true if none
function util.find_module_set_to_use_for_entity(entity_name, recipe, preset)
    -- If a recipe is set, then first check for matches with targets that have both recipes and entities
    if recipe then
        for _, row in pairs(preset.rows) do
            if #row.target.recipes > 0 and #row.target.entities > 0 then
                if util.array_contains(row.target.entities, entity_name) and util.array_contains_recipe(row.target.recipes, recipe) then
                    return row.module_configs
                end
            end
        end
    end
    -- Next check any entity-only and recipe-only rows in order
    for _, row in pairs(preset.rows) do
        if #row.target.recipes == 0 then
            if util.array_contains(row.target.entities, entity_name) then
                return row.module_configs
            end
        elseif recipe and #row.target.entities == 0 then
            if util.array_contains_recipe(row.target.recipes, recipe) then
                return row.module_configs
            end
        end
    end
    -- Otherwise, use default if enabled
    if preset.use_default then
        return preset.default
    end
    return true
end

--- @param name string
--- @param recipe PrototypeWithQuality?
--- @param module_config_set ModuleConfigSet
--- @return ModuleConfig|false, {[LocalisedString]: LocalisedString}? Module config to use for this entity, or false if none, with table of error messages
function util.choose_module_config_from_set(name, recipe, module_config_set)
    --- @type ModuleConfig?
    local config_to_use = nil
    local messages = {}
    for _, module_config in pairs(module_config_set.configs) do
        local valid, message = util.entity_valid_for_modules(name, module_config)
        if valid then
            if recipe then
                valid, message = util.modules_allowed(prototypes.recipe[recipe.name], module_config)
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