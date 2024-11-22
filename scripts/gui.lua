local mod_gui = require("__core__.lualib.mod-gui")

local table = require("__flib__.table")
local gui = require("__flib__.gui")

local import_export = require("scripts.import-export")
local types = require("scripts.types")
local util = require("scripts.util")

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
            style_mods = { right_margin = 6 },
            handler = { [defines.events.on_gui_elem_changed] = mi_gui.handlers.main.choose_assembler },
            elem_type = "entity",
            elem_filters = { { filter = "name", name = storage.module_entities } },
            tooltip = { "module-inserter-choose-assembler" },
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
            style_mods = {
                margin = 5,
                padding = 0,
                horizontal_spacing = 0,
                vertical_spacing = 0,
            },
            children = {},
        }
        for m = 1, slots do
            module_table.children[m] = mi_gui.templates.module_button(module_row_tags, m)
        end
        local row_frame = {
            type = "frame",
            name = "module_row_frame_" .. module_row_index,
            style = "inside_shallow_frame",
            tags = module_row_tags,
            children = {
                module_table
            },
        }
    return row_frame
    end,

    --- @param name string? Name to give this gui element
    --- @return flib.GuiElemDef
    module_set = function(name)
        return {
            type = "flow",
            name = name or "module_set",
            direction = "vertical",
            children = {},
        }
    end,

    --- @param row_index int
    --- @return flib.GuiElemDef
    target_section = function(row_index)
        return {
            type = "frame",
            style = "inside_shallow_frame",
            name = "target_frame",
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
                    column_count = 3,
                    name = "target_section",
                    style_mods = {
                        margin = 5,
                        padding = 0,
                        horizontal_spacing = 0,
                        vertical_spacing = 0,
                        minimal_width = 138,
                        horizontally_stretchable = false,
                    },
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
            style = "deep_frame_in_shallow_frame",
            direction = "horizontal",
            style_mods = {
                margin = 2,
                padding = 2,
                minimal_width = 525,
            },
            children = {
                mi_gui.templates.target_section(index),
            }
        }
    end,

    --- @param config_tmp PresetConfig
    --- @return flib.GuiElemDef
    config_rows = function(config_tmp)
        local config_rows = {}
        for index, _ in ipairs(config_tmp.rows) do
            config_rows[index] = mi_gui.templates.config_row(index)
        end
        return config_rows
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
                    style = "mi_preset_button",
                    handler = mi_gui.handlers.preset.load,
                },
                -- TODO export
                -- {
                --     type = "sprite-button",
                --     style = "tool_button",
                --     sprite = "utility/export_slot",
                --     tooltip = { "module-inserter-export_tt" },
                --     handler = mi_gui.handlers.preset.export,
                -- },
                {
                    type = "sprite-button",
                    name = "delete_button",
                    style = "tool_button_red",
                    sprite = "utility/trash",
                    tooltip = "Delete this preset", -- TODO Translate
                    handler = mi_gui.handlers.preset.delete,
                },
                {
                    type = "sprite-button",
                    name = "rename_button",
                    style = "tool_button",
                    sprite = "utility/rename_icon",
                    tooltip = "Rename this preset", -- TODO Translate
                    handler = mi_gui.handlers.preset.rename,
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
    --- @param title string Window title
    --- @param name string? current name
    --- @return flib.GuiElemDef
    enter_name_window = function(title, name)
        --- @type flib.GuiElemDef
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
                        {
                            type = "label",
                            style = "frame_title",
                            caption = title,
                            elem_mods = { ignored_by_interaction = true } ---@diagnostic disable-line: missing-fields
                        },
                        {
                            type = "empty-widget",
                            style = "flib_titlebar_drag_handle",
                            elem_mods = { ignored_by_interaction = true } ---@diagnostic disable-line: missing-fields
                        },
                        {
                            type = "sprite-button",
                            style = "frame_action_button",
                            sprite = "utility/close",
                            hovered_sprite = "utility/close_black",
                            clicked_sprite = "utility/close_black",
                            handler = mi_gui.handlers.rename.close_button,
                        },
                    }
                },
                {
                    type = "flow",
                    direction = "horizontal",
                    children = {
                        {
                            type = "textfield",
                            name = "rename_textfield",
                            text = name,
                            style_mods = { width = 200 }, ---@diagnostic disable-line: missing-fields
                            icon_selector = true,
                            handler = { [defines.events.on_gui_confirmed] = mi_gui.handlers.rename.confirm,}
                        },
                        {
                            type = "sprite-button",
                            style = "item_and_count_select_confirm",
                            sprite = "utility/enter",
                            tooltip = "Confirm",
                            handler = mi_gui.handlers.rename.confirm,
                        }
                    }
                },
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

    local refs = gui.add(player.gui.screen, {
        {
            type = "frame",
            style_mods = { maximal_height = 750 }, ---@diagnostic disable-line: missing-fields
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
                                                    style_mods = { horizontal_spacing = 0, minimal_height = 51, minimal_width = 430 }, ---@diagnostic disable-line: missing-fields
                                                    children = {
                                                        {
                                                            type = "frame",
                                                            style = "inside_shallow_frame",
                                                            style_mods = { horizontally_stretchable = true, vertically_stretchable = true }, ---@diagnostic disable-line: missing-fields
                                                            children = {
                                                                type = "checkbox",
                                                                name = "default_checkbox",
                                                                caption = "Default Modules",
                                                                state = false,
                                                                style_mods = {
                                                                    margin = 6,
                                                                    horizontally_stretchable = true,
                                                                    vertically_stretchable = true,
                                                                    minimal_width = 99,
                                                                    vertical_align = "center"
                                                                }, ---@diagnostic disable-line: missing-fields
                                                                handler = { [defines.events.on_gui_checked_state_changed] = mi_gui.handlers.main.default_checkbox },
                                                                tooltip = "If checked, will fill any entities not specified below with the modules here", -- TODO move text string to locale
                                                            }
                                                        },
                                                        mi_gui.templates.module_set("default_module_set"),
                                                    }
                                                }
                                            }
                                        },
                                    }
                                },
                                {
                                    type = "flow",
                                    direction = "vertical",
                                    style_mods = { padding = 12, top_padding = 8, vertical_spacing = 10, minimal_height = 444 }, ---@diagnostic disable-line: missing-fields
                                    children = {
                                        {
                                            type = "scroll-pane",
                                            style = "mi_naked_scroll_pane",
                                            name = "config_rows",
                                            children = mi_gui.templates.config_rows(pdata.active_config)
                                        },
                                        mi_gui.templates.pushers.vertical,
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
                                        -- TODO import/export
                                        mi_gui.templates.pushers.horizontal,
                                        -- {
                                        --     type = "sprite-button",
                                        --     style = "tool_button",
                                        --     sprite = "mi_import_string",
                                        --     tooltip = { "module-inserter-import_tt" },
                                        --     handler = mi_gui.handlers.presets.import,
                                        -- },
                                        -- {
                                        --     type = "sprite-button",
                                        --     style = "tool_button",
                                        --     sprite = "utility/export_slot",
                                        --     tooltip = { "module-inserter-export_tt" },
                                        --     handler = mi_gui.handlers.presets.export,
                                        -- },
                                    }
                                },
                                {
                                    type = "flow",
                                    direction = "vertical",
                                    style_mods = { width = 246, padding = 12, top_padding = 8, vertical_spacing = 10 }, ---@diagnostic disable-line: missing-fields
                                    children = {
                                        {
                                            type = "frame",
                                            style = "deep_frame_in_shallow_frame",
                                            children = {
                                                {
                                                    type = "scroll-pane",
                                                    style = "mi_naked_scroll_pane",
                                                    style_mods = { vertically_stretchable = true, minimal_width = 222 }, ---@diagnostic disable-line: missing-fields
                                                    name = "scroll_pane",
                                                }
                                            }
                                        }
                                    }
                                },
                                {
                                    
                                    type = "flow",
                                    direction = "horizontal",
                                    children = {
                                        {
                                            type = "button",
                                            name = "add_preset_button",
                                            caption = "Add Preset",
                                            handler = mi_gui.handlers.presets.add
                                        }
                                    }
                                },
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
        default_module_set = refs.default_module_set,
    }
    pdata.gui.presets = {
        scroll_pane = refs.scroll_pane,
    }

    refs.main_window.force_auto_center()
    mi_gui.update_presets(pdata)
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

    refs.window.force_auto_center()
    local textbox = refs.textbox
    if bp_string then
        textbox.read_only = true
    end
    textbox.select_all()
    textbox.focus()
