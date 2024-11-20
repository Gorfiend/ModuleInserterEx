local START_SIZE = 5
local mod_gui = require("__core__.lualib.mod-gui")
local table = require("__flib__.table")
local gui = require("__flib__.gui")
local import_export = require("scripts.import_export")
local types = require("scripts.types")

local mi_gui = {}
mi_gui.templates = {
    --- @return flib.GuiElemDef
    assembler_button = function(assembler)
        return {
            type = "choose-elem-button",
            name = "assembler",
            style = "slot_button",
            style_mods = { right_margin = 6 },
            handler = { [defines.events.on_gui_elem_changed] = mi_gui.handlers.main.choose_assembler },
            elem_type = "entity",
            elem_filters = { { filter = "name", name = storage.module_entities } },
            entity = assembler,
            tooltip = assembler and prototypes.entity[assembler].localised_name or { "module-inserter-choose-assembler" }
        }
    end,

    --- @param index int
    --- @return flib.GuiElemDef
    module_button = function(index)
        -- TODO This could be filtered based on the current assembler to only valid modules (e.g. hide productivity for beacons)
        return {
            type = "choose-elem-button",
            style = "slot_button",
            name = index,
            handler = { [defines.events.on_gui_elem_changed] = mi_gui.handlers.main.choose_module },
            elem_type = "item-with-quality",
            elem_filters = { { filter = "type", type = "module" } },
        }
    end,

    --- @param slots int
    --- @param name string? Name to give this gui element
    --- @return flib.GuiElemDef
    module_row = function(slots, name)
        local module_table = {
            type = "table",
            column_count = 8,
            name = name or "modules",
            children = {},
            style_mods = {
                margin = 0,
                padding = 0,
                horizontal_spacing = 0,
                vertical_spacing = 0,
            }
        }
        for m = 1, slots do
            module_table.children[m] = mi_gui.templates.module_button(m)
        end
        return module_table
    end,

    --- @param index int config row index for this row
    --- @param config RowConfig?
    --- @return flib.GuiElemDef
    config_row = function(index, config)
        return {
            type = "flow",
            direction = "horizontal",
            name = index,
            style_mods = { horizontal_spacing = 0 },
            children = {
                mi_gui.templates.assembler_button(config and config.from or nil),
            }
        }
    end,

    --- @param n int row count
    --- @param config_tmp PresetConfig
    --- @return flib.GuiElemDef
    config_rows = function(n, config_tmp)
        local config_rows = {}
        for index = 1, n do
            config_rows[index] = mi_gui.templates.config_row(index, config_tmp.rows[index])
        end
        return config_rows
    end,

    --- @return flib.GuiElemDef
    preset_row = function(name, selected)
        return {
            type = "flow",
            direction = "horizontal",
            children = {
                {
                    type = "button",
                    caption = name,
                    style = name == selected and "mi_preset_button_selected" or "mi_preset_button",
                    handler = mi_gui.handlers.preset.load,
                },
                {
                    type = "sprite-button",
                    style = "tool_button",
                    sprite = "utility/export_slot",
                    tooltip = { "module-inserter-export_tt" },
                    handler = mi_gui.handlers.preset.export,
                },
                {
                    type = "sprite-button",
                    style = "tool_button_red",
                    sprite = "utility/trash",
                    handler = mi_gui.handlers.preset.delete,
                },
            }
        }
    end,

    --- @return flib.GuiElemDef
    preset_rows = function(presets, selected)
        local preset_rows = {}
        local i = 1
        for name, _ in pairs(presets) do
            preset_rows[i] = mi_gui.templates.preset_row(name, selected)
            i = i + 1
        end
        return preset_rows
    end,
    pushers = {
        --- @return flib.GuiElemDef
        horizontal = { type = "empty-widget", style_mods = { horizontally_stretchable = true } },
        --- @return flib.GuiElemDef
        vertical = { type = "empty-widget", style_mods = { vertically_stretchable = true } }
    },

    --- @return flib.GuiElemDef
    import_export_window = function(bp_string)
        local caption = bp_string and { "gui.export-to-string" } or { "gui-blueprint-library.import-string" }
        local button_caption = bp_string and { "gui.close" } or { "gui-blueprint-library.import" }
        local button_handler = bp_string and mi_gui.handlers.import.close_button or mi_gui.handlers.import.import_button
        return {
            type = "frame",
            direction = "vertical",
            name = "window",
            children = {
                {
                    type = "flow",
                    name = "titlebar_flow",
                    children = {
                        { type = "label",        style = "frame_title",               caption = caption,                            elem_mods = { ignored_by_interaction = true } },
                        { type = "empty-widget", style = "flib_titlebar_drag_handle", elem_mods = { ignored_by_interaction = true } },
                        {
                            type = "sprite-button",
                            style = "frame_action_button",
                            sprite = "utility/close",
                            hovered_sprite = "utility/close_black",
                            clicked_sprite = "utility/close_black",
                            handler = mi_gui.handlers.import.close_button,
                        }
                    }
                },
                {
                    type = "text-box",
                    text = bp_string,
                    elem_mods = { word_wrap = true },
                    style_mods = { width = 400, height = 250 },
                    name = "textbox",
                },
                {
                    type = "flow",
                    direction = "horizontal",
                    children = {
                        mi_gui.templates.pushers.horizontal,
                        {
                            type = "button",
                            style = "dialog_button",
                            caption = button_caption,
                            handler = button_handler,
                        }
                    }
                }
            }
        }
    end,
}

