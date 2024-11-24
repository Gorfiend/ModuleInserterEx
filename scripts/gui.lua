local table = require("__flib__.table")
local gui = require("__flib__.gui")

local import_export = require("scripts.import-export")
local types = require("scripts.types")
local util = require("scripts.util")

local TARGET_SECTION_WIDTH = 170
local PRESET_BUTTON_FIELD_WIDTH = 200

local mi_gui = {}
mi_gui.templates = {
    --- @param row_index int
    --- @param index int
    --- @return flib.GuiElemDef
    assembler_button = function(row_index, index)
        return {
            type = "choose-elem-button",
            name = index,
            style = "slot_button",
            handler = { [defines.events.on_gui_elem_changed] = mi_gui.handlers.main.choose_assembler },
            elem_type = "entity",
            elem_filters = { { filter = "name", name = storage.module_entities } },
            tooltip = { "module-inserter-ex-choose-assembler" },
            --- @type TargetButtonTags
            tags = {
                row_index = row_index,
                slot_index = index,
            }
        }
    end,

    --- @param module_row_tags ModuleRowTags
    --- @param slot_index int
    --- @return flib.GuiElemDef
    module_button = function(module_row_tags, slot_index)
        -- TODO This could be filtered based on the current assembler to only valid modules (e.g. hide productivity for beacons)
        return {
            type = "choose-elem-button",
            style = "slot_button",
            name = "module_button_" .. slot_index,
            handler = { [defines.events.on_gui_elem_changed] = mi_gui.handlers.main.choose_module },
            elem_type = "item-with-quality",
            elem_filters = { { filter = "type", type = "module" } },
            --- @type ModuleButtonTags
            tags = {
                row_index = module_row_tags.row_index,
                module_row_index = module_row_tags.module_row_index,
                slot_index = slot_index,
            }
        }
    end,

    --- @param row_index int
    --- @param module_row_index int
    --- @param slots int
    --- @return flib.GuiElemDef
    module_row = function(row_index, module_row_index, slots)
        --- @type ModuleRowTags
        local module_row_tags = {
            row_index = row_index,
            module_row_index = module_row_index,
        }
        local module_table = {
            type = "table",
            name = "module_row_table_" .. module_row_index,
            column_count = 8,
            tags = module_row_tags,
            style = "slot_table",
            children = {},
        }
        for m = 1, slots do
            module_table.children[m] = mi_gui.templates.module_button(module_row_tags, m)
        end
        local row_frame = {
            type = "frame",
            name = "module_row_frame_" .. module_row_index,
            style = "slot_button_deep_frame",
            tags = module_row_tags,
            children = {
                module_table,
                {
                    type = "sprite-button",
                    name = "delete_module_row_button",
                    tooltip = { "module-inserter-ex-delete-module-set" },
                    sprite = "utility/trash",
                    style = "tool_button_red",
                    style_mods = { margin = 6, },
                    handler = mi_gui.handlers.main.delete_module_row,
                },
                {
                    type = "sprite-button",
                    name = "add_module_row_button",
                    tooltip = { "module-inserter-ex-add-module-set" },
                    sprite = "utility/add",
                    style = "tool_button",
                    style_mods = { margin = 6, },
                    handler = mi_gui.handlers.main.add_module_row,
                },
            },
        }
        return row_frame
    end,

    --- @param name string Name to give this gui element
    --- @return flib.GuiElemDef
    module_set = function(name)
        return {
            type = "flow",
            name = name or "module_set",
            direction = "vertical",
            style_mods = { horizontally_stretchable = true },
            children = {},
        }
    end,

    --- @param row_index int
    --- @return flib.GuiElemDef
    target_section = function(row_index)
        return {
            type = "frame",
            name = "target_frame",
            style = "slot_button_deep_frame",
            style_mods = {
                horizontally_stretchable = false,
            },
            --- @type TargetFrameTags
            tags = {
                row_index = row_index,
            },
            children = {
                {
                    type = "table",
                    column_count = 4,
                    name = "target_section",
                    style = "filter_slot_table",
                    --- @type TargetFrameTags
                    tags = {
                        row_index = row_index,
                    },
                    children = {
                        mi_gui.templates.assembler_button(row_index, 1),
                    },
                }
            }
        }
    end,

    --- @param index int config row index for this row
    --- @return flib.GuiElemDef
    config_row = function(index)
        return {
            type = "frame",
            name = index,
            style = "flib_shallow_frame_in_shallow_frame",
            children = {
                mi_gui.templates.target_section(index),
                { type = "empty-widget", style_mods = { width = 6 } },
                mi_gui.templates.module_set("module_set"),
            }
        }
    end,

    --- @param index int preset index for this row
    --- @return flib.GuiElemDef
    preset_row = function(index)
        return {
            type = "flow",
            direction = "horizontal",
            name = "preset_row_" .. index,
            --- @type PresetRowTags
            tags = {
                preset_index = index,
            },
            children = {
                {
                    type = "button",
                    name = "select_button",
                    style_mods = { width = PRESET_BUTTON_FIELD_WIDTH },
                    handler = mi_gui.handlers.preset.load,
                },
                {
                    type = "sprite-button",
                    name = "rename_button",
                    style = "tool_button",
                    sprite = "utility/rename_icon",
                    tooltip = { "module-inserter-ex-rename-preset" },
                    handler = mi_gui.handlers.preset.rename,
                },
                {
                    type = "textfield",
                    name = "rename_textfield",
                    icon_selector = true,
                    visible = false,
                    style_mods = { width = PRESET_BUTTON_FIELD_WIDTH },
                    handler = { [defines.events.on_gui_confirmed] = mi_gui.handlers.preset.rename, }
                },
                {
                    type = "sprite-button",
                    name = "rename_confirm_button",
                    style = "item_and_count_select_confirm",
                    sprite = "utility/enter",
                    tooltip = { "module-inserter-ex-confirm-rename-preset" },
                    visible = false,
                    handler = mi_gui.handlers.preset.rename,
                },
                {
                    type = "sprite-button",
                    name = "export_button",
                    style = "tool_button",
                    sprite = "utility/export_slot",
                    tooltip = { "module-inserter-ex-export-single" },
                    handler = mi_gui.handlers.preset.export,
                },
                {
                    type = "sprite-button",
                    name = "delete_button",
                    style = "tool_button_red",
                    sprite = "utility/trash",
                    tooltip = { "module-inserter-ex-delete-preset" },
                    handler = mi_gui.handlers.preset.delete,
                },
            }
        }
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
                    drag_target = "window",
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

function mi_gui.create(player_index)
    local pdata = storage._pdata[player_index]
    local player = game.get_player(player_index)
    if not player or not pdata then return end

    local refs = gui.add(player.gui.screen, {
        type = "frame",
        style_mods = { height = 750 }, ---@diagnostic disable-line: missing-fields
        direction = "vertical",
        handler = { [defines.events.on_gui_closed] = mi_gui.handlers.main.close_window },
        name = "main_window",
        children = {
            {
                type = "flow",
                name = "titlebar_flow",
                drag_target = "main_window",
                children = {
                    {
                        type = "label",
                        style = "frame_title",
                        caption = { "module-inserter-ex-config-window-title" },
                        elem_mods = { ignored_by_interaction = true }, ---@diagnostic disable-line: missing-fields
                    },
                    {
                        type = "empty-widget",
                        style = "flib_titlebar_drag_handle",
                        elem_mods = { ignored_by_interaction = true }, ---@diagnostic disable-line: missing-fields
                    },
                    {
                        type = "sprite-button",
                        name = "pin_button",
                        style = "frame_action_button",
                        tooltip = { "module-inserter-ex-keep-open" },
                        toggled = pdata.pinned,
                        sprite = "flib_pin_white",
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
                                    { type = "label", style = "subheader_caption_label", caption = { "module-inserter-ex-config-frame-title" } },
                                    mi_gui.templates.pushers.horizontal,
                                    {
                                        type = "sprite-button",
                                        style = "tool_button_red",
                                        sprite = "utility/trash",
                                        tooltip = { "module-inserter-ex-config-button-clear-all" },
                                        handler = mi_gui.handlers.main.clear_all,
                                    },
                                }
                            },
                            {
                                type = "frame",
                                style = "repeated_subheader_frame",
                                children = {
                                    {
                                        type = "label",
                                        style_mods = { minimal_width = TARGET_SECTION_WIDTH, horizontal_align = "center", }, ---@diagnostic disable-line: missing-fields
                                        caption = { "", "module-inserter-ex-target-entities", " [img=info]" },
                                        tooltip = { "module-inserter-ex-target-entities-tooltip" },
                                    },
                                    mi_gui.templates.pushers.horizontal,
                                    {
                                        type = "label",
                                        caption = { "", "module-inserter-ex-module-specification", " [img=info]" },
                                        tooltip = { "module-inserter-ex-module-specification-tooltip" },
                                    },
                                    mi_gui.templates.pushers.horizontal,
                                }
                            },
                            {
                                type = "scroll-pane",
                                name = "main_scroll",
                                style = "flib_naked_scroll_pane_no_padding",
                                style_mods = { minimal_width = 610, }, ---@diagnostic disable-line: missing-fields
                                vertical_scroll_policy = "always",
                                children = {
                                    {
                                        type = "frame",
                                        style = "inside_shallow_frame_with_padding",
                                        direction = "vertical",
                                        children = {
                                            {
                                                type = "frame",
                                                name = "default_frame",
                                                style = "flib_shallow_frame_in_shallow_frame",
                                                children = {
                                                    {
                                                        type = "flow",
                                                        style_mods = { minimal_width = TARGET_SECTION_WIDTH, horizontally_stretchable = false, }, ---@diagnostic disable-line: missing-fields
                                                        children = {
                                                            type = "checkbox",
                                                            name = "default_checkbox",
                                                            caption = { "module-inserter-ex-default-modules" },
                                                            state = false,
                                                            style_mods = {
                                                                margin = 6,
                                                                horizontally_stretchable = true,
                                                            },
                                                            handler = { [defines.events.on_gui_checked_state_changed] = mi_gui.handlers.main.default_checkbox },
                                                            tooltip =  { "module-inserter-ex-default-modules-tooltip" },
                                                        }
                                                    },
                                                    mi_gui.templates.module_set("default_module_set"),
                                                },
                                            },
                                            {
                                                type = "flow",
                                                name = "config_rows",
                                                direction = "vertical",
                                                style_mods = { top_padding = 12, vertical_spacing = 6, }, ---@diagnostic disable-line: missing-fields
                                            },
                                        },
                                    },
                                }
                            },
                        }
                    },
                    {
                        type = "frame",
                        name = "preset_frame",
                        style = "inside_shallow_frame",
                        direction = "vertical",
                        children = {
                            {
                                type = "frame",
                                name = "preset_header",
                                style = "subheader_frame",
                                children = {
                                    {
                                        type = "label",
                                        style = "subheader_caption_label",
                                        caption = { "module-inserter-ex-storage-frame-title" }
                                    },
                                    mi_gui.templates.pushers.horizontal,
                                    {
                                        type = "sprite-button",
                                        name = "import_preset_button",
                                        style = "tool_button",
                                        sprite = "utility/import",
                                        tooltip = { "module-inserter-ex-import" },
                                        handler = mi_gui.handlers.presets.import,
                                    },
                                    {
                                        type = "sprite-button",
                                        name = "export_all_presets_button",
                                        style = "tool_button",
                                        sprite = "utility/export_slot",
                                        tooltip = { "module-inserter-ex-export-all" },
                                        handler = mi_gui.handlers.presets.export,
                                    },
                                },
                            },
                            {
                                type = "flow",
                                direction = "vertical",
                                children = {
                                    {
                                        type = "scroll-pane",
                                        style = "flib_naked_scroll_pane_no_padding",
                                        name = "preset_pane",
                                        style_mods = { vertically_stretchable = true }, ---@diagnostic disable-line: missing-fields
                                    },
                                },
                            },
                            {
                                type = "button",
                                name = "add_preset_button",
                                caption = { "module-inserter-ex-add-preset" },
                                tooltip = { "module-inserter-ex-add-preset-tooltip" },
                                style_mods = { horizontally_stretchable = true, }, ---@diagnostic disable-line: missing-fields
                                handler = mi_gui.handlers.presets.add
                            },
                        }
                    }
                }
            }
        }
    })
    pdata.gui.main = {
        window = refs.main_window,
        pin_button = refs.pin_button,
        scroll = refs.main_scroll,
        config_rows = refs.config_rows,
        default_checkbox = refs.default_checkbox,
        default_module_set = refs.default_module_set,
    }
    pdata.gui.presets = {
        preset_pane = refs.preset_pane,
    }

    refs.main_window.force_auto_center()
    mi_gui.update_presets(pdata)
    mi_gui.update_contents(player, pdata)
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

    refs.window.force_auto_center()
    local textbox = refs.textbox
    if bp_string then
        textbox.read_only = true
    end
    textbox.select_all()
    textbox.focus()
