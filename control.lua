require "__core__/lualib/util"
local v = require "__ModuleInserter__/semver"

local lib = require "__ModuleInserter__/lib_control"
local debugDump = lib.debugDump
local saveVar = lib.saveVar
local config_exists = lib.config_exists
local GUI = require "__ModuleInserter__/gui"
local profiler = require "profiler"
local MOD_NAME = "ModuleInserter"

local UPDATE_RATE = 117
local _productivity = {}

local function productivity_allowed(recipe, module_proto)--luacheck: ignore
    if _productivity[recipe] == nil then
        _productivity[recipe] = false
        local limits = module_proto and module_proto.limitations
        if limits and next(limits) then
            for _, r in pairs(limits) do
                if r == recipe then
                    _productivity[recipe] = true
                    break
                end
            end
        end
    end
    return _productivity[recipe]
end

local function compare_contents(tbl1, tbl2)
    if tbl1 == tbl2 then return true end
    for k, value in pairs(tbl1) do
        if (value ~= tbl2[k]) then return false end
    end
    for k, _ in pairs(tbl2) do
        if tbl1[k] == nil then return false end
    end
    return true
end

local function sort_modules(entity, modules, cTable)
    --Don't sort empty inventories
    if not next(modules) then return end
    local inventory = entity.get_module_inventory()
    local contents = inventory and inventory.get_contents()
    --log({"", "cTable", serpent.block(cTable)})
    --log({"", "contents", serpent.block(contents)})
    if compare_contents(cTable, contents) then
        local status, err = pcall(function()
            inventory.clear()
            local insert = inventory.insert
            for _, module in pairs(modules) do
                if module then
                    insert{name = module, count = 1}
                end
            end
        end)
        if not status then
            debugDump(err, true)
            inventory.clear()
            for name, count in pairs(contents) do
                inventory.insert{name = name, count = count}
            end
        end
    end
end

local function on_tick(event)
    local tick = event.tick
    if not global.proxies then global.proxies = {} end
    local current = global.proxies[tick]
    if current then
        local check_tick = tick + UPDATE_RATE
        local check = global.proxies[check_tick] or {}
        local entity
        for k, data in pairs(current) do
            if data.proxy then
                entity = (data.target and data.target.valid) and data.target
                if not data.proxy.valid then
                    if entity then
                        sort_modules(entity, data.modules, data.cTable)
                    end
                else
                    if entity then
                        check[k] = data
                    end
                    current[k] = nil
                end
            end
        end
        if next(check) then
            global.proxies[check_tick] = check
        end
        global.proxies[tick] = nil
        if table_size(global.proxies) == 0 then
            script.on_event(defines.events.on_tick, nil)
        end
    end
end

local function conditional_events(check)
    if check then
        for tick, proxies in pairs(global.proxies) do
            for id, data in pairs(proxies) do
                if not (data.target and data.target.valid) then
                    proxies[id] = nil
                end
            end
            if tick < game.tick or not next(proxies) then
                log("Removed old tick: " .. tick .. "(current: " .. game.tick ..")")
                global.proxies[tick] = nil
            end
        end
    end
    if table_size(global.proxies) == 0 then
        script.on_event(defines.events.on_tick, nil)
    else
        script.on_event(defines.events.on_tick, on_tick)
    end
end

local function drop_module(entity, name, count, module_inventory, chest, player, create_entity)--luacheck: ignore
    if not (chest and chest.valid) then
        chest = create_entity{
            name = "module_inserter_pickup",
            --name = "wooden-chest",
            position = entity.position,
            force = entity.force,
            create_build_effect_smoke = false
        }
        if not (chest and chest.valid) then
            error("Invalid chest")
        else
            if player then
                chest.order_deconstruction(chest.force, player)
            else
                chest.order_deconstruction(chest.force)
            end
        end
    end

    local stack = {name = name, count = count}
    --log({"", entity.name, " dropped: ", serpent.line(stack)})
    stack.count = chest.insert(stack)
    if module_inventory.remove(stack) ~= stack.count then
        log("Not all modules removed")
    end
    return chest
