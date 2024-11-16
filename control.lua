local gui = require("__flib__.gui")
local migration = require("__flib__.migration")
local mi_gui = require("scripts.gui")
local table = require("__flib__.table")

local lib = require("__ModuleInserterEx__/lib_control")
local debugDump = lib.debugDump

-- GlobalData
--- @class GlobalData
--- @field to_create {[int]:{[int]:ToCreateData}}
--- @field nameToSlots {[string]:int} Name of all entities mapped to their module slot count
--- @field module_entities string[] all entities that have valid module slots
--- @field _pdata {[int]:PlayerConfig}
storage = {}

--- @class PlayerConfig
--- @field last_preset string
--- @field config ModuleConfig[]
--- @field config_tmp ModuleConfig[]?
--- @field pstorage table
--- @field gui table
--- @field gui_open boolean
--- @field pinned boolean Is the gui pinned
--- @field config_by_entity ConfigByEntity
--- @field cursor boolean True when the module inserter item is in this players cursor


--- @alias ConfigByEntity {[string]: ModuleSpecification}

--- @class ModuleSpecification

--- @class MiEventInfo
--- @field event flib.GuiEventData
--- @field player LuaPlayer
--- @field pdata PlayerConfig

--- @class ModuleConfig
--- @field cTable CTable modules mapped to their count
--- @field from string the entity name this applies to
--- @field to string[] array of module slot indexes to the module in that slot

--- @alias CTable {[string]:int}


--- @class ToCreateData
--- @field entity LuaEntity
--- @field modules string[]
--- @field player LuaPlayer
--- @field surface LuaSurface

local inventory_defines_map = {
    ["furnace"] = defines.inventory.furnace_modules,
    ["assembling-machine"] = defines.inventory.assembling_machine_modules,
    ["lab"] = defines.inventory.lab_modules,
    ["mining-drill"] = defines.inventory.mining_drill_modules,
    ["rocket-silo"] = defines.inventory.rocket_silo_modules,
    ["beacon"] = defines.inventory.beacon_modules,
}

script.on_event(defines.events.on_mod_item_opened, function(e)
    if e.item.name == "module-inserter" then
        e.player = game.get_player(e.player_index)
        e.pdata = storage._pdata[e.player_index]
        if not e.pdata.gui_open then
            mi_gui.open(e)
        end
    end
end)

script.on_event("toggle-module-inserter", function(e)
    e.player = game.get_player(e.player_index)
    e.pdata = storage._pdata[e.player_index]
    mi_gui.toggle(e)
end)