end

--- @param pdata PlayerConfig
--- @param player LuaPlayer
function mi_gui.create_name_window(pdata, player)
    local current_gui = pdata.gui.rename
    if current_gui and current_gui.window and current_gui.window.valid then
        current_gui.window.destroy()
        pdata.gui.rename = nil
    end
    local refs = gui.add(player.gui.screen, mi_gui.templates.enter_name_window("Enter Name", pdata.naming.name))
    pdata.gui.rename = {
        window = refs.window,
        textfield = refs.rename_textfield,
    }

    refs.window.force_auto_center() -- TODO place it at the button used to open it
    local textfield = refs.rename_textfield
    textfield.select_all()
    textfield.focus()
end

--- @param pdata PlayerConfig
--- @param player LuaPlayer
--- @param save boolean Whether to save the new name
function mi_gui.close_name_window(pdata, player, save)
    local current_gui = pdata.gui.rename
    if current_gui and current_gui.window and current_gui.window.valid then
        if save and pdata.naming then
            local new_name = current_gui.textfield.text
            if new_name == "" then
                player.print({ "module-inserter-storage-name-not-set" })
                return
            end
            pdata.naming.name = new_name
            pdata.naming = nil
            mi_gui.update_presets(pdata)
        end
        current_gui.window.destroy()
        pdata.gui.rename = nil
    end