end

--- @param player LuaPlayer
--- @param gui_config_rows LuaGuiElement
--- @param config_tmp PresetConfig
function mi_gui.update_rows(player, gui_config_rows, config_tmp)
    -- Add or destroy rows as needed
    while #gui_config_rows.children < #config_tmp.rows do
        gui.add(gui_config_rows, { mi_gui.templates.config_row(#gui_config_rows.children + 1) })
    end
    while #gui_config_rows.children > #config_tmp.rows do
        gui_config_rows.children[#gui_config_rows.children].destroy()
    end

    for index, row_config in ipairs(config_tmp.rows) do
        mi_gui.update_row(player, gui_config_rows, row_config, index)
    end
end

--- @param player LuaPlayer
--- @param gui_module_row LuaGuiElement
--- @param slots int
--- @param config_set ModuleConfigSet
--- @param index int index of this module row in the set
function mi_gui.update_modules(player, gui_module_row, slots, config_set, index)
    local module_config = config_set.configs[index]
    gui_module_row.add_module_row_button.visible = (index == #config_set.configs)
    gui_module_row.delete_module_row_button.enabled = #config_set.configs > 1
    local button_table = gui_module_row.children[1]
    slots = slots or 0
    local module_list = module_config.module_list or {}
    --- @type ModuleRowTags
    local module_row_tags = gui_module_row.tags

    -- Add or destroy buttons as needed
    while #button_table.children < slots do
        gui.add(button_table, { mi_gui.templates.module_button(module_row_tags, #button_table.children + 1) })
    end
    while #button_table.children > slots do
        button_table.children[#button_table.children].destroy()
    end

    for i = 1, slots do
        local child = button_table.children[i]
        child.elem_value = module_list[i]
        local tooltip = module_list[i] and prototypes.item[module_list[i].name].localised_name or { "module-inserter-ex-choose-module" }
        if i == 1 and player.mod_settings["module-inserter-ex-fill-all"].value then
            tooltip = { "", tooltip, { "module-inserter-ex-choose-module-fill-all-tooltip" } }
        end
        child.tooltip = tooltip
    end
end

--- @param player LuaPlayer
--- @param row_index int index of the row being updated (0 for the default config)
--- @param module_set LuaGuiElement
--- @param slots int
--- @param config_set ModuleConfigSet
function mi_gui.update_module_set(player, row_index, module_set, slots, config_set)
    for i, config_row in ipairs(config_set.configs) do
        local module_row = module_set.children[i]
        if not module_row then
            gui.add(module_set, mi_gui.templates.module_row(row_index, i, slots))
        end
        module_row = module_set.children[i]
        mi_gui.update_modules(player, module_row, slots, config_set, i)
    end

    while #module_set.children > #config_set.configs do
        module_set.children[#module_set.children].destroy()
    end
end

--- @param gui_target_table LuaGuiElement
--- @param target_config TargetConfig
function mi_gui.update_target_section(gui_target_table, target_config)
    local target_button_count = #target_config.entities + 1
    -- Add or destroy buttons as needed
    while #gui_target_table.children < target_button_count do
        --- @type TargetFrameTags
        local tags = gui_target_table.tags
        gui.add(gui_target_table, { mi_gui.templates.assembler_button(tags.row_index, #gui_target_table.children + 1) })
    end
    while #gui_target_table.children > target_button_count do
        gui_target_table.children[#gui_target_table.children].destroy()
    end

    for i = 1, target_button_count do
        local child = gui_target_table.children[i]
        local target = target_config.entities[i]
        child.elem_value = target
        child.tooltip = util.get_localised_entity_name(target, { "module-inserter-ex-choose-assembler" })
    end
end

--- @param player LuaPlayer
--- @param gui_config_rows LuaGuiElement
--- @param row_config RowConfig
--- @param row_index int index of the row config being updated
function mi_gui.update_row(player, gui_config_rows, row_config, row_index)
    if not (gui_config_rows and gui_config_rows.valid) then return end
    local row = gui_config_rows.children[row_index]
    if not row then
        local row_template = mi_gui.templates.config_row(row_index)
        local _, first = gui.add(gui_config_rows, { row_template })
        row = first
    end

    mi_gui.update_target_section(row.target_frame.target_section, row_config.target)

    if not util.target_config_has_entries(row_config.target) then
        -- No assembler, delete the module section
        for _, elem in pairs(row.module_set.children) do
            elem.destroy()
        end
    else
        local slots = util.get_target_config_max_slots(row_config.target)
        -- Update the module section
        mi_gui.update_module_set(player, row_index, row.module_set, slots, row_config.module_configs)
    end
end

--- @param player LuaPlayer
--- @param pdata PlayerConfig
function mi_gui.update_contents(player, pdata)
    local active_config = pdata.active_config

    pdata.gui.main.default_checkbox.state = active_config.use_default
    if active_config.use_default then
        pdata.gui.main.default_module_set.visible = true
        mi_gui.update_module_set(player, 0, pdata.gui.main.default_module_set, storage.max_slot_count, active_config.default)
    else
        pdata.gui.main.default_module_set.visible = false
    end

    mi_gui.update_rows(player, pdata.gui.main.config_rows, active_config)
end

--- @param player LuaPlayer
--- @param pdata PlayerConfig
--- @param select boolean? Whether to select the new preset
--- @param data PresetConfig? data to restore
--- @return boolean
function mi_gui.add_preset(player, pdata, select, data)
    local new_preset = data or types.make_preset_config(util.generate_random_name())
    table.insert(pdata.saved_presets, new_preset)
    if select then
        pdata.active_config = new_preset
        mi_gui.update_contents(player, pdata)
    end
    mi_gui.update_presets(pdata)
    return true
end

--- @param pdata PlayerConfig
function mi_gui.update_presets(pdata)
    local preset_pane = pdata.gui.presets.preset_pane
    while #preset_pane.children > #pdata.saved_presets do
        preset_pane.children[#preset_pane.children].destroy()
    end
    while #preset_pane.children < #pdata.saved_presets do
        gui.add(preset_pane, { mi_gui.templates.preset_row(#preset_pane.children + 1) })
    end
    for i, preset_flow in ipairs(preset_pane.children) do
        local preset_button = preset_flow.select_button
        local this_preset = pdata.saved_presets[i]
        preset_button.caption = this_preset.name
        if pdata.naming == this_preset then
            preset_flow.rename_textfield.visible = true
            preset_flow.rename_confirm_button.visible = true
            preset_button.visible = false
            preset_flow.rename_button.visible = false
        else
            preset_flow.rename_textfield.visible = false
            preset_flow.rename_confirm_button.visible = false
            preset_button.visible = true
            preset_flow.rename_button.visible = true
            preset_button.toggled = (this_preset == pdata.active_config)
        end
        -- Don't allow deleting the final preset
        preset_flow.delete_button.enabled = (#pdata.saved_presets > 1)
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
    if not e.pdata.pinned then
        e.player.opened = window
    end
end

--- @param e MiEventInfo
function mi_gui.close(e)
    local pdata = e.pdata
    if pdata.closing then
        return
    end
    local window = pdata.gui.main.window
    if window and window.valid then
        window.visible = false
    end
    pdata.naming = nil
    mi_gui.update_presets(pdata)
    if e.player.opened == window then
        pdata.closing = true
        e.player.opened = nil
        pdata.closing = nil
    end
end

--- @param e MiEventInfo
function mi_gui.toggle(e)
    local window = e.pdata.gui.main.window
    if window and window.valid and window.visible then
        mi_gui.close(e)
    else
        mi_gui.open(e)
    end
end

mi_gui.handlers = {
    main = {
        --- @param e MiEventInfo
        default_checkbox = function(e)
            e.pdata.active_config.use_default = e.pdata.gui.main.default_checkbox.state
            mi_gui.update_contents(e.player, e.pdata)
        end,
        --- @param e MiEventInfo
        clear_all = function(e)
            e.pdata.active_config.default = types.make_module_config_set()
            e.pdata.active_config.rows = { types.make_row_config() }
            mi_gui.update_contents(e.player, e.pdata)
        end,
        --- @param e MiEventInfo
        close_window = function(e)
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
            pdata.pinned = not pdata.pinned
            pin.toggled = pdata.pinned
            if pdata.pinned then
                pdata.gui.main.window.auto_center = false
                e.player.opened = nil
            else
                pdata.gui.main.window.force_auto_center()
                e.player.opened = pdata.gui.main.window
            end
        end,
        --- @param e MiEventInfo
        choose_assembler = function(e)
            local pdata = e.pdata
            local active_config = pdata.active_config
            local config_rows = pdata.gui.main.config_rows
            if not (config_rows and config_rows.valid) then return end
            local element = e.event.element
            if not element then return end
            local elem_value = element.elem_value

            --- @type TargetButtonTags
            local tags = e.event.element.tags

            local row_config = active_config.rows[tags.row_index]
            local old_value = row_config.target.entities[tags.slot_index]
            if elem_value == old_value then
                return
            end

            if elem_value then
                for k, row in pairs(active_config.rows) do
                    for _, target in pairs(row.target.entities) do
                        if target and target == elem_value then
                            element.elem_value = old_value
                            if k == tags.row_index then
                                e.player.print({ "module-inserter-ex-already-configured-in-this-row", prototypes.entity[elem_value].localised_name })
                            else
                                e.player.print({ "module-inserter-ex-already-configured-in-another-row", prototypes.entity[elem_value].localised_name, k })
                            end
                            return
                        end
                    end
                end
                local valid, error = util.entity_valid_for_module_set(elem_value --[[@as string]], row_config.module_configs)
                if not valid then
                    element.elem_value = old_value
                    e.player.print(error)
                    return
                end
            end


            if elem_value then
                row_config.target.entities[tags.slot_index] = elem_value --[[@as string]]
            else
                table.remove(row_config.target.entities, tags.slot_index)
            end

            local do_scroll = elem_value and tags.row_index == #active_config.rows

            util.normalize_preset_config(active_config)

            mi_gui.update_rows(e.player, e.pdata.gui.main.config_rows, active_config)
            if do_scroll then
                e.pdata.gui.main.scroll.scroll_to_bottom()
            end
        end,

        --- @param e MiEventInfo
        choose_module = function(e)
            local element = e.event.element
            if not element then return end
            local active_config = e.pdata.active_config
            if not active_config then return end
            local config_rows = e.pdata.gui.main.config_rows
            if not (config_rows and config_rows.valid) then return end

            --- @type ModuleConfigSet
            local module_config_set
            --- @type TargetConfig
            local target_config
            --- @type ModuleButtonTags
            local module_button_tags = element.tags
            local slot = module_button_tags.slot_index
            local is_default_config = (module_button_tags.row_index == 0)
            local row_config = nil
            local slot_count
            if is_default_config then
                module_config_set = active_config.default
                slot_count = storage.max_slot_count
            else
                row_config = active_config.rows[module_button_tags.row_index]
                module_config_set = row_config.module_configs
                target_config = row_config.target
                slot_count = util.get_target_config_max_slots(row_config.target)
            end

            local module_config = module_config_set.configs[module_button_tags.module_row_index]
            if element.elem_value and target_config then
                -- If a normal row with assembler targets selected, check if the module is valid
                local valid, error = util.module_valid_for_config(element.elem_value.name, target_config)
                if not valid then
                    e.player.print(error)
                    element.elem_value = module_config.module_list[slot]
                    return
                end
            end
            module_config.module_list[slot] = util.normalize_id_quality_pair(element.elem_value --[[@as ItemIDAndQualityIDPair]])

            if slot == 1 and e.player.mod_settings["module-inserter-ex-fill-all"].value then
                for i = 2, slot_count do
                    module_config.module_list[i] = module_config.module_list[slot]
                end
            end

            util.normalize_module_set(slot_count, module_config_set)

            if not is_default_config then
                mi_gui.update_module_set(e.player, module_button_tags.row_index, config_rows.children[module_button_tags.row_index].module_set, slot_count, module_config_set)
            else
                mi_gui.update_module_set(e.player, 0, e.pdata.gui.main.default_module_set, slot_count, module_config_set)
            end
        end,
        --- @param e MiEventInfo
        destroy_tool = function(e)
            e.player.get_main_inventory().remove { name = "module-inserter-ex", count = 1 }
            mi_gui.close(e)
        end,
        --- @param e MiEventInfo
        add_module_row = function(e)
            --- @type ModuleRowTags
            local module_row_tags = e.event.element.parent.tags
            local row_index = module_row_tags.row_index
            --- @type ModuleConfigSet
            local config_set
            local slots
            if row_index == 0 then
                config_set = e.pdata.active_config.default
                slots = storage.max_slot_count
            else
                local row_config = e.pdata.active_config.rows[row_index]
                config_set = row_config.module_configs
                slots = util.get_target_config_max_slots(row_config.target)
            end
            config_set.configs[#config_set.configs + 1] = types.make_module_config()
            mi_gui.update_module_set(e.player, row_index, e.pdata.gui.main.config_rows.children[row_index].module_set, slots, config_set)
        end,
        --- @param e MiEventInfo
        delete_module_row = function(e)
            --- @type ModuleRowTags
            local module_row_tags = e.event.element.parent.tags
            local row_index = module_row_tags.row_index
            --- @type ModuleConfigSet
            local config_set
            local slots
            if row_index == 0 then
                config_set = e.pdata.active_config.default
                slots = storage.max_slot_count
            else
                local row_config = e.pdata.active_config.rows[row_index]
                config_set = row_config.module_configs
                slots = util.get_target_config_max_slots(row_config.target)
            end
            table.remove(config_set.configs, module_row_tags.module_row_index)
            mi_gui.update_module_set(e.player, row_index, e.pdata.gui.main.config_rows.children[row_index].module_set, slots, config_set)
        end,
    },
    presets = {

        --- @param e MiEventInfo
        add = function(e)
            if e.event.shift then
                mi_gui.add_preset(e.player, e.pdata, true, table.deep_copy(e.pdata.active_config))
            else
                mi_gui.add_preset(e.player, e.pdata, true)
            end
        end,

        --- @param e MiEventInfo
        import = function(e)
            mi_gui.create_import_window(e.pdata, e.player)
        end,
        --- @param e MiEventInfo
        export = function(e)
            mi_gui.create_import_window(e.pdata, e.player, helpers.table_to_json(e.pdata.saved_presets))
        end
    },
    preset = {

        --- @param e MiEventInfo
        load = function(e)
            local pdata = e.pdata
            --- @type PresetRowTags
            local tags = e.event.element.parent.tags
            local index = tags.preset_index

            local preset = pdata.saved_presets[index]
            if not preset then return end

            pdata.active_config = preset
            -- Ensure it is normalized
            util.normalize_preset_config(pdata.active_config)

            pdata.naming = nil -- Cancel any active rename
            mi_gui.update_contents(e.player, pdata)
            mi_gui.update_presets(pdata)

            local keep_open = not e.player.mod_settings["module-inserter-ex-close-after-load"].value
            if not keep_open then
                mi_gui.close(e)
                e.player.print({ "module-inserter-ex-storage-loaded", pdata.active_config.name })
            end
        end,

        --- @param e MiEventInfo
        export = function(e)
            --- @type PresetRowTags
            local tags = e.event.element.parent.tags
            local config = e.pdata.saved_presets[tags.preset_index]
            if not config then return end
            mi_gui.create_import_window(e.pdata, e.player, helpers.table_to_json(config))
        end,
        --- @param e MiEventInfo
        delete = function(e)
            if #e.pdata.saved_presets <= 1 then
                return
            end
            --- @type PresetRowTags
            local tags = e.event.element.parent.tags
            local update_selection = (e.pdata.saved_presets[tags.preset_index] == e.pdata.active_config)
            table.remove(e.pdata.saved_presets, tags.preset_index)
            if update_selection then
                e.pdata.active_config = e.pdata.saved_presets[math.min(#e.pdata.saved_presets, tags.preset_index)]
                mi_gui.update_contents(e.player, e.pdata)
            end
            mi_gui.update_presets(e.pdata)
        end,
        --- @param e MiEventInfo
        rename = function(e)
            --- @type LuaGuiElement
            local parent = e.event.element.parent
            if not parent then return end
            --- @type LuaGuiElement
            local textfield = parent.rename_textfield
            --- @type PresetRowTags
            local tags = parent.tags
            local preset = e.pdata.saved_presets[tags.preset_index]
            if e.pdata.naming == preset then
                -- Confirm the rename
                local text = textfield.text
                if text == "" then
                    e.player.print({ "module-inserter-ex-storage-name-not-set" })
                    return
                end
                e.pdata.naming.name = textfield.text
                e.pdata.naming = nil
            else
                e.pdata.naming = preset
                textfield.text = preset.name
            end
            mi_gui.update_presets(e.pdata)
            textfield.select_all()
            textfield.focus()
        end,
    },
    import = {
        --- @param e MiEventInfo
        import_button = function(e)
            local player = e.player
            local pdata = e.pdata
            local text_box = pdata.gui.import.textbox
            local configs = import_export.import_config(text_box.text)
            if not configs then
                -- TODO maybe add a more detailed failure message
                player.print({ "failed-to-import-string", "Invalid Format" })
                return
            end
            for _, preset in ipairs(configs) do
                mi_gui.add_preset(e.player, e.pdata, false, preset)
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
