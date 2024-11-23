local mod_gui = require("__core__.lualib.mod-gui")

local gui = require("__flib__.gui")
local migration = require("__flib__.migration")
local table = require("__flib__.table")

local mi_gui = require("scripts.gui")
local types = require("scripts.types")
local util = require("scripts.util")

local lib = require("__ModuleInserterEx__/lib_control")
local debugDump = lib.debugDump

--- @type GlobalData
storage = {} ---@diagnostic disable-line: missing-fields


--- @param e GuiEventData|EventData.on_mod_item_opened|EventData.CustomInputEvent
--- @return MiEventInfo
local function make_event_info(e)
    return {
        event = e,
        player = game.get_player(e.player_index),
        pdata = storage._pdata[e.player_index],
    }
end

script.on_event(defines.events.on_mod_item_opened, function(e)
    if e.item.name == "module-inserter-ex" then
        me = make_event_info(e)
        if not me.pdata.gui_open then
            mi_gui.open(me)
        end
    end
end)

script.on_event("toggle-module-inserter-ex", function(e)
    mi_gui.toggle(make_event_info(e))
end)

local function get_module_inserter(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local inv = player.get_main_inventory()
    local mi = inv and inv.find_item_stack("module-inserter-ex") or nil
    if mi then
        mi.swap_stack(player.cursor_stack)
    else
        player.clear_cursor()
        player.cursor_stack.set_stack({ name = "module-inserter-ex" })
    end
end

script.on_event("get-module-inserter-ex", get_module_inserter)
script.on_event(defines.events.on_lua_shortcut, function(e)
    if e.prototype_name == "module-inserter-ex" then
        get_module_inserter(e)
    end
end)

local function delayed_creation(e)
    local current = storage.to_create[e.tick]
    if current then
        for _, data in pairs(current) do
            if data.entity and data.entity.valid then
                util.create_request_proxy(data)
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

---@param e EventData.on_player_selected_area
local function on_player_selected_area(e)
    local status, err = pcall(function()
        local player_index = e.player_index
        if e.item ~= "module-inserter-ex" or not player_index then return end
        local player = game.get_player(player_index)
        if not player then return end
        local pdata = storage._pdata[player_index]
        local active_preset = pdata.active_config
        if not active_preset then
            player.print({"module-inserter-ex-config-not-set"})
            return
        end
        local surface = player.surface
        local delay = e.tick --[[@as uint]]
        local max_proxies = settings.global["module-inserter-ex-proxies-per-tick"].value
        local result_messages = {}
        for i, entity in pairs(e.entities) do

            --skip the entity if it is a tile ghost
            if entity.type == "tile-ghost" then
                goto continue
            end

            local modules, messages = util.find_modules_to_use_for_entity(entity, active_preset)

            if modules then
                if (i % max_proxies == 0) then
                    delay = delay + 1
                end
                if not storage.to_create[delay] then storage.to_create[delay] = {} end
                storage.to_create[delay][entity.unit_number --[[@as int]]] = {
                    entity = entity,
                    module_config = table.deep_copy(modules),
                    player = player,
                    surface = surface,
                }
            end
            if messages then
                for k, v in pairs(messages) do
                    result_messages[k] = v
                end
            end
            ::continue::
        end
        for _, message in pairs(result_messages) do
            player.print(message)
        end
        conditional_events()
    end)
    if not status then
        debugDump(err, true)
        conditional_events(true)
    end
end

---@param e EventData.on_player_alt_selected_area
local function on_player_alt_selected_area(e)
    local status, err = pcall(function()
        if not e.item == "module-inserter-ex" then return end
        local player = game.players[e.player_index]
        for _, entity in pairs(e.entities) do
            util.create_request_proxy({
                entity = entity,
                module_config = types.make_module_config(),
                player = player,
                surface = entity.surface,
            })
        end
        conditional_events()
    end)
    if not status then
        debugDump(err, true)
        conditional_events(true)
    end
end

---@param e EventData.on_player_reverse_selected_area
local function on_player_reverse_selected_area(e)
    local status, err = pcall(function()
        local player_index = e.player_index
        if e.item ~= "module-inserter-ex" or not player_index then return end

        local player = game.get_player(player_index)
        if not player then return end
        local surface = player.surface
        local delay = e.tick
        local max_proxies = settings.global["module-inserter-ex-proxies-per-tick"].value

        for i, entity in pairs(e.entities) do
            if entity.type == "entity-ghost" then
                entity.insert_plan = {}
            else
                if (i % max_proxies == 0) then
                    delay = delay + 1
                end
                if not storage.to_create[delay] then storage.to_create[delay] = {} end
                storage.to_create[delay][entity.unit_number] = {
                    entity = entity,
                    module_config = types.make_module_config(),
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
    storage.name_to_slot_count = {}
    storage.module_entities = {}
    storage.max_slot_count = 0
    local i = 1
    for name, prototype in pairs(prototypes.entity) do
        if prototype.module_inventory_size and prototype.module_inventory_size > 0 and not se_grounded_entity(name) then
            storage.name_to_slot_count[name] = prototype.module_inventory_size
            storage.max_slot_count = math.max(storage.max_slot_count, prototype.module_inventory_size)
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

    --- @param preset PresetConfig
    local function _clean(preset)
        -- TODO shrink the default config if needed
        --- @param module_config ModuleConfigSet
        local function _clean_module_config(module_config)
            for _, mc in pairs(module_config.configs) do
                for i, m in pairs(mc.module_list) do
                    if m and not items[m.name] then
                        mc.module_list[i] = nil
                        removed_modules[m.name] = true
                    end
            end
            end
        end
        _clean_module_config(preset.default)
        for _, row in pairs(preset.rows) do
            for i, target in pairs(row.target.entities) do
                if target and not entities[target] then
                    removed_entities[target] = true
                    row.target.entities[i] = nil
                end
            end
            _clean_module_config(row.module_configs)
        end
        util.normalize_preset_config(preset)
    end
    for _, pdata in pairs(storage._pdata) do
        _clean(pdata.active_config)
        for _, preset in pairs(pdata.saved_presets) do
            _clean(preset)
        end
    end
    for k in pairs(removed_entities) do
        log("Module Inserter: Removed Entity " .. k .. " from all configurations")
    end
    for k in pairs(removed_modules) do
        log("Module Inserter: Removed module " .. k .. " from all configurations")
    end
end

local function init_global()
    storage.to_create = storage.to_create or {}
    storage.name_to_slot_count = storage.name_to_slot_count or {}
    storage._pdata = storage._pdata or {}
end

local function init_player(i)
    init_global()
    local pdata = storage._pdata[i] or {}
    local active_config = pdata.active_config or types.make_preset_config("Default Config")
    storage._pdata[i] = {
        active_config = active_config,
        saved_presets = pdata.saved_presets or { active_config },
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
    ["7.0.0"] = function ()
        -- Major update breaking compatibility - remove all storage and existing gui
        storage = {}
        for _, player in pairs(game.players) do
            for _, elem in pairs(player.gui.screen.children) do
                if elem.get_mod() == "ModuleInserterEx" then
                    elem.destroy()
                end
            end
            for _, elem in pairs(mod_gui.get_button_flow(player)) do
                if elem.get_mod() == "ModuleInserterEx" then
                    elem.destroy()
                end
            end
        end
    end
}

script.on_configuration_changed(function(e)
    create_lookup_tables()
    remove_invalid_items()
    if migration.on_config_changed(e, migrations) then
        for pi, pdata in pairs(storage._pdata) do
            mi_gui.destroy(pdata, game.get_player(pi) --[[@as LuaPlayer]])
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
    handler(make_event_info(e))
end)

script.on_event(defines.events.on_player_created, function(e)
    init_player(e.player_index)
end)

script.on_event(defines.events.on_player_removed, function(e)
    storage._pdata[e.player_index] = nil
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(e)
    if not e.player_index then return end
    if e.setting == "module-inserter-ex-button-style" or e.setting == "module-inserter-ex-hide-button" then
        mi_gui.update_main_button(game.get_player(e.player_index))
        mi_gui.update_main_frame_buttons(game.get_player(e.player_index))
    end
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    if player.mod_settings["module-inserter-ex-hide-button"].value then return end
    -- Track if they have the module inserter in hand, then when they let go remove it from their inventory
    -- Don't do this if the mod gui button to open the inserter options is disabled
    if player.cursor_stack.valid_for_read and player.cursor_stack.name == "module-inserter-ex" then
        storage._pdata[e.player_index].cursor = true
    elseif storage._pdata[e.player_index].cursor then
        storage._pdata[e.player_index].cursor = false
        local inv = player.get_main_inventory()
        if not inv then return end
        local count = inv.get_item_count("module-inserter-ex")
        if count > 0 then
            inv.remove{name = "module-inserter-ex", count = count}
        end
    end
end)