end


--- @param gui_config_rows LuaGuiElement
--- @param config_tmp PresetConfig
--- @param do_scroll boolean?
function mi_gui.update_rows(gui_config_rows, config_tmp, do_scroll)
    -- Add or destroy rows as needed
    while #gui_config_rows.children < #config_tmp.rows do
        gui.add(gui_config_rows, { mi_gui.templates.config_row(#gui_config_rows.children + 1) })
    end
    while #gui_config_rows.children > #config_tmp.rows do
        gui_config_rows.children[#gui_config_rows.children].destroy()
    end

    for index, row_config in ipairs(config_tmp.rows) do
        mi_gui.update_row(gui_config_rows, row_config, index)
    end

    if do_scroll then
        gui_config_rows.scroll_to_bottom()
    end
end


--- @param module_row LuaGuiElement
--- @param slots int
--- @param module_config ModuleConfig
function mi_gui.update_modules(module_row, slots, module_config)
    local button_table = module_row.children[1]
    slots = slots or 0
    local module_list = module_config.module_list or {}
    --- @type ModuleRowTags
    local module_row_tags = module_row.tags

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
        -- TODO if this is the first slot, and the setting for fill from first is set, add that info to the tooltip
        child.tooltip = module_list[i] and prototypes.item[module_list[i].name].localised_name or { "module-inserter-choose-module" }
    end
end

--- @param row_index int index of the row being updated (0 for the default config)
--- @param module_set LuaGuiElement
--- @param slots int
--- @param config_set ModuleConfigSet
function mi_gui.update_module_set(row_index, module_set, slots, config_set)
    for i, config_row in ipairs(config_set.configs) do
        local module_row = module_set.children[i]
        if not module_row then
            gui.add(module_set, mi_gui.templates.module_row(row_index, i, slots))
        end
        module_row = module_set.children[i]
        mi_gui.update_modules(module_row, slots, config_row)
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
        child.tooltip = util.get_localised_entity_name(target, { "module-inserter-choose-assembler" })
    end
end

--- @param gui_config_rows LuaGuiElement
--- @param row_config RowConfig
--- @param row_index int index of the row config being updated
function mi_gui.update_row(gui_config_rows, row_config, row_index)
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
        if row.module_set then
            for _, elem in pairs(row.module_set.children) do
                elem.destroy()
            end
            row.module_set.destroy()
        end
    else
        local slots = util.get_target_config_max_slots(row_config.target)
        -- Create and update the module section
        if not row.module_set or not row.module_set.valid then
            gui.add(row, mi_gui.templates.module_set())
        end
        mi_gui.update_module_set(row_index, row.module_set, slots, row_config.module_configs)
    end
end

--- @param pdata PlayerConfig
function mi_gui.update_contents(pdata)
    local active_config = pdata.active_config

    pdata.gui.main.default_checkbox.state = active_config.use_default
    if active_config.use_default then
        pdata.gui.main.default_module_set.visible = true
        mi_gui.update_module_set(0, pdata.gui.main.default_module_set, storage.max_slot_count, active_config.default)
    else
        pdata.gui.main.default_module_set.visible = false
    end

    mi_gui.update_rows(pdata.gui.main.config_rows, active_config)
end

--- @param pdata PlayerConfig
--- @param name string? name to use
--- @param select boolean? Whether to select the new preset
--- @param data PresetConfig? data to restore
--- @return boolean
function mi_gui.add_preset(pdata, name, select, data)
    local new_preset = data or types.make_preset_config(name or util.generate_random_name())
    table.insert(pdata.saved_presets, new_preset)
    if select then
        pdata.active_config = new_preset
        mi_gui.update_contents(pdata)
    end
    mi_gui.update_presets(pdata)
    return true
end

--- @param pdata PlayerConfig
function mi_gui.update_presets(pdata)
    local preset_scroll = pdata.gui.presets.scroll_pane
    while #preset_scroll.children > #pdata.saved_presets do
        preset_scroll.children[#preset_scroll.children].destroy()
    end
    while #preset_scroll.children < #pdata.saved_presets do
        gui.add(preset_scroll, { mi_gui.templates.preset_row(#preset_scroll.children + 1) })
    end
    for i, preset_flow in ipairs(preset_scroll.children) do
        local preset_button = preset_flow.select_button
        preset_button.caption = pdata.saved_presets[i].name
        if pdata.saved_presets[i] == pdata.active_config then
            preset_button.style = "mi_preset_button_selected"
        else
            preset_button.style = "mi_preset_button"
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
    pdata.gui_open = false
    pdata.temp_config = nil
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
        -- TODO remove the destroy when done updating gui
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
        revert_changes = function(e, keep_open)
            local temp = e.pdata.temp_config
            if temp then
                e.pdata.active_config = table.deep_copy(temp)
            end
        end,
        --- @param e MiEventInfo
        default_checkbox = function(e)
            e.pdata.active_config.use_default = e.pdata.gui.main.default_checkbox.state
            mi_gui.update_contents(e.pdata)
        end,
        --- @param e MiEventInfo
        clear_all = function(e)
            e.pdata.active_config = types.make_preset_config(e.pdata.active_config.name)
            mi_gui.update_contents(e.pdata)
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
                                e.player.print({ "", prototypes.entity[elem_value].localised_name, " is already configured in this row " })
                            else
                                e.player.print({ "", prototypes.entity[elem_value].localised_name, " is already configured in row ", k })
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

            -- TODO ensure the module set is valid for the entity (probably don't change the entity if there's invalid modules, and show a message)
            util.normalize_preset_config(active_config)

            mi_gui.update_rows(e.pdata.gui.main.config_rows, active_config, do_scroll)
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

            if slot == 1 and e.player.mod_settings["module_inserter_fill_all"].value then
                for i = 2, slot_count do
                    module_config.module_list[i] = module_config.module_list[slot]
                end
            end

            util.normalize_module_set(slot_count, module_config_set)

            if not is_default_config then
                mi_gui.update_module_set(module_button_tags.row_index, config_rows.children[module_button_tags.row_index].module_set, slot_count, module_config_set)
            else
                mi_gui.update_module_set(0, e.pdata.gui.main.default_module_set, slot_count, module_config_set)
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
        add = function(e)
            mi_gui.add_preset(e.pdata, nil, true)
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
                    mi_gui.add_preset(e.pdata, name, false, config)
                else
                    for s_name, data in pairs(config) do
                        mi_gui.add_preset(e.pdata, s_name, false, data)
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
            local pdata = e.pdata
            --- @type PresetRowTags
            local tags = e.event.element.parent.tags
            local index = tags.preset_index

            local preset = pdata.saved_presets[index]
            if not preset then return end

            pdata.active_config = preset
            -- Ensure it is normalized
            util.normalize_preset_config(pdata.active_config)
            pdata.temp_config = table.deep_copy(pdata.active_config)

            mi_gui.update_contents(pdata)
            mi_gui.update_presets(pdata)

            local keep_open = not e.player.mod_settings["module_inserter_close_after_load"].value
            if not keep_open then
                mi_gui.close(e)
                e.player.print({ "module-inserter-storage-loaded", pdata.active_config.name })
            end
        end,

        --- @param e MiEventInfo
        export = function(e)
            local pdata = e.pdata
            local name = e.event.element.parent.select_button.caption
            local index = e.event.element.parent.tags.preset_row
            local config = pdata.saved_presets[index]
            if not config then
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
            if #e.pdata.saved_presets <= 1 then
                return
            end
            --- @type PresetRowTags
            local tags = e.event.element.parent.tags
            local update_selection = (e.pdata.saved_presets[tags.preset_index] == e.pdata.active_config)
            table.remove(e.pdata.saved_presets, tags.preset_index)
            if update_selection then
                e.pdata.active_config = e.pdata.saved_presets[math.min(#e.pdata.saved_presets, tags.preset_index)]
                mi_gui.update_contents(e.pdata)
            end
            mi_gui.update_presets(e.pdata)
        end,
        --- @param e MiEventInfo
        rename = function(e)
            --- @type PresetRowTags
            local tags = e.event.element.parent.tags
            e.pdata.naming = e.pdata.saved_presets[tags.preset_index]
            mi_gui.create_name_window(e.pdata, e.player)
        end,
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
                mi_gui.add_preset(e.pdata, name, false, config)
            else
                for s_name, data in pairs(config) do
                    mi_gui.add_preset(e.pdata, s_name, false, data)
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
    rename = {
        --- @param e MiEventInfo
        close_button = function (e)
            mi_gui.close_name_window(e.pdata, e.player, false)
        end,
        --- @param e MiEventInfo
        confirm = function (e)
            mi_gui.close_name_window(e.pdata, e.player, true)
        end,
    },
}

return mi_gui