local function get_module_inserter(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local inv = player.get_main_inventory()
    local mi = inv and inv.find_item_stack("module-inserter") or nil
    if mi then
        mi.swap_stack(player.cursor_stack)
    else
        player.clear_cursor()
        -- WHY IS THIS NOT WORKING IN REMOTE VIEW
        player.cursor_stack.set_stack({ name = "module-inserter" })
    end
end

script.on_event("get-module-inserter", get_module_inserter)
script.on_event(defines.events.on_lua_shortcut, function(e)
    if e.prototype_name == "module-inserter" then
        get_module_inserter(e)
    end
end)

script.on_event("mi-confirm-gui", function(e)
    local pdata =  storage._pdata and storage._pdata[e.player_index]
    if pdata and pdata.gui_open and not pdata.pinned then
        e.pdata = pdata
        e.player = game.get_player(e.player_index)
        mi_gui.handlers.main.apply_changes(e)
    end
end)

local function drop_module(entity, name, count, module_inventory, chest, create_entity)
    if not (chest and chest.valid) then
        chest = create_entity{
            name = "module_inserter_pickup",
            position = entity.position,
            force = entity.force,
            create_build_effect_smoke = false
        }
        if not (chest and chest.valid) then
            error("Invalid chest")
        end
    end

    local stack = {name = name, count = count}
    stack.count = chest.insert(stack)
    if module_inventory.remove(stack) ~= stack.count then
        log("Not all modules removed")
    end
    return chest
end

local function print_planner(planner)--luacheck: ignore
    for i = 1, 4 do
        log(serpent.line(planner.get_mapper(i, "from")) .. serpent.line(planner.get_mapper(i, "to")))
    end
end

--TODO: figure out which modules can be replaced via upgrade item
--only 1 type desired
--multiple module types if:
--  amounts can be matched from contents to desired
---@param contents ItemCountWithQuality[]
---@param desired any
---@param desired_count any
---@param upgrade_planner LuaItemCommon
---@return LuaItemCommon?
local function create_upgrade_planner(contents, desired, desired_count, upgrade_planner)
    if desired_count == 0 or table_size(contents) == 0 then return end
    if desired_count == 1 then
        local from = {type = "item", name = ""}
        local to = {type = "item", name = next(desired)}
        local i = 0
        for _, info in pairs(contents) do
            if info.name ~= to.name then
                i = i + 1
                from.name = info.name
                upgrade_planner.set_mapper(i, "from", from)
                upgrade_planner.set_mapper(i, "to", to)
            end
        end
        -- Fill empty slots too
        i = i + 1
        upgrade_planner.set_mapper(i, "to", to)
        if i > 0 then
            return upgrade_planner
        end
    end
    local matches = {}
    local assigned = {}
    --"upgrading" to the same module
    for name, c in pairs(contents) do
        if desired[name] and desired[name] == c then
            matches[name] = name
            assigned[name] = name
        end
    end
    for name, c in pairs(contents) do
        for name_d, c_d in pairs(desired) do
            if c == c_d and not matches[name] and not assigned[name_d] then
                matches[name] = name_d
                assigned[name_d] = name
            end
        end
    end
    if desired_count == table_size(matches) then
        local from = {type = "item", name = ""}
        local to = {type = "item", name = next(desired)}
        local i = 0
        for name, name_d in pairs(matches) do
            if name ~= name_d then
                from.name = name
                to.name = name_d
                i = i + 1
                upgrade_planner.set_mapper(i, "from", from)
                upgrade_planner.set_mapper(i, "to", to)
            end
        end
        if i > 0 then
            return upgrade_planner
        end
    end
end

--- @param module_name string
--- @param stack_index int
--- @param inventory_define defines.inventory
--- @return table
local function createBlueprintInsertPlan(module_name, stack_index, inventory_define)
    return {
        id = { name = module_name, },
        items = {
            in_inventory = {{
                inventory = inventory_define,
                stack = stack_index - 1,
                count = 1,
            }}
        }
    }
end

--- @param data ToCreateData
local function create_request_proxy(data)
    entity = data.entity
    modules = data.modules

    if entity.type == "entity-ghost" then
        local inventory_define = inventory_defines_map[entity.ghost_type]
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

    local inventory_define = inventory_defines_map[entity.type]
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
            if stack.name == target then -- TODO also check the quality
                need_to_add = false
            else
                need_to_remove = true
            end
        end

        if need_to_add then
            module_requests[i] = createBlueprintInsertPlan(target, i, inventory_define)
        end
        if need_to_remove then
            removal_plan[i] = createBlueprintInsertPlan(stack.name, i, inventory_define)
        end
    end
    if next(module_requests) == nil and next(removal_plan) == nil then
        -- Nothing needs to change, so skip creating anything
        return
    end

    create_info = {
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

local function delayed_creation(e)
    local current = storage.to_create[e.tick]
    if current then
        local ent
        for _, data in pairs(current) do
            ent = data.entity
            if ent and ent.valid then
                create_request_proxy(data)
            end
        end
        storage.to_create[e.tick] = nil
        script.on_nth_tick(e.nth_tick, nil)
    end
end

local function conditional_events(check)
    if check then
        for tick, to_create in pairs(storage.to_create) do
            for id, data in pairs(to_create) do
                if not (data.entity and data.entity.valid) then
                    to_create[id] = nil
                end
            end
            if not next(to_create) then
                storage.to_create[tick] = nil
            end
        end
    end
    for tick in pairs(storage.to_create) do
        script.on_nth_tick(tick, delayed_creation)
    end
end

--- @param recipe LuaRecipe
--- @param modules table
local function modules_allowed(recipe, modules)
    -- TODO really not sure what the checks here should be
    -- TODO also add the entity in this check?
    -- TODO may want to cache this result?
    if recipe.prototype.allowed_module_categories then
        for module, _ in pairs(modules) do
            local category = prototypes.item[module].category
            if not recipe.prototype.allowed_module_categories[category] then
                return false
            end
        end
    end
    if recipe.prototype.allowed_effects then
        for module, _ in pairs(modules) do
            for effect_name, effect_num in pairs(prototypes.item[module].module_effects) do
                if effect_num > 0 and not recipe.prototype.allowed_effects[effect_name] then
                    return false
                end
            end
        end
    end
    return true
end

local function on_player_selected_area(e)
    local status, err = pcall(function()
        local player_index = e.player_index
        if e.item ~= "module-inserter" or not player_index then return end
        local player = game.get_player(player_index)
        if not player then return end
        local pdata = storage._pdata[player_index]
        local config = pdata.config_by_entity
        if not config then
            player.print({"module-inserter-config-not-set"})
            return
        end
        local ent_type, target
        local surface = player.surface
        local delay = e.tick --[[@as uint]]
        local max_proxies = settings.global["module_inserter_proxies_per_tick"].value
        local message = nil
        local default_config = config["mi-default-proxy-machine"]
        for i, entity in pairs(e.entities) do
            entity = entity --[[@as LuaEntity]]
            --remove existing proxies if we have a config for its target
            if entity.name == "item-request-proxy" then
                target = entity.proxy_target
                if target and target.valid and (config[target.name] or default_config) then -- also check config.default
                    entity.destroy{raise_destroy = true}
                end
                goto continue
            end

            --skip the entity if it is a tile ghost
            if entity.type == "tile-ghost" then
                goto continue
            end

            local is_ghost = entity.type == "entity-ghost"
            local function ent_prop(field)
                if is_ghost then return entity["ghost_"..field] end
                return entity[field]
            end

            local entity_configs = config[ent_prop("name")]
            if not entity_configs then
                if not default_config then
                    goto continue
                else
                    entity_configs = table.deep_copy(default_config)
                    for _, e_config in pairs(entity_configs) do
                        local ent_slots = ent_prop("prototype").module_inventory_size
                        if ent_slots < #e_config.to then
                            for m = ent_slots + 1, #e_config.to do
                                e_config.to[m] = nil
                            end
                            e_config.cTable = {}
                            for _, module in pairs(e_config.to) do
                                if module then
                                    e_config.cTable[module] = (e_config.cTable[module] or 0) + 1
                                end
                            end
                        end
                    end
                end
            end


            ent_type = ent_prop("type")
            local recipe = ent_type == "assembling-machine" and entity.get_recipe()
            local entity_config = nil
            if recipe then
                for _, e_config in pairs(entity_configs) do
                    if modules_allowed(recipe, e_config.cTable) then
                        entity_config = e_config
                        break
                    else
                        message = "item-limitation.production-module-usable-only-on-intermediates"
                    end
                end
            else
                entity_config = entity_configs[1]
            end
            if entity_config then
                if (i % max_proxies == 0) then
                    delay = delay + 1
                end
                if not storage.to_create[delay] then storage.to_create[delay] = {} end
                storage.to_create[delay][entity.unit_number --[[@as int]]] = {
                    entity = entity,
                    modules = table.shallow_copy(entity_config.to),
                    player = player,
                    surface = surface,
                }
            end
            ::continue::
        end
        if message then
            player.print({message})
        end
        conditional_events()
    end)
    if not status then
        debugDump(err, true)
        conditional_events(true)
    end
end

local function on_player_alt_selected_area(e)
    local status, err = pcall(function()
        if not e.item == "module-inserter" then return end
        for _, entity in pairs(e.entities) do
            if entity.name == "item-request-proxy" then
                entity.destroy{raise_destroy = true}
            elseif entity.type == "entity-ghost" then
                entity.insert_plan = {}
            end
        end
        conditional_events()
    end)
    if not status then
        debugDump(err, true)
        conditional_events(true)
    end
end

local function on_player_reverse_selected_area(e)
    local status, err = pcall(function()
        local player_index = e.player_index
        if e.item ~= "module-inserter" or not player_index then return end

        local player = game.get_player(player_index)
        local surface = player.surface
        local delay = e.tick
        local max_proxies = settings.global["module_inserter_proxies_per_tick"].value

        for i, entity in pairs(e.entities) do
            if entity.name == "item-request-proxy" then
                entity.destroy{raise_destroy = true}
            elseif entity.type == "entity-ghost" then
                entity.insert_plan = {}
            else
                if (i % max_proxies == 0) then
                    delay = delay + 1
                end
                if not storage.to_create[delay] then storage.to_create[delay] = {} end
                storage.to_create[delay][entity.unit_number] = {
                    entity = entity,
                    modules = {},
                    player = player,
                    surface = surface
                }
            end
        end
        conditional_events()
    end)
    if not status then
        debugDump(err, true)
        conditional_events(true)
    end
end

local function se_grounded_entity(name)
    local result = name:sub(-9) == "-grounded" -- -#"grounded"
    return result
end

local function create_lookup_tables()
    storage.nameToSlots = {}
    storage.module_entities = {}
    local i = 1
    for name, prototype in pairs(prototypes.entity) do
        if prototype.module_inventory_size and prototype.module_inventory_size > 0 and not se_grounded_entity(name) then
            storage.nameToSlots[name] = prototype.module_inventory_size
            storage.module_entities[i] = name
            i = i + 1
        end
    end
end

local function remove_invalid_items()
    local items = prototypes.item
    local entities = prototypes.entity
    local removed_entities = {}
    local removed_modules = {}
    local function _remove(tbl)
        for _, config in pairs(tbl) do
            if (config.from or config.from == false) and not entities[config.from] then
                removed_entities[config.from] = true
                config.from = nil
                config.to = {}
                config.cTable = {}
            end
            for k, m in pairs(config.to) do
                if m and not items[m] then
                    config.to[k] = nil
                    config.cTable[m] = nil
                    removed_modules[config.from] = true
                end
            end
        end
    end
    for _, pdata in pairs(storage._pdata) do
        _remove(pdata.config)
        if pdata.config_tmp then
            _remove(pdata.config_tmp)
        end
        for _, preset in pairs(pdata.pstorage) do
            _remove(preset)
        end
    end
    for k in pairs(removed_entities) do
        log("Module Inserter: Removed configuration for " ..k)
    end
    for k in pairs(removed_modules) do
        log("Module Inserter: Removed module " .. k .. " from all configurations")
    end
end

local function init_global()
    storage.to_create = storage.to_create or {}
    storage.nameToSlots = storage.nameToSlots or {}
    storage._pdata = storage._pdata or {}
end

local function init_player(i)
    init_global()
    local pdata = storage._pdata[i] or {}
    storage._pdata[i] = {
        last_preset = pdata.last_preset or "",
        config = pdata.config or {},
        config_by_entity = pdata.config_by_entity or {},
        pstorage = pdata.pstorage or {},
        gui = pdata.gui or {},
        gui_open = false,
        pinned = false,
        cursor = false,
    }
    mi_gui.update_main_button(game.get_player(i))
    mi_gui.create(i)
end

local function init_players()
    for i, _ in pairs(game.players) do
        init_player(i)
    end
end

script.on_init(function()
    create_lookup_tables()
    init_global()
    init_players()
end)

script.on_load(function()
    conditional_events()
end)

local migrations = {
}

script.on_configuration_changed(function(e)
    create_lookup_tables()
    remove_invalid_items()
    if migration.on_config_changed(e, migrations) then
        for pi, pdata in pairs(storage._pdata) do
            mi_gui.destroy(pdata, game.get_player(pi))
            mi_gui.create(pi)
        end

    end
    conditional_events(true)
end)

script.on_event(defines.events.on_player_selected_area, on_player_selected_area)
script.on_event(defines.events.on_player_alt_selected_area, on_player_alt_selected_area)
script.on_event(defines.events.on_player_reverse_selected_area, on_player_reverse_selected_area)

gui.handle_events()

--- @return table<string, fun(e: flib.GuiEventData)>
local function make_handler_table()
    handler_table = {}
    for group_name, group in pairs(mi_gui.handlers) do
        for name, func in pairs(group) do
            handler_table[group_name .. "_" .. name] = func
        end
    end
    return handler_table
end

gui.add_handlers(make_handler_table(), function (e, handler)
    ev = {
        event = e,
        player = game.get_player(e.player_index),
        pdata = storage._pdata[e.player_index]
    }
    handler(ev)
end)

script.on_event(defines.events.on_player_created, function(e)
    init_player(e.player_index)
end)

script.on_event(defines.events.on_player_removed, function(e)
    storage._pdata[e.player_index] = nil
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(e)
    if not e.player_index then return end
    if e.setting == "module_inserter_button_style" or e.setting == "module_inserter_hide_button" then
        mi_gui.update_main_button(game.get_player(e.player_index))
    end
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    if player.mod_settings["module_inserter_hide_button"].value then return end
    -- Track if they have the module inserter in hand, then when they let go remove it from their inventory
    -- Don't do this if the mod gui button to open the inserter options is disabled
    if player.cursor_stack.valid_for_read and player.cursor_stack.name == "module-inserter" then
        storage._pdata[e.player_index].cursor = true
    elseif storage._pdata[e.player_index].cursor then
        storage._pdata[e.player_index].cursor = false
        local inv = player.get_main_inventory()
        if not inv then return end
        local count = inv.get_item_count("module-inserter")
        if count > 0 then
            inv.remove{name = "module-inserter", count = count}
        end
    end
end)

commands.add_command("mi_clean", "", function()
    for _, egui in pairs(game.player.gui.screen.children) do
        if egui.get_mod() == "ModuleInserterEx" then
            egui.destroy()
        end
    end
end)