--- @param player LuaPlayer?
function mi_gui.update_main_button(player)
    if not player then return end
    local button_flow = mod_gui.get_button_flow(player)
    local button = button_flow.module_inserter_config_button
    local visible = not player.mod_settings["module_inserter_hide_button"].value
    local style = player.mod_settings["module_inserter_button_style"].value --[[@as string]]
    if not button or not button.valid then
        gui.add(button_flow, { {
            type = "sprite-button",
            name = "module_inserter_config_button",
            handler = mi_gui.handlers.mod_gui_button.toggle,
            style = style,
            sprite = "technology/modules"
        } })
        button = button_flow.module_inserter_config_button
    end
    button.style = style
    button.visible = visible
end

--- @param player LuaPlayer?
function mi_gui.update_main_frame_buttons(player)
    if not player then return end
    local button = storage._pdata[player.index].gui.main.destroy_tool_button
    button.visible = player.mod_settings["module_inserter_hide_button"].value --[[@as boolean]]
end

function mi_gui.create(player_index)
    local pdata = storage._pdata[player_index]
    local player = game.get_player(player_index)
    if not player or not pdata then return end

    local config_tmp = table.deep_copy(pdata.config)
    pdata.config_tmp = config_tmp

    local config_row_count = math.max(table_size(config_tmp.rows), START_SIZE)
    for index = 1, config_row_count do
        if not config_tmp.rows[index] then
            config_tmp.rows[index] = types.make_row_config()
        end
    end
    local refs = gui.add(player.gui.screen, {
        {
            type = "frame",
            style_mods = { maximal_height = 650 }, ---@diagnostic disable-line: missing-fields
            direction = "vertical",
            handler = { [defines.events.on_gui_closed] = mi_gui.handlers.main.close_window },
            name = "main_window",
            children = {
                {
                    type = "flow",
                    name = "titlebar_flow",
                    children = {
                        {
                            type = "label",
                            style = "frame_title",
                            caption = "Module Inserter",
                            elem_mods = { ignored_by_interaction = true }, ---@diagnostic disable-line: missing-fields
                        },
                        {
                            type = "empty-widget",
                            style = "flib_titlebar_drag_handle",
                            elem_mods = { ignored_by_interaction = true }, ---@diagnostic disable-line: missing-fields
                        },
                        {
                            type = "sprite-button",
                            name = "destroy_tool_button",
                            style = "frame_action_button_red",
                            sprite = "utility/trash",
                            tooltip = { "module-inserter-destroy" },
                            handler = mi_gui.handlers.main.destroy_tool,
                            visible = player.mod_settings["module_inserter_hide_button"].value --[[@as boolean]],
                        },
                        {
                            type = "sprite-button",
                            style = "frame_action_button",
                            tooltip = { "module-inserter-keep-open" },
                            sprite = pdata.pinned and "mi_pin_black" or "mi_pin_white",
                            hovered_sprite = "mi_pin_black",
                            clicked_sprite = "mi_pin_black",
                            name = "pin_button",
                            handler = mi_gui.handlers.main.pin,
                        },
                        {
                            type = "sprite-button",
                            style = "frame_action_button",
                            sprite = "utility/close",
                            hovered_sprite = "utility/close_black",
                            clicked_sprite = "utility/close_black",
                            handler = mi_gui.handlers.main.close,
                        }
                    }
                },
                {
                    type = "flow",
                    direction = "horizontal",
                    style = "inset_frame_container_horizontal_flow",
                    children = {
                        {
                            type = "frame",
                            style = "inside_shallow_frame",
                            direction = "vertical",
                            children = {
                                {
                                    type = "frame",
                                    style = "subheader_frame",
                                    children = {
                                        { type = "label", style = "subheader_caption_label", caption = { "module-inserter-config-frame-title" } },
                                        mi_gui.templates.pushers.horizontal,
                                        {
                                            type = "sprite-button",
                                            style = "tool_button_green",
                                            style_mods = { padding = 0 }, ---@diagnostic disable-line: missing-fields
                                            handler = mi_gui.handlers.main.apply_changes,
                                            sprite = "utility/check_mark_white",
                                            tooltip = { "module-inserter-config-button-apply" }
                                        },
                                        {
                                            type = "sprite-button",
                                            style = "tool_button_red",
                                            sprite = "utility/trash",
                                            tooltip = { "module-inserter-config-button-clear-all" },
                                            handler = mi_gui.handlers.main.clear_all,
                                        },
                                    }
                                },
                                {
                                    type = "flow",
                                    name = "default_flow",
                                    direction = "vertical",
                                    style_mods = { padding = 12 }, ---@diagnostic disable-line: missing-fields
                                    children = {
                                        {
                                            type = "frame",
                                            name = "default_frame",
                                            style = "deep_frame_in_shallow_frame",
                                            style_mods = { horizontally_stretchable = true }, ---@diagnostic disable-line: missing-fields
                                            children = {
                                                {
                                                    type = "flow",
                                                    direction = "horizontal",
                                                    name = "default_row",
                                                    style_mods = { horizontal_spacing = 0, minimal_height = 40, minimal_width = 430, vertical_align = "center" }, ---@diagnostic disable-line: missing-fields
                                                    children = {
                                                        {
                                                            type = "checkbox",
                                                            name = "default_checkbox",
                                                            caption = "Use Default",
                                                            state = false,
                                                            style_mods = { right_margin = 6 }, ---@diagnostic disable-line: missing-fields
                                                            handler = { [defines.events.on_gui_checked_state_changed] = mi_gui.handlers.main.default_checkbox },
                                                            tooltip = "If checked, will fill any entities without a more specific row with the modules here", -- TODO move text string to locale
                                                        },
                                                        mi_gui.templates.module_row(storage.max_slot_count, "default_modules"),
                                                    }
                                                }
                                            }
                                        },
                                    }
                                },
                                {
                                    type = "flow",
                                    direction = "vertical",
                                    style_mods = { padding = 12, top_padding = 8, vertical_spacing = 10 }, ---@diagnostic disable-line: missing-fields
                                    children = {
                                        {
                                            type = "frame",
                                            style = "deep_frame_in_shallow_frame",
                                            style_mods = { horizontally_stretchable = true, minimal_height = 444 }, ---@diagnostic disable-line: missing-fields
                                            children = {
                                                {
                                                    type = "scroll-pane",
                                                    style = "mi_naked_scroll_pane",
                                                    name = "config_rows",
                                                    children = mi_gui.templates.config_rows(START_SIZE, config_tmp)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        {
                            type = "frame",
                            style = "inside_shallow_frame",
                            direction = "vertical",
                            children = {
                                {
                                    type = "frame",
                                    style = "subheader_frame",
                                    children = {
                                        { type = "label", style = "subheader_caption_label", caption = { "module-inserter-storage-frame-title" } },
                                        mi_gui.templates.pushers.horizontal,
                                        {
                                            type = "sprite-button",
                                            style = "tool_button",
                                            sprite = "mi_import_string",
                                            tooltip = { "module-inserter-import_tt" },
                                            handler = mi_gui.handlers.presets.import,
                                        },
                                        {
                                            type = "sprite-button",
                                            style = "tool_button",
                                            sprite = "utility/export_slot",
                                            tooltip = { "module-inserter-export_tt" },
                                            handler = mi_gui.handlers.presets.export,
                                        },
                                    }
                                },
                                {
                                    type = "flow",
                                    direction = "vertical",
                                    style_mods = { width = 246, padding = 12, top_padding = 8, vertical_spacing = 10 }, ---@diagnostic disable-line: missing-fields
                                    children = {
                                        {
                                            type = "flow",
                                            direction = "horizontal",
                                            children = {
                                                {
                                                    type = "textfield",
                                                    text = pdata.last_preset,
                                                    style_mods = { width = 150 }, ---@diagnostic disable-line: missing-fields
                                                    name = "textfield",
                                                    handler = { [defines.events.on_gui_click] = mi_gui.handlers.presets.textfield },
                                                },
                                                mi_gui.templates.pushers.horizontal,
                                                {
                                                    type = "button",
                                                    caption = { "gui-save-game.save" },
                                                    style = "module-inserter-small-button",
                                                    handler = mi_gui.handlers.presets.save,
                                                },
                                            }
                                        },
                                        {
                                            type = "frame",
                                            style = "deep_frame_in_shallow_frame",
                                            children = {
                                                {
                                                    type = "scroll-pane",
                                                    style = "mi_naked_scroll_pane",
                                                    style_mods = { vertically_stretchable = true, minimal_width = 222 }, ---@diagnostic disable-line: missing-fields
                                                    name = "scroll_pane",
                                                    children = mi_gui.templates.preset_rows(pdata.saved_presets,
                                                        pdata.last_preset)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
    })
    pdata.gui.main = {
        window = refs.main_window,
        pin_button = refs.pin_button,
        destroy_tool_button = refs.destroy_tool_button,
        config_rows = refs.config_rows,
        default_checkbox = refs.default_checkbox,
        default_modules = refs.default_modules,
    }
    pdata.gui.presets = {
        textfield = refs.textfield,
        scroll_pane = refs.scroll_pane,
    }

    refs.titlebar_flow.drag_target = refs.main_window
    refs.main_window.force_auto_center()
    mi_gui.update_contents(pdata)
    refs.main_window.visible = false
end

--- @param pdata PlayerConfig
--- @param player LuaPlayer
--- @param bp_string string?
function mi_gui.create_import_window(pdata, player, bp_string)
    local import_gui = pdata.gui.import
    if import_gui and import_gui.window and import_gui.window.valid then
        import_gui.window.destroy()
        pdata.gui.import = nil
    end
    local refs = gui.add(player.gui.screen, { mi_gui.templates.import_export_window(bp_string) })
    pdata.gui.import = {
        window = refs.window,
        textbox = refs.textbox,
    }

    refs.titlebar_flow.drag_target = refs.window
    refs.window.force_auto_center()
    local textbox = refs.textbox
    if bp_string then
        textbox.read_only = true
    end
    textbox.select_all()
    textbox.focus()
end

function mi_gui.shrink_rows(config_rows, c, config_tmp)
    for i = c, START_SIZE + 1, -1 do
        if config_tmp[i] then
            if config_tmp[i - 1].from then
                break
            elseif not config_tmp[i].from and not config_tmp[i - 1].from then
                config_rows.children[i].destroy()
                config_tmp[i] = nil
            end
        else
            if config_rows.children[i] then
                config_rows.children[i].destroy()
            end
        end
    end
end

--- @param config_rows LuaGuiElement
--- @param c int row index
--- @param config_tmp PresetConfig
function mi_gui.extend_rows(config_rows, c, config_tmp)
    if not config_rows.children[c + 1] then
        gui.add(config_rows, { mi_gui.templates.config_row(c + 1) })
        config_tmp.rows[c + 1] = types.make_row_config()
        config_rows.scroll_to_bottom()
    end
end

--- @param module_row LuaGuiElement
--- @param slots int
--- @param modules ModuleConfigSet
function mi_gui.update_modules(module_row, slots, modules)
    local module_btns = table_size(module_row.children)
    slots = slots or 0
    local module_list = modules and modules.configs[1] and modules.configs[1].module_list or {}
    if module_btns < slots then
        for i = module_btns + 1, slots do
            gui.add(module_row, { mi_gui.templates.module_button(i) })
        end
    elseif module_btns > slots then
        for i = slots + 1, module_btns do
            local child = module_row.children[i]
            child.destroy()
        end
    end
    for i = 1, slots do
        local child = module_row.children[i]
        child.elem_value = module_list[i]
        child.tooltip = module_list[i] and prototypes.item[module_list[i].name].localised_name or { "module-inserter-choose-module" }
    end
end

--- @param pdata PlayerConfig
--- @param row_config RowConfig
--- @param index int
function mi_gui.update_row(pdata, row_config, index)
    local assembler = row_config.from

    local config_rows = pdata.gui.main.config_rows
    if not (config_rows and config_rows.valid) then return end
    local row = config_rows.children[index]
    if not row then
        local row_template = mi_gui.templates.config_row(index)
        local _, first = gui.add(config_rows, { row_template })
        row = first
    end
    row.assembler.elem_value = assembler
    row.assembler.tooltip = assembler and prototypes.entity[assembler] and prototypes.entity[assembler].localised_name or { "module-inserter-choose-assembler" }

    if not assembler then
        -- No assembler, delete the module section
        if row.modules then
            row.modules.destroy()
        end
    else
        local slots = storage.name_to_slot_count[row_config.from]
        -- Create and update the module section
        if not row.modules or not row.modules.valid then
            gui.add(row, mi_gui.templates.module_row(slots))
        end
        mi_gui.update_modules(row.modules, slots, row_config.module_configs)
    end
end

--- @param pdata PlayerConfig
--- @param clear boolean?
function mi_gui.update_contents(pdata, clear)
    local config_tmp = pdata.config_tmp

    if clear then
        pdata.gui.main.config_rows.clear()
    end

    pdata.gui.main.default_checkbox.state = config_tmp.use_default
    if config_tmp.use_default then
        pdata.gui.main.default_modules.visible = true
        mi_gui.update_modules(pdata.gui.main.default_modules, storage.max_slot_count, config_tmp.default)
    else
        pdata.gui.main.default_modules.visible = false
    end

    local index = 0
    for _, row_config in pairs(config_tmp.rows) do
        index = index + 1
        mi_gui.update_row(pdata, row_config, index)
    end
    for i = index, math.max(index, START_SIZE) do
        mi_gui.extend_rows(pdata.gui.main.config_rows, i, config_tmp)
    end

    mi_gui.shrink_rows(pdata.gui.main.config_rows, table_size(pdata.gui.main.config_rows.children), config_tmp)
end

--- @param player LuaPlayer
--- @param pdata PlayerConfig
--- @param name string
--- @param config PresetConfig
--- @param textfield LuaGuiElement?
--- @return boolean
function mi_gui.add_preset(player, pdata, name, config, textfield)
    local gui_elements = pdata.gui

    if name == "" then
        player.print({ "module-inserter-storage-name-not-set" })
        return false
    end
    if pdata.saved_presets[name] then
        if not player.mod_settings["module_inserter_overwrite"].value then
            player.print { "module-inserter-storage-name-in-use", name }
            if textfield then
                textfield.select_all()
                textfield.focus()
            end
            return false
        else
            pdata.saved_presets[name] = table.deep_copy(config)
            player.print { "module-inserter-storage-updated", name }
            return true
        end
    end

    pdata.saved_presets[name] = table.deep_copy(config)
    gui.add(gui_elements.presets.scroll_pane, { mi_gui.templates.preset_row(name) })
    return true
end

function mi_gui.update_presets(pdata, selected_preset)
    for _, preset_flow in pairs(pdata.gui.presets.scroll_pane.children) do
        local preset = preset_flow.children[1]
        if preset.caption == selected_preset then
            preset.style = "mi_preset_button_selected"
        else
            preset.style = "mi_preset_button"
        end
    end
end

--- @param pdata PlayerConfig
--- @param player LuaPlayer
function mi_gui.destroy(pdata, player)
    local main_gui = pdata.gui.main
    if main_gui and main_gui.window and main_gui.window.valid then
        main_gui.window.destroy()
    end
    local import_gui = pdata.gui.import
    if import_gui and import_gui.window and import_gui.window.valid then
        import_gui.window.destroy()
    end
    if not pdata.pinned then
        player.opened = nil
    end
    pdata.gui.main = nil
    pdata.gui.presets = nil
    pdata.gui.import = nil
    pdata.gui_open = false
end

--- @param e MiEventInfo
function mi_gui.open(e)
    local window = e.pdata.gui and e.pdata.gui.main and e.pdata.gui.main.window
    if not (window and window.valid) then
        mi_gui.destroy(e.pdata, e.player)
        mi_gui.create(e.event.player_index)
        window = e.pdata.gui.main.window
    end
    window.visible = true
    e.pdata.gui_open = true
    if not e.pdata.pinned then
        e.player.opened = window
    end
end

function mi_gui.close(e)
    local pdata = e.pdata
    if pdata.closing then
        return
    end
    local window = pdata.gui.main.window
    if window and window.valid then
        window.visible = false
    end
    pdata.gui_open = false
    if e.player.opened == window then
        pdata.closing = true
        e.player.opened = nil
        pdata.closing = nil
    end
end

--- @param e MiEventInfo
function mi_gui.toggle(e)
    if e.pdata.gui_open then
        mi_gui.close(e)
    else
        mi_gui.destroy(e.pdata, e.player)
        mi_gui.open(e)
    end
end

mi_gui.handlers = {
    mod_gui_button = {
        toggle = mi_gui.toggle
    },
    main = {
        --- @param e MiEventInfo
        apply_changes = function(e, keep_open)
            e.pdata.config = table.deep_copy(e.pdata.config_tmp)
            --- @type ConfigByEntity
            e.pdata.config_by_entity = {}
            for _, config in pairs(e.pdata.config.rows) do
                if config.from then
                    e.pdata.config_by_entity[config.from] = table.deep_copy(config.module_configs)
                end
            end
            --log(serpent.block(e.pdata.config_by_entity))
            if not keep_open then
                mi_gui.close(e)
            end
        end,
        --- @param e MiEventInfo
        default_checkbox = function(e)
            e.pdata.config_tmp.use_default = e.pdata.gui.main.default_checkbox.state
            mi_gui.update_contents(e.pdata)
        end,
        --- @param e MiEventInfo
        clear_all = function(e)
            local tmp = types.make_preset_config()
            for i = 1, START_SIZE do
                tmp.rows[i] = types.make_row_config()
            end
            e.pdata.config_tmp = tmp
            mi_gui.update_contents(e.pdata)
        end,
        --- @param e MiEventInfo
        close_window = function(e)
            mi_gui.handlers.main.apply_changes(e, true)
            if not e.pdata.pinned then
                mi_gui.close(e)
            end
        end,
        --- @param e MiEventInfo
        close = function(e)
            mi_gui.close(e)
        end,
        --- @param e MiEventInfo
        pin = function(e)
            local pdata = e.pdata
            local pin = pdata.gui.main.pin_button
            if pdata.pinned then
                pin.sprite = "mi_pin_white"
                pin.style = "frame_action_button"
                pdata.pinned = false
                pdata.gui.main.window.force_auto_center()
                e.player.opened = pdata.gui.main.window
            else
                pin.sprite = "mi_pin_black"
                pin.style = "flib_selected_frame_action_button"
                pdata.pinned = true
                pdata.gui.main.window.auto_center = false
                e.player.opened = nil
            end
        end,
        --- @param e MiEventInfo
        choose_assembler = function(e)
            local pdata = e.pdata
            local config_tmp = pdata.config_tmp
            local config_rows = pdata.gui.main.config_rows
            if not (config_rows and config_rows.valid) then return end
            local index = tonumber(e.event.element.parent.name)
            if not index then return end
            local element = e.event.element
            if not element then return end
            local elem_value = element.elem_value

            if elem_value == config_tmp.rows[index].from then
                return
            end

            if elem_value then
                for k, v in pairs(config_tmp.rows) do
                    if v.from and k ~= index and v.from == elem_value then
                        e.event.element.elem_value = nil
                        e.player.print({ "", prototypes.entity[elem_value].localised_name,
                            " is already configured in row ", k })
                        return
                    end
                end
            end

            local c = table_size(config_tmp.rows)

            if not elem_value then
                config_tmp.rows[index] = types.make_row_config()
                mi_gui.shrink_rows(config_rows, c, config_tmp)
            else
                config_tmp.rows[index].from = elem_value --[[@as string]]
            end

            mi_gui.update_row(e.pdata, config_tmp.rows[index], index)
            if index == c then
                mi_gui.extend_rows(config_rows, c, config_tmp)
            end
        end,

        --- @param e MiEventInfo
        choose_module = function(e)
            local element = e.event.element
            if not element then return end
            local config_tmp = e.pdata.config_tmp
            if not config_tmp then return end
            local config_rows = e.pdata.gui.main.config_rows
            if not (config_rows and config_rows.valid) then return end
            local slot = tonumber(element.name)
            if not slot then return end

            --- @type ModuleConfigSet
            local module_config_set
            local entity_proto = nil
            local index = nil
            local row_config = nil
            if element.parent.parent.name == "default_row" then
                module_config_set = config_tmp.default
            else
                index = tonumber(element.parent.parent.name)
                if not index then return end
                row_config = config_tmp.rows[index]
                module_config_set = row_config.module_configs -- TODO when implementing multiple module configs per row, need to update this
                entity_proto = row_config.from and prototypes.entity[row_config.from]
                if not entity_proto then return end
            end

            local module_config = module_config_set.configs[1]
            module_config.module_list[slot] = element.elem_value --[[@as ItemIDAndQualityIDPair]]
            if element.elem_value and row_config and row_config.from then
                -- If a normal row with an assembler selected, check if the module is valid
                local proto = prototypes.item[element.elem_value]
                local success = true
                if proto then
                    local itemEffects = proto.module_effects
                    if entity_proto and itemEffects then
                        for name, effect in pairs(itemEffects) do
                            if effect > 0 and not entity_proto.allowed_effects[name] then
                                success = false
                                e.player.print({ "inventory-restriction.cant-insert-module", proto.localised_name,
                                    entity_proto.localised_name })
                                    module_config[slot] = nil
                                element.elem_value = nil
                                break
                            end
                        end
                    end
                    if success then
                        module_config[slot] = proto.name
                    end
                end
            end
            local slot_count = entity_proto and entity_proto.module_inventory_size or storage.max_slot_count
            if slot == 1 and e.player.mod_settings["module_inserter_fill_all"].value then
                for i = 2, slot_count do
                    module_config.module_list[i] = module_config.module_list[slot]
                end
            end
            if index then
                mi_gui.update_modules(config_rows.children[index].modules, slot_count, module_config_set)
            else
                mi_gui.update_modules(e.pdata.gui.main.default_modules, slot_count, module_config_set)
            end
        end,
        --- @param e MiEventInfo
        destroy_tool = function(e)
            e.player.get_main_inventory().remove { name = "module-inserter", count = 1 }
            mi_gui.close(e)
        end
    },
    presets = {
        --- @param e MiEventInfo
        save = function(e)
            local textfield = e.pdata.gui.presets.textfield
            local name = textfield.text
            if mi_gui.add_preset(e.player, e.pdata, name, e.pdata.config_tmp, textfield) then
                mi_gui.update_presets(e.pdata, name)
            end
        end,
        --- @param e MiEventInfo
        textfield = function(e)
            e.event.element.select_all()
            e.event.element.focus()
        end,
        --- @param e MiEventInfo
        import = function(e)
            local stack = e.player.cursor_stack
            if stack and stack.valid and stack.valid_for_read and (stack.type == "blueprint" or stack.type == "blueprint-book") then
                local player = e.player
                local pdata = e.pdata
                local result, config, name = import_export.import_config(player, stack.export_stack())
                if not result then return end
                if result ~= 0 then
                    player.print({ "failed-to-import-string", name })
                    return
                end
                if name then
                    mi_gui.add_preset(player, pdata, name, config)
                else
                    for sname, data in pairs(config) do
                        mi_gui.add_preset(player, pdata, sname, data)
                    end
                end
            else
                mi_gui.create_import_window(e.pdata, e.player)
            end
        end,
        --- @param e MiEventInfo
        export = function(e)
            local text = import_export.export_config(e.player, e.pdata.saved_presets)
            if not text then return end
            if e.event.shift then
                local stack = e.player.cursor_stack
                if not stack then return end
                if stack.valid_for_read then
                    e.player.print("Click with an empty cursor")
                    return
                else
                    if not stack.set_stack { name = "blueprint", count = 1 } then
                        e.player.print({ "", { "error-while-importing-string" }, " Could not set stack" })
                        return
                    end
                    stack.import_stack(text)
                end
            else
                mi_gui.create_import_window(e.pdata, e.player, text)
            end
        end
    },
    preset = {
        --- @param e MiEventInfo
        load = function(e)
            local name = e.event.element.caption --[[@as string]]
            local pdata = e.pdata
            local gui_elements = pdata.gui

            local preset = pdata.saved_presets[name]
            if not preset then return end

            pdata.config_tmp = table.deep_copy(preset)
            -- Normalize the table, filing in any lower indexes
            -- Normally not needed, but in case of a bad blueprint import or something
            local max_index = START_SIZE
            for k, _ in pairs(pdata.config_tmp) do
                max_index = math.max(max_index, k)
            end
            for i = 1, max_index do
                if not pdata.config_tmp.rows[i] then
                    pdata.config_tmp.rows[i] = types.make_row_config()
                end
            end
            pdata.config = table.deep_copy(pdata.config_tmp)

            --TODO save the last loaded/saved preset somewhere to fill the textfield
            gui_elements.presets.textfield.text = name or ""

            local keep_open = not e.player.mod_settings["module_inserter_close_after_load"].value
            mi_gui.update_contents(pdata, true)
            mi_gui.update_presets(pdata, name)

            mi_gui.handlers.main.apply_changes(e, keep_open)
            pdata.last_preset = name
            --mi_gui.close(player, pdata)
            e.player.print { "module-inserter-storage-loaded", name }
        end,
        --- @param e MiEventInfo
        export = function(e)
            local pdata = e.pdata
            local name = e.event.element.parent.children[1].caption
            local config = pdata.saved_presets[name]
            if not config or not name or name == "" then
                e.player.print("Preset " .. name .. "not found")
                return
            end

            local text = import_export.export_config(e.player, config, name)
            if not text then return end
            if e.event.shift then
                local stack = e.player.cursor_stack
                if not stack then return end
                if stack.valid_for_read then
                    e.player.print("Click with an empty cursor")
                    return
                else
                    if not stack.set_stack { name = "blueprint", count = 1 } then
                        e.player.print({ "", { "error-while-importing-string" }, " Could not set stack" })
                        return
                    end
                    stack.import_stack(text)
                end
            else
                mi_gui.create_import_window(pdata, e.player, text)
            end
        end,
        --- @param e MiEventInfo
        delete = function(e)
            local name = e.event.element.parent.children[1].caption --[[@as string]]
            local pdata = e.pdata
            local parent = e.event.element.parent --[[@as LuaGuiElement]]
            pdata.saved_presets[name] = nil
            parent.destroy()
        end
    },
    import = {
        --- @param e MiEventInfo
        import_button = function(e)
            local player = e.player
            local pdata = e.pdata
            local text_box = pdata.gui.import.textbox
            local result, config, name = import_export.import_config(player, text_box.text)
            if not result then return end
            if result ~= 0 then
                player.print({ "failed-to-import-string", name })
                return
            end
            if name then
                mi_gui.add_preset(player, pdata, name, config)
            else
                for sname, data in pairs(config) do
                    mi_gui.add_preset(player, pdata, sname, data)
                end
            end
            mi_gui.handlers.import.close_button(e)
        end,
        --- @param e MiEventInfo
        close_button = function(e)
            local window = e.pdata.gui.import.window
            window.destroy()
            e.pdata.gui.import = nil
        end
    },
}

return mi_gui