end

local function create_request_proxy(entity, ent_name, modules, desired, proxies, player, create_entity)
    local module_inventory = entity.get_module_inventory()
    if not module_inventory then
        return proxies
    end

    local contents = module_inventory.get_contents()
    --TODO maybe worth doing 2 special cases: contents or modules being empty tables
    local same = compare_contents(desired, contents)

    if not same then
        local missing = {}
        local surplus = {}
        local changed
        --log({"", entity.name, " contents: ", serpent.line(contents)})
        --log({"", entity.name, " desired: ", serpent.line(desired)})
        local diff, chest
        for name, count in pairs(desired) do
            diff = (contents[name] or 0) - count -- >0: drop, < 0 missing
            contents[name] = nil
            if diff < 0 then
                missing[name] = -1 * diff
            elseif diff > 0 then
                chest = drop_module(entity, name, diff, module_inventory, chest, player, create_entity)
                surplus[name] = diff
            end
        end
        for name, count in pairs(contents) do
            diff = count - (desired[name] or 0) -- >0: drop, < 0 missing
            assert(not missing[name] and not surplus[name])
            if diff < 0 then
                missing[name] = -1 * diff
            elseif diff > 0 then
                chest = drop_module(entity, name, diff, module_inventory, chest, player, create_entity)
                surplus[name] = diff
                changed = true
            end
        end
        --log({"", entity.name, " missing: ", serpent.line(missing)})
        if changed then
            contents = module_inventory.get_contents()
            same = compare_contents(desired, contents)
        end
        if not same and next(missing)  then
            local module_proxy = {
                name = "item-request-proxy",
                position = entity.position,
                force = entity.force,
                target = entity,
                modules = missing
            }
            local ghost = create_entity(module_proxy)--luacheck: ignore
            proxies[entity.unit_number] = {name = ent_name, proxy = ghost, modules = modules, cTable = desired, target = entity}
        end
    end
    if same then
        sort_modules(entity, modules, desired)
    end
    return proxies
end

--True if module can be used for recipe
local _recipe_to_module = {}
local function module_usable(module, recipe)--luacheck: ignore
    if not _recipe_to_module[recipe] then
        _recipe_to_module[recipe] = {}
    end
    if _recipe_to_module[recipe][module] == nil then
        local module_proto = game.item_prototypes[module]
        local limits = module_proto and module_proto.limitations
        if not (limits and next(limits)) then
            _recipe_to_module[recipe][module] = true
            return true
        end
        local productivity = module_proto and module_proto.module_effects
        productivity = productivity and productivity.productivity
        if productivity and productivity.bonus ~= 0 and recipe and not productivity_allowed(recipe, module_proto) then
            _recipe_to_module[recipe][module] = false
            return false
        end
        _recipe_to_module[recipe][module] = true
    end
    return _recipe_to_module[recipe][module]
end

local function on_player_selected_area(event)
    local status, err = pcall(function()
        local p = game.create_profiler()
        profiler.Start(true)
        local player_index = event.player_index
        if event.item ~= "module-inserter" or not player_index then return end
        local player = game.get_player(player_index)
        local pdata = global._pdata[player_index]

        local config = pdata.config
        --player.print("Entities: " .. #event.entities)
        local check_tick = event.tick + UPDATE_RATE
        local proxies = global.proxies[check_tick] or {}
        local ent_type, ent_name
        --local entity_configs = {}
        local create_entity = player.surface.create_entity
        for _, entity in pairs(event.entities) do
            ent_name = entity.name
            --remove existing proxies if we have a config for it's target
            if ent_name == "item-request-proxy" then
                local target = entity.proxy_target
                if target and target.valid and config_exists(config, target.name) then
                    for tick, proxy in pairs(global.proxies) do
                        if proxy[target.unit_number] then
                            proxy[target.unit_number] = nil
                            if not next(proxy) then
                                global.proxies[tick] = nil
                            end
                            entity.destroy{raise_destroy = true}
                            goto continue
                        end
                    end
                end
            end
            if not global.nameToSlots[ent_name] then
                goto continue
            end
            --TODO check at what point it costs more than it saves
            -- if entity_configs[ent_name] == nil then
            --     entity_configs[ent_name] = config_exists(config, ent_name)
            -- end
            local entity_config = config_exists(config, ent_name)--entity_configs[ent_name]
            if not entity_config then
                goto continue
            end
            ent_type = entity.type
            local recipe = ent_type == "assembling-machine" and entity.get_recipe()
            if ent_type == "assembling-machine" and not recipe then
                player.print("Can't insert modules in assembler without recipe")
                goto continue
            end
            local cTable = entity_config.cTable
            if entity_config.limitations and recipe then
                -- local _item_prototypes = game.item_prototypes
                -- local prototype, productivity
                local message = false
                recipe = recipe.name
                for module, _ in pairs(cTable) do
                    -- prototype = _item_prototypes[module]
                    -- productivity = prototype and prototype.module_effects
                    -- productivity = productivity and productivity.productivity
                    -- if productivity and productivity.bonus ~= 0 and ent_type == "assembling-machine" and recipe and not productivity_allowed(recipe, prototype) then
                    if not module_usable(module, recipe) then
                        if not message then
                            message = "item-limitation.production-module-usable-only-on-intermediates"
                        end
                        break
                    end
                end
                if message then
                    player.print({message})
                    goto continue
                end
            end
            proxies = create_request_proxy(entity, ent_name, entity_config.to, cTable, proxies, player, create_entity)
            ::continue::
        end
        if next(proxies) then
            global.proxies[check_tick] = proxies
        else
            global.proxies[check_tick] = nil
        end
        conditional_events()
        p.stop()
        profiler.Stop()
        log("Entities: " .. #event.entities)
        log({"", p})
        p = nil--luacheck: ignore
    end)
    if not status then
        debugDump(err, true)
        conditional_events(true)
        profiler.Stop(true)
    end
    profiler.Stop(true)
end

local function on_player_alt_selected_area(event)
    local status, err = pcall(function()
        if not event.item == "module-inserter" then return end
        --player.print("Alt entities: " .. #event.entities)
        for _, entity in pairs(event.entities) do
            --log(serpent.block({t=entity.type, n=entity.name, g=entity.ghost_name}))
            if entity.name == "item-request-proxy" then
                for _, proxies in pairs(global.proxies) do
                    if proxies[entity.unit_number] then
                        proxies[entity.unit_number] = nil
                    end
                end
                entity.destroy()
            end
        end
        for tick, proxies in pairs(global.proxies) do
            if not next(proxies) then
                global.proxies[tick] = nil
            end
        end
        conditional_events()
    end)
    if not status then
        debugDump(err, true)
        conditional_events(true)
    end
end

script.on_event(defines.events.on_player_selected_area, on_player_selected_area)
script.on_event(defines.events.on_player_alt_selected_area, on_player_alt_selected_area)

--TODO get # of slots only when necessary
local function getMetaItemData()
    global.nameToSlots = {}
    for name, prototype in pairs(game.entity_prototypes) do
        if prototype.module_inventory_size and prototype.module_inventory_size > 0 then
            global.nameToSlots[name] = prototype.module_inventory_size
        end
    end
end

local function remove_invalid_items()
    local items = game.item_prototypes
    local function _remove(tbl)
        for _, config in pairs(tbl) do
            for k, m in pairs(config.to) do
                if m and not items[m] then
                    config.to[k] = nil
                    config.cTable[m] = nil
                end
            end
        end
    end
    for _, pdata in pairs(global._pdata) do
        _remove(pdata.config)
        if pdata.config_tmp then
            _remove(pdata.config_tmp)
        end
        for _, preset in pairs(pdata.storage) do
            _remove(preset)
        end
    end
end

local function init_global()
    global.proxies = global.proxies or {}
    global.nameToSlots = global.nameToSlots or {}
    global._pdata = global._pdata or {}
end

local function init_player(player)
    local i = player.index
    local pdata = global._pdata[player.index] or {}
    global._pdata[i] = {
        config = pdata.config or {},
        storage = pdata.storage or {},
        settings = pdata.settings or {},

        gui_actions = pdata.gui_actions or {},
        gui_elements = pdata.gui_elements or {},

    }

    GUI.init(player, global._pdata[i])
end

local function init_players()
    for _, player in pairs(game.players) do
        init_player(player)
    end
end

local function on_init()
    init_global()
    getMetaItemData()
end

local function on_load()
    -- set metatables, register conditional event handlers, local references to global
    conditional_events()
end

local function on_configuration_changed(data)
    if not data then
        return
    end
    if data.mod_changes and data.mod_changes[MOD_NAME] then
        local newVersion = data.mod_changes[MOD_NAME].new_version
        newVersion = v(newVersion)
        local oldVersion = data.mod_changes[MOD_NAME].old_version
        -- mod was added to existing save
        if not oldVersion then
            init_global()
            init_players()
        else
            oldVersion = v(oldVersion)
            if oldVersion < v"0.2.3" then
                global = {}
                init_global()
                init_players()
            end

            if oldVersion < v"4.0.1" then
                --saveVar(global, "preUpdate")
                if global.config then
                    for name, p in pairs(global.config) do
                        for i=#p,1,-1 do
                            if p[i].from == "" then
                                global.config[name][i].from = nil
                                global.config[name][i].to = {}
                            end
                            if type(p[i].to) ~= "table" then
                                global.config[name][i].to = {}
                            end
                        end
                    end
                end
                if global["config-tmp"] then
                    for name, p in pairs(global["config-tmp"]) do
                        for i=#p,1,-1 do
                            if p[i].from == "" then
                                global["config-tmp"][name][i].from = nil
                                global["config-tmp"][name][i].to = {}
                            end
                            if type(p[i].to) ~= "table" then
                                global["config-tmp"][name][i].to = {}
                            end
                        end
                    end
                end
                if global.storage then
                    for player, store in pairs(global.storage) do
                        for name, p in pairs(store) do
                            for i=#p,1,-1 do
                                if p[i].from == "" then
                                    global.storage[player][name][i].from = nil
                                    global.storage[player][name][i].to = {}
                                end
                                if type(p[i].to) ~= "table" then
                                    global.storage[player][name][i].to = {}
                                end
                            end
                        end
                    end
                end
            end

            if oldVersion < v"4.0.4" then
                --just to make extra sure all is set
                init_global()
                for i, player in pairs(game.players) do
                    if player and player.valid then
                        init_player(player)
                    else
                        global.config[i] = nil
                        global.settings[i] = nil
                        global.storage[i] = nil
                        global["config-tmp"][i] = nil
                    end
                end
            end

            if oldVersion < v'4.1.0' then
                init_global()
                global.removeTicks = nil
                local check_tick = game.tick + UPDATE_RATE
                local proxies = global.proxies[check_tick] or {}
                local cTable, player
                if global.entitiesToInsert then
                    for key, origEntity in pairs(global.entitiesToInsert) do
                        if origEntity.entity and origEntity.entity.valid and type(origEntity.modules) == "table" then
                            local ent = origEntity.entity
                            player = origEntity.player and origEntity.player.valid and origEntity.player
                            cTable = {}
                            for _, module in pairs(origEntity.modules) do
                                if module then
                                    cTable[module] = (cTable[module] or 0) + 1
                                end
                            end
                            proxies = create_request_proxy(ent, ent.name, origEntity.modules, cTable, proxies, player, ent.surface.create_entity)
                        end
                        global.entitiesToInsert[key] = nil
                    end
                    global.proxies[check_tick] = proxies
                end
                global.entitiesToInsert = nil
                conditional_events()
                init_players()
            end

            if oldVersion < v'4.1.1' then
                init_global()
                local pdata
                for pi, p in pairs(game.players) do
                    init_player(p)
                    pdata = global._pdata[pi]
                    global.config[pi].loaded = nil
                    pdata.gui_elements = global.gui_elements and global.gui_elements[pi] or {}
                    pdata.config = global.config and global.config[pi] or {}
                    pdata.config_tmp = global["config-tmp"] and global["config-tmp"][pi]
                    pdata.storage = global.storage and global.storage[pi] or {}
                    pdata.settings = global.settings and global.settings[pi] or {}
                end
                global.gui_elements = nil
                global.config = nil
                global.storage = nil
                global.settings = nil
            end
            if oldVersion < v'4.1.2' then
                local _item_prototypes = game.item_prototypes
                local function create_cTable(tbl)
                    for i, item_config in pairs(tbl) do
                        item_config.cTable = {}
                        local prototype, limitations
                        for _, module in pairs(item_config.to) do
                            if module then
                                prototype = _item_prototypes[module]
                                limitations = prototype and prototype.limitations
                                if limitations and next(limitations) then
                                    item_config.limitations = true
                                end
                                item_config.cTable[module] = (item_config.cTable[module] or 0) + 1
                            end
                        end
                    end
                end
                for _, pdata in pairs(global._pdata) do
                    create_cTable(pdata.config)
                    create_cTable(pdata.config_tmp)
                    for _, preset in pairs(pdata.storage) do
                        create_cTable(preset)
                    end
                end
            end
            global.version = tostring(newVersion) --do i really need that?
        end
    end
    getMetaItemData()
    --TODO: this shouldn't be possible, since i prevent it being set in the gui?
    --!Unless prototypes change the restrictions between configuring and selecting an area -> on_config_changed could do a check?
    -- if ent_type == "beacon" and not entity_proto.allowed_effects['productivity'] then
    --     player.print({"inventory-restriction.cant-insert-module", prototype.localised_name, entity.localised_name})
    --     goto continue
    -- end
    remove_invalid_items()
    conditional_events(true)
    --check for other mods
end

local function on_player_created(event)
    init_player(game.players[event.player_index])
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, on_player_created)

script.on_event(defines.events.on_gui_click, GUI.generic_event)
script.on_event(defines.events.on_gui_elem_changed, GUI.generic_event)

local function on_runtime_mod_setting_changed(event)
    local _, err = pcall(function()
        --log(serpent.block(event))
        if event.setting == "module_inserter_config_size" and event.player_index then
            local pi = event.player_index
            local pdata = global._pdata[pi]
            GUI.close(pdata, pi)
        end
    end)
    if err then
        log("ModuleInserter: Error occured")
        log(serpent.block(err))
    end
end
script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)

local function on_pre_mined_item(event)
    if event.entity and event.entity.valid and global.nameToSlots[event.entity.name] then
        local status, err = pcall(function()
                local id = event.entity.unit_number
                for tick, proxies in pairs(global.proxies) do
                    if proxies[id] then
                        proxies[id] = nil
                        if not next(proxies) then
                            global.proxies[tick] = nil
                        end
                    end
                end
                conditional_events()
        end)
        if not status then
            debugDump(err, true)
            conditional_events(true)
        end
    end
end

script.on_event({
    defines.events.on_pre_player_mined_item,
    defines.events.on_robot_pre_mined,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy},
    on_pre_mined_item
)

local function on_research_finished(event)
    if event.research.name == 'construction-robotics' then
        for pi, player in pairs(event.research.force.players) do
            GUI.init(player, global._pdata[pi], true)
        end
    end
end
script.on_event(defines.events.on_research_finished, on_research_finished)

remote.add_interface("mi",
    {
        saveVar = function(name)
            saveVar(global, name)
        end,

        init = function()
            init_global()
            init_players()
        end
    })